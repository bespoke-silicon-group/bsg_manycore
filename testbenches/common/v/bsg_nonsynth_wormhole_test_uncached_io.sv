
`include "bsg_manycore_defines.svh"
`include "bsg_cache.svh"

module bsg_nonsynth_wormhole_test_uncached_io
  import bsg_manycore_pkg::*;
  import bsg_cache_pkg::*;
  #(parameter `BSG_INV_PARAM(vcache_data_width_p)
    , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , parameter `BSG_INV_PARAM(vcache_dma_data_width_p)
    , parameter `BSG_INV_PARAM(num_vcaches_p) // how many vcaches are mapped to this test mem?
    , parameter lg_num_vcaches_lp = `BSG_SAFE_CLOG2(num_vcaches_p)
   
    , parameter `BSG_INV_PARAM(wh_cid_width_p)
    , parameter `BSG_INV_PARAM(wh_flit_width_p)
    , parameter `BSG_INV_PARAM(wh_cord_width_p)
    , parameter `BSG_INV_PARAM(wh_len_width_p)

    // determines address hashing based on cid and src_cord
    , parameter no_concentration_p=0
  
    , parameter dma_ratio_lp = (vcache_dma_data_width_p/vcache_data_width_p)
    , parameter data_len_lp = (vcache_block_size_in_words_p/dma_ratio_lp)

    , parameter longint unsigned `BSG_INV_PARAM(mem_size_p)   // size of memory in bytes
    , parameter mem_els_lp = mem_size_p/(vcache_dma_data_width_p/8)
    , parameter mem_addr_width_lp = `BSG_SAFE_CLOG2(mem_els_lp)



    , parameter block_offset_width_lp = `BSG_SAFE_CLOG2((vcache_data_width_p>>3)*vcache_block_size_in_words_p)

    , parameter wh_link_sif_width_lp =
      `bsg_ready_and_link_sif_width(wh_flit_width_p)

    , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_data_width_p>>3)
  )
  (
    input clk_i
    , input reset_i

    , input  [wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [wh_link_sif_width_lp-1:0] wh_link_sif_o
  );

  // State variables
  typedef enum logic [2:0] {
    RESET
    ,READY
    ,RECV_ADDR
    ,RECV_MASK
    ,RECV_EVICT_DATA
    ,SEND_FILL_HEADER
    ,SEND_FILL_DATA
  } mem_state_e;

  mem_state_e mem_state_r, mem_state_n;
  bsg_cache_wh_opcode_e opcode_r, opcode_n;
  logic [wh_flit_width_p-1:0] addr_r, addr_n;
  logic [wh_cord_width_p-1:0] src_cord_r, src_cord_n;
  logic [wh_cid_width_p-1:0] src_cid_r, src_cid_n;

  // memory block
  logic mem_we;
  logic [mem_addr_width_lp-1:0] mem_addr;
  logic [vcache_dma_data_width_p-1:0] mem_w_data;
  logic [vcache_dma_data_width_p-1:0] mem_r_data;
  logic [vcache_dma_data_width_p-1:0] mem_r [mem_els_lp-1:0];

  always_ff @ (posedge clk_i) begin
    if (mem_we) begin
      for (integer i = 0; i < dma_ratio_lp; i++) begin
        mem_r[mem_addr][vcache_data_width_p*i+:vcache_data_width_p] <= mem_w_data[vcache_data_width_p*i+:vcache_data_width_p];
      end
    end
  end

  assign mem_r_data = mem_r[mem_addr];

  // Memory Output
  // mem_r is not initialized  on reset, but we filter the X data being injected into the network to prevent X propagation.
  logic [vcache_dma_data_width_p-1:0] mem_r_data_filtered;
  always_comb begin
    for (integer b = 0; b < vcache_dma_data_width_p; b++) begin
      if (mem_r_data[b] === 1'bX) begin
        mem_r_data_filtered[b] = 1'b0;
      end
      else begin
        mem_r_data_filtered[b] = mem_r_data[b];
      end
    end
  end

  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  wh_link_sif_s wh_link_sif_in;
  wh_link_sif_s wh_link_sif_out;
  assign wh_link_sif_in = wh_link_sif_i;
  assign wh_link_sif_o = wh_link_sif_out;


  `declare_bsg_cache_wh_header_flit_s(wh_flit_width_p,wh_cord_width_p,wh_len_width_p,wh_cid_width_p);

  bsg_cache_wh_header_flit_s header_flit_in;
  assign header_flit_in = wh_link_sif_in.data;

  bsg_cache_wh_header_flit_s header_flit_out;
  assign header_flit_out.unused = '0;
  assign header_flit_out.opcode = e_cache_wh_read; // dont care
  assign header_flit_out.src_cord = '0;   // dont care
  assign header_flit_out.src_cid = '0;   // dont care
  assign header_flit_out.cid = src_cid_r;
  assign header_flit_out.len = wh_len_width_p'(1);
  assign header_flit_out.cord = src_cord_r;

  always_comb begin
    wh_link_sif_out = '0;

    opcode_n = opcode_r;
    addr_n = addr_r;
    src_cord_n = src_cord_r;
    src_cid_n = src_cid_r;
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
          opcode_n = header_flit_in.opcode;
          src_cord_n = header_flit_in.src_cord;
          src_cid_n = header_flit_in.src_cid;
          mem_state_n = RECV_ADDR;
        end
      end
      
      RECV_ADDR: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          addr_n = wh_link_sif_in.data;
          case (opcode_r)
            e_cache_wh_read:              mem_state_n = SEND_FILL_HEADER;
            e_cache_wh_write_non_masked:  mem_state_n = RECV_EVICT_DATA;
            // This never happens.
            default: mem_state_n = READY; 
          endcase
        end
      end

      RECV_EVICT_DATA: begin
        wh_link_sif_out.ready_and_rev = 1'b1;
        if (wh_link_sif_in.v) begin
          mem_we = 1'b1;
          mem_state_n = READY;
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
        wh_link_sif_out.data = mem_r_data_filtered;
        if (wh_link_sif_in.ready_and_rev) begin
          mem_state_n = READY;
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
      src_cid_r[0+:wh_cid_width_p],
      src_cord_r[0+:lg_num_vcaches_lp],
      (mem_addr_width_lp-lg_num_vcaches_lp-wh_cid_width_p)'(addr_r[wh_flit_width_p-1:word_offset_width_lp])
    };
  end
  else begin
    assign mem_addr = (mem_addr_width_lp)'(addr_r[wh_flit_width_p-1:word_offset_width_lp]);
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mem_state_r <= RESET;
      opcode_r <= e_cache_wh_read;
      src_cord_r <= '0;
      src_cid_r <= '0;
      addr_r <= '0;
    end
    else begin
      mem_state_r <= mem_state_n;
      opcode_r <= opcode_n;
      src_cord_r <= src_cord_n;
      src_cid_r <= src_cid_n;
      addr_r <= addr_n;
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_nonsynth_wormhole_test_uncached_io)

