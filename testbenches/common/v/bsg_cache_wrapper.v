/**
 *  bsg_cache_wrapper.v
 */

`include "bsg_manycore_packet.vh"

module bsg_cache_wrapper
  import bsg_cache_pkg::*;
  #(parameter num_cache_p = "inv"
    ,parameter data_width_p = "inv"
    ,parameter addr_width_p = "inv"
    ,parameter block_size_in_words_p = "inv"
    ,parameter sets_p = "inv"
    ,parameter ways_p = "inv"

    ,parameter x_cord_width_p="inv"
    ,parameter y_cord_width_p="inv"
    ,parameter load_id_width_p="inv"

    ,localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    ,localparam cache_addr_width_lp=addr_width_p-1+byte_offset_width_lp

    ,localparam link_sif_width_lp=
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
    ,localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(cache_addr_width_lp)
  )
  (
    input clk_i
    ,input reset_i
  
    // manycore side
    ,input [num_cache_p-1:0][x_cord_width_p-1:0] my_x_i
    ,input [num_cache_p-1:0][y_cord_width_p-1:0] my_y_i
    ,input [num_cache_p-1:0][link_sif_width_lp-1:0] link_sif_i 
    ,output logic [num_cache_p-1:0][link_sif_width_lp-1:0] link_sif_o
  
    ,output [num_cache_p-1:0][bsg_cache_dma_pkt_width_lp-1:0] dma_pkt_o
    ,output [num_cache_p-1:0]                                 dma_pkt_v_o
    ,input  [num_cache_p-1:0]                                 dma_pkt_yumi_i

    ,input  [num_cache_p-1:0][data_width_p-1:0]               dma_data_i
    ,input  [num_cache_p-1:0]                                 dma_data_v_i
    ,output [num_cache_p-1:0]                                 dma_data_ready_o

    ,output [num_cache_p-1:0][data_width_p-1:0]               dma_data_o
    ,output [num_cache_p-1:0]                                 dma_data_v_o
    ,input  [num_cache_p-1:0]                                 dma_data_yumi_i
  );

  // bsg_manycore_link_to_cache
  //
  `declare_bsg_cache_pkt_s(cache_addr_width_lp, data_width_p);
  bsg_cache_pkt_s [num_cache_p-1:0] cache_pkt;
  logic [num_cache_p-1:0] cache_v_li;
  logic [num_cache_p-1:0] cache_ready_lo;
  logic [num_cache_p-1:0][data_width_p-1:0] cache_data_lo;
  logic [num_cache_p-1:0] cache_v_lo;
  logic [num_cache_p-1:0] cache_yumi_li;

  for (genvar i = 0; i < num_cache_p; i++) begin
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
      ,.reset_i(reset_i)

      ,.my_x_i(my_x_i[i])
      ,.my_y_i(my_y_i[i])

      ,.link_sif_i(link_sif_i[i])
      ,.link_sif_o(link_sif_o[i])

      ,.cache_pkt_o(cache_pkt[i])
      ,.v_o(cache_v_li[i])
      ,.ready_i(cache_ready_lo[i])

      ,.data_i(cache_data_lo[i])
      ,.v_i(cache_v_lo[i])
      ,.yumi_o(cache_yumi_li[i])
    );
  end

  // bsg_cache
  //
  for (genvar i = 0; i < num_cache_p; i++) begin
    bsg_cache #(
      .addr_width_p(cache_addr_width_lp)
      ,.data_width_p(data_width_p)
      ,.block_size_in_words_p(block_size_in_words_p)
      ,.sets_p(sets_p)
    ) cache (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      
      ,.cache_pkt_i(cache_pkt[i])
      ,.v_i(cache_v_li[i])
      ,.ready_o(cache_ready_lo[i])

      ,.data_o(cache_data_lo[i])
      ,.v_o(cache_v_lo[i])
      ,.yumi_i(cache_yumi_li[i])

      ,.dma_pkt_o(dma_pkt_o[i])
      ,.dma_pkt_v_o(dma_pkt_v_o[i])
      ,.dma_pkt_yumi_i(dma_pkt_yumi_i[i])

      ,.dma_data_i(dma_data_i[i])
      ,.dma_data_v_i(dma_data_v_i[i])
      ,.dma_data_ready_o(dma_data_ready_o[i])

      ,.dma_data_o(dma_data_o[i])
      ,.dma_data_v_o(dma_data_v_o[i])
      ,.dma_data_yumi_i(dma_data_yumi_i[i])

      ,.v_we_o()
    );
  end

endmodule
