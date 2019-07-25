/**
 *  memory_system.v
 *
 */



module memory_system
  import bsg_mem_cfg_pkg::*;
  #(parameter bsg_mem_cfg_e mem_cfg_p=e_mem_cfg_default
    , parameter bsg_global_x_p="inv" 
    , parameter bsg_global_y_p="inv"

    , parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter block_size_in_words_p="inv"

    , parameter axi_id_width_p = "inv"
    , parameter axi_addr_width_p = "inv"
    , parameter axi_data_width_p = "inv"
    , parameter axi_burst_len_p = "inv"
    , parameter axi_strb_width_lp=(axi_data_width_p>>3)

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    // manycore side
    , input [bsg_global_x_p-1:0][link_sif_width_lp-1:0] link_sif_i
    , output [bsg_global_x_p-1:0][link_sif_width_lp-1:0] link_sif_o

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

  if (mem_cfg_p == e_mem_cfg_default) begin: mem_default

    bsg_cache_wrapper_axi #(
      .bsg_global_x_p(bsg_global_x_p)
      ,.bsg_global_y_p(bsg_global_y_p)
    
      ,.data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.load_id_width_p(load_id_width_p)

      ,.block_size_in_words_p(block_size_in_words_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)

      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
    ) cache_axi (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      
      ,.link_sif_i(link_sif_i)
      ,.link_sif_o(link_sif_o)

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

  end
  else if (mem_cfg_p == e_mem_cfg_infinite) begin: mem_infinite

    for (genvar i = 0; i < bsg_global_x_p; i++) begin: mem_infty
      bsg_nonsynth_mem_infinite #(
        .data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.load_id_width_p(load_id_width_p)
      ) mem_infty (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_sif_i(link_sif_i[i])
        ,.link_sif_o(link_sif_o[i])
        
        ,.my_x_i((x_cord_width_p)'(i))
        ,.my_y_i((y_cord_width_p)'(bsg_global_y_p))
      );
    end
    
    // tieoff unused AXI signals
    assign axi_awid_o = '0;
    assign axi_awaddr_o = '0;
    assign axi_awlen_o = '0;
    assign axi_awsize_o = '0;
    assign axi_awburst_o = '0;
    assign axi_awcache_o = '0;
    assign axi_awprot_o = '0;
    assign axi_awlock_o = '0;
    assign axi_awvalid_o = 1'b0;
    wire unused_awready = axi_awready_i;

    assign axi_wdata_o = '0;
    assign axi_wstrb_o = '0;
    assign axi_wlast_o = 1'b0;
    assign axi_wvalid_o = 1'b0;
    wire unused_wready = axi_wready_i;

    assign axi_bready_o = 1'b0;
    wire [axi_id_width_p-1:0] unused_bid = axi_bid_i;
    wire [1:0] unused_bresp = axi_bresp_i;
    wire unused_bvalid_i = axi_bvalid_i;

    assign axi_arid_o = '0;
    assign axi_araddr_o = '0;
    assign axi_arlen_o = '0;
    assign axi_arsize_o = '0;
    assign axi_arburst_o = '0;
    assign axi_arcache_o = '0;
    assign axi_arprot_o = '0;
    assign axi_arlock_o = '0;
    assign axi_arvalid_o = 1'b0;
    wire unused_arready = axi_arready_i;

    assign axi_rready_o = 1'b0;
    wire [axi_id_width_p-1:0] unused_rid = axi_rid_i;
    wire [axi_data_width_p-1:0] unused_rdata = axi_rdata_i;
    wire [1:0] unused_rresp = axi_rresp_i;
    wire unused_rlast = axi_rlast_i;
    wire unused_rvalid = axi_rvalid_i;

  end
  else begin
    initial begin
      assert("mem_cfg_p" == "undefined") else $error("undefined mem_cfg.");
    end
  end

endmodule
