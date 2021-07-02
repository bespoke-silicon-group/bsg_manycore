/**
 *    bsg_manycore_gather_scatter.v
 *
 *    This module does gather-scatter operation. 
 *  
 *    How to use this module
 *    ----------------------------------
 *    - First, vanilla core acquires a lock on this gather-scatter tile.
 *    - The core that acquired the lock sets the configuration, and sends the run packet.
 *      Then, the core creates a reservation locally (lr), and go to sleep (lr.aq).
 *    - The gather-scatter runs the operation. When it's finished, it breaks the reservation on the callee tile,
 *      waking up the tile.
 *    - The tile wakes up and accesses the data, if necessary, and releases the lock.
 *    - The next core acquires the lock, and so on...
 *
 *    EPA map (word addr)
 *    ----------------------------------
 *    0x0     =   RUN (write only)
 *                data[31]    = scatter_not_gather
 *                data[17:0]  = reservation lock addr
 *    0x1     =   access len (write only)
 *    0x2     =   EVA stride (write only) (stride by n words)
 *    0x3     =   EVA start addr (write only)
 *    0x400   =   DMEM address space (1024 words) (read-write)
 *    
 *    **Reading from the write-only locations returns 0xdeadbeef, and has no side-effect.
 *
 *
 */


module bsg_manycore_gather_scatter
  import bsg_manycore_pkg::*;
  #(parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter data_width_p = "inv"
    , parameter addr_width_p = "inv"

    , parameter icache_entries_p = "inv"
    , parameter icache_tag_width_p = "inv"

    , parameter dmem_size_p = "inv" 
    , parameter vcache_size_p = "inv"
    , parameter vcache_block_size_in_words_p = "inv"
    , parameter vcache_sets_p = "inv"

    , parameter num_tiles_x_p = "inv"
    , parameter num_tiles_y_p = "inv"

    , parameter max_out_credits_p = 32 // this is fixed.
    , parameter ep_fifo_els_p = 16

    , parameter reg_id_width_lp = bsg_manycore_reg_id_width_gp
    , parameter reg_els_lp = (2**bsg_manycore_reg_id_width_gp)
  
    , parameter fwd_fifo_els_p = "inv"

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter debug_p = 1
    , parameter branch_trace_en_p = 0
  )
  (
    input clk_i
    , input reset_i

    // mesh network
    , input [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    // my coords
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );


  // localparam
  localparam data_mask_width_lp = (data_width_p>>3);
  localparam credit_counter_width_lp= `BSG_SAFE_CLOG2(max_out_credits_p+1);
  localparam dmem_addr_width_lp = `BSG_SAFE_CLOG2(dmem_size_p);
  localparam access_len_width_lp = `BSG_SAFE_CLOG2(dmem_size_p+1);


  // Instantiate endpoint_standard.
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  logic in_v_lo;
  logic [data_width_p-1:0] in_data_lo;
  logic [data_mask_width_lp-1:0] in_mask_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic in_we_lo;
  bsg_manycore_load_info_s in_load_info_lo;
  bsg_manycore_load_info_s load_info_r, load_info_n;
  logic [x_cord_width_p-1:0] in_src_x_cord_lo;
  logic [y_cord_width_p-1:0] in_src_y_cord_lo;
  logic in_yumi_li;

  logic [data_width_p-1:0] returning_data_li;
  logic returning_v_li;

  bsg_manycore_packet_s out_packet_li;
  logic out_v_li;
  logic out_ready_lo;

  logic [data_width_p-1:0] returned_data_lo;
  logic [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_lo;
  logic returned_v_lo;
  logic returned_yumi_li;

  logic [credit_counter_width_lp-1:0] out_credits_lo;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.fifo_els_p(ep_fifo_els_p)
    ,.max_out_credits_p(max_out_credits_p)  
  ) ep0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    ,.in_v_o(in_v_lo)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_addr_o(in_addr_lo)
    ,.in_we_o(in_we_lo)
    ,.in_load_info_o(in_load_info_lo)
    ,.in_src_x_cord_o(in_src_x_cord_lo)
    ,.in_src_y_cord_o(in_src_y_cord_lo)
    ,.in_yumi_i(in_yumi_li)

    ,.returning_data_i(returning_data_li)
    ,.returning_v_i(returning_v_li)

    ,.out_v_i(out_v_li)
    ,.out_packet_i(out_packet_li)
    ,.out_credit_or_ready_o(out_ready_lo)

    ,.returned_data_r_o(returned_data_lo)
    ,.returned_reg_id_r_o(returned_reg_id_lo)
    ,.returned_v_r_o(returned_v_lo)
    ,.returned_pkt_type_r_o()
    ,.returned_yumi_i(returned_yumi_li)
    ,.returned_fifo_full_o()

    ,.out_credits_o(out_credits_lo)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );


  // local DMEM to store data
  logic dmem_v_li;
  logic dmem_w_li;
  logic [data_width_p-1:0] dmem_data_li;
  logic [dmem_addr_width_lp-1:0] dmem_addr_li;
  logic [data_mask_width_lp-1:0] dmem_mask_li;
  logic [data_width_p-1:0] dmem_data_lo;

  bsg_mem_1rw_sync_mask_write_byte #(
    .data_width_p(data_width_p)
    ,.els_p(dmem_size_p) // TODO: separate this from vanilla core
    ,.latch_last_read_p(1)
  ) dmem0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(dmem_v_li)
    ,.w_i(dmem_w_li)
    ,.data_i(dmem_data_li)
    ,.addr_i(dmem_addr_li)
    ,.write_mask_i(dmem_mask_li)

    ,.data_o(dmem_data_lo)
  );

  logic [data_width_p-1:0] dmem_load_data_lo;

  load_packer lp0 (
    .mem_data_i(dmem_data_lo)
    ,.unsigned_load_i(load_info_r.is_unsigned_op)
    ,.byte_load_i(load_info_r.is_byte_op)
    ,.hex_load_i(load_info_r.is_hex_op)
    ,.part_sel_i(load_info_r.part_sel)
    ,.load_data_o(dmem_load_data_lo)
  );


  // Gather-Scatter CSR
  logic [access_len_width_lp-1:0] access_len_r, access_len_n;
  logic [dmem_addr_width_lp-1:0] stride_r, stride_n;
  logic [data_width_p-1:0] eva_base_r, eva_base_n;

  // address decoding
  wire is_csr_addr        = in_addr_lo[epa_word_addr_width_gp-1] & (in_addr_lo[addr_width_p-1:epa_word_addr_width_gp] == '0);
  wire is_run_addr        = is_csr_addr & (in_addr_lo[0+:epa_word_addr_width_gp-1] == 'd0);
  wire is_access_len_addr = is_csr_addr & (in_addr_lo[0+:epa_word_addr_width_gp-1] == 'd1);
  wire is_stride_addr     = is_csr_addr & (in_addr_lo[0+:epa_word_addr_width_gp-1] == 'd2);
  wire is_eva_base_addr   = is_csr_addr & (in_addr_lo[0+:epa_word_addr_width_gp-1] == 'd3);

  wire is_dmem_addr       = in_addr_lo[dmem_addr_width_lp] & (in_addr_lo[addr_width_p-1:dmem_addr_width_lp+1] == '0);

  // Gather-Scatter FSM
  typedef enum logic [1:0] {
    IDLE
    ,GATHER
    ,SCATTER
    ,WAKEUP
  } gs_state_e; 


  gs_state_e gs_state_r, gs_state_n;
  logic [x_cord_width_p-1:0] src_x_cord_r, src_x_cord_n;
  logic [y_cord_width_p-1:0] src_y_cord_r, src_y_cord_n;
  logic [epa_word_addr_width_gp-1:0] wakeup_addr_r, wakeup_addr_n;


  // sending back response
  logic send_zero_n, send_zero_r;
  logic send_invalid_n, send_invalid_r;
  logic send_dmem_data_n, send_dmem_data_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      {send_zero_r
      ,send_invalid_r
      ,send_dmem_data_r} <= '0;
    end
    else begin
      send_zero_r <= send_zero_n;
      send_invalid_r <= send_invalid_n;
      send_dmem_data_r <= send_dmem_data_n;
    end
  end

  always_comb begin
    returning_data_li = '0;
    returning_v_li = 1'b0;

    if (send_zero_r) begin
      returning_data_li = '0;
      returning_v_li = 1'b1;
    end
    else if (send_invalid_r) begin
      returning_data_li = 'hdeadbeef;
      returning_v_li = 1'b1;
    end
    else if (send_dmem_data_r) begin
      returning_data_li = dmem_load_data_lo;
      returning_v_li = 1'b1;
    end
  end

  // progress counter
  logic counter_clear;
  logic counter_up;
  logic [`BSG_SAFE_CLOG2(dmem_size_p+1)-1:0] count_lo;
  logic [`BSG_SAFE_CLOG2(dmem_size_p+1)-1:0] count_minus_one;

  bsg_counter_clear_up #(
    .max_val_p(dmem_size_p)
    ,.init_val_p(0)
  ) counter0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.clear_i(counter_clear)
    ,.up_i(counter_up)
  
    ,.count_o(count_lo)
  );

  assign count_minus_one = (`BSG_SAFE_CLOG2(dmem_size_p+1))'(count_lo - 'd1);
   
  
  // address logic
  logic [data_width_p-1:0] eva_li;
  logic [x_cord_width_p-1:0] x_cord_lo;
  logic [y_cord_width_p-1:0] y_cord_lo;
  logic [addr_width_p-1:0] epa_lo;
  logic is_invalid_addr_lo;
 
  bsg_manycore_eva_to_npa #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)

    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_sets_p(vcache_sets_p)
  ) eva2npa (
    .eva_i(eva_li)
    ,.tgo_x_i((x_cord_width_p)'(0))  // TODO: enable tile-group addressing?
    ,.tgo_y_i((y_cord_width_p)'(0))

    ,.x_cord_o(x_cord_lo)
    ,.y_cord_o(y_cord_lo)
    ,.epa_o(epa_lo)

    ,.is_invalid_addr_o(is_invalid_addr_lo)
  );

  // gather logic
  // It needs a scoreboard to keep track of how many remote load requests are outstanding,
  // and when the responses return (possibly out of order), it's able to track where in DMEM it needs to be written.
  logic [reg_id_width_lp-1:0] alloc_id_lo;
  logic alloc_v_lo;
  logic alloc_yumi_li;

  logic dealloc_v_li;
  logic [reg_id_width_lp-1:0] dealloc_id_li;

  bsg_id_pool #(
    .els_p(reg_els_lp)
  ) pool0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.alloc_id_o(alloc_id_lo)
    ,.alloc_v_o(alloc_v_lo)
    ,.alloc_yumi_i(alloc_yumi_li)

    ,.dealloc_v_i(dealloc_v_li)
    ,.dealloc_id_i(dealloc_id_li)
  );

  logic [dmem_addr_width_lp-1:0] dest_dmem_addr;
  bsg_mem_1r1w #(
    .width_p(dmem_addr_width_lp)
    ,.els_p(reg_els_lp)
    ,.read_write_same_addr_p(1)
  ) mem0 (
    .w_clk_i(clk_i)
    ,.w_reset_i(reset_i)

    ,.w_v_i(alloc_yumi_li)
    ,.w_addr_i(alloc_id_lo)
    ,.w_data_i(count_lo[0+:dmem_addr_width_lp])

    ,.r_v_i() // unused
    ,.r_addr_i(returned_reg_id_lo)
    ,.r_data_o(dest_dmem_addr)
  );



  // FSM comb logic
  wire scatter_not_gather = in_data_lo[data_width_p-1];

  always_comb begin

    load_info_n = load_info_r;

    access_len_n = access_len_r;
    stride_n = stride_r;
    eva_base_n = eva_base_r;
    
    gs_state_n = gs_state_r;
    src_x_cord_n = src_x_cord_r;
    src_y_cord_n = src_y_cord_r;
    wakeup_addr_n = wakeup_addr_r;

    in_yumi_li = 1'b0;

    dmem_v_li = 1'b0;
    dmem_w_li = 1'b0;
    dmem_addr_li = '0;
    dmem_data_li = '0;
    dmem_mask_li = '0;

    send_zero_n = 1'b0;
    send_invalid_n = 1'b0;
    send_dmem_data_n = 1'b0;

    out_v_li = 1'b0;
    out_packet_li = '0;
    out_packet_li.src_y_cord = my_y_i;
    out_packet_li.src_x_cord = my_x_i;

    counter_clear = 1'b0;
    counter_up = 1'b0; 

    eva_li = '0;

    returned_yumi_li = 1'b0;

    alloc_yumi_li = 1'b0;
    dealloc_v_li = 1'b0;
    dealloc_id_li = '0;

    case (gs_state_r)

      // During IDLE state, tiles can access DMEM, set configurations, and start new gather or scatter ops.
      IDLE: begin

        if (in_v_lo) begin
          if (in_we_lo) begin
            // incoming store
            if (is_run_addr) begin
              in_yumi_li = 1'b1;
              send_zero_n = 1'b1;

              src_x_cord_n = in_src_x_cord_lo;
              src_y_cord_n = in_src_y_cord_lo;
              wakeup_addr_n = in_data_lo[2+:epa_word_addr_width_gp];
   
              // if it's scatter, read the first word as it switches the state.
              dmem_v_li = scatter_not_gather;
              dmem_w_li = 1'b0;
              dmem_addr_li = '0;
    
              counter_clear = 1'b1;
              counter_up = scatter_not_gather;

              gs_state_n = scatter_not_gather
                ? SCATTER
                : GATHER;
            end
            else if (is_access_len_addr) begin
              in_yumi_li = 1'b1;
              send_zero_n = 1'b1;
              access_len_n = in_data_lo[0+:access_len_width_lp];
            end
            else if (is_stride_addr) begin
              in_yumi_li = 1'b1;
              send_zero_n = 1'b1;
              stride_n = in_data_lo[0+:dmem_addr_width_lp];
            end
            else if (is_eva_base_addr) begin
              in_yumi_li = 1'b1;
              send_zero_n = 1'b1;
              eva_base_n = in_data_lo;
            end
            else if (is_dmem_addr) begin
              in_yumi_li = 1'b1;
              send_zero_n = 1'b1;
              dmem_v_li = 1'b1;
              dmem_w_li = 1'b1;
              dmem_addr_li = in_addr_lo[0+:dmem_addr_width_lp];
              dmem_mask_li = in_mask_lo; 
              dmem_data_li = in_data_lo;
            end
            else begin
              // no side effect, you just get a credit back.
              // it will trigger an assertion though.
              in_yumi_li = 1'b1;
              send_zero_n = 1'b1;
            end
          end
          else begin
            // incoming load
            if (is_dmem_addr) begin
              // reading DMEM
              in_yumi_li = 1'b1;
              send_dmem_data_n = 1'b1;
              dmem_v_li = 1'b1; 
              dmem_w_li = 1'b0; 
              dmem_addr_li = in_addr_lo[0+:dmem_addr_width_lp];
            end
            else begin
              // no side effect, you just get invalid data back.
              // it will trigger an assertion though.
              in_yumi_li = 1'b1;
              send_invalid_n = 1'b1;
            end
          end
        end

      end
      
      // gather reads from the network, and store them in DMEM.
      GATHER: begin
        eva_li = eva_base_r + ((count_lo*stride_r) << 2);

        out_v_li = alloc_v_lo & (out_credits_lo != '0);
        out_packet_li.addr = epa_lo;
        out_packet_li.op = e_remote_load;
        out_packet_li.reg_id = alloc_id_lo;
        out_packet_li.payload = '0; // normal integer load.
        out_packet_li.y_cord = y_cord_lo;
        out_packet_li.x_cord = x_cord_lo;

        alloc_yumi_li = out_v_li & out_ready_lo & alloc_v_lo;

        counter_up = out_v_li & out_ready_lo & alloc_v_lo & (count_lo != access_len_r-1);
        counter_clear = out_v_li & out_ready_lo & alloc_v_lo & (count_lo == access_len_r-1);

        returned_yumi_li = returned_v_lo;
        dmem_v_li = returned_v_lo;
        dmem_w_li = 1'b1;
        dmem_addr_li = dest_dmem_addr;
        dmem_mask_li = {data_mask_width_lp{1'b1}};
        dmem_data_li = returned_data_lo;
        dealloc_v_li = returned_v_lo;
        dealloc_id_li = returned_reg_id_lo;

        gs_state_n = (out_ready_lo & out_v_li & (count_lo == access_len_r-1))
          ? WAKEUP
          : GATHER;
      end

      // scatter reads from DMEM, and scatter them across the network.
      SCATTER: begin

        eva_li = eva_base_r + ((count_minus_one*stride_r)<< 2);
    
        out_v_li = (out_credits_lo != '0);
        out_packet_li.addr = epa_lo;
        out_packet_li.op = e_remote_store;
        out_packet_li.op_ex = 4'b1111;
        out_packet_li.reg_id = '0;
        out_packet_li.payload = dmem_data_lo;
        out_packet_li.y_cord = y_cord_lo;
        out_packet_li.x_cord = x_cord_lo;
      
        dmem_v_li = out_v_li & out_ready_lo & (count_lo != access_len_r);
        dmem_w_li = 1'b0;
        dmem_addr_li = count_lo;

        counter_up = out_v_li & out_ready_lo & (count_lo != access_len_r);
        counter_clear = out_v_li & out_ready_lo & (count_lo == access_len_r);
        
        gs_state_n = (out_v_li & out_ready_lo & (count_lo == access_len_r))
          ? WAKEUP
          : SCATTER;

      end
  
      // wakeup goes out after all the credits are restored.
      WAKEUP: begin
        out_v_li = (out_credits_lo == max_out_credits_p);
        out_packet_li.addr = {{(addr_width_p-epa_word_addr_width_gp){1'b0}}, wakeup_addr_r};
        out_packet_li.op = e_remote_store;
        out_packet_li.op_ex = 4'b1111;
        out_packet_li.reg_id = '0;
        out_packet_li.payload = 'd1; // wake up by storing 1.
        out_packet_li.y_cord = src_y_cord_r;
        out_packet_li.x_cord = src_x_cord_r;

        // there could still be data returning from gather.
        returned_yumi_li = returned_v_lo;
        dmem_v_li = returned_v_lo; 
        dmem_w_li = 1'b1;
        dmem_addr_li = dest_dmem_addr;
        dmem_mask_li = {data_mask_width_lp{1'b1}};
        dmem_data_li = returned_data_lo;

        dealloc_v_li = returned_v_lo;
        dealloc_id_li = returned_reg_id_lo;

        gs_state_n = (out_v_li & out_ready_lo)
          ? IDLE
          : WAKEUP;
      end

      // should never happen.
      default: begin
        gs_state_n = IDLE;
      end

    endcase 
  end



  // sequential
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      load_info_r <= '0;
      access_len_r <= '0;
      stride_r <= '0;
      eva_base_r <= '0;
      
      gs_state_r <= IDLE;
      src_x_cord_r <= '0;
      src_y_cord_r <= '0;
      wakeup_addr_r <= '0;
    end
    else begin
      load_info_r <= load_info_n;
      access_len_r <= access_len_n;
      stride_r <= stride_n;
      eva_base_r <= eva_base_n;

      gs_state_r <= gs_state_n;
      src_x_cord_r <= src_x_cord_n;
      src_y_cord_r <= src_y_cord_n;
      wakeup_addr_r <= wakeup_addr_n;
    end
  end

  // synopsys translate_off
  localparam debug_lp = 1;

  always_ff @ (negedge clk_i) begin
    if (debug_lp & ~reset_i) begin
      if (in_v_lo & in_we_lo & is_access_len_addr)
        $display("[GATHER-SCATTER] setting access_len = %d", in_data_lo);

      if (in_v_lo & in_we_lo & is_stride_addr)
        $display("[GATHER-SCATTER] setting stride = %d", in_data_lo);

      if (in_v_lo & in_we_lo & is_eva_base_addr)
        $display("[GATHER-SCATTER] setting EVA base = %x", in_data_lo);

      if (in_v_lo & in_we_lo & is_run_addr)
        $display("[GATHER-SCATTER] RUN: src_x=%0d, src_y=%0d scatter_not_gather=%0d, wakeup_addr=%0x",
          in_src_x_cord_lo, in_src_y_cord_lo, scatter_not_gather, wakeup_addr_n);
    end
  end

  // synopsys translate_on



endmodule
