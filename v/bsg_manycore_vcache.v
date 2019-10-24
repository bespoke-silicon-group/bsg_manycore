/**
 *  bsg_manycore_vcache.v
 *
 */

`include "bsg_manycore_packet.vh"

module bsg_manycore_vcache
  import bsg_cache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter block_size_in_words_p="inv"
    , parameter sets_p = "inv"
    , parameter ways_p = "inv"
    
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , parameter cache_addr_width_lp=(addr_width_p-1+byte_offset_width_lp)

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
    , parameter cache_dma_pkt_width_lp =
      `bsg_cache_dma_pkt_width(cache_addr_width_lp)
  )
  (
    input clk_i
    , input reset_i

    // manycore link
    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  
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


  // reset flop
  //
  logic reset_r;
  always_ff @ (posedge clk_i)
    reset_r <= reset_i;

  // link_to_cache
  //
  `declare_bsg_cache_pkt_s(cache_addr_width_lp,data_width_p);
  bsg_cache_pkt_s cache_pkt;
  logic cache_v_li;
  logic cache_ready_lo;
  logic [data_width_p-1:0] cache_data_lo;
  logic cache_v_lo;
  logic cache_yumi_li;  

  bsg_manycore_link_to_cache #(
    .link_addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.block_size_in_words_p(block_size_in_words_p)
  ) link_to_cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.my_x_i((x_cord_width_p)'(my_x_i))
    ,.my_y_i((y_cord_width_p)'(my_y_i))

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    ,.cache_pkt_o(cache_pkt)
    ,.v_o(cache_v_li)
    ,.ready_i(cache_ready_lo)

    ,.data_i(cache_data_lo)
    ,.v_i(cache_v_lo)
    ,.yumi_o(cache_yumi_li)
  );

  
  // bsg_cache
  //
  bsg_cache #(
    .addr_width_p(cache_addr_width_lp)
    ,.data_width_p(data_width_p)
    ,.block_size_in_words_p(block_size_in_words_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
  ) cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    
    ,.cache_pkt_i(cache_pkt)
    ,.v_i(cache_v_li)
    ,.ready_o(cache_ready_lo)

    ,.data_o(cache_data_lo)
    ,.v_o(cache_v_lo)
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

    ,.v_we_o()
  );
  


endmodule
