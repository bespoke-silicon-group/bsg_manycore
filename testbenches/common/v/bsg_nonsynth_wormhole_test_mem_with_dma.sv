`include "bsg_manycore_defines.svh"
`include "bsg_cache.svh"

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
    , parameter wh_subcord_width_p = "inv" // src subcoordinate in pod
    , parameter wh_cord_offset_lp = (1<<wh_subcord_width_p)

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
    , parameter debug_p = 0
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

  logic dma_mem_w_n;
  logic dma_mem_w_r;
  logic dma_mem_v_n;  
  logic dma_mem_v_r;

  logic [dma_mem_addr_width_lp-1:0] dma_mem_addr;
  logic [dma_mem_data_width_lp-1:0] dma_mem_w_data;
  logic [dma_mem_data_width_lp-1:0] dma_mem_r_data;  
  logic  dma_data_v_r;
  logic  dma_data_v_n;
  
  bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma
    #(.width_p(dma_mem_data_width_lp)
      ,.els_p(dma_mem_els_lp)
      ,.id_p(id_p))
  dma_mem
    (
     .clk_i(clk_i)
     ,.reset_i(reset_i)
     
     ,.v_i(dma_mem_v_r)
     ,.w_i(dma_mem_w_r)

     ,.addr_i(dma_mem_addr)

     ,.data_o(dma_mem_r_data)

     ,.data_i(dma_mem_w_data)
     ,.w_mask_i('1)
     );

  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  wh_link_sif_s wh_link_sif_in;
  wh_link_sif_s wh_link_sif_out;
  assign wh_link_sif_in = wh_link_sif_i;
  assign wh_link_sif_o = wh_link_sif_out;


  `declare_bsg_cache_wh_header_flit_s(wh_flit_width_p,wh_cord_width_p,wh_len_width_p,wh_cid_width_p);

  bsg_cache_wh_header_flit_s header_flit_in;
  assign header_flit_in = wh_link_sif_in.data;

  // dma mem read data -> wormhole read data

  logic piso_ready_lo;
  logic piso_data_v_lo;
  logic [vcache_dma_data_width_p-1:0] piso_data_lo;
  logic piso_ready_li;
  
  bsg_parallel_in_serial_out_passthrough
    #(.width_p(vcache_dma_data_width_p)
      ,.els_p(data_len_lp))
  dmamem2wh
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(dma_data_v_r)
     ,.ready_and_o(piso_ready_lo)
     ,.data_i(dma_mem_r_data)

     ,.v_o(piso_data_v_lo)
     ,.ready_and_i(piso_ready_li)
     ,.data_o(piso_data_lo)
     );

  // wormhole write data -> dma mem write data
  logic [vcache_dma_data_width_p-1:0] wh_data_n;
  logic [vcache_dma_data_width_p-1:0] wh_data_r;
  logic wh_data_v_r;
  logic wh_data_v_n;  

  logic sipo_ready_lo;
  // currently only used for debugging
  logic sipo_data_v_lo;

  bsg_serial_in_parallel_out_passthrough
    #(.width_p(vcache_dma_data_width_p)
      ,.els_p(data_len_lp))
  wh2dmamem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(wh_data_v_r)
     ,.ready_and_o(sipo_ready_lo)
     ,.data_i(wh_data_r)

     ,.data_o(dma_mem_w_data)
     ,.v_o(sipo_data_v_lo)
     ,.ready_and_i('1)
     );

  always @(posedge clk_i)
    // assert (dma_mem_w_r & dma_mem_v_r => sipo_data_v_lo)
    assert(reset_i | (~(dma_mem_w_r & dma_mem_v_r) | sipo_data_v_lo));

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

  always @(posedge clk_i)
    // assert (dma_data_v_r & count_lo == '1 => piso_ready_lo)
    // this asserts that the piso is ready the cycle after we read from dma mem
    assert(reset_i | (~(dma_data_v_r & count_lo == '1) | piso_ready_lo));

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
  logic [wh_cid_width_p-1:0] src_cid_r, src_cid_n;
  
  bsg_cache_wh_header_flit_s header_flit_out;
  assign header_flit_out.unused = '0;
  assign header_flit_out.write_not_read = '0; // dont care
  assign header_flit_out.src_cord = '0;   // dont care
  assign header_flit_out.src_cid = '0;   // dont care
  assign header_flit_out.cid = src_cid_r;
  assign header_flit_out.len = wh_len_width_p'(data_len_lp);
  assign header_flit_out.dest_cord = src_cord_r;

  always_comb begin
    wh_link_sif_out = '0;
    clear_li = 1'b0;
    up_li = 1'b0;

    write_not_read_n = write_not_read_r;
    addr_n = addr_r;
    src_cord_n = src_cord_r;
    src_cid_n = src_cid_r;
    mem_state_n = mem_state_r;
 
    dma_mem_v_n = '0;
    dma_mem_w_n = '0;    
    dma_data_v_n = '0;    

    piso_ready_li = '0;    

    wh_data_n = '0;
    wh_data_v_n = '0;
    
    case (mem_state_r)

      RESET: begin
        mem_state_n = READY;
      end

      READY: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          write_not_read_n = header_flit_in.write_not_read;
          src_cord_n = header_flit_in.src_cord;
          src_cid_n = header_flit_in.src_cid;
          mem_state_n = RECV_ADDR;
        end
      end
      
      RECV_ADDR: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          addr_n = wh_link_sif_in.data;
          dma_mem_v_n = ~write_not_read_r;          
          mem_state_n = write_not_read_r
            ? RECV_EVICT_DATA
            : SEND_FILL_HEADER;
        end
      end

      RECV_EVICT_DATA: begin
        wh_link_sif_out.ready_and_rev = sipo_ready_lo;
        wh_data_v_n = wh_link_sif_in.v;
        wh_data_n = wh_link_sif_in.data;

        if (wh_link_sif_in.v &
            sipo_ready_lo) begin
          up_li = (count_lo != data_len_lp-1);
          clear_li = (count_lo == data_len_lp-1);
          mem_state_n = (count_lo == data_len_lp-1)
            ? READY
            : RECV_EVICT_DATA;         

          // do write if no more flits
          dma_mem_v_n = (count_lo == data_len_lp-1);
          dma_mem_w_n = (count_lo == data_len_lp-1);
        end
      end

      SEND_FILL_HEADER: begin
        wh_link_sif_out.v = 1'b1;
        wh_link_sif_out.data = header_flit_out;
        dma_data_v_n = 1'b1;
        if (wh_link_sif_in.ready_and_rev) begin
          mem_state_n = SEND_FILL_DATA;
        end
      end

      SEND_FILL_DATA: begin
        wh_link_sif_out.v = piso_data_v_lo;        
        wh_link_sif_out.data = piso_data_lo;
        piso_ready_li = wh_link_sif_in.ready_and_rev;
        
        dma_data_v_n = '1;        
        if (wh_link_sif_in.ready_and_rev &
            piso_data_v_lo) begin          
          clear_li = (count_lo == data_len_lp-1);
          up_li = (count_lo != data_len_lp-1);
          mem_state_n = (count_lo == data_len_lp-1)
            ? READY
            : SEND_FILL_DATA;

          // stop after no more valid flits
          dma_data_v_n = ~(count_lo == data_len_lp-1);          
        end
      end

      default: begin
        mem_state_n = READY; // never happens
      end

    endcase

  end

  logic [wh_cord_width_p-1:0] cord;
  assign cord = src_cord_r - wh_cord_width_p'(wh_cord_offset_lp);
  
  // address hashing
  if (no_concentration_p) begin
    // no concentration. each wh ruche link gets a test_mem.
    assign dma_mem_addr = {
      cord[lg_wh_ruche_factor_lp+:lg_num_vcaches_lp],
      addr_r[block_offset_width_lp+:dma_mem_addr_width_lp-lg_num_vcaches_lp]
    };
    
  end
  else begin
    // wh ruche links coming from top and bottom caches are concentrated into one link.
    assign dma_mem_addr = {
       (1)'(src_cid_r/wh_ruche_factor_p),
       cord[0+:(lg_num_vcaches_lp-1)],
       addr_r[block_offset_width_lp+:dma_mem_addr_width_lp-lg_num_vcaches_lp]
    };
    
  end


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mem_state_r <= RESET;
      write_not_read_r <= 1'b0;
      src_cord_r <= '0;
      src_cid_r <= '0;
      addr_r <= '0;
      dma_mem_v_r <= '0;
      dma_mem_w_r <= '0;      
      dma_data_v_r <= '0;
      wh_data_v_r <= '0;
      wh_data_r <= '0;      
    end
    else begin
      mem_state_r <= mem_state_n;
      write_not_read_r <= write_not_read_n;
      src_cord_r <= src_cord_n;
      src_cid_r <= src_cid_n;
      addr_r <= addr_n;
      dma_mem_v_r <= dma_mem_v_n;
      dma_mem_w_r <= dma_mem_w_n;      
      dma_data_v_r <= dma_data_v_n;
      wh_data_v_r <= wh_data_v_n;
      wh_data_r <= wh_data_n;      
    end
  end

  always @ (posedge clk_i) begin
    if (debug_p) begin
      if (~reset_i) begin
        case (mem_state_r)
          RESET: begin
            ;
          end
          READY: begin
            ;
          end
          RECV_EVICT_DATA: begin
            $display("[DEBUG] WH MEM: id = %d: %s: cid = %d, addr_r = %08x, src_cord_r = %04x, cord = %04x, dma_mem_addr = %08x, wh_data_n = %08x, count_lo = %d, wh_data_v_n = %b, wh_data_v_r = %08x", 
                     id_p, mem_state_r.name(), src_cid_r, addr_r, src_cord_r, cord, dma_mem_addr, wh_data_n, count_lo, wh_data_v_n, wh_data_v_r);
          end
          default: begin
            $display("[DEBUG] WH MEM: id = %d: %s: cid = %d, addr_r = %08x, src_cord_r = %04x, cord = %04x, dma_mem_addr = %08x, piso_data_lo = %08x, count_lo = %d, dma_mem_v_r = %b, dma_data_v_r = %b",
                     id_p, mem_state_r.name(), src_cid_r, addr_r, src_cord_r,cord, dma_mem_addr, piso_data_lo, count_lo, dma_mem_v_r, dma_data_v_r);
          end
        endcase // case (mem_state_r)
      end // if (~reset_i)
    end // if (debug_p)
  end


  initial begin
    if (debug_p) begin
      $display("%m: lg_wh_ruche_factor_lp=%d, lg_num_vcaches_lp=%d, block_offset_width_lp=%d, mem_addr_width_lp=%d, lg_num_vcaches_lp=%d, wh_cord_offset_lp=%d, dma_mem_addr_width_lp=%d",
               lg_wh_ruche_factor_lp, lg_num_vcaches_lp, block_offset_width_lp, mem_addr_width_lp, lg_num_vcaches_lp, wh_cord_offset_lp, dma_mem_addr_width_lp);
    end
  end
  
endmodule
