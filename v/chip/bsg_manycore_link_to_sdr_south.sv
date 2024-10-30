
`include "bsg_manycore_defines.svh"

module bsg_manycore_link_to_sdr_south

 import bsg_manycore_pkg::*;

 #(parameter `BSG_INV_PARAM(lg_fifo_depth_p)
  ,parameter `BSG_INV_PARAM(lg_credit_to_token_decimation_p)

  ,parameter `BSG_INV_PARAM(addr_width_p)
  ,parameter `BSG_INV_PARAM(data_width_p)
  ,parameter `BSG_INV_PARAM(x_cord_width_p)
  ,parameter `BSG_INV_PARAM(y_cord_width_p)

  ,parameter link_sif_width_lp =
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter fwd_width_lp =
    `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter rev_width_lp =
    `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  )

  (input  core_clk_i

  ,input  [link_sif_width_lp-1:0] core_link_sif_i
  ,output [link_sif_width_lp-1:0] core_link_sif_o


  ,input  async_uplink_reset_i
  ,input  async_downlink_reset_i
  ,input  async_downstream_reset_i
  ,input  async_token_reset_i

  ,output async_uplink_reset_o
  ,output async_downlink_reset_o
  ,output async_downstream_reset_o
  ,output async_token_reset_o

  ,input  async_fwd_link_i_disable_i
  ,input  async_fwd_link_o_disable_i
  ,input  async_rev_link_i_disable_i
  ,input  async_rev_link_o_disable_i

  ,output                    io_fwd_link_clk_o
  ,output [fwd_width_lp-1:0] io_fwd_link_data_o
  ,output                    io_fwd_link_v_o
  ,input                     io_fwd_link_token_i

  ,input                     io_fwd_link_clk_i
  ,input  [fwd_width_lp-1:0] io_fwd_link_data_i
  ,input                     io_fwd_link_v_i
  ,output                    io_fwd_link_token_o

  ,output                    io_rev_link_clk_o
  ,output [rev_width_lp-1:0] io_rev_link_data_o
  ,output                    io_rev_link_v_o
  ,input                     io_rev_link_token_i

  ,input                     io_rev_link_clk_i
  ,input  [rev_width_lp-1:0] io_rev_link_data_i
  ,input                     io_rev_link_v_i
  ,output                    io_rev_link_token_o
  );

  //-------------------------------------------
  //As the manycore will distribute across large area, it will take long
  //time for the reset signal to propgate. We should register the reset
  //signal in each tile

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s core_link_sif_li, core_link_sif_lo;

  assign core_link_sif_li = core_link_sif_i;
  assign core_link_sif_o = core_link_sif_lo;

  assign async_uplink_reset_o     = async_uplink_reset_i;
  assign async_downlink_reset_o   = async_downlink_reset_i;
  assign async_downstream_reset_o = async_downstream_reset_i;
  assign async_token_reset_o      = async_token_reset_i;

  logic core_uplink_reset_sync, core_downstream_reset_sync;
  bsg_sync_sync #(.width_p(1)) up_bss
  (.oclk_i     (core_clk_i            )
  ,.iclk_data_i(async_uplink_reset_i  )
  ,.oclk_data_o(core_uplink_reset_sync)
  );
  bsg_sync_sync #(.width_p(1)) down_bss
  (.oclk_i     (core_clk_i                )
  ,.iclk_data_i(async_downstream_reset_i  )
  ,.oclk_data_o(core_downstream_reset_sync)
  );

   assign core_link_sif_lo = '0;
   assign io_fwd_link_clk_o = '0;
   assign io_fwd_link_data_o = '0;
   assign io_fwd_link_v_o = '0;
   assign io_fwd_link_token_o = '0;
   assign io_rev_link_clk_o = '0;
   assign io_rev_link_data_o = '0;
   assign io_rev_link_v_o = '0;
   assign io_rev_link_token_o = '0;


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_to_sdr_south)

