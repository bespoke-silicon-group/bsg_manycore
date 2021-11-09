/**
 *    bsg_manycore_pod_row_sdr.v
 *
 */


module bsg_manycore_pod_row_sdr
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_chip_pkg::*;
  #(parameter fwd_width_lp =
      `bsg_manycore_packet_width(hb_addr_width_gp,hb_data_width_gp,hb_x_cord_width_gp,hb_y_cord_width_gp)
    , parameter rev_width_lp =
      `bsg_manycore_return_packet_width(hb_x_cord_width_gp,hb_y_cord_width_gp,hb_data_width_gp)

    ,  parameter total_num_tiles_x_lp=(hb_num_pods_x_gp*hb_num_tiles_x_gp)

    , parameter num_clk_ports_p=1

    , parameter tag_els_p=1024
    , parameter tag_lg_els_lp=`BSG_SAFE_CLOG2(tag_els_p)
  )
  (
    // clk gen
    input ext_clk_i

    // pod tag
    , input [hb_num_pods_x_gp-1:0] pod_tag_clk_i
    , input [hb_num_pods_x_gp-1:0] pod_tag_data_i
    , input [hb_num_pods_x_gp-1:0][tag_lg_els_lp-1:0] pod_tag_node_id_offset_i


    , input [S:N][E:W] async_reset_tag_clk_i
    , input [S:N][E:W] async_reset_tag_data_i
    , input [S:N][E:W][tag_lg_els_lp-1:0] async_reset_tag_node_id_offset_i

    // global coordinates
    , input [2+total_num_tiles_x_lp-1:0][hb_x_cord_width_gp-1:0] global_x_i
    , input [2+total_num_tiles_x_lp-1:0][hb_y_cord_width_gp-1:0] global_y_i

    // ver IO
    , input  [S:N][2+total_num_tiles_x_lp-1:0] async_ver_fwd_link_i_disable_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0] async_ver_fwd_link_o_disable_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0] async_ver_rev_link_i_disable_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0] async_ver_rev_link_o_disable_i

    , output [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_fwd_link_clk_o
    , output [S:N][2+total_num_tiles_x_lp-1:0][fwd_width_lp-1:0]  ver_io_fwd_link_data_o
    , output [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_fwd_link_v_o
    , input  [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_fwd_link_token_i

    , input  [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_fwd_link_clk_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0][fwd_width_lp-1:0]  ver_io_fwd_link_data_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_fwd_link_v_i
    , output [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_fwd_link_token_o

    , output [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_rev_link_clk_o
    , output [S:N][2+total_num_tiles_x_lp-1:0][rev_width_lp-1:0]  ver_io_rev_link_data_o
    , output [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_rev_link_v_o
    , input  [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_rev_link_token_i

    , input  [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_rev_link_clk_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0][rev_width_lp-1:0]  ver_io_rev_link_data_i
    , input  [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_rev_link_v_i
    , output [S:N][2+total_num_tiles_x_lp-1:0]                    ver_io_rev_link_token_o

    // hor manycore IO
    , input  [E:W][hb_num_tiles_y_gp-1:0] async_hor_fwd_link_i_disable_i
    , input  [E:W][hb_num_tiles_y_gp-1:0] async_hor_fwd_link_o_disable_i
    , input  [E:W][hb_num_tiles_y_gp-1:0] async_hor_rev_link_i_disable_i
    , input  [E:W][hb_num_tiles_y_gp-1:0] async_hor_rev_link_o_disable_i

    , output [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_fwd_link_clk_o
    , output [E:W][hb_num_tiles_y_gp-1:0][fwd_width_lp-1:0]       hor_io_fwd_link_data_o
    , output [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_fwd_link_v_o
    , input  [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_fwd_link_token_i

    , input  [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_fwd_link_clk_i
    , input  [E:W][hb_num_tiles_y_gp-1:0][fwd_width_lp-1:0]       hor_io_fwd_link_data_i
    , input  [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_fwd_link_v_i
    , output [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_fwd_link_token_o

    , output [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_rev_link_clk_o
    , output [E:W][hb_num_tiles_y_gp-1:0][rev_width_lp-1:0]       hor_io_rev_link_data_o
    , output [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_rev_link_v_o
    , input  [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_rev_link_token_i

    , input  [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_rev_link_clk_i
    , input  [E:W][hb_num_tiles_y_gp-1:0][rev_width_lp-1:0]       hor_io_rev_link_data_i
    , input  [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_rev_link_v_i
    , output [E:W][hb_num_tiles_y_gp-1:0]                         hor_io_rev_link_token_o

    // wh IO
    , output [E:W][S:N][wh_ruche_factor_gp-1:0]                           io_wh_link_clk_o
    , output [E:W][S:N][wh_ruche_factor_gp-1:0][wh_flit_width_gp-1:0]     io_wh_link_data_o
    , output [E:W][S:N][wh_ruche_factor_gp-1:0]                           io_wh_link_v_o
    , input  [E:W][S:N][wh_ruche_factor_gp-1:0]                           io_wh_link_token_i

    , input  [E:W][S:N][wh_ruche_factor_gp-1:0]                           io_wh_link_clk_i
    , input  [E:W][S:N][wh_ruche_factor_gp-1:0][wh_flit_width_gp-1:0]     io_wh_link_data_i
    , input  [E:W][S:N][wh_ruche_factor_gp-1:0]                           io_wh_link_v_i
    , output [E:W][S:N][wh_ruche_factor_gp-1:0]                           io_wh_link_token_o
  );


  // link structs
  `declare_bsg_manycore_link_sif_s(hb_addr_width_gp,hb_data_width_gp,hb_x_cord_width_gp,hb_y_cord_width_gp);
  `declare_bsg_manycore_ruche_x_link_sif_s(hb_addr_width_gp,hb_data_width_gp,hb_x_cord_width_gp,hb_y_cord_width_gp);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_gp, wh_link_sif_s);


  // CLOCK GEN
  logic core_clk;
  assign core_clk = ext_clk_i;


  // POD array
  logic [hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0] pod_reset_li;
  logic [hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0][hb_x_cord_width_gp-1:0] pod_global_x_li;
  logic [hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0][hb_y_cord_width_gp-1:0] pod_global_y_li;

  bsg_manycore_link_sif_s [S:N][hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0] pod_ver_link_sif_li, pod_ver_link_sif_lo;
  wh_link_sif_s [E:W][S:N][wh_ruche_factor_gp-1:0] pod_wh_link_sif_li, pod_wh_link_sif_lo;
  bsg_manycore_link_sif_s [E:W][hb_num_tiles_y_gp-1:0] pod_hor_link_sif_li, pod_hor_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [E:W][hb_num_tiles_y_gp-1:0] pod_ruche_link_li, pod_ruche_link_lo;

  bsg_manycore_pod_ruche_row #(
    .num_tiles_x_p        (hb_num_tiles_x_gp)
    ,.num_tiles_y_p       (hb_num_tiles_y_gp)
    ,.pod_x_cord_width_p  (hb_pod_x_cord_width_gp)
    ,.pod_y_cord_width_p  (hb_pod_y_cord_width_gp)
    ,.x_cord_width_p      (hb_x_cord_width_gp)
    ,.y_cord_width_p      (hb_y_cord_width_gp)
    ,.addr_width_p        (hb_addr_width_gp)
    ,.data_width_p        (hb_data_width_gp)
    ,.ruche_factor_X_p    (hb_ruche_factor_X_gp)

    ,.num_subarray_x_p    (hb_num_subarray_x_gp)
    ,.num_subarray_y_p    (hb_num_subarray_y_gp)

    ,.dmem_size_p         (hb_dmem_size_gp)
    ,.icache_entries_p    (hb_icache_entries_gp)
    ,.icache_tag_width_p  (hb_icache_tag_width_gp)

    ,.num_vcache_rows_p   (num_vcache_rows_gp)
    ,.vcache_addr_width_p (vcache_addr_width_gp)
    ,.vcache_data_width_p (vcache_data_width_gp)
    ,.vcache_ways_p       (vcache_ways_gp)
    ,.vcache_sets_p       (vcache_sets_gp)
    ,.vcache_block_size_in_words_p  (vcache_block_size_in_words_gp)
    ,.vcache_size_p                 (vcache_size_gp)
    ,.vcache_dma_data_width_p       (vcache_dma_data_width_gp)

    ,.wh_ruche_factor_p   (wh_ruche_factor_gp)
    ,.wh_cid_width_p      (wh_cid_width_gp)
    ,.wh_flit_width_p     (wh_flit_width_gp)
    ,.wh_cord_width_p     (wh_cord_width_gp)
    ,.wh_len_width_p      (wh_len_width_gp)

    ,.num_pods_x_p        (hb_num_pods_x_gp)

    ,.num_clk_ports_p     (num_clk_ports_p)
  ) podrow (
    .clk_i              (core_clk)
    ,.reset_i           (pod_reset_li)

    ,.ver_link_sif_i    (pod_ver_link_sif_li)
    ,.ver_link_sif_o    (pod_ver_link_sif_lo)

    ,.wh_link_sif_i     (pod_wh_link_sif_li)
    ,.wh_link_sif_o     (pod_wh_link_sif_lo)

    ,.hor_link_sif_i    (pod_hor_link_sif_li)
    ,.hor_link_sif_o    (pod_hor_link_sif_lo)

    ,.ruche_link_i      (pod_ruche_link_li)
    ,.ruche_link_o      (pod_ruche_link_lo)

    ,.global_x_i        (pod_global_x_li)
    ,.global_y_i        (pod_global_y_li)
  );


  // NORTH SDR
  logic [hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0] sdr_n_core_reset_ver_lo;
  logic [hb_num_pods_x_gp-1:0][E:W] sdr_n_core_reset_lo;
  logic [hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0][hb_x_cord_width_gp-1:0] sdr_n_core_global_x_li, sdr_n_core_global_x_lo;
  logic [hb_num_pods_x_gp-1:0][hb_num_tiles_x_gp-1:0][hb_y_cord_width_gp-1:0] sdr_n_core_global_y_li, sdr_n_core_global_y_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_n_async_uplink_reset_li,     sdr_n_async_uplink_reset_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_n_async_downlink_reset_li,   sdr_n_async_downlink_reset_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_n_async_downstream_reset_li, sdr_n_async_downstream_reset_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_n_async_token_reset_li,      sdr_n_async_token_reset_lo;

  for (genvar x = 0; x < hb_num_pods_x_gp; x++) begin: sdr_n_x
    bsg_manycore_link_to_sdr_north_row #(
      .lg_fifo_depth_p                  (sdr_lg_fifo_depth_gp)
      ,.lg_credit_to_token_decimation_p (sdr_lg_credit_to_token_decimation_gp)
      ,.num_tiles_x_p                   (hb_num_tiles_x_gp)
      ,.x_cord_width_p                  (hb_x_cord_width_gp)
      ,.y_cord_width_p                  (hb_y_cord_width_gp)
      ,.addr_width_p                    (hb_addr_width_gp)
      ,.data_width_p                    (hb_data_width_gp)
      ,.num_clk_ports_p(num_clk_ports_p)
    ) sdr_n (
      .core_clk_i                 ({num_clk_ports_p{core_clk}})
      ,.core_reset_o              (sdr_n_core_reset_lo[x])
      ,.core_reset_ver_o          (sdr_n_core_reset_ver_lo[x])

      ,.core_global_x_i           (sdr_n_core_global_x_li[x])
      ,.core_global_y_i           (sdr_n_core_global_y_li[x])
      ,.core_global_x_o           (sdr_n_core_global_x_lo[x])
      ,.core_global_y_o           (sdr_n_core_global_y_lo[x])

      ,.core_link_sif_i           (pod_ver_link_sif_lo[N][x])
      ,.core_link_sif_o           (pod_ver_link_sif_li[N][x])

      ,.async_uplink_reset_i      (sdr_n_async_uplink_reset_li[x])
      ,.async_downlink_reset_i    (sdr_n_async_downlink_reset_li[x])
      ,.async_downstream_reset_i  (sdr_n_async_downstream_reset_li[x])
      ,.async_token_reset_i       (sdr_n_async_token_reset_li[x])

      ,.async_uplink_reset_o      (sdr_n_async_uplink_reset_lo[x])
      ,.async_downlink_reset_o    (sdr_n_async_downlink_reset_lo[x])
      ,.async_downstream_reset_o  (sdr_n_async_downstream_reset_lo[x])
      ,.async_token_reset_o       (sdr_n_async_token_reset_lo[x])

      ,.async_fwd_link_i_disable_i(async_ver_fwd_link_i_disable_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.async_fwd_link_o_disable_i(async_ver_fwd_link_o_disable_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.async_rev_link_i_disable_i(async_ver_rev_link_i_disable_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.async_rev_link_o_disable_i(async_ver_rev_link_o_disable_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_fwd_link_clk_o         (ver_io_fwd_link_clk_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_data_o        (ver_io_fwd_link_data_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_v_o           (ver_io_fwd_link_v_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_token_i       (ver_io_fwd_link_token_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_fwd_link_clk_i         (ver_io_fwd_link_clk_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_data_i        (ver_io_fwd_link_data_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_v_i           (ver_io_fwd_link_v_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_token_o       (ver_io_fwd_link_token_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_rev_link_clk_o         (ver_io_rev_link_clk_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_data_o        (ver_io_rev_link_data_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_v_o           (ver_io_rev_link_v_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_token_i       (ver_io_rev_link_token_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_rev_link_clk_i         (ver_io_rev_link_clk_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_data_i        (ver_io_rev_link_data_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_v_i           (ver_io_rev_link_v_i[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_token_o       (ver_io_rev_link_token_o[N][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.tag_clk_i         (pod_tag_clk_i[x])
      ,.tag_data_i        (pod_tag_data_i[x])
      ,.node_id_offset_i  (pod_tag_node_id_offset_i[x])
    );


    // connect async_reset between sdr
    if (x > 0) begin
      assign sdr_n_async_uplink_reset_li[x]     = sdr_n_async_uplink_reset_lo[x-1];
      assign sdr_n_async_downlink_reset_li[x]   = sdr_n_async_downlink_reset_lo[x-1];
      assign sdr_n_async_downstream_reset_li[x] = sdr_n_async_downstream_reset_lo[x-1];
      assign sdr_n_async_token_reset_li[x]      = sdr_n_async_token_reset_lo[x-1];
    end
  
  end

  assign sdr_n_core_global_x_li = global_x_i[1+:total_num_tiles_x_lp];
  assign sdr_n_core_global_y_li = global_y_i[1+:total_num_tiles_x_lp];
  assign pod_global_x_li = sdr_n_core_global_x_lo;
  assign pod_global_y_li = sdr_n_core_global_y_lo;
  assign pod_reset_li = sdr_n_core_reset_ver_lo;


  // SOUTH SDR
  logic [hb_num_pods_x_gp-1:0] sdr_s_async_uplink_reset_li,     sdr_s_async_uplink_reset_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_s_async_downlink_reset_li,   sdr_s_async_downlink_reset_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_s_async_downstream_reset_li, sdr_s_async_downstream_reset_lo;
  logic [hb_num_pods_x_gp-1:0] sdr_s_async_token_reset_li,      sdr_s_async_token_reset_lo;

  for (genvar x = 0; x < hb_num_pods_x_gp; x++) begin: sdr_s_x
    bsg_manycore_link_to_sdr_south_row #(
      .lg_fifo_depth_p                  (sdr_lg_fifo_depth_gp)
      ,.lg_credit_to_token_decimation_p (sdr_lg_credit_to_token_decimation_gp)
      ,.num_tiles_x_p       (hb_num_tiles_x_gp)
      ,.x_cord_width_p      (hb_x_cord_width_gp)
      ,.y_cord_width_p      (hb_y_cord_width_gp)
      ,.addr_width_p        (hb_addr_width_gp)
      ,.data_width_p        (hb_data_width_gp)
      ,.num_clk_ports_p(num_clk_ports_p)
    ) sdr_s (
      .core_clk_i({num_clk_ports_p{core_clk}})

      ,.core_link_sif_i           (pod_ver_link_sif_lo[S][x])
      ,.core_link_sif_o           (pod_ver_link_sif_li[S][x])

      ,.async_uplink_reset_i      (sdr_s_async_uplink_reset_li[x])
      ,.async_downlink_reset_i    (sdr_s_async_downlink_reset_li[x])
      ,.async_downstream_reset_i  (sdr_s_async_downstream_reset_li[x])
      ,.async_token_reset_i       (sdr_s_async_token_reset_li[x])

      ,.async_uplink_reset_o      (sdr_s_async_uplink_reset_lo[x])
      ,.async_downlink_reset_o    (sdr_s_async_downlink_reset_lo[x])
      ,.async_downstream_reset_o  (sdr_s_async_downstream_reset_lo[x])
      ,.async_token_reset_o       (sdr_s_async_token_reset_lo[x])

      ,.async_fwd_link_i_disable_i(async_ver_fwd_link_i_disable_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.async_fwd_link_o_disable_i(async_ver_fwd_link_o_disable_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.async_rev_link_i_disable_i(async_ver_rev_link_i_disable_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.async_rev_link_o_disable_i(async_ver_rev_link_o_disable_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_fwd_link_clk_o         (ver_io_fwd_link_clk_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_data_o        (ver_io_fwd_link_data_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_v_o           (ver_io_fwd_link_v_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_token_i       (ver_io_fwd_link_token_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_fwd_link_clk_i         (ver_io_fwd_link_clk_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_data_i        (ver_io_fwd_link_data_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_v_i           (ver_io_fwd_link_v_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_fwd_link_token_o       (ver_io_fwd_link_token_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_rev_link_clk_o         (ver_io_rev_link_clk_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_data_o        (ver_io_rev_link_data_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_v_o           (ver_io_rev_link_v_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_token_i       (ver_io_rev_link_token_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])

      ,.io_rev_link_clk_i         (ver_io_rev_link_clk_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_data_i        (ver_io_rev_link_data_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_v_i           (ver_io_rev_link_v_i[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
      ,.io_rev_link_token_o       (ver_io_rev_link_token_o[S][(x*hb_num_tiles_x_gp)+1+:hb_num_tiles_x_gp])
    );

    // connect async_reset between sdr
    if (x > 0) begin
      assign sdr_s_async_uplink_reset_li[x-1]     = sdr_s_async_uplink_reset_lo[x];
      assign sdr_s_async_downlink_reset_li[x-1]   = sdr_s_async_downlink_reset_lo[x];
      assign sdr_s_async_downstream_reset_li[x-1] = sdr_s_async_downstream_reset_lo[x];
      assign sdr_s_async_token_reset_li[x-1]      = sdr_s_async_token_reset_lo[x];
    end
  end


  // WEST SDR
  logic [hb_num_tiles_y_gp-1:0] sdr_w_core_reset_li, sdr_w_core_reset_lo;
  logic [hb_num_tiles_y_gp-1:0][hb_x_cord_width_gp-1:0] sdr_w_core_global_x_li, sdr_w_core_global_x_lo;
  logic [hb_num_tiles_y_gp-1:0][hb_y_cord_width_gp-1:0] sdr_w_core_global_y_li, sdr_w_core_global_y_lo;


  bsg_manycore_link_sif_s [hb_num_tiles_y_gp-1:0][S:N] sdr_w_ver_link_sif_li, sdr_w_ver_link_sif_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_w_async_uplink_reset_li,     sdr_w_async_uplink_reset_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_w_async_downlink_reset_li,   sdr_w_async_downlink_reset_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_w_async_downstream_reset_li, sdr_w_async_downstream_reset_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_w_async_token_reset_li,      sdr_w_async_token_reset_lo;

  for (genvar y = 0; y < hb_num_tiles_y_gp; y++) begin: sdr_w_y
    bsg_manycore_link_ruche_to_sdr_west #(
      .lg_fifo_depth_p                  (sdr_lg_fifo_depth_gp)
      ,.lg_credit_to_token_decimation_p (sdr_lg_credit_to_token_decimation_gp)

      ,.x_cord_width_p      (hb_x_cord_width_gp)
      ,.y_cord_width_p      (hb_y_cord_width_gp)
      ,.addr_width_p        (hb_addr_width_gp)
      ,.data_width_p        (hb_data_width_gp)
      ,.ruche_factor_X_p    (hb_ruche_factor_X_gp)
    ) sdr_w (
      .core_clk_i       (core_clk)
      ,.core_reset_i    (sdr_w_core_reset_li[y])
      ,.core_reset_o    (sdr_w_core_reset_lo[y])

      ,.core_ver_link_sif_i   (sdr_w_ver_link_sif_li[y])
      ,.core_ver_link_sif_o   (sdr_w_ver_link_sif_lo[y])

      ,.core_hor_link_sif_i   (pod_hor_link_sif_lo[W][y])
      ,.core_hor_link_sif_o   (pod_hor_link_sif_li[W][y])

      ,.core_ruche_link_i     (pod_ruche_link_lo[W][y])
      ,.core_ruche_link_o     (pod_ruche_link_li[W][y])

      ,.core_global_x_i       (sdr_w_core_global_x_li[y])
      ,.core_global_y_i       (sdr_w_core_global_y_li[y])
      ,.core_global_x_o       (sdr_w_core_global_x_lo[y])
      ,.core_global_y_o       (sdr_w_core_global_y_lo[y])

      ,.async_uplink_reset_i      (sdr_w_async_uplink_reset_li[y])
      ,.async_downlink_reset_i    (sdr_w_async_downlink_reset_li[y])
      ,.async_downstream_reset_i  (sdr_w_async_downstream_reset_li[y])
      ,.async_token_reset_i       (sdr_w_async_token_reset_li[y])

      ,.async_uplink_reset_o      (sdr_w_async_uplink_reset_lo[y])
      ,.async_downlink_reset_o    (sdr_w_async_downlink_reset_lo[y])
      ,.async_downstream_reset_o  (sdr_w_async_downstream_reset_lo[y])
      ,.async_token_reset_o       (sdr_w_async_token_reset_lo[y])

      ,.async_fwd_link_i_disable_i(async_hor_fwd_link_i_disable_i[W][y])
      ,.async_fwd_link_o_disable_i(async_hor_fwd_link_o_disable_i[W][y])
      ,.async_rev_link_i_disable_i(async_hor_rev_link_i_disable_i[W][y])
      ,.async_rev_link_o_disable_i(async_hor_rev_link_o_disable_i[W][y])

      ,.io_fwd_link_clk_o       (hor_io_fwd_link_clk_o[W][y])
      ,.io_fwd_link_data_o      (hor_io_fwd_link_data_o[W][y])
      ,.io_fwd_link_v_o         (hor_io_fwd_link_v_o[W][y])
      ,.io_fwd_link_token_i     (hor_io_fwd_link_token_i[W][y])

      ,.io_fwd_link_clk_i       (hor_io_fwd_link_clk_i[W][y])
      ,.io_fwd_link_data_i      (hor_io_fwd_link_data_i[W][y])
      ,.io_fwd_link_v_i         (hor_io_fwd_link_v_i[W][y])
      ,.io_fwd_link_token_o     (hor_io_fwd_link_token_o[W][y])

      ,.io_rev_link_clk_o       (hor_io_rev_link_clk_o[W][y])
      ,.io_rev_link_data_o      (hor_io_rev_link_data_o[W][y])
      ,.io_rev_link_v_o         (hor_io_rev_link_v_o[W][y])
      ,.io_rev_link_token_i     (hor_io_rev_link_token_i[W][y])

      ,.io_rev_link_clk_i       (hor_io_rev_link_clk_i[W][y])
      ,.io_rev_link_data_i      (hor_io_rev_link_data_i[W][y])
      ,.io_rev_link_v_i         (hor_io_rev_link_v_i[W][y])
      ,.io_rev_link_token_o     (hor_io_rev_link_token_o[W][y])
    );

    // connect between sdr west
    if (y < hb_num_tiles_y_gp-1) begin
      // ver link
      assign sdr_w_ver_link_sif_li[y][S] = sdr_w_ver_link_sif_lo[y+1][N];
      assign sdr_w_ver_link_sif_li[y+1][N] = sdr_w_ver_link_sif_lo[y][S];
      // async reset
      assign sdr_w_async_uplink_reset_li[y] = sdr_w_async_uplink_reset_lo[y+1];
      assign sdr_w_async_downlink_reset_li[y] = sdr_w_async_downlink_reset_lo[y+1];
      assign sdr_w_async_downstream_reset_li[y] = sdr_w_async_downstream_reset_lo[y+1];
      assign sdr_w_async_token_reset_li[y] = sdr_w_async_token_reset_lo[y+1];
      // core reset
      assign sdr_w_core_reset_li[y+1] = sdr_w_core_reset_lo[y];
      // core global cord
      assign sdr_w_core_global_x_li[y+1] = sdr_w_core_global_x_lo[y];
      assign sdr_w_core_global_y_li[y+1] = sdr_w_core_global_y_lo[y];
    end

  end

  // EAST SDR
  logic [hb_num_tiles_y_gp-1:0] sdr_e_core_reset_li, sdr_e_core_reset_lo;
  logic [hb_num_tiles_y_gp-1:0][hb_x_cord_width_gp-1:0] sdr_e_core_global_x_li, sdr_e_core_global_x_lo;
  logic [hb_num_tiles_y_gp-1:0][hb_y_cord_width_gp-1:0] sdr_e_core_global_y_li, sdr_e_core_global_y_lo;

  bsg_manycore_link_sif_s [hb_num_tiles_y_gp-1:0][S:N] sdr_e_ver_link_sif_li, sdr_e_ver_link_sif_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_e_async_uplink_reset_li,     sdr_e_async_uplink_reset_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_e_async_downlink_reset_li,   sdr_e_async_downlink_reset_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_e_async_downstream_reset_li, sdr_e_async_downstream_reset_lo;
  logic [hb_num_tiles_y_gp-1:0] sdr_e_async_token_reset_li,      sdr_e_async_token_reset_lo;

  for (genvar y = 0; y < hb_num_tiles_y_gp; y++) begin: sdr_e_y
    bsg_manycore_link_ruche_to_sdr_east #(
      .lg_fifo_depth_p                  (sdr_lg_fifo_depth_gp)
      ,.lg_credit_to_token_decimation_p (sdr_lg_credit_to_token_decimation_gp)

      ,.x_cord_width_p      (hb_x_cord_width_gp)
      ,.y_cord_width_p      (hb_y_cord_width_gp)
      ,.addr_width_p        (hb_addr_width_gp)
      ,.data_width_p        (hb_data_width_gp)
      ,.ruche_factor_X_p    (hb_ruche_factor_X_gp)
    ) sdr_e (
      .core_clk_i       (core_clk)
      ,.core_reset_i    (sdr_e_core_reset_li[y])
      ,.core_reset_o    (sdr_e_core_reset_lo[y])

      ,.core_ver_link_sif_i   (sdr_e_ver_link_sif_li[y])
      ,.core_ver_link_sif_o   (sdr_e_ver_link_sif_lo[y])

      ,.core_hor_link_sif_i   (pod_hor_link_sif_lo[E][y])
      ,.core_hor_link_sif_o   (pod_hor_link_sif_li[E][y])

      ,.core_ruche_link_i     (pod_ruche_link_lo[E][y])
      ,.core_ruche_link_o     (pod_ruche_link_li[E][y])

      ,.core_global_x_i       (sdr_e_core_global_x_li[y])
      ,.core_global_y_i       (sdr_e_core_global_y_li[y])
      ,.core_global_x_o       (sdr_e_core_global_x_lo[y])
      ,.core_global_y_o       (sdr_e_core_global_y_lo[y])

      ,.async_uplink_reset_i      (sdr_e_async_uplink_reset_li[y])
      ,.async_downlink_reset_i    (sdr_e_async_downlink_reset_li[y])
      ,.async_downstream_reset_i  (sdr_e_async_downstream_reset_li[y])
      ,.async_token_reset_i       (sdr_e_async_token_reset_li[y])

      ,.async_uplink_reset_o      (sdr_e_async_uplink_reset_lo[y])
      ,.async_downlink_reset_o    (sdr_e_async_downlink_reset_lo[y])
      ,.async_downstream_reset_o  (sdr_e_async_downstream_reset_lo[y])
      ,.async_token_reset_o       (sdr_e_async_token_reset_lo[y])

      ,.async_fwd_link_i_disable_i(async_hor_fwd_link_i_disable_i[E][y])
      ,.async_fwd_link_o_disable_i(async_hor_fwd_link_o_disable_i[E][y])
      ,.async_rev_link_i_disable_i(async_hor_rev_link_i_disable_i[E][y])
      ,.async_rev_link_o_disable_i(async_hor_rev_link_o_disable_i[E][y])

      ,.io_fwd_link_clk_o       (hor_io_fwd_link_clk_o[E][y])
      ,.io_fwd_link_data_o      (hor_io_fwd_link_data_o[E][y])
      ,.io_fwd_link_v_o         (hor_io_fwd_link_v_o[E][y])
      ,.io_fwd_link_token_i     (hor_io_fwd_link_token_i[E][y])

      ,.io_fwd_link_clk_i       (hor_io_fwd_link_clk_i[E][y])
      ,.io_fwd_link_data_i      (hor_io_fwd_link_data_i[E][y])
      ,.io_fwd_link_v_i         (hor_io_fwd_link_v_i[E][y])
      ,.io_fwd_link_token_o     (hor_io_fwd_link_token_o[E][y])

      ,.io_rev_link_clk_o       (hor_io_rev_link_clk_o[E][y])
      ,.io_rev_link_data_o      (hor_io_rev_link_data_o[E][y])
      ,.io_rev_link_v_o         (hor_io_rev_link_v_o[E][y])
      ,.io_rev_link_token_i     (hor_io_rev_link_token_i[E][y])

      ,.io_rev_link_clk_i       (hor_io_rev_link_clk_i[E][y])
      ,.io_rev_link_data_i      (hor_io_rev_link_data_i[E][y])
      ,.io_rev_link_v_i         (hor_io_rev_link_v_i[E][y])
      ,.io_rev_link_token_o     (hor_io_rev_link_token_o[E][y])
    );

    // connect between sdr east
    if (y < hb_num_tiles_y_gp-1) begin
      // ver link
      assign sdr_e_ver_link_sif_li[y][S] = sdr_e_ver_link_sif_lo[y+1][N];
      assign sdr_e_ver_link_sif_li[y+1][N] = sdr_e_ver_link_sif_lo[y][S];
      // async reset
      assign sdr_e_async_uplink_reset_li[y+1] = sdr_e_async_uplink_reset_lo[y];
      assign sdr_e_async_downlink_reset_li[y+1] = sdr_e_async_downlink_reset_lo[y];
      assign sdr_e_async_downstream_reset_li[y+1] = sdr_e_async_downstream_reset_lo[y];
      assign sdr_e_async_token_reset_li[y+1] = sdr_e_async_token_reset_lo[y];
      // core reset
      assign sdr_e_core_reset_li[y+1] = sdr_e_core_reset_lo[y];
      // core global cord
      assign sdr_e_core_global_x_li[y+1] = sdr_e_core_global_x_lo[y];
      assign sdr_e_core_global_y_li[y+1] = sdr_e_core_global_y_lo[y];
    end


  end

  // CORNER SDR NW
  bsg_manycore_link_wh_to_sdr_nw #(
    .lg_fifo_depth_p(sdr_lg_fifo_depth_gp)
    ,.lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_gp)

    ,.x_cord_width_p      (hb_x_cord_width_gp)
    ,.y_cord_width_p      (hb_y_cord_width_gp)
    ,.addr_width_p        (hb_addr_width_gp)
    ,.data_width_p        (hb_data_width_gp)

    ,.wh_ruche_factor_p   (wh_ruche_factor_gp)
    ,.wh_flit_width_p     (wh_flit_width_gp)
  ) sdr_nw (
    .core_clk_i         (core_clk)
    ,.core_reset_i      (sdr_n_core_reset_lo[0][W])
    ,.core_reset_o      (sdr_w_core_reset_li[0])

    ,.core_global_x_i   (global_x_i[0])
    ,.core_global_y_i   (global_y_i[0])
    ,.core_global_x_o   (sdr_w_core_global_x_li[0])
    ,.core_global_y_o   (sdr_w_core_global_y_li[0])

    ,.core_ver_link_sif_i         (sdr_w_ver_link_sif_lo[0][N])
    ,.core_ver_link_sif_o         (sdr_w_ver_link_sif_li[0][N])

    ,.core_wh_link_sif_i          (pod_wh_link_sif_lo[W][N])
    ,.core_wh_link_sif_o          (pod_wh_link_sif_li[W][N])


    ,.tag_clk_i               (async_reset_tag_clk_i[N][W])
    ,.tag_data_i              (async_reset_tag_data_i[N][W])
    ,.tag_node_id_offset_i    (async_reset_tag_node_id_offset_i[N][W])
    ,.async_uplink_reset_o        (sdr_n_async_uplink_reset_li[0])
    ,.async_downlink_reset_o      (sdr_n_async_downlink_reset_li[0])
    ,.async_downstream_reset_o    (sdr_n_async_downstream_reset_li[0])
    ,.async_token_reset_o         (sdr_n_async_token_reset_li[0])

    ,.async_fwd_link_i_disable_i  (async_ver_fwd_link_i_disable_i[N][0])
    ,.async_fwd_link_o_disable_i  (async_ver_fwd_link_o_disable_i[N][0])
    ,.async_rev_link_i_disable_i  (async_ver_rev_link_i_disable_i[N][0])
    ,.async_rev_link_o_disable_i  (async_ver_rev_link_o_disable_i[N][0])

    ,.io_fwd_link_clk_o           (ver_io_fwd_link_clk_o[N][0])
    ,.io_fwd_link_data_o          (ver_io_fwd_link_data_o[N][0])
    ,.io_fwd_link_v_o             (ver_io_fwd_link_v_o[N][0])
    ,.io_fwd_link_token_i         (ver_io_fwd_link_token_i[N][0])

    ,.io_fwd_link_clk_i           (ver_io_fwd_link_clk_i[N][0])
    ,.io_fwd_link_data_i          (ver_io_fwd_link_data_i[N][0])
    ,.io_fwd_link_v_i             (ver_io_fwd_link_v_i[N][0])
    ,.io_fwd_link_token_o         (ver_io_fwd_link_token_o[N][0])

    ,.io_rev_link_clk_o           (ver_io_rev_link_clk_o[N][0])
    ,.io_rev_link_data_o          (ver_io_rev_link_data_o[N][0])
    ,.io_rev_link_v_o             (ver_io_rev_link_v_o[N][0])
    ,.io_rev_link_token_i         (ver_io_rev_link_token_i[N][0])

    ,.io_rev_link_clk_i           (ver_io_rev_link_clk_i[N][0])
    ,.io_rev_link_data_i          (ver_io_rev_link_data_i[N][0])
    ,.io_rev_link_v_i             (ver_io_rev_link_v_i[N][0])
    ,.io_rev_link_token_o         (ver_io_rev_link_token_o[N][0])

    ,.io_wh_link_clk_o            (io_wh_link_clk_o[W][N])
    ,.io_wh_link_data_o           (io_wh_link_data_o[W][N])
    ,.io_wh_link_v_o              (io_wh_link_v_o[W][N])
    ,.io_wh_link_token_i          (io_wh_link_token_i[W][N])

    ,.io_wh_link_clk_i            (io_wh_link_clk_i[W][N])
    ,.io_wh_link_data_i           (io_wh_link_data_i[W][N])
    ,.io_wh_link_v_i              (io_wh_link_v_i[W][N])
    ,.io_wh_link_token_o          (io_wh_link_token_o[W][N])
  );

  // CORNER SDR NE
  bsg_manycore_link_wh_to_sdr_ne #(
    .lg_fifo_depth_p(sdr_lg_fifo_depth_gp)
    ,.lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_gp)

    ,.x_cord_width_p      (hb_x_cord_width_gp)
    ,.y_cord_width_p      (hb_y_cord_width_gp)
    ,.addr_width_p        (hb_addr_width_gp)
    ,.data_width_p        (hb_data_width_gp)

    ,.wh_ruche_factor_p   (wh_ruche_factor_gp)
    ,.wh_flit_width_p     (wh_flit_width_gp)
  ) sdr_ne (
    .core_clk_i         (core_clk)
    ,.core_reset_i      (sdr_n_core_reset_lo[hb_num_pods_x_gp-1][E])
    ,.core_reset_o      (sdr_e_core_reset_li[0])

    ,.core_global_x_i   (global_x_i[2+total_num_tiles_x_lp-1])
    ,.core_global_y_i   (global_y_i[2+total_num_tiles_x_lp-1])
    ,.core_global_x_o   (sdr_e_core_global_x_li[0])
    ,.core_global_y_o   (sdr_e_core_global_y_li[0])

    ,.core_ver_link_sif_i         (sdr_e_ver_link_sif_lo[0][N])
    ,.core_ver_link_sif_o         (sdr_e_ver_link_sif_li[0][N])

    ,.core_wh_link_sif_i          (pod_wh_link_sif_lo[E][N])
    ,.core_wh_link_sif_o          (pod_wh_link_sif_li[E][N])


    ,.tag_clk_i               (async_reset_tag_clk_i[N][E])
    ,.tag_data_i              (async_reset_tag_data_i[N][E])
    ,.tag_node_id_offset_i    (async_reset_tag_node_id_offset_i[N][E])
    ,.async_uplink_reset_o        (sdr_e_async_uplink_reset_li[0])
    ,.async_downlink_reset_o      (sdr_e_async_downlink_reset_li[0])
    ,.async_downstream_reset_o    (sdr_e_async_downstream_reset_li[0])
    ,.async_token_reset_o         (sdr_e_async_token_reset_li[0])

    ,.async_fwd_link_i_disable_i  (async_ver_fwd_link_i_disable_i[N][2+total_num_tiles_x_lp-1])
    ,.async_fwd_link_o_disable_i  (async_ver_fwd_link_o_disable_i[N][2+total_num_tiles_x_lp-1])
    ,.async_rev_link_i_disable_i  (async_ver_rev_link_i_disable_i[N][2+total_num_tiles_x_lp-1])
    ,.async_rev_link_o_disable_i  (async_ver_rev_link_o_disable_i[N][2+total_num_tiles_x_lp-1])

    ,.io_fwd_link_clk_o           (ver_io_fwd_link_clk_o[N][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_data_o          (ver_io_fwd_link_data_o[N][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_v_o             (ver_io_fwd_link_v_o[N][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_token_i         (ver_io_fwd_link_token_i[N][2+total_num_tiles_x_lp-1])

    ,.io_fwd_link_clk_i           (ver_io_fwd_link_clk_i[N][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_data_i          (ver_io_fwd_link_data_i[N][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_v_i             (ver_io_fwd_link_v_i[N][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_token_o         (ver_io_fwd_link_token_o[N][2+total_num_tiles_x_lp-1])

    ,.io_rev_link_clk_o           (ver_io_rev_link_clk_o[N][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_data_o          (ver_io_rev_link_data_o[N][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_v_o             (ver_io_rev_link_v_o[N][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_token_i         (ver_io_rev_link_token_i[N][2+total_num_tiles_x_lp-1])

    ,.io_rev_link_clk_i           (ver_io_rev_link_clk_i[N][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_data_i          (ver_io_rev_link_data_i[N][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_v_i             (ver_io_rev_link_v_i[N][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_token_o         (ver_io_rev_link_token_o[N][2+total_num_tiles_x_lp-1])

    ,.io_wh_link_clk_o            (io_wh_link_clk_o[E][N])
    ,.io_wh_link_data_o           (io_wh_link_data_o[E][N])
    ,.io_wh_link_v_o              (io_wh_link_v_o[E][N])
    ,.io_wh_link_token_i          (io_wh_link_token_i[E][N])

    ,.io_wh_link_clk_i            (io_wh_link_clk_i[E][N])
    ,.io_wh_link_data_i           (io_wh_link_data_i[E][N])
    ,.io_wh_link_v_i              (io_wh_link_v_i[E][N])
    ,.io_wh_link_token_o          (io_wh_link_token_o[E][N])
  );

  // CORNER SDR SW
  bsg_manycore_link_wh_to_sdr_sw #(
    .lg_fifo_depth_p(sdr_lg_fifo_depth_gp)
    ,.lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_gp)

    ,.x_cord_width_p      (hb_x_cord_width_gp)
    ,.y_cord_width_p      (hb_y_cord_width_gp)
    ,.addr_width_p        (hb_addr_width_gp)
    ,.data_width_p        (hb_data_width_gp)

    ,.wh_ruche_factor_p   (wh_ruche_factor_gp)
    ,.wh_flit_width_p     (wh_flit_width_gp)
  ) sdr_sw (
    .core_clk_i         (core_clk)
    ,.core_reset_i      (sdr_w_core_reset_lo[hb_num_tiles_y_gp-1])
    ,.core_reset_o      ()

    ,.core_global_x_i   ('0)
    ,.core_global_y_i   ('0)
    ,.core_global_x_o   ()
    ,.core_global_y_o   ()

    ,.core_ver_link_sif_i         (sdr_w_ver_link_sif_lo[hb_num_tiles_y_gp-1][S])
    ,.core_ver_link_sif_o         (sdr_w_ver_link_sif_li[hb_num_tiles_y_gp-1][S])

    ,.core_wh_link_sif_i          (pod_wh_link_sif_lo[W][S])
    ,.core_wh_link_sif_o          (pod_wh_link_sif_li[W][S])

    ,.tag_clk_i               (async_reset_tag_clk_i[S][W])
    ,.tag_data_i              (async_reset_tag_data_i[S][W])
    ,.tag_node_id_offset_i    (async_reset_tag_node_id_offset_i[S][W])
    ,.async_uplink_reset_o        (sdr_w_async_uplink_reset_li[hb_num_tiles_y_gp-1])
    ,.async_downlink_reset_o      (sdr_w_async_downlink_reset_li[hb_num_tiles_y_gp-1])
    ,.async_downstream_reset_o    (sdr_w_async_downstream_reset_li[hb_num_tiles_y_gp-1])
    ,.async_token_reset_o         (sdr_w_async_token_reset_li[hb_num_tiles_y_gp-1])

    ,.async_fwd_link_i_disable_i  (async_ver_fwd_link_i_disable_i[S][0])
    ,.async_fwd_link_o_disable_i  (async_ver_fwd_link_o_disable_i[S][0])
    ,.async_rev_link_i_disable_i  (async_ver_rev_link_i_disable_i[S][0])
    ,.async_rev_link_o_disable_i  (async_ver_rev_link_o_disable_i[S][0])

    ,.io_fwd_link_clk_o           (ver_io_fwd_link_clk_o[S][0])
    ,.io_fwd_link_data_o          (ver_io_fwd_link_data_o[S][0])
    ,.io_fwd_link_v_o             (ver_io_fwd_link_v_o[S][0])
    ,.io_fwd_link_token_i         (ver_io_fwd_link_token_i[S][0])

    ,.io_fwd_link_clk_i           (ver_io_fwd_link_clk_i[S][0])
    ,.io_fwd_link_data_i          (ver_io_fwd_link_data_i[S][0])
    ,.io_fwd_link_v_i             (ver_io_fwd_link_v_i[S][0])
    ,.io_fwd_link_token_o         (ver_io_fwd_link_token_o[S][0])

    ,.io_rev_link_clk_o           (ver_io_rev_link_clk_o[S][0])
    ,.io_rev_link_data_o          (ver_io_rev_link_data_o[S][0])
    ,.io_rev_link_v_o             (ver_io_rev_link_v_o[S][0])
    ,.io_rev_link_token_i         (ver_io_rev_link_token_i[S][0])

    ,.io_rev_link_clk_i           (ver_io_rev_link_clk_i[S][0])
    ,.io_rev_link_data_i          (ver_io_rev_link_data_i[S][0])
    ,.io_rev_link_v_i             (ver_io_rev_link_v_i[S][0])
    ,.io_rev_link_token_o         (ver_io_rev_link_token_o[S][0])

    ,.io_wh_link_clk_o            (io_wh_link_clk_o[W][S])
    ,.io_wh_link_data_o           (io_wh_link_data_o[W][S])
    ,.io_wh_link_v_o              (io_wh_link_v_o[W][S])
    ,.io_wh_link_token_i          (io_wh_link_token_i[W][S])

    ,.io_wh_link_clk_i            (io_wh_link_clk_i[W][S])
    ,.io_wh_link_data_i           (io_wh_link_data_i[W][S])
    ,.io_wh_link_v_i              (io_wh_link_v_i[W][S])
    ,.io_wh_link_token_o          (io_wh_link_token_o[W][S])

  );

  // CORNER SDR SE
  bsg_manycore_link_wh_to_sdr_se #(
    .lg_fifo_depth_p(sdr_lg_fifo_depth_gp)
    ,.lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_gp)

    ,.x_cord_width_p      (hb_x_cord_width_gp)
    ,.y_cord_width_p      (hb_y_cord_width_gp)
    ,.addr_width_p        (hb_addr_width_gp)
    ,.data_width_p        (hb_data_width_gp)

    ,.wh_ruche_factor_p   (wh_ruche_factor_gp)
    ,.wh_flit_width_p     (wh_flit_width_gp)
  ) sdr_se (
    .core_clk_i         (core_clk)
    ,.core_reset_i      (sdr_e_core_reset_lo[hb_num_tiles_y_gp-1])
    ,.core_reset_o      ()

    ,.core_global_x_i   ('0)
    ,.core_global_y_i   ('0)
    ,.core_global_x_o   ()
    ,.core_global_y_o   ()

    ,.core_ver_link_sif_i         (sdr_e_ver_link_sif_lo[hb_num_tiles_y_gp-1][S])
    ,.core_ver_link_sif_o         (sdr_e_ver_link_sif_li[hb_num_tiles_y_gp-1][S])

    ,.core_wh_link_sif_i          (pod_wh_link_sif_lo[E][S])
    ,.core_wh_link_sif_o          (pod_wh_link_sif_li[E][S])


    ,.tag_clk_i               (async_reset_tag_clk_i[S][E])
    ,.tag_data_i              (async_reset_tag_data_i[S][E])
    ,.tag_node_id_offset_i    (async_reset_tag_node_id_offset_i[S][E])
    ,.async_uplink_reset_o      (sdr_s_async_uplink_reset_li[hb_num_pods_x_gp-1])
    ,.async_downlink_reset_o    (sdr_s_async_downlink_reset_li[hb_num_pods_x_gp-1])
    ,.async_downstream_reset_o  (sdr_s_async_downstream_reset_li[hb_num_pods_x_gp-1])
    ,.async_token_reset_o       (sdr_s_async_token_reset_li[hb_num_pods_x_gp-1])

    ,.async_fwd_link_i_disable_i  (async_ver_fwd_link_i_disable_i[S][2+total_num_tiles_x_lp-1])
    ,.async_fwd_link_o_disable_i  (async_ver_fwd_link_o_disable_i[S][2+total_num_tiles_x_lp-1])
    ,.async_rev_link_i_disable_i  (async_ver_rev_link_i_disable_i[S][2+total_num_tiles_x_lp-1])
    ,.async_rev_link_o_disable_i  (async_ver_rev_link_o_disable_i[S][2+total_num_tiles_x_lp-1])

    ,.io_fwd_link_clk_o           (ver_io_fwd_link_clk_o[S][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_data_o          (ver_io_fwd_link_data_o[S][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_v_o             (ver_io_fwd_link_v_o[S][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_token_i         (ver_io_fwd_link_token_i[S][2+total_num_tiles_x_lp-1])

    ,.io_fwd_link_clk_i           (ver_io_fwd_link_clk_i[S][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_data_i          (ver_io_fwd_link_data_i[S][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_v_i             (ver_io_fwd_link_v_i[S][2+total_num_tiles_x_lp-1])
    ,.io_fwd_link_token_o         (ver_io_fwd_link_token_o[S][2+total_num_tiles_x_lp-1])

    ,.io_rev_link_clk_o           (ver_io_rev_link_clk_o[S][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_data_o          (ver_io_rev_link_data_o[S][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_v_o             (ver_io_rev_link_v_o[S][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_token_i         (ver_io_rev_link_token_i[S][2+total_num_tiles_x_lp-1])

    ,.io_rev_link_clk_i           (ver_io_rev_link_clk_i[S][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_data_i          (ver_io_rev_link_data_i[S][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_v_i             (ver_io_rev_link_v_i[S][2+total_num_tiles_x_lp-1])
    ,.io_rev_link_token_o         (ver_io_rev_link_token_o[S][2+total_num_tiles_x_lp-1])

    ,.io_wh_link_clk_o            (io_wh_link_clk_o[E][S])
    ,.io_wh_link_data_o           (io_wh_link_data_o[E][S])
    ,.io_wh_link_v_o              (io_wh_link_v_o[E][S])
    ,.io_wh_link_token_i          (io_wh_link_token_i[E][S])

    ,.io_wh_link_clk_i            (io_wh_link_clk_i[E][S])
    ,.io_wh_link_data_i           (io_wh_link_data_i[E][S])
    ,.io_wh_link_v_i              (io_wh_link_v_i[E][S])
    ,.io_wh_link_token_o          (io_wh_link_token_o[E][S])



  );


endmodule
