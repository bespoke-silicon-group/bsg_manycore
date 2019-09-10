/**
 *  bsg_cache_wrapper_axi.v
 */

`include "bsg_manycore_packet.vh"

module bsg_cache_wrapper_axi
  import bsg_cache_pkg::*;
  #(parameter bsg_global_x_p = "inv"
    ,parameter bsg_global_y_p = "inv"

    ,parameter data_width_p = "inv"
    ,parameter addr_width_p = "inv"
    ,parameter x_cord_width_p="inv"
    ,parameter y_cord_width_p="inv"
    ,parameter load_id_width_p="inv"

    ,parameter block_size_in_words_p = "inv"
    ,parameter sets_p = "inv"
    ,parameter ways_p = "inv"

    ,parameter axi_id_width_p = "inv"
    ,parameter axi_addr_width_p = "inv"
    ,parameter axi_data_width_p = "inv"
    ,parameter axi_burst_len_p = "inv"

    ,localparam axi_strb_width_lp=(axi_data_width_p>>3)
    ,localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    ,localparam cache_addr_width_lp=addr_width_p-1+byte_offset_width_lp

    ,localparam link_sif_width_lp=
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    ,input reset_i
  
    // manycore side
    ,input [bsg_global_x_p-1:0][link_sif_width_lp-1:0] link_sif_i 
    ,output logic [bsg_global_x_p-1:0][link_sif_width_lp-1:0] link_sif_o

    // axi write address channel
    ,output logic [axi_id_width_p-1:0] axi_awid_o
    ,output logic [axi_addr_width_p-1:0] axi_awaddr_o
    ,output logic [7:0] axi_awlen_o
    ,output logic [2:0] axi_awsize_o
    ,output logic [1:0] axi_awburst_o
    ,output logic [3:0] axi_awcache_o
    ,output logic [2:0] axi_awprot_o
    ,output logic axi_awlock_o
    ,output logic axi_awvalid_o
    ,input axi_awready_i

    // axi write data channel
    ,output logic [axi_data_width_p-1:0] axi_wdata_o
    ,output logic [axi_strb_width_lp-1:0] axi_wstrb_o
    ,output logic axi_wlast_o
    ,output logic axi_wvalid_o
    ,input axi_wready_i

    // axi write response channel
    ,input [axi_id_width_p-1:0] axi_bid_i
    ,input [1:0] axi_bresp_i
    ,input axi_bvalid_i
    ,output logic axi_bready_o

    // axi read address channel
    ,output logic [axi_id_width_p-1:0] axi_arid_o
    ,output logic [axi_addr_width_p-1:0] axi_araddr_o
    ,output logic [7:0] axi_arlen_o
    ,output logic [2:0] axi_arsize_o
    ,output logic [1:0] axi_arburst_o
    ,output logic [3:0] axi_arcache_o
    ,output logic [2:0] axi_arprot_o
    ,output logic axi_arlock_o
    ,output logic axi_arvalid_o
    ,input axi_arready_i

    // axi read data channel
    ,input [axi_id_width_p-1:0] axi_rid_i
    ,input [axi_data_width_p-1:0] axi_rdata_i
    ,input [1:0] axi_rresp_i
    ,input axi_rlast_i
    ,input axi_rvalid_i
    ,output logic axi_rready_o
  );

  // bsg_manycore_link_to_cache
  //
  `declare_bsg_cache_pkt_s(cache_addr_width_lp, data_width_p);
  bsg_cache_pkt_s [bsg_global_x_p-1:0] cache_pkt;
  logic [bsg_global_x_p-1:0] cache_v_li;
  logic [bsg_global_x_p-1:0] cache_ready_lo;
  logic [bsg_global_x_p-1:0][data_width_p-1:0] cache_data_lo;
  logic [bsg_global_x_p-1:0] cache_v_lo;
  logic [bsg_global_x_p-1:0] cache_yumi_li;

  for (genvar i = 0; i < bsg_global_x_p; i++) begin: l2c
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

      ,.my_x_i((x_cord_width_p)'(i))
      ,.my_y_i((y_cord_width_p)'(bsg_global_y_p))

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
  `declare_bsg_cache_dma_pkt_s(cache_addr_width_lp);
  bsg_cache_dma_pkt_s [bsg_global_x_p-1:0] dma_pkt;
  logic [bsg_global_x_p-1:0] dma_pkt_v_lo;
  logic [bsg_global_x_p-1:0] dma_pkt_yumi_li;

  logic [bsg_global_x_p-1:0][data_width_p-1:0] dma_data_li;
  logic [bsg_global_x_p-1:0] dma_data_v_li;
  logic [bsg_global_x_p-1:0] dma_data_ready_lo;

  logic [bsg_global_x_p-1:0][data_width_p-1:0] dma_data_lo;
  logic [bsg_global_x_p-1:0] dma_data_v_lo;
  logic [bsg_global_x_p-1:0] dma_data_yumi_li;

  for (genvar i = 0; i < bsg_global_x_p; i++) begin: vcache
    bsg_cache #(
      .addr_width_p(cache_addr_width_lp)
      ,.data_width_p(data_width_p)
      ,.block_size_in_words_p(block_size_in_words_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
    ) cache (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      
      ,.cache_pkt_i(cache_pkt[i])
      ,.v_i(cache_v_li[i])
      ,.ready_o(cache_ready_lo[i])

      ,.data_o(cache_data_lo[i])
      ,.v_o(cache_v_lo[i])
      ,.yumi_i(cache_yumi_li[i])

      ,.dma_pkt_o(dma_pkt[i])
      ,.dma_pkt_v_o(dma_pkt_v_lo[i])
      ,.dma_pkt_yumi_i(dma_pkt_yumi_li[i])

      ,.dma_data_i(dma_data_li[i])
      ,.dma_data_v_i(dma_data_v_li[i])
      ,.dma_data_ready_o(dma_data_ready_lo[i])

      ,.dma_data_o(dma_data_lo[i])
      ,.dma_data_v_o(dma_data_v_lo[i])
      ,.dma_data_yumi_i(dma_data_yumi_li[i])

      ,.v_we_o()
    );
  end

  // bsg_cache_to_axi
  //
  bsg_cache_to_axi_hashed #(
    .addr_width_p(cache_addr_width_lp)
    ,.block_size_in_words_p(block_size_in_words_p)
    ,.data_width_p(data_width_p)
    ,.num_cache_p(bsg_global_x_p)

    ,.axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)
  ) cache_to_axi (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.dma_pkt_i(dma_pkt)
    ,.dma_pkt_v_i(dma_pkt_v_lo)
    ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

    ,.dma_data_o(dma_data_li)
    ,.dma_data_v_o(dma_data_v_li)
    ,.dma_data_ready_i(dma_data_ready_lo)

    ,.dma_data_i(dma_data_lo)
    ,.dma_data_v_i(dma_data_v_lo)
    ,.dma_data_yumi_o(dma_data_yumi_li)

    ,.axi_awid_o(axi_awid_o)
    ,.axi_awaddr_o(axi_awaddr_o)
    ,.axi_awlen_o(axi_awlen_o)
    ,.axi_awsize_o(axi_awsize_o)
    ,.axi_awburst_o(axi_awburst_o)
    ,.axi_awcache_o(axi_awcache_o)
    ,.axi_awprot_o(axi_awprot_o)
    ,.axi_awlock_o(axi_awlock_o)
    ,.axi_awvalid_o(axi_awvalid_o)
    ,.axi_awready_i(axi_awready_i)

    ,.axi_wdata_o(axi_wdata_o)
    ,.axi_wstrb_o(axi_wstrb_o)
    ,.axi_wlast_o(axi_wlast_o)
    ,.axi_wvalid_o(axi_wvalid_o)
    ,.axi_wready_i(axi_wready_i)

    ,.axi_bid_i(axi_bid_i)
    ,.axi_bresp_i(axi_bresp_i)
    ,.axi_bvalid_i(axi_bvalid_i)
    ,.axi_bready_o(axi_bready_o)

    ,.axi_arid_o(axi_arid_o)
    ,.axi_araddr_o(axi_araddr_o)
    ,.axi_arlen_o(axi_arlen_o)
    ,.axi_arsize_o(axi_arsize_o)
    ,.axi_arburst_o(axi_arburst_o)
    ,.axi_arcache_o(axi_arcache_o)
    ,.axi_arprot_o(axi_arprot_o)
    ,.axi_arlock_o(axi_arlock_o)
    ,.axi_arvalid_o(axi_arvalid_o)
    ,.axi_arready_i(axi_arready_i)

    ,.axi_rid_i(axi_rid_i)
    ,.axi_rdata_i(axi_rdata_i)
    ,.axi_rresp_i(axi_rresp_i)
    ,.axi_rlast_i(axi_rlast_i)
    ,.axi_rvalid_i(axi_rvalid_i)
    ,.axi_rready_o(axi_rready_o)
  );

endmodule
