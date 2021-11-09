module bsg_manycore_link_to_sdr_south



 import bsg_manycore_pkg::*;

 #(parameter lg_fifo_depth_p                 = "inv"
  ,parameter lg_credit_to_token_decimation_p = "inv"

  ,parameter addr_width_p     = "inv"
  ,parameter data_width_p     = "inv"
  ,parameter x_cord_width_p   = "inv"
  ,parameter y_cord_width_p   = "inv"

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

  bsg_link_sdr
 #(.width_p                        (fwd_width_lp)
  ,.lg_fifo_depth_p                (lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.bypass_upstream_twofer_fifo_p  (1)
  ,.bypass_downstream_twofer_fifo_p(0)
  ) fwd_sdr
  (.core_clk_i             (core_clk_i)
  ,.core_uplink_reset_i    (core_uplink_reset_sync     | async_fwd_link_o_disable_i)
  ,.core_downstream_reset_i(core_downstream_reset_sync | async_fwd_link_i_disable_i)
  ,.async_downlink_reset_i (async_downlink_reset_i     | async_fwd_link_i_disable_i)
  ,.async_token_reset_i    (async_token_reset_i        | async_fwd_link_o_disable_i)

  ,.core_data_i (core_link_sif_li.fwd.data)
  ,.core_v_i    (core_link_sif_li.fwd.v)
  ,.core_ready_o(core_link_sif_lo.fwd.ready_and_rev)

  ,.core_data_o (core_link_sif_lo.fwd.data)
  ,.core_v_o    (core_link_sif_lo.fwd.v)
  ,.core_yumi_i (core_link_sif_lo.fwd.v & core_link_sif_li.fwd.ready_and_rev)

  ,.link_clk_o  (io_fwd_link_clk_o)
  ,.link_data_o (io_fwd_link_data_o)
  ,.link_v_o    (io_fwd_link_v_o)
  ,.link_token_i(io_fwd_link_token_i)

  ,.link_clk_i  (io_fwd_link_clk_i)
  ,.link_data_i (io_fwd_link_data_i)
  ,.link_v_i    (io_fwd_link_v_i)
  ,.link_token_o(io_fwd_link_token_o)
  );

  bsg_link_sdr
 #(.width_p                        (rev_width_lp)
  ,.lg_fifo_depth_p                (lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.bypass_upstream_twofer_fifo_p  (1)
  ,.bypass_downstream_twofer_fifo_p(0)
  ) rev_sdr
  (.core_clk_i             (core_clk_i)
  ,.core_uplink_reset_i    (core_uplink_reset_sync     | async_rev_link_o_disable_i)
  ,.core_downstream_reset_i(core_downstream_reset_sync | async_rev_link_i_disable_i)
  ,.async_downlink_reset_i (async_downlink_reset_i     | async_rev_link_i_disable_i)
  ,.async_token_reset_i    (async_token_reset_i        | async_rev_link_o_disable_i)

  ,.core_data_i (core_link_sif_li.rev.data)
  ,.core_v_i    (core_link_sif_li.rev.v)
  ,.core_ready_o(core_link_sif_lo.rev.ready_and_rev)

  ,.core_data_o (core_link_sif_lo.rev.data)
  ,.core_v_o    (core_link_sif_lo.rev.v)
  ,.core_yumi_i (core_link_sif_lo.rev.v & core_link_sif_li.rev.ready_and_rev)

  ,.link_clk_o  (io_rev_link_clk_o)
  ,.link_data_o (io_rev_link_data_o)
  ,.link_v_o    (io_rev_link_v_o)
  ,.link_token_i(io_rev_link_token_i)

  ,.link_clk_i  (io_rev_link_clk_i)
  ,.link_data_i (io_rev_link_data_i)
  ,.link_v_i    (io_rev_link_v_i)
  ,.link_token_o(io_rev_link_token_o)
  );

endmodule
