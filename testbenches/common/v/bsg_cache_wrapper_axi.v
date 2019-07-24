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

    ,parameter bsg_dram_included_p = "inv"
    ,parameter bsg_dram_size_p = "inv"

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
  logic [axi_id_width_p-1:0] awid;
  logic [axi_addr_width_p-1:0] awaddr;
  logic [7:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic [3:0] awcache;
  logic [2:0] awprot;
  logic awlock;
  logic awvalid;
  logic awready;

  logic [axi_data_width_p-1:0] wdata;
  logic [axi_strb_width_lp-1:0] wstrb;
  logic wlast;
  logic wvalid;
  logic wready;

  logic [axi_id_width_p-1:0] bid;
  logic [1:0] bresp;
  logic bvalid;
  logic bready;

  logic [axi_id_width_p-1:0] arid;
  logic [axi_addr_width_p-1:0] araddr;
  logic [7:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic arlock;
  logic arvalid;
  logic arready;

  logic [axi_id_width_p-1:0] rid;
  logic [axi_data_width_p-1:0] rdata;
  logic [1:0] rresp;
  logic rlast;
  logic rvalid;
  logic rready;

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

    ,.axi_awid_o(awid)
    ,.axi_awaddr_o(awaddr)
    ,.axi_awlen_o(awlen)
    ,.axi_awsize_o(awsize)
    ,.axi_awburst_o(awburst)
    ,.axi_awcache_o(awcache)
    ,.axi_awprot_o(awprot)
    ,.axi_awlock_o(awlock)
    ,.axi_awvalid_o(awvalid)
    ,.axi_awready_i(awready)

    ,.axi_wdata_o(wdata)
    ,.axi_wstrb_o(wstrb)
    ,.axi_wlast_o(wlast)
    ,.axi_wvalid_o(wvalid)
    ,.axi_wready_i(wready)

    ,.axi_bid_i(bid)
    ,.axi_bresp_i(bresp)
    ,.axi_bvalid_i(bvalid)
    ,.axi_bready_o(bready)

    ,.axi_arid_o(arid)
    ,.axi_araddr_o(araddr)
    ,.axi_arlen_o(arlen)
    ,.axi_arsize_o(arsize)
    ,.axi_arburst_o(arburst)
    ,.axi_arcache_o(arcache)
    ,.axi_arprot_o(arprot)
    ,.axi_arlock_o(arlock)
    ,.axi_arvalid_o(arvalid)
    ,.axi_arready_i(arready)

    ,.axi_rid_i(rid)
    ,.axi_rdata_i(rdata)
    ,.axi_rresp_i(rresp)
    ,.axi_rlast_i(rlast)
    ,.axi_rvalid_i(rvalid)
    ,.axi_rready_o(rready)
  );

 bsg_manycore_axi_mem #(
    .axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)
    ,.mem_els_p(bsg_dram_size_p/(axi_data_width_p/data_width_p))
  ) axi_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.axi_awid_i(awid)
    ,.axi_awaddr_i(awaddr)
    ,.axi_awvalid_i(awvalid)
    ,.axi_awready_o(awready)

    ,.axi_wdata_i(wdata)
    ,.axi_wstrb_i(wstrb)
    ,.axi_wlast_i(wlast)
    ,.axi_wvalid_i(wvalid)
    ,.axi_wready_o(wready)

    ,.axi_bid_o(bid)
    ,.axi_bresp_o(bresp)
    ,.axi_bvalid_o(bvalid)
    ,.axi_bready_i(bready)

    ,.axi_arid_i(arid)
    ,.axi_araddr_i(araddr)
    ,.axi_arvalid_i(arvalid)
    ,.axi_arready_o(arready)

    ,.axi_rid_o(rid)
    ,.axi_rdata_o(rdata)
    ,.axi_rresp_o(rresp)
    ,.axi_rlast_o(rlast)
    ,.axi_rvalid_o(rvalid)
    ,.axi_rready_i(rready)
  );

  // synopsys translate_off

    always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      if (bsg_dram_included_p == 0) begin
        assert(awvalid !== 1'b1) else $error("[BSG_ERROR][TESTBENCH] DRAM write detected in no DRAM mode!!!");
        assert(arvalid !== 1'b1) else $error("[BSG_ERROR][TESTBENCH] DRAM read detected in no DRAM mode!!!");
      end
    end
  end


  // synopsys translate_on

endmodule
