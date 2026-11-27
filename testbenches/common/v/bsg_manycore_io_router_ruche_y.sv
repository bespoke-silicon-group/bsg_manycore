/**
 *    bsg_manycore_io_router_ruche_y.sv
 *
 *    Host I/O row router for arrays with Y ruche data links.
 *
 *    Requests are routed XY, and their Y leg ends on a ruche lane whenever the
 *    remaining distance is at least the ruche factor, so packets addressed to
 *    the I/O row below the array arrive on the router's RN input. This router
 *    accepts them and otherwise behaves like the mesh I/O router: W/E/N links
 *    are local, and S, RW, RE and RS are stubbed because nothing lies south of
 *    the I/O row and it has no X ruche links.
 *
 *    Ruche stage 0 connects to the RN/RS ports and later stages feed through,
 *    as in bsg_manycore_tile_vcache_ruche. The north lanes connect directly to
 *    the array's (already rotated) south ruche outputs; the caller rotates the
 *    south lanes and terminates them.
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_io_router_ruche_y
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(ruche_factor_Y_p)

    , localparam dims_lp = 4
    , dirs_lp = 2*dims_lp

    , manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , ruche_y_link_sif_width_lp =
      `bsg_manycore_ruche_y_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // local links; S is stubbed
    , input  [S:W][manycore_link_sif_width_lp-1:0] links_sif_i
    , output [S:W][manycore_link_sif_width_lp-1:0] links_sif_o

    , input  [ruche_factor_Y_p-1:0][S:N][ruche_y_link_sif_width_lp-1:0] ver_ruche_link_i
    , output [ruche_factor_Y_p-1:0][S:N][ruche_y_link_sif_width_lp-1:0] ver_ruche_link_o

    , input  [manycore_link_sif_width_lp-1:0] proc_link_sif_i
    , output [manycore_link_sif_width_lp-1:0] proc_link_sif_o

    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s [dirs_lp:W] link_sif_li, link_sif_lo;

  // Same P-port credit/FIFO settings as the mesh I/O router, extended to nine
  // directions (index 0 is P).
  localparam rev_use_credits_lp = 9'b000000001;
  localparam int rev_fifo_els_lp[dirs_lp:0] = '{2,2,2,2,2,2,2,2,3};

  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.dims_p(dims_lp)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
    // stub {RS,RN,RE,RW,S,N,E,W} = RS, RE, RW, S
    ,.stub_p(8'b10111000)
    ,.fwd_fifo_els_p('{default:2})
    ,.rev_use_credits_p(rev_use_credits_lp)
    ,.rev_fifo_els_p(rev_fifo_els_lp)
  ) rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.links_sif_i(link_sif_li)
    ,.links_sif_o(link_sif_lo)
    ,.proc_link_sif_i(proc_link_sif_i)
    ,.proc_link_sif_o(proc_link_sif_o)
    ,.global_x_i(global_x_i)
    ,.global_y_i(global_y_i)
  );

  assign link_sif_li[S:W] = links_sif_i;
  assign links_sif_o = link_sif_lo[S:W];

  assign link_sif_li[RE] = '0;
  assign link_sif_li[RW] = '0;

  bsg_manycore_ruche_y_link_sif_s [ruche_factor_Y_p-1:0][S:N] ruche_link_li, ruche_link_lo;
  assign ruche_link_li = ver_ruche_link_i;
  assign ver_ruche_link_o = ruche_link_lo;

  for (genvar d = N; d <= S; d++) begin: ry
    localparam ruche_dir_lp = (d == N) ? RN : RS;
    assign link_sif_li[ruche_dir_lp].fwd =
      `bsg_manycore_ruche_y_link_fwd_inject_dest_x(x_cord_width_p,ruche_link_li[0][d].fwd,global_x_i);
    assign link_sif_li[ruche_dir_lp].rev = ruche_link_li[0][d].rev;
    assign ruche_link_lo[0][d].fwd =
      `bsg_manycore_link_sif_fwd_filter_dest_x(x_cord_width_p,link_sif_lo[ruche_dir_lp].fwd);
    assign ruche_link_lo[0][d].rev = link_sif_lo[ruche_dir_lp].rev;
  end

  for (genvar i = 1; i < ruche_factor_Y_p; i++) begin: ry_feedthrough
    assign ruche_link_lo[i][N] = ruche_link_li[i][S];
    assign ruche_link_lo[i][S] = ruche_link_li[i][N];
  end

  // synopsys translate_off
  initial begin
    assert(ruche_factor_Y_p >= 2)
      else $fatal(1, "bsg_manycore_io_router_ruche_y requires ruche_factor_Y_p >= 2.");
  end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_io_router_ruche_y)
