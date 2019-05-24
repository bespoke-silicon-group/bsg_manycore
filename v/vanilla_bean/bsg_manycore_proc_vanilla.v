/**
 *    bsg_manycore_proc_vanilla.v
 *
 */

`include "bsg_manycore_packet.vh"
`include "definitions.vh"
`include "parameters.vh"

module bsg_manycore_proc_vanilla
  #(parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter data_width_p = "inv"
    , parameter addr_width_p = "inv"
    , parameter load_id_width_p = "inv"

    , parameter icache_tag_width_p = "inv"
    , parameter icache_entries_p = "inv"

    , parameter dmem_size_p = "inv"

    , parameter dram_ch_addr_width_p = "inv"
    , parameter epa_byte_addr_width_p = "inv"
    , parameter dram_ch_start_col_p = 0

    , parameter max_out_credits_p = 32
    , parameter proc_fifo_els_p = 4
    , parameter debug_p = 1

    , localparam credit_counter_width_lp=$clog2(max_out_credits_p+1)
    , localparam icache_addr_width_lp = `BSG_SAFE_CLOG2(icache_entries_p)
    , localparam dmem_addr_width_lp = `BSG_SAFE_CLOG2(dmem_size_p)
    , localparam pc_width_lp=(icache_addr_width_lp+icache_tag_width_p)
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam reg_addr_width_lp=RV32_reg_addr_width_gp

    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)

  )
  (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // endpoint standard
  //
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p,
    x_cord_width_p, y_cord_width_p, load_id_width_p);

  logic in_v_lo;
  logic in_we_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic [data_width_p-1:0] in_data_lo;
  logic [(data_width_p>>3)-1:0] in_mask_lo;
  logic in_yumi_li;

  logic returning_data_v_li;
  logic [data_width_p-1:0] returning_data_li;

  bsg_manycore_packet_s out_packet_li;
  logic out_v_li;
  logic out_ready_lo;

  logic returned_v_r_lo;
  logic returned_yumi_li;
  logic [data_width_p-1:0] returned_data_r_lo;
  logic [load_id_width_p-1:0] returned_load_id_r_lo;
  logic returned_fifo_full_lo;

  logic [credit_counter_width_lp-1:0] out_credits_lo;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.load_id_width_p(load_id_width_p)

    ,.fifo_els_p(proc_fifo_els_p)
    ,.max_out_credits_p(max_out_credits_p)
    ,.returned_fifo_p(1)
    ,.debug_p(debug_p)
  ) endp (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    // rx
    ,.in_v_o(in_v_lo)
    ,.in_we_o(in_we_lo)
    ,.in_addr_o(in_addr_lo)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_yumi_i(in_yumi_li)
    ,.in_src_x_cord_o()
    ,.in_src_y_cord_o()

    ,.returning_v_i(returning_data_v_li)
    ,.returning_data_i(returning_data_li)

    // tx
    ,.out_packet_i(out_packet_li)
    ,.out_v_i(out_v_li)
    ,.out_ready_o(out_ready_lo)

    ,.returned_v_r_o(returned_v_r_lo)
    ,.returned_data_r_o(returned_data_r_lo)
    ,.returned_load_id_r_o(returned_load_id_r_lo)
    ,.returned_fifo_full_o(returned_fifo_full_lo)
    ,.returned_yumi_i(returned_yumi_li)

    ,.out_credits_o(out_credits_lo)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );


  // RX unit
  //
  logic remote_dmem_v_lo;
  logic remote_dmem_w_lo;
  logic [dmem_addr_width_lp-1:0] remote_dmem_addr_lo;
  logic [data_mask_width_lp-1:0] remote_dmem_mask_lo;
  logic [data_width_p-1:0] remote_dmem_data_lo;
  logic [data_width_p-1:0] remote_dmem_data_li;
  logic remote_dmem_yumi_li;

  logic icache_v_lo;
  logic [pc_width_lp-1:0] icache_pc_lo;
  logic [data_width_p-1:0] icache_instr_lo;
  logic icache_yumi_li;

  logic freeze;
  logic [x_cord_width_p-1:0] tgo_x;
  logic [y_cord_width_p-1:0] tgo_y;
  logic [pc_width_lp-1:0] pc_init_val;

  network_rx #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
  ) rx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.v_i(in_v_lo)
    ,.w_i(in_we_lo)
    ,.addr_i(in_addr_lo)
    ,.data_i(in_data_lo)
    ,.mask_i(in_mask_lo)
    ,.yumi_o(in_yumi_li)

    ,.returning_data_o(returning_data_li)
    ,.returning_data_v_o(returning_data_v_li)

    ,.remote_dmem_v_o(remote_dmem_v_lo)
    ,.remote_dmem_w_o(remote_dmem_w_lo)
    ,.remote_dmem_addr_o(remote_dmem_addr_lo)
    ,.remote_dmem_data_o(remote_dmem_data_lo)
    ,.remote_dmem_mask_o(remote_dmem_mask_lo)
    ,.remote_dmem_data_i(remote_dmem_data_li)
    ,.remote_dmem_yumi_i(remote_dmem_yumi_li)

    ,.icache_v_o(icache_v_lo)
    ,.icache_pc_o(icache_pc_lo)
    ,.icache_instr_o(icache_instr_lo)
    ,.icache_yumi_i(icache_yumi_li)

    ,.freeze_o(freeze)
    ,.tgo_x_o(tgo_x)
    ,.tgo_y_o(tgo_y)
    ,.pc_init_val_o(pc_init_val)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );


  // TX unit
  //
  remote_req_s remote_req;
  logic remote_req_v;
  logic remote_req_yumi;

  logic ifetch_v_lo;
  logic [data_width_p-1:0] ifetch_instr_lo;

  logic [reg_addr_width_lp-1:0] float_remote_load_resp_rd_lo;
  logic [data_width_p-1:0] float_remote_load_resp_data_lo;
  logic float_remote_load_resp_v_lo;

  logic [reg_addr_width_lp-1:0] int_remote_load_resp_rd_lo;
  logic [data_width_p-1:0] int_remote_load_resp_data_lo;
  logic int_remote_load_resp_v_lo;
  logic int_remote_load_resp_force_lo;
  logic int_remote_load_resp_yumi_li;



  network_tx #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)

    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)

    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)

    ,.max_out_credits_p(max_out_credits_p)
  ) tx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.out_packet_o(out_packet_li)
    ,.out_v_o(out_v_li)
    ,.out_ready_i(out_ready_lo)

    ,.returned_v_i(returned_v_r_lo)
    ,.returned_data_i(returned_data_r_lo)
    ,.returned_load_id_i(returned_load_id_r_lo)
    ,.returned_fifo_full_i(returned_fifo_full_lo)
    ,.returned_yumi_o(returned_yumi_li)

    ,.tgo_x_i(tgo_x)
    ,.tgo_y_i(tgo_y) 
    ,.out_credits_i(out_credits_lo)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)

    ,.remote_req_i(remote_req)
    ,.remote_req_v_i(remote_req_v)
    ,.remote_req_yumi_o(remote_req_yumi)

    ,.ifetch_v_o(ifetch_v_lo)
    ,.ifetch_instr_o(ifetch_instr_lo)

    ,.float_remote_load_resp_rd_o(float_remote_load_resp_rd_lo)
    ,.float_remote_load_resp_data_o(float_remote_load_resp_data_lo)
    ,.float_remote_load_resp_v_o(float_remote_load_resp_v_lo)

    ,.int_remote_load_resp_rd_o(int_remote_load_resp_rd_lo)
    ,.int_remote_load_resp_data_o(int_remote_load_resp_data_lo)
    ,.int_remote_load_resp_v_o(int_remote_load_resp_v_lo)
    ,.int_remote_load_resp_force_o(int_remote_load_resp_force_lo)
    ,.int_remote_load_resp_yumi_i(int_remote_load_resp_yumi_li)

  );

<<<<<<< HEAD
  // convert the core_to_mem structure to signals.


  //+-----------------------------------------------------
  //|Returned data arbitration between the local memory 
  //|and the network.
  //+-----------------------------------------------------

  // Returned buffer signals
  logic returned_buf_v;
  logic [data_width_p-1:0] returned_data_buf;
  logic [load_id_width_p-1:0] returned_load_id_buf;

  // Buffer full signal to the core. Core immediately yummies 
  // when this signal is high.
  logic buf_full_to_core;
  assign buf_full_to_core = (returned_fifo_full_lo | returned_buf_v);

  // Yumi to the network and not local memory
  logic yumi_to_network;
  assign yumi_to_network = from_mem_yumi_lo & ~core_mem_rv;

  logic buffer_returned_data;
  assign buffer_returned_data = returned_fifo_full_lo & (core_mem_rv | returned_buf_v);

  // Yumi to returned fifo
  assign returned_yumi_li = buffer_returned_data 
                              | (yumi_to_network & ~returned_buf_v);
                                                            
  // Returned data buffer
  always_ff @ (posedge clk_i) begin                                                     
    if (reset_i) begin                                       
      returned_buf_v <= 1'b0;
      returned_data_buf <= data_width_p'(0);
      returned_load_id_buf <= load_id_width_p'(0);
    end
    else begin
      // Buffer the data when returned fifo is full and local mem
      // or returend data is valid as they have higher priority. 
      // One level of buffering is sufficient because core will not
      // issue new local requests when buf_full_to_core is asserted.
      if(buffer_returned_data) begin
        returned_buf_v <= 1'b1;
        returned_data_buf <= returned_data_r_lo;
        returned_load_id_buf <= returned_load_id_r_lo;
      end
      else if (yumi_to_network) begin
        returned_buf_v <= 1'b0;
      end
    end
  end

  always_comb begin
    mem_to_core.buf_full = buf_full_to_core;

    // local mem has the highest priority
    if(core_mem_rv) begin
      from_mem_v_li = 1'b1;
      mem_to_core.read_data = core_mem_rdata;
      mem_to_core.load_info = local_load_id_r;
    end else if(returned_buf_v) begin
      from_mem_v_li = 1'b1;
      mem_to_core.read_data = returned_data_buf;
      mem_to_core.load_info = returned_load_id_buf;
    end else begin
      from_mem_v_li = returned_v_r_lo;
      mem_to_core.read_data = returned_data_r_lo;
      mem_to_core.load_info = returned_load_id_r_lo;
    end
  end

      

  wire out_request;

  bsg_manycore_pkt_encode #(
    .x_cord_width_p(x_cord_width_p)
=======
  // Vanilla Core
  //
  vanilla_core #(
    .data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.x_cord_width_p(x_cord_width_p)
>>>>>>> network refactor
    ,.y_cord_width_p(y_cord_width_p)
  ) vcore (
    .clk_i(clk_i)
    ,.reset_i(reset_i | freeze)

    ,.pc_init_val_i(pc_init_val)
    
    ,.remote_req_o(remote_req)
    ,.remote_req_v_o(remote_req_v)
    ,.remote_req_yumi_i(remote_req_yumi)

    ,.icache_v_i(icache_v_lo)
    ,.icache_pc_i(icache_pc_lo)
    ,.icache_instr_i(icache_instr_lo)
    ,.icache_yumi_o(icache_yumi_li)

    ,.ifetch_v_i(ifetch_v_lo)
    ,.ifetch_instr_i(ifetch_instr_lo)

    ,.remote_dmem_v_i(remote_dmem_v_lo)
    ,.remote_dmem_w_i(remote_dmem_w_lo)
    ,.remote_dmem_addr_i(remote_dmem_addr_lo)
    ,.remote_dmem_data_i(remote_dmem_data_lo)
    ,.remote_dmem_mask_i(remote_dmem_mask_lo)
    ,.remote_dmem_data_o(remote_dmem_data_li)
    ,.remote_dmem_yumi_o(remote_dmem_yumi_li)

    ,.float_remote_load_resp_rd_i(float_remote_load_resp_rd_lo)
    ,.float_remote_load_resp_data_i(float_remote_load_resp_data_lo)
    ,.float_remote_load_resp_v_i(float_remote_load_resp_v_lo)

    ,.int_remote_load_resp_rd_i(int_remote_load_resp_rd_lo)
    ,.int_remote_load_resp_data_i(int_remote_load_resp_data_lo)
    ,.int_remote_load_resp_v_i(int_remote_load_resp_v_lo)
    ,.int_remote_load_resp_force_i(int_remote_load_resp_force_lo)
    ,.int_remote_load_resp_yumi_o(int_remote_load_resp_yumi_li)

    ,.outstanding_req_i(out_credits_lo != max_out_credits_p)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );

  assign load_returning_data = xbar_port_data_out[0];
  assign core_mem_rdata = xbar_port_data_out[1];
  assign core_mem_yumi = xbar_port_yumi_out[1];
  assign in_yumi_li = xbar_port_yumi_out[0] | remote_store_icache | is_config_op;
  assign to_mem_yumi_li = (xbar_port_yumi_out[1] | launching_out);
  // ----------------------------------------------------------------------------------------
  // Handle the control registers
  // ----------------------------------------------------------------------------------------
                                         
  wire is_freeze_addr = {1'b0, in_addr_lo[epa_word_addr_width_lp-2:0]} == epa_word_addr_width_lp'(`CSR_FREEZE);
  wire is_tgo_x_addr = {1'b0, in_addr_lo[epa_word_addr_width_lp-2:0]} == epa_word_addr_width_lp'(`CSR_TGO_X);
  wire is_tgo_y_addr = {1'b0, in_addr_lo[epa_word_addr_width_lp-2:0]} == epa_word_addr_width_lp'(`CSR_TGO_Y);
  wire is_config_decoded = is_freeze_addr | is_tgo_x_addr | is_tgo_y_addr;

  // freeze register
  wire freeze_op = is_config_op & is_freeze_addr & in_data_lo[0] ;
  wire unfreeze_op = is_config_op & is_freeze_addr & (~in_data_lo[0]);

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      CSR_FREEZE_r <= freeze_init_p;
    end
    else
    if (freeze_op | unfreeze_op) begin
      // synopsys translate_off
      $display("## CSR_FREEZE_r <= %x (%m)", in_data_lo[0]);
      // synopsys translate_on
      CSR_FREEZE_r <= in_data_lo[0];
    end
  end
   
  always_ff @ (posedge clk_i) begin
    if (is_config_op & is_tgo_x_addr & in_we_lo) begin
      CSR_TGO_X_r <= x_cord_width_p'(in_data_lo);  
    end

    if (is_config_op & is_tgo_y_addr & in_we_lo) begin
      CSR_TGO_Y_r <= y_cord_width_p'(in_data_lo);
    end

  end


  // ----------------------------------------------------------------------------------------
  // Handle the returning data/credit back to the network
  // ----------------------------------------------------------------------------------------
  wire store_yumi = in_yumi_li & in_we_lo;
  wire CSR_load_yumi = in_v_lo & is_config_decoded & (~in_we_lo);
  wire [data_width_p-1:0] CSR_load_data = is_tgo_x_addr ? CSR_TGO_X_r : CSR_TGO_Y_r;

  //delay the response for store for 1 cycle
  always_ff @ (posedge clk_i) 
    if (reset_i)
      delayed_returning_v_r <= 1'b0;
    else
      delayed_returning_v_r <= store_yumi | CSR_load_yumi;

  always_ff @ (posedge clk_i) begin
    delayed_returning_data_r <= CSR_load_yumi 
      ? CSR_load_data
      : in_data_lo;
  end

  assign returning_v = load_returning_v | delayed_returning_v_r;
  assign returning_data = delayed_returning_v_r
    ? delayed_returning_data_r
    : load_returning_data;



  // synopsys translate_off

  bsg_manycore_packet_s data_o_debug;
  assign data_o_debug = out_packet_li;

  if (debug_p)
  // you can use this format to log packets coming from a node
     always @(negedge clk_i)
       begin
          if (launching_out)
            $display("# y,x=(%x,%x) PROC sending packet (addr=%x, op=%x, op_ex=%x, data=%x, y_cord=%x, x_cord=%x\n%b"
                     , my_y_i
                     , my_x_i
                     , data_o_debug.addr
                     , data_o_debug.op
                     , data_o_debug.op_ex
                     , data_o_debug.payload
                     , data_o_debug.y_cord
                     , data_o_debug.x_cord
                     , out_packet_li
                     );
       end


   always @(negedge clk_i)
     begin
        if ( remote_invalid_addr)
              begin
                 $error("# ERROR y,x=(%x,%x) remote access addr (%x) is invalid",my_y_i,my_x_i,in_addr_lo*4);
                 $finish();
              end
     end


   always @(negedge clk_i)
     begin
        if (xbar_port_v_in[1])
          assert (core_mem_addr[30:2] < ((1 << icache_addr_width_lp) + (dmem_size_p)))
            else
              begin
                 $error("# ERROR y,x=(%x,%x) local store addr (%x) past end of data memory (%x)"
                        ,my_y_i,my_x_i,core_mem_addr,4*((1 << icache_addr_width_lp)+(dmem_size_p)));
                 $finish();
              end
     end

  always_ff@(negedge clk_i)
        if ( is_config_op  & (~is_config_decoded)) begin
                $error("## Accessing Non-existing CSR Address = %h", in_addr_lo );
                $finish();
        end

  always_ff@(negedge clk_i)
        if ( (delayed_returning_v_r & load_returning_v) == 1'b1 ) begin
                $error(" Store returning and Load returning happens at the same time!" );
                $finish();
        end

  always_ff @ (negedge clk_i) begin
    if(~reset_i) begin
      assert(~(core_mem_rv & returned_buf_v & buf_full_to_core))
      else begin
        $error("# ERROR data lost due to contention between local and remote loads");
      end
    end
  end
  // synopsys translate_on
endmodule
