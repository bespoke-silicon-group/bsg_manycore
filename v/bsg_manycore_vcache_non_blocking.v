/**
 *  bsg_manycore_vcache_non_blocking.v
 *
 */


module bsg_manycore_vcache_non_blocking 
  import bsg_manycore_pkg::*;
  import bsg_cache_non_blocking_pkg::*;
  #(parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter block_size_in_words_p="inv"
    , parameter miss_fifo_els_p="inv"

    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , parameter cache_addr_width_lp=(addr_width_p-1+byte_offset_width_lp)

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  
    , parameter cache_dma_pkt_width_lp=
      `bsg_cache_non_blocking_dma_pkt_width(cache_addr_width_lp)

  )
  (
    input clk_i
    , input reset_i

    // manycore link
    , input  [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    // cache DMA
    , output logic [cache_dma_pkt_width_lp-1:0] dma_pkt_o
    , output logic dma_pkt_v_o
    , input dma_pkt_yumi_i

    , input [data_width_p-1:0] dma_data_i
    , input dma_data_v_i
    , output logic dma_data_ready_o

    , output logic [data_width_p-1:0] dma_data_o
    , output logic dma_data_v_o
    , input dma_data_yumi_i
  );


  localparam id_width_lp=(x_cord_width_p+y_cord_width_p+bsg_manycore_reg_id_width_gp+$bits(bsg_manycore_return_packet_type_e));
 
  // flop the reset signal, since vcache tile may be large. 
  logic reset_r;
  always_ff @ (posedge clk_i)
    reset_r <= reset_i;

  
  `declare_bsg_cache_non_blocking_pkt_s(id_width_lp,cache_addr_width_lp,data_width_p);
  bsg_cache_non_blocking_pkt_s cache_pkt;
  logic cache_v_li;
  logic cache_ready_lo;
  logic [data_width_p-1:0] cache_data_lo;
  logic [id_width_lp-1:0] cache_id_lo;
  logic cache_v_lo;
  logic cache_yumi_li;

  logic fifo_ready_lo;
  logic fifo_v_lo;
  logic [data_width_p-1:0] fifo_data_lo;
  logic [id_width_lp-1:0] fifo_id_lo;
  logic fifo_yumi_li;

  bsg_two_fifo #(
    .width_p(id_width_lp+data_width_p)
  ) return_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(cache_v_lo)
    ,.data_i({cache_id_lo, cache_data_lo})
    ,.ready_o(fifo_ready_lo)

    ,.v_o(fifo_v_lo)
    ,.yumi_i(fifo_yumi_li)
    ,.data_o({fifo_id_lo, fifo_data_lo})
  );


  bsg_manycore_link_to_cache_non_blocking #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)

    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.block_size_in_words_p(block_size_in_words_p)
    ,.miss_fifo_els_p(miss_fifo_els_p)
  ) link_to_cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
   
    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o) 

    ,.cache_pkt_o(cache_pkt)
    ,.v_o(cache_v_li)
    ,.ready_i(cache_ready_lo)

    ,.v_i(fifo_v_lo)
    ,.id_i(fifo_id_lo)
    ,.data_i(fifo_data_lo)
    ,.yumi_o(fifo_yumi_li)
  );



  bsg_cache_non_blocking #(
    .id_width_p(id_width_lp)
    ,.addr_width_p(cache_addr_width_lp)
    ,.data_width_p(data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.block_size_in_words_p(block_size_in_words_p)
    ,.miss_fifo_els_p(miss_fifo_els_p)
  ) cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.v_i(cache_v_li)
    ,.cache_pkt_i(cache_pkt)
    ,.ready_o(cache_ready_lo)

    ,.v_o(cache_v_lo)
    ,.id_o(cache_id_lo)
    ,.data_o(cache_data_lo)
    ,.yumi_i(cache_yumi_li)

    ,.dma_pkt_o(dma_pkt_o)
    ,.dma_pkt_v_o(dma_pkt_v_o)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_i)

    ,.dma_data_i(dma_data_i)
    ,.dma_data_v_i(dma_data_v_i)
    ,.dma_data_ready_o(dma_data_ready_o)

    ,.dma_data_o(dma_data_o)
    ,.dma_data_v_o(dma_data_v_o)
    ,.dma_data_yumi_i(dma_data_yumi_i) 
  );

  assign cache_yumi_li = cache_v_lo & fifo_ready_lo;


endmodule
