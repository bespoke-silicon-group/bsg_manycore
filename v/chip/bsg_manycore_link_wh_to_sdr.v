
 import bsg_noc_pkg::*;
 import bsg_tag_pkg::*;
 import bsg_manycore_pkg::*;

 #(parameter lg_fifo_depth_p                 = "inv"
  ,parameter lg_credit_to_token_decimation_p = "inv"

  ,parameter addr_width_p      = "inv"
  ,parameter data_width_p      = "inv"
  ,parameter x_cord_width_p    = "inv"
  ,parameter y_cord_width_p    = "inv"

  ,parameter wh_ruche_factor_p = "inv"
  ,parameter wh_flit_width_p   = "inv"

  ,parameter tag_els_p=1024
  ,parameter tag_local_els_p=4*2
  ,parameter tag_lg_width_p=4
  ,parameter tag_lg_els_lp=`BSG_SAFE_CLOG2(tag_els_p)
    

  ,parameter link_sif_width_lp =
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter fwd_width_lp =
    `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter rev_width_lp =
    `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  ,parameter wh_link_sif_width_lp =
    `bsg_ready_and_link_sif_width(wh_flit_width_p)
  )

  (input  core_clk_i
  ,input  core_reset_i
  ,output core_reset_o

  ,input  [link_sif_width_lp-1:0] core_ver_link_sif_i
  ,output [link_sif_width_lp-1:0] core_ver_link_sif_o

  ,input  [wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] core_wh_link_sif_i
  ,output [wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] core_wh_link_sif_o

  ,input  [x_cord_width_p-1:0] core_global_x_i
  ,input  [y_cord_width_p-1:0] core_global_y_i
  ,output [x_cord_width_p-1:0] core_global_x_o
  ,output [y_cord_width_p-1:0] core_global_y_o


  // tag master
  ,input tag_clk_i
  ,input tag_data_i
  ,input [tag_lg_els_lp-1:0] tag_node_id_offset_i

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

  ,output [wh_ruche_factor_p-1:0]                      io_wh_link_clk_o
  ,output [wh_ruche_factor_p-1:0][wh_flit_width_p-1:0] io_wh_link_data_o
  ,output [wh_ruche_factor_p-1:0]                      io_wh_link_v_o
  ,input  [wh_ruche_factor_p-1:0]                      io_wh_link_token_i

  ,input  [wh_ruche_factor_p-1:0]                      io_wh_link_clk_i
  ,input  [wh_ruche_factor_p-1:0][wh_flit_width_p-1:0] io_wh_link_data_i
  ,input  [wh_ruche_factor_p-1:0]                      io_wh_link_v_i
  ,output [wh_ruche_factor_p-1:0]                      io_wh_link_token_o
  );


  
  // BTM
  bsg_tag_s [tag_local_els_p-1:0] clients_lo;
  bsg_tag_master_decentralized #(
    .els_p(tag_els_p)
    ,.local_els_p(tag_local_els_p)
    ,.lg_width_p(tag_lg_width_p)
  ) btm0 (
    .clk_i(tag_clk_i)
    ,.data_i(tag_data_i)
    ,.node_id_offset_i(tag_node_id_offset_i)
    ,.clients_o(clients_lo)
  );

  // BTC
  logic async_uplink_reset_lo;
  logic async_downlink_reset_lo;
  logic async_downstream_reset_lo;
  logic async_token_reset_lo;
  
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc0 (
    .bsg_tag_i(clients_lo[0])
    ,.data_async_r_o({async_token_reset_lo})
  );
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc1 (
    .bsg_tag_i(clients_lo[1])
    ,.data_async_r_o({async_downstream_reset_lo})
  );
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc2 (
    .bsg_tag_i(clients_lo[2])
    ,.data_async_r_o({async_downlink_reset_lo})
  );
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc3 (
    .bsg_tag_i(clients_lo[3])
    ,.data_async_r_o({async_uplink_reset_lo})
  );


  logic async_wh_uplink_reset_lo;
  logic async_wh_downlink_reset_lo;
  logic async_wh_downstream_reset_lo;
  logic async_wh_token_reset_lo;
  
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc4 (
    .bsg_tag_i(clients_lo[4])
    ,.data_async_r_o({async_wh_token_reset_lo})
  );
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc5 (
    .bsg_tag_i(clients_lo[5])
    ,.data_async_r_o({async_wh_downstream_reset_lo})
  );
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc6 (
    .bsg_tag_i(clients_lo[6])
    ,.data_async_r_o({async_wh_downlink_reset_lo})
  );
  bsg_tag_client_unsync #(
    .width_p(1)
  ) btc7 (
    .bsg_tag_i(clients_lo[7])
    ,.data_async_r_o({async_wh_uplink_reset_lo})
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
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);

  bsg_manycore_link_sif_s ver_link_sif_li, ver_link_sif_lo;
  wh_link_sif_s [wh_ruche_factor_p-1:0] wh_link_sif_li, wh_link_sif_lo;

  assign ver_link_sif_li = core_ver_link_sif_i;
  assign core_ver_link_sif_o = ver_link_sif_lo;
  // hard-coded from ruche factor = 2
  assign wh_link_sif_li[0] = core_wh_link_sif_i[0];
  assign core_wh_link_sif_o[0] = wh_link_sif_lo[0];
  bsg_inv #(
    .width_p($bits(wh_link_sif_s))
    ,.harden_p(1)
  ) hard_inv_in (
    .i(core_wh_link_sif_i[1])
    ,.o(wh_link_sif_li[1])
  );
  bsg_inv #(
    .width_p($bits(wh_link_sif_s))
    ,.harden_p(1)
  ) hard_inv_out (
    .i(wh_link_sif_lo[1])
    ,.o(core_wh_link_sif_o[1])
  );

  assign async_uplink_reset_o     = async_uplink_reset_lo;
  assign async_downlink_reset_o   = async_downlink_reset_lo;
  assign async_downstream_reset_o = async_downstream_reset_lo;
  assign async_token_reset_o      = async_token_reset_lo;

  logic core_uplink_reset_sync, core_downstream_reset_sync;
  bsg_sync_sync #(.width_p(1)) up_bss
  (.oclk_i     (core_clk_i            )
  ,.iclk_data_i(async_uplink_reset_lo  )
  ,.oclk_data_o(core_uplink_reset_sync)
  );
  bsg_sync_sync #(.width_p(1)) down_bss
  (.oclk_i     (core_clk_i                )
  ,.iclk_data_i(async_downstream_reset_lo  )
  ,.oclk_data_o(core_downstream_reset_sync)
  );

  logic core_wh_uplink_reset_sync, core_wh_downstream_reset_sync;
  bsg_sync_sync #(.width_p(1)) wh_up_bss
  (.oclk_i     (core_clk_i            )
  ,.iclk_data_i(async_wh_uplink_reset_lo  )
  ,.oclk_data_o(core_wh_uplink_reset_sync)
  );
  bsg_sync_sync #(.width_p(1)) wh_down_bss
  (.oclk_i     (core_clk_i                )
  ,.iclk_data_i(async_wh_downstream_reset_lo  )
  ,.oclk_data_o(core_wh_downstream_reset_sync)
  );

  bsg_link_sdr
 #(.width_p                        (fwd_width_lp)
  ,.lg_fifo_depth_p                (lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.bypass_upstream_twofer_fifo_p  (0)
  ,.bypass_downstream_twofer_fifo_p(0)
  ) fwd_sdr
  (.core_clk_i             (core_clk_i)
  ,.core_uplink_reset_i    (core_uplink_reset_sync     | async_fwd_link_o_disable_i)
  ,.core_downstream_reset_i(core_downstream_reset_sync | async_fwd_link_i_disable_i)
  ,.async_downlink_reset_i (async_downlink_reset_lo    | async_fwd_link_i_disable_i)
  ,.async_token_reset_i    (async_token_reset_lo       | async_fwd_link_o_disable_i)

  ,.core_data_i (ver_link_sif_li.fwd.data)
  ,.core_v_i    (ver_link_sif_li.fwd.v)
  ,.core_ready_o(ver_link_sif_lo.fwd.ready_and_rev)

  ,.core_data_o (ver_link_sif_lo.fwd.data)
  ,.core_v_o    (ver_link_sif_lo.fwd.v)
  ,.core_yumi_i (ver_link_sif_lo.fwd.v & ver_link_sif_li.fwd.ready_and_rev)

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
  ,.bypass_downstream_twofer_fifo_p(0)
  ) rev_sdr
  (.core_clk_i             (core_clk_i)
  ,.core_uplink_reset_i    (core_uplink_reset_sync     | async_rev_link_o_disable_i)
  ,.core_downstream_reset_i(core_downstream_reset_sync | async_rev_link_i_disable_i)
  ,.async_downlink_reset_i (async_downlink_reset_lo    | async_rev_link_i_disable_i)
  ,.async_token_reset_i    (async_token_reset_lo       | async_rev_link_o_disable_i)

  ,.core_data_i (ver_link_sif_li.rev.data)
  ,.core_v_i    (ver_link_sif_li.rev.v)
  ,.core_ready_o(ver_link_sif_lo.rev.ready_and_rev)

  ,.core_data_o (ver_link_sif_lo.rev.data)
  ,.core_v_o    (ver_link_sif_lo.rev.v)
  ,.core_yumi_i (ver_link_sif_lo.rev.v & ver_link_sif_li.rev.ready_and_rev)

  ,.link_clk_o  (io_rev_link_clk_o)
  ,.link_data_o (io_rev_link_data_o)
  ,.link_v_o    (io_rev_link_v_o)
  ,.link_token_i(io_rev_link_token_i)

  ,.link_clk_i  (io_rev_link_clk_i)
  ,.link_data_i (io_rev_link_data_i)
  ,.link_v_i    (io_rev_link_v_i)
  ,.link_token_o(io_rev_link_token_o)
  );

  for (genvar i = 0; i < wh_ruche_factor_p; i++)
  begin: wh_sdr
    bsg_link_sdr
   #(.width_p                        (wh_flit_width_p)
    ,.lg_fifo_depth_p                (lg_fifo_depth_p)
    ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
    ,.bypass_upstream_twofer_fifo_p  (0)
    ,.bypass_downstream_twofer_fifo_p(0)
    ) sdr
    (.core_clk_i             (core_clk_i)
    ,.core_uplink_reset_i    (core_wh_uplink_reset_sync)
    ,.core_downstream_reset_i(core_wh_downstream_reset_sync)
    ,.async_downlink_reset_i (async_wh_downlink_reset_lo)
    ,.async_token_reset_i    (async_wh_token_reset_lo)

    ,.core_data_i (wh_link_sif_li[i].data)
    ,.core_v_i    (wh_link_sif_li[i].v)
    ,.core_ready_o(wh_link_sif_lo[i].ready_and_rev)

    ,.core_data_o (wh_link_sif_lo[i].data)
    ,.core_v_o    (wh_link_sif_lo[i].v)
    ,.core_yumi_i (wh_link_sif_lo[i].v & wh_link_sif_li[i].ready_and_rev)

    ,.link_clk_o  (io_wh_link_clk_o  [i])
    ,.link_data_o (io_wh_link_data_o [i])
    ,.link_v_o    (io_wh_link_v_o    [i])
    ,.link_token_i(io_wh_link_token_i[i])

    ,.link_clk_i  (io_wh_link_clk_i  [i])
    ,.link_data_i (io_wh_link_data_i [i])
    ,.link_v_i    (io_wh_link_v_i    [i])
    ,.link_token_o(io_wh_link_token_o[i])
    );
  end
