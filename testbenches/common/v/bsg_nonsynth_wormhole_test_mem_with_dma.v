module bsg_nonsynth_wormhole_test_mem_with_dma
  import bsg_manycore_pkg::*;
  #(parameter vcache_data_width_p = "inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_dma_data_width_p="inv"
    , parameter num_vcaches_p = "inv" // how many vcaches are mapped to this test mem?
    , parameter lg_num_vcaches_lp = `BSG_SAFE_CLOG2(num_vcaches_p)
   
    , parameter wh_cid_width_p="inv"
    , parameter wh_flit_width_p="inv"
    , parameter wh_cord_width_p="inv"
    , parameter wh_len_width_p="inv"
    , parameter wh_ruche_factor_p="inv"

    // determines address hashing based on cid and src_cord
    , parameter no_concentration_p=0

    , parameter data_len_lp = (vcache_data_width_p*vcache_block_size_in_words_p/vcache_dma_data_width_p)
    , parameter longint unsigned mem_size_p = "inv"   // size of memory in bytes
    , parameter mem_els_lp = mem_size_p/(vcache_dma_data_width_p/8)
    , parameter mem_addr_width_lp = `BSG_SAFE_CLOG2(mem_els_lp)

    , parameter lg_wh_ruche_factor_lp = `BSG_SAFE_CLOG2(wh_ruche_factor_p)

    , parameter count_width_lp = `BSG_SAFE_CLOG2(data_len_lp)

    , parameter block_offset_width_lp = `BSG_SAFE_CLOG2((vcache_data_width_p>>3)*vcache_block_size_in_words_p)

    , parameter wh_link_sif_width_lp =
      `bsg_ready_and_link_sif_width(wh_flit_width_p)

    , parameter id_p = "inv"
  )
  (
    input clk_i
    , input reset_i

    , input  [wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [wh_link_sif_width_lp-1:0] wh_link_sif_o
  );

  // dma mem
  localparam dma_mem_els_lp = mem_els_lp/data_len_lp;
  localparam dma_mem_addr_width_lp = `BSG_SAFE_CLOG2(dma_mem_els_lp);  
  localparam dma_mem_data_width_lp = vcache_dma_data_width_p * data_len_lp;  

  logic dma_mem_w;
  logic dma_mem_v;
  
  logic [dma_mem_addr_width_lp-1:0] dma_mem_addr;
  logic [dma_mem_data_width_lp-1:0] dma_mem_w_data;
  logic [dma_mem_data_width_lp-1:0] dma_mem_r_data;  
  
  bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma
    #(.width_p(dma_mem_data_width_lp)
      ,.els_p(dma_mem_els_lp)
      ,.id_p(id_p))
  dma_mem
    (
     .clk_i(clk_i)
     ,.reset_i(reset_i)
     
     ,.v_i(dma_mem_v)
     ,.w_i(dma_mem_w)

     ,.addr_i(dma_mem_addr)

     ,.data_o(dma_mem_r_data)

     ,.data_i(dma_mem_w_data)
     ,.w_mask_i('1)
     );

  // memory
  logic mem_we;
  logic [mem_addr_width_lp-1:0] mem_addr;
  logic [vcache_dma_data_width_p-1:0] mem_w_data;
  logic [vcache_dma_data_width_p-1:0] mem_r_data;
  logic [vcache_dma_data_width_p-1:0] mem_r [mem_els_lp-1:0];  

  always_ff @ (posedge clk_i) begin
    if (mem_we) begin
      mem_r[mem_addr] <= mem_w_data;
    end
  end

  assign mem_r_data = mem_r[mem_addr];


  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  wh_link_sif_s wh_link_sif_in;
  wh_link_sif_s wh_link_sif_out;
  assign wh_link_sif_in = wh_link_sif_i;
  assign wh_link_sif_o = wh_link_sif_out;


  `declare_bsg_manycore_vcache_wh_header_flit_s(wh_flit_width_p,wh_cord_width_p,wh_len_width_p,wh_cid_width_p);

  bsg_manycore_vcache_wh_header_flit_s header_flit_in;
  assign header_flit_in = wh_link_sif_in.data;


  // wormhole write data -> dma mem write data
  logic wh_w_data_v_li;
  logic sipo_ready_and_lo;
  logic sipo_v_lo;
  logic wh_w_data_read_and_li;
  logic [vcache_dma_data_width_p-1:0] wh_w_data;

  bsg_serial_in_parallel_out_passthrough
    #(.width_p(vcache_dma_data_width_p)
      ,.els_p(data_len_lp))
  wh2dmamem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(wh_w_data_v_li)
     ,.ready_and_o(sipo_ready_and_lo)
     ,.data_i(wh_w_data)
     
     ,.v_o(sipo_v_lo)
     ,.ready_and_i('1)
     ,.data_o(dma_mem_w_data)
     );

  assign dma_mem_w = sipo_v_lo;
  assign wh_w_data = wh_link_sif_in.data;
  
  //assign dma_mem_v = dma_mem_r_data_v_r | sipo_v_lo;
  // assert ~wh_w_data_v_li | sipo_ready_and_lo

  // dma mem read data -> wormhole read data
  logic dma_mem_r_data_v_r;
  logic dma_mem_r_data_v_n;  
  logic piso_ready_and_lo;
  
  logic piso_v_lo;
  logic wh_r_data_ready_and_li;
  logic [vcache_dma_data_width_p-1:0] wh_r_data;
  
  bsg_parallel_in_serial_out_passthrough
    #(.width_p(vcache_dma_data_width_p)
      ,.els_p(data_len_lp))
  dmamem2wh
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(dma_mem_r_data_v_r)
     ,.ready_and_o(piso_ready_and_lo)
     ,.data_i(dma_mem_r_data)

     ,.v_o(piso_v_lo)
     ,.ready_and_i(wh_r_data_ready_and_li)
     ,.data_o(wh_r_data)
     );  

  assign dma_mem_r_data_v_n = dma_mem_v & ~dma_mem_w;

  // assert ~dma_mem_r_data_v_n | piso_ready_and_lo

  // flit counter
  logic clear_li;
  logic up_li;
  logic [count_width_lp-1:0] count_lo;

  bsg_counter_clear_up #(
    .max_val_p(data_len_lp-1)
    ,.init_val_p(0)
  ) count (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(clear_li)
    ,.up_i(up_li)
    ,.count_o(count_lo)
  );


  typedef enum logic [2:0] {
    RESET
    ,READY
    ,RECV_ADDR
    ,RECV_EVICT_DATA
    ,SEND_FILL_HEADER
    ,SEND_FILL_DATA
  } mem_state_e;

  mem_state_e mem_state_r, mem_state_n;
  logic write_not_read_r, write_not_read_n;
  logic [wh_flit_width_p-1:0] addr_r, addr_n;
  logic [wh_cord_width_p-1:0] src_cord_r, src_cord_n;
  logic [wh_cid_width_p-1:0] cid_r, cid_n;
  
  bsg_manycore_vcache_wh_header_flit_s header_flit_out;
  assign header_flit_out.unused = '0;
  assign header_flit_out.write_not_read = '0; // dont care
  assign header_flit_out.src_cord = '0;   // dont care
  assign header_flit_out.cid = cid_r;
  assign header_flit_out.len = wh_len_width_p'(data_len_lp);
  assign header_flit_out.dest_cord = src_cord_r;

  always_comb begin
    wh_link_sif_out = '0;
    clear_li = 1'b0;
    up_li = 1'b0;

    wh_w_data_v_li = '0;    
    
    write_not_read_n = write_not_read_r;
    addr_n = addr_r;
    src_cord_n = src_cord_r;
    cid_n = cid_r;
    mem_state_n = mem_state_r;
 
    mem_we = 1'b0;
    mem_w_data = wh_link_sif_in.data;

    case (mem_state_r)

      RESET: begin
        mem_state_n = READY;
      end

      READY: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          write_not_read_n = header_flit_in.write_not_read;
          src_cord_n = header_flit_in.src_cord;
          cid_n = header_flit_in.cid;
          mem_state_n = RECV_ADDR;
        end
      end
      
      RECV_ADDR: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          addr_n = wh_link_sif_in.data;
          mem_state_n = write_not_read_r
            ? RECV_EVICT_DATA
            : SEND_FILL_HEADER;
        end
      end

      RECV_EVICT_DATA: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          mem_we = 1'b1;
          wh_w_data_v_li = 1'b1;          
          up_li = (count_lo != data_len_lp-1);
          clear_li = (count_lo == data_len_lp-1);
          mem_state_n = (count_lo == data_len_lp-1)
            ? READY
            : RECV_EVICT_DATA;          
        end
      end

      SEND_FILL_HEADER: begin
        wh_link_sif_out.v = 1'b1;
        wh_link_sif_out.data = header_flit_out;
        if (wh_link_sif_in.ready_and_rev) begin
          mem_state_n = SEND_FILL_DATA;
        end
      end

      SEND_FILL_DATA: begin
        wh_link_sif_out.v = 1'b1;
        wh_link_sif_out.data = mem_r_data;
        if (wh_link_sif_in.ready_and_rev) begin
          
          clear_li = (count_lo == data_len_lp-1);
          up_li = (count_lo != data_len_lp-1);
          mem_state_n = (count_lo == data_len_lp-1)
            ? READY
            : SEND_FILL_DATA;
        end
      end

      default: begin
        mem_state_n = READY; // never happens
      end

    endcase


  end

  
  // address hashing
  if (no_concentration_p) begin
    // no concentration. each wh ruche link gets a test_mem.
    assign mem_addr = {
      src_cord_r[lg_wh_ruche_factor_lp+:lg_num_vcaches_lp],
      addr_r[block_offset_width_lp+:mem_addr_width_lp-lg_num_vcaches_lp-count_width_lp],
      count_lo
    };

    assign dma_mem_addr = {
      src_cord_r[lg_wh_ruche_factor_lp+:lg_num_vcaches_lp],
      addr_r[block_offset_width_lp+:mem_addr_width_lp-lg_num_vcaches_lp]
    };
    
  end
  else begin
    // wh ruche links coming from top and bottom caches are concentrated into one link.
    assign mem_addr = {
      (1)'(cid_r/wh_ruche_factor_p), // determine north or south vcache
      src_cord_r[0+:(lg_num_vcaches_lp-1)],
      addr_r[block_offset_width_lp+:mem_addr_width_lp-lg_num_vcaches_lp-count_width_lp],
      count_lo
    };

    assign dma_mem_addr = {
       (1)'(cid_r/wh_ruche_factor_p),
       src_cord_r[0+:(lg_num_vcaches_lp-1)],
       addr_r[block_offset_width_lp+:mem_addr_width_lp-lg_num_vcaches_lp]
    };
    
  end





  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mem_state_r <= RESET;
      write_not_read_r <= 1'b0;
      src_cord_r <= '0;
      cid_r <= '0;
      addr_r <= '0;
      dma_mem_r_data_v_r <= '0;
    end
    else begin
      mem_state_r <= mem_state_n;
      write_not_read_r <= write_not_read_n;
      src_cord_r <= src_cord_n;
      cid_r <= cid_n;
      addr_r <= addr_n;
      dma_mem_r_data_v_r <= dma_mem_r_data_v_n;
    end
  end

  always @ (posedge clk_i) begin
    if (~reset_i) begin
      case (mem_state_r)
        RESET: begin
          ;
        end     
        READY: begin
          ;
        end      
        default: begin          
          `ifdef NODMA
          $display("[DEBUG] WH MEM: id = %d: %s: cid = %d, addr_r = %08x, mem_addr = %08x, count_lo = %d, mem_we = %b", 
                   id_p, mem_state_r.name(), cid_r, addr_r, mem_addr, count_lo, mem_we);
          `else
          $display("[DEBUG] WH MEM: id = %d: %s: cid = %d, addr_r = %08x, dma_mem_addr = %08x, count_lo = %d, mem_we = %b", 
                   id_p, mem_state_r.name(), cid_r, addr_r, dma_mem_addr, count_lo, mem_we);
          `endif
        end
      endcase // case (mem_state_r)
    end // if (~reset_i)    
  end
  
  
endmodule
