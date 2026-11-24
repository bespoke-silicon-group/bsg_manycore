/**
 *  Compute tile with X/Y ruche data and barrier links.
 *  Y factor zero retains the X-only topology and barrier CSR layout.
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_tile_compute_ruche_full
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(`BSG_INV_PARAM(dmem_size_p)
    , `BSG_INV_PARAM(vcache_size_p)
    , `BSG_INV_PARAM(icache_entries_p)
    , `BSG_INV_PARAM(icache_tag_width_p)
    , `BSG_INV_PARAM(icache_block_size_in_words_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)

    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(ruche_factor_X_p)
    , `BSG_INV_PARAM(ruche_factor_Y_p)
    , `BSG_INV_PARAM(barrier_ruche_factor_X_p)
    , `BSG_INV_PARAM(barrier_ruche_factor_Y_p)

    , `BSG_INV_PARAM(num_vcache_rows_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(ipoly_hashing_p)

    , localparam dims_lp = (ruche_factor_Y_p > 0) ? 4 : 3
    , dirs_lp = 2*dims_lp
    , barrier_dirs_lp = dirs_lp+1
    , barrier_lg_dirs_lp = `BSG_SAFE_CLOG2(barrier_dirs_lp+1)
    // Keep disabled Y ports one lane wide rather than declaring [-1:0].
    , ruche_y_lanes_lp = `BSG_MAX(1,ruche_factor_Y_p)

    , parameter stub_p = {dirs_lp{1'b0}}
    , repeater_output_p = {dirs_lp{1'b0}}
    , hetero_type_p = 0
    , debug_p = 0

    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , ruche_y_link_sif_width_lp =
      `bsg_manycore_ruche_y_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
    , output logic reset_o

    , input  [S:W][link_sif_width_lp-1:0] link_i
    , output [S:W][link_sif_width_lp-1:0] link_o

    , input  [ruche_factor_X_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [ruche_factor_X_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_o
    , input  [ruche_y_lanes_lp-1:0][S:N][ruche_y_link_sif_width_lp-1:0] ver_ruche_link_i
    , output [ruche_y_lanes_lp-1:0][S:N][ruche_y_link_sif_width_lp-1:0] ver_ruche_link_o

    , input  [S:W] barrier_link_i
    , output [S:W] barrier_link_o
    , input  [barrier_ruche_factor_X_p-1:0][E:W] hor_barrier_ruche_link_i
    , output [barrier_ruche_factor_X_p-1:0][E:W] hor_barrier_ruche_link_o
    , input  [barrier_ruche_factor_Y_p-1:0][S:N] ver_barrier_ruche_link_i
    , output [barrier_ruche_factor_Y_p-1:0][S:N] ver_barrier_ruche_link_o

    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
    , output logic [x_cord_width_p-1:0] global_x_o
    , output logic [y_cord_width_p-1:0] global_y_o
  );

  logic reset_r;
  bsg_dff #(.width_p(1)) dff_reset (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );
  assign reset_o = reset_r;

  logic [x_subcord_width_lp-1:0] my_x_r;
  logic [y_subcord_width_lp-1:0] my_y_r;
  logic [pod_x_cord_width_p-1:0] pod_x_r;
  logic [pod_y_cord_width_p-1:0] pod_y_r;

  bsg_dff #(.width_p(x_cord_width_p)) dff_x (
    .clk_i(clk_i)
    ,.data_i(global_x_i)
    ,.data_o({pod_x_r, my_x_r})
  );
  bsg_dff #(.width_p(y_cord_width_p)) dff_y (
    .clk_i(clk_i)
    ,.data_i(global_y_i)
    ,.data_o({pod_y_r, my_y_r})
  );
  assign global_x_o = {pod_x_r, my_x_r};
  assign global_y_o = y_cord_width_p'(({pod_y_r, my_y_r}) + 1);

  // Vanilla's P interface returns credits with an extra cycle of delay.
  localparam [dirs_lp:0] fwd_use_credits_lp = (hetero_type_p == 0) ? 1 : 0;
  localparam int fwd_fifo_els_lp[dirs_lp:0] =
    '{0: ((hetero_type_p == 0) ? 3 : 2), default:2};
  localparam [dirs_lp:0] rev_use_credits_lp = fwd_use_credits_lp;
  localparam int rev_fifo_els_lp[dirs_lp:0] = fwd_fifo_els_lp;

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo;
  bsg_manycore_link_sif_s [dirs_lp:W] links_sif_li, links_sif_lo;

  bsg_manycore_mesh_node #(
    .stub_p(stub_p)
    ,.dims_p(dims_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(repeater_output_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
    ,.fwd_use_credits_p(fwd_use_credits_lp)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp)
    ,.rev_use_credits_p(rev_use_credits_lp)
    ,.rev_fifo_els_p(rev_fifo_els_lp)
  ) rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.links_sif_i(links_sif_li)
    ,.links_sif_o(links_sif_lo)
    ,.proc_link_sif_i(proc_link_sif_li)
    ,.proc_link_sif_o(proc_link_sif_lo)
    ,.global_x_i({pod_x_r, my_x_r})
    ,.global_y_i({pod_y_r, my_y_r})
  );

  logic [barrier_dirs_lp-1:0] barr_data_li, barr_data_lo, barr_src_r_li;
  logic [barrier_lg_dirs_lp-1:0] barr_dest_r_li;
  bsg_barrier #(.dirs_p(barrier_dirs_lp)) barr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.data_i(barr_data_li)
    ,.data_o(barr_data_lo)
    ,.src_r_i(barr_src_r_li)
    ,.dest_r_i(barr_dest_r_li)
  );

  bsg_manycore_hetero_socket #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.vcache_size_p(vcache_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.hetero_type_p(hetero_type_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp[0])
    ,.rev_fifo_els_p(rev_fifo_els_lp[0])
    ,.barrier_dirs_p(barrier_dirs_lp)
    ,.ipoly_hashing_p(ipoly_hashing_p)
    ,.debug_p(debug_p)
  ) proc (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)
    ,.barrier_data_i(barr_data_lo[0])
    ,.barrier_data_o(barr_data_li[0])
    ,.barrier_src_r_o(barr_src_r_li)
    ,.barrier_dest_r_o(barr_dest_r_li)
    ,.pod_x_i(pod_x_r)
    ,.pod_y_i(pod_y_r)
    ,.my_x_i(my_x_r)
    ,.my_y_i(my_y_r)
`ifdef BSG_VERILATOR_PROFILE_PORTS
    ,.profiler_global_ctr_i($root.`HOST_MODULE_PATH.global_ctr[31:0])
    ,.profiler_print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.profiler_print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
    ,.profiler_trace_en_i($root.`HOST_MODULE_PATH.trace_en)
`endif
  );

  assign links_sif_li[S:W] = link_i;
  assign link_o = links_sif_lo[S:W];

  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s [ruche_factor_X_p-1:0][E:W] ruche_link_li, ruche_link_lo;
  assign ruche_link_li = ruche_link_i;
  assign ruche_link_o = ruche_link_lo;
  for (genvar d = W; d <= E; d++) begin: rx
    localparam ruche_dir_lp = (d == W) ? RW : RE;
    assign links_sif_li[ruche_dir_lp].fwd =
      `bsg_manycore_ruche_x_link_fwd_inject_src_y(x_cord_width_p,y_cord_width_p,ruche_link_li[0][d].fwd,{pod_y_r, my_y_r});
    assign links_sif_li[ruche_dir_lp].rev =
      `bsg_manycore_ruche_x_link_rev_inject_dest_y(x_cord_width_p,y_cord_width_p,ruche_link_li[0][d].rev,{pod_y_r, my_y_r});
    assign ruche_link_lo[0][d].fwd =
      `bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_p,y_cord_width_p,links_sif_lo[ruche_dir_lp].fwd);
    assign ruche_link_lo[0][d].rev =
      `bsg_manycore_link_sif_rev_filter_dest_y(x_cord_width_p,y_cord_width_p,links_sif_lo[ruche_dir_lp].rev);
  end
  for (genvar i = 1; i < ruche_factor_X_p; i++) begin: rx_feedthrough
    assign ruche_link_lo[i][E] = ruche_link_li[i][W];
    assign ruche_link_lo[i][W] = ruche_link_li[i][E];
  end

  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_y_link_sif_s [ruche_y_lanes_lp-1:0][S:N] ver_ruche_link_li, ver_ruche_link_lo;
  assign ver_ruche_link_li = ver_ruche_link_i;
  assign ver_ruche_link_o = ver_ruche_link_lo;
  if (ruche_factor_Y_p > 0) begin: full_ruche
    for (genvar d = N; d <= S; d++) begin: ry
      localparam ruche_dir_lp = (d == N) ? RN : RS;
      assign links_sif_li[ruche_dir_lp].fwd =
        `bsg_manycore_ruche_y_link_fwd_inject_dest_x(x_cord_width_p,ver_ruche_link_li[0][d].fwd,{pod_x_r, my_x_r});
      assign links_sif_li[ruche_dir_lp].rev = ver_ruche_link_li[0][d].rev;
      assign ver_ruche_link_lo[0][d].fwd =
        `bsg_manycore_link_sif_fwd_filter_dest_x(x_cord_width_p,links_sif_lo[ruche_dir_lp].fwd);
      assign ver_ruche_link_lo[0][d].rev = links_sif_lo[ruche_dir_lp].rev;
    end
    for (genvar i = 1; i < ruche_factor_Y_p; i++) begin: ry_feedthrough
      assign ver_ruche_link_lo[i][N] = ver_ruche_link_li[i][S];
      assign ver_ruche_link_lo[i][S] = ver_ruche_link_li[i][N];
    end

    assign barr_data_li[7] = ver_barrier_ruche_link_i[0][N];
    assign barr_data_li[8] = ver_barrier_ruche_link_i[0][S];
    assign ver_barrier_ruche_link_o[0][N] = barr_data_lo[7];
    assign ver_barrier_ruche_link_o[0][S] = barr_data_lo[8];
    for (genvar i = 1; i < barrier_ruche_factor_Y_p; i++) begin: bry_feedthrough
      assign ver_barrier_ruche_link_o[i][N] = ver_barrier_ruche_link_i[i][S];
      assign ver_barrier_ruche_link_o[i][S] = ver_barrier_ruche_link_i[i][N];
    end
  end
  else begin: x_only
    assign ver_ruche_link_lo = '0;
    assign ver_barrier_ruche_link_o = '0;
  end

  assign barr_data_li[S:W] = barrier_link_i;
  assign barrier_link_o = barr_data_lo[S:W];
  assign barr_data_li[5] = hor_barrier_ruche_link_i[0][W];
  assign barr_data_li[6] = hor_barrier_ruche_link_i[0][E];
  assign hor_barrier_ruche_link_o[0][W] = barr_data_lo[5];
  assign hor_barrier_ruche_link_o[0][E] = barr_data_lo[6];
  for (genvar i = 1; i < barrier_ruche_factor_X_p; i++) begin: brx_feedthrough
    assign hor_barrier_ruche_link_o[i][W] = hor_barrier_ruche_link_i[i][E];
    assign hor_barrier_ruche_link_o[i][E] = hor_barrier_ruche_link_i[i][W];
  end

  // synopsys translate_off
  initial begin
    assert (ruche_factor_X_p >= 2)
      else $fatal(1,"ruche_factor_X_p must be greater or equal to 2.");
    assert (ruche_factor_Y_p == 0 || ruche_factor_Y_p >= 2)
      else $fatal(1,"ruche_factor_Y_p must be 0 or greater or equal to 2.");
    assert (barrier_ruche_factor_X_p >= 2)
      else $fatal(1,"barrier_ruche_factor_X_p must be greater or equal to 2.");
    assert ((ruche_factor_Y_p == 0 && barrier_ruche_factor_Y_p == 0)
            || (ruche_factor_Y_p >= 2 && barrier_ruche_factor_Y_p >= 2))
      else $fatal(1,"Y barrier ruche must be enabled together with Y data ruche.");
  end
  // synopsys translate_on
endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_compute_ruche_full)
