
  ,parameter lg_fifo_depth_p                 = "inv"
  ,parameter lg_credit_to_token_decimation_p = "inv"

  ,parameter addr_width_p     = "inv"
  ,parameter data_width_p     = "inv"
  ,parameter x_cord_width_p   = "inv"
  ,parameter y_cord_width_p   = "inv"
  ,parameter ruche_factor_X_p = "inv"

  ,parameter link_sif_width_lp =
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter ruche_x_link_sif_width_lp =
    `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter fwd_width_lp =
    `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter rev_width_lp =
    `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  )

  (input  core_clk_i
  ,input  core_reset_i
  ,output core_reset_o

  ,input  [S:N][link_sif_width_lp-1:0] core_ver_link_sif_i
  ,output [S:N][link_sif_width_lp-1:0] core_ver_link_sif_o

  ,input  [link_sif_width_lp-1:0] core_hor_link_sif_i
  ,output [link_sif_width_lp-1:0] core_hor_link_sif_o

  ,input  [ruche_x_link_sif_width_lp-1:0] core_ruche_link_i
  ,output [ruche_x_link_sif_width_lp-1:0] core_ruche_link_o

  ,input  [x_cord_width_p-1:0] core_global_x_i
  ,input  [y_cord_width_p-1:0] core_global_y_i
  ,output [x_cord_width_p-1:0] core_global_x_o
  ,output [y_cord_width_p-1:0] core_global_y_o

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

  logic core_reset_r;
  logic [x_cord_width_p-1:0] core_global_x_r;
  logic [y_cord_width_p-1:0] core_global_y_r;

  assign core_reset_o = core_reset_r;
  assign core_global_x_o = core_global_x_r;
  assign core_global_y_o = y_cord_width_p'(core_global_y_r+1'b1);

  bsg_dff #(.width_p(1)) dff_core_reset
  (.clk_i(core_clk_i),.data_i(core_reset_i),.data_o(core_reset_r));
  bsg_dff #(.width_p(x_cord_width_p)) dff_global_x
  (.clk_i(core_clk_i),.data_i(core_global_x_i),.data_o(core_global_x_r));
  bsg_dff #(.width_p(y_cord_width_p)) dff_global_y
  (.clk_i(core_clk_i),.data_i(core_global_y_i),.data_o(core_global_y_r));


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo;
  bsg_manycore_link_sif_s [S:W] core_link_sif_li, core_link_sif_lo;

  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s [E:W] core_ruche_link_li, core_ruche_link_lo;

  assign core_link_sif_li[S:N] = core_ver_link_sif_i;
  assign core_ver_link_sif_o = core_link_sif_lo[S:N];

  if (tieoff_east_not_west_p == 0)
  begin: tieoff_west
    // hard-coded for odd ruche factor (= 3).
    assign core_link_sif_li  [E] = core_hor_link_sif_i;
    bsg_inv #(
      .width_p($bits(bsg_manycore_ruche_x_link_sif_s))
      ,.harden_p(1)
    ) inv0 (
      .i(core_ruche_link_i)
      ,.o(core_ruche_link_li[E])
    );
    assign core_link_sif_li  [W] = '0;
    assign core_ruche_link_li[W] = '0;
    assign core_hor_link_sif_o = core_link_sif_lo  [E];
    bsg_buf #(
      .width_p($bits(bsg_manycore_ruche_x_link_sif_s))
      ,.harden_p(1)
    ) buf0 (
      .i(core_ruche_link_lo[E])
      ,.o(core_ruche_link_o)
    );
  end
  else
  begin
    assign core_link_sif_li  [E] = '0;
    assign core_ruche_link_li[E] = '0;
    assign core_link_sif_li  [W] = core_hor_link_sif_i;
    assign core_ruche_link_li[W] = core_ruche_link_i;
    assign core_hor_link_sif_o = core_link_sif_lo  [W];
    assign core_ruche_link_o   = core_ruche_link_lo[W];
  end

  bsg_manycore_hor_io_router
 #(.addr_width_p    (addr_width_p)
  ,.data_width_p    (data_width_p)
  ,.x_cord_width_p  (x_cord_width_p)
  ,.y_cord_width_p  (y_cord_width_p)
  ,.ruche_factor_X_p(ruche_factor_X_p)
  ,.tieoff_west_p   (tieoff_east_not_west_p == 0)
  ,.tieoff_east_p   (tieoff_east_not_west_p)
  ) io_rtr
  (.clk_i           (core_clk_i)
  ,.reset_i         (core_reset_r)

  ,.link_sif_i      (core_link_sif_li)
  ,.link_sif_o      (core_link_sif_lo)

  ,.proc_link_sif_i (proc_link_sif_li)
  ,.proc_link_sif_o (proc_link_sif_lo)

  ,.ruche_link_i    (core_ruche_link_li)
  ,.ruche_link_o    (core_ruche_link_lo)

  ,.global_x_i      (core_global_x_r)
  ,.global_y_i      (core_global_y_r)
  );

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
  ,.bypass_upstream_twofer_fifo_p  (0)
  ,.bypass_downstream_twofer_fifo_p(1)
  ) fwd_sdr
  (.core_clk_i             (core_clk_i)
  ,.core_uplink_reset_i    (core_uplink_reset_sync     | async_fwd_link_o_disable_i)
  ,.core_downstream_reset_i(core_downstream_reset_sync | async_fwd_link_i_disable_i)
  ,.async_downlink_reset_i (async_downlink_reset_i     | async_fwd_link_i_disable_i)
  ,.async_token_reset_i    (async_token_reset_i        | async_fwd_link_o_disable_i)

  ,.core_data_i (proc_link_sif_lo.fwd.data)
  ,.core_v_i    (proc_link_sif_lo.fwd.v)
  ,.core_ready_o(proc_link_sif_li.fwd.ready_and_rev)

  ,.core_data_o (proc_link_sif_li.fwd.data)
  ,.core_v_o    (proc_link_sif_li.fwd.v)
  ,.core_yumi_i (proc_link_sif_li.fwd.v & proc_link_sif_lo.fwd.ready_and_rev)

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
  ,.bypass_upstream_twofer_fifo_p  (0)
  ,.bypass_downstream_twofer_fifo_p(1)
  ) rev_sdr
  (.core_clk_i             (core_clk_i)
  ,.core_uplink_reset_i    (core_uplink_reset_sync     | async_rev_link_o_disable_i)
  ,.core_downstream_reset_i(core_downstream_reset_sync | async_rev_link_i_disable_i)
  ,.async_downlink_reset_i (async_downlink_reset_i     | async_rev_link_i_disable_i)
  ,.async_token_reset_i    (async_token_reset_i        | async_rev_link_o_disable_i)

  ,.core_data_i (proc_link_sif_lo.rev.data)
  ,.core_v_i    (proc_link_sif_lo.rev.v)
  ,.core_ready_o(proc_link_sif_li.rev.ready_and_rev)

  ,.core_data_o (proc_link_sif_li.rev.data)
  ,.core_v_o    (proc_link_sif_li.rev.v)
  ,.core_yumi_i (proc_link_sif_li.rev.v & proc_link_sif_lo.rev.ready_and_rev)

  ,.link_clk_o  (io_rev_link_clk_o)
  ,.link_data_o (io_rev_link_data_o)
  ,.link_v_o    (io_rev_link_v_o)
  ,.link_token_i(io_rev_link_token_i)

  ,.link_clk_i  (io_rev_link_clk_i)
  ,.link_data_i (io_rev_link_data_i)
  ,.link_v_i    (io_rev_link_v_i)
  ,.link_token_o(io_rev_link_token_o)
  );
