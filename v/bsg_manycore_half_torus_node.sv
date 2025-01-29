/**
 *  bsg_manycore_half_torus_node.v
 *
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_half_torus_node
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  #(`BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)

    , `BSG_INV_PARAM(base_x_cord_p)
    , `BSG_INV_PARAM(num_tiles_x_p)

    , dims_p=2
    , localparam dirs_lp=(dims_p*2)+1
    , num_vc_lp = 2

    
    // bit vector to choose which direction in the router to use credit interface.
    , parameter fwd_use_credits_p = {dirs_lp{1'b0}}
    , rev_use_credits_p = {dirs_lp{1'b0}}

    // number of elements in the input FIFO for each direction.
    , parameter int fwd_fifo_els_p[dirs_lp-1:0] = '{2,2,2,2,2}
    , parameter int rev_fifo_els_p[dirs_lp-1:0] = '{2,2,2,2,2}

    , debug_p = 0

    , localparam packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , return_packet_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
    , link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , vc_link_sif_width_lp =
      `bsg_manycore_vc_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,num_vc_lp)
  )
  ( 
    input clk_i
    , input reset_i

    // input and output links
    , input  [S:N][link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][link_sif_width_lp-1:0] ver_link_sif_o
    , input  [E:W][vc_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][vc_link_sif_width_lp-1:0] hor_link_sif_o

    // proc links
    , input  [link_sif_width_lp-1:0] proc_link_sif_i
    , output [link_sif_width_lp-1:0] proc_link_sif_o

    // tile coordinates (relative to entire array of pods)
    , input  [x_cord_width_p-1:0] global_x_i
    , input  [y_cord_width_p-1:0] global_y_i
  );


  // cast link_sif
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_vc_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,num_vc_lp);

  bsg_manycore_link_sif_s [S:N] ver_link_sif_in, ver_link_sif_out;
  assign ver_link_sif_in = ver_link_sif_i;
  assign ver_link_sif_o = ver_link_sif_out;
  bsg_manycore_link_sif_s proc_link_sif_in, proc_link_sif_out;
  assign proc_link_sif_in = proc_link_sif_i;
  assign proc_link_sif_o  = proc_link_sif_out;
  bsg_manycore_vc_link_sif_s [E:W] hor_link_sif_in, hor_link_sif_out;
  assign hor_link_sif_in = hor_link_sif_i;
  assign hor_link_sif_o  = hor_link_sif_out;


  // FWD router
  bsg_manycore_fwd_link_sif_s fwd_proc_link_li, fwd_proc_link_lo;
  bsg_manycore_fwd_link_sif_s [S:N] fwd_ver_link_li, fwd_ver_link_lo;
  bsg_manycore_fwd_vc_link_sif_s [E:W] fwd_hor_link_li, fwd_hor_link_lo;

  bsg_half_torus_router #(
    .width_p(packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.base_x_cord_p(base_x_cord_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.XY_order_p(1)
    ,.use_credits_p(fwd_use_credits_p[0])
    ,.fifo_els_p(fwd_fifo_els_p)
  ) fwd (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.proc_link_i(fwd_proc_link_li)
    ,.proc_link_o(fwd_proc_link_lo)
    ,.ver_link_i(fwd_ver_link_li)
    ,.ver_link_o(fwd_ver_link_lo)
    ,.hor_link_i(fwd_hor_link_li)
    ,.hor_link_o(fwd_hor_link_lo)

    ,.my_x_i(global_x_i)
    ,.my_y_i(global_y_i)
   );

 


 
  // REV router
  bsg_manycore_rev_link_sif_s rev_proc_link_li, rev_proc_link_lo;
  bsg_manycore_rev_link_sif_s [S:N] rev_ver_link_li, rev_ver_link_lo;
  bsg_manycore_rev_vc_link_sif_s [E:W] rev_hor_link_li, rev_hor_link_lo;

  bsg_half_torus_router #(
    .width_p(return_packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.base_x_cord_p(base_x_cord_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.XY_order_p(0)
    ,.use_credits_p(rev_use_credits_p[0])
    ,.fifo_els_p(rev_fifo_els_p)
  ) rev (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.proc_link_i(rev_proc_link_li)
    ,.proc_link_o(rev_proc_link_lo)
    ,.ver_link_i(rev_ver_link_li)
    ,.ver_link_o(rev_ver_link_lo)
    ,.hor_link_i(rev_hor_link_li)
    ,.hor_link_o(rev_hor_link_lo)

    ,.my_x_i(global_x_i)
    ,.my_y_i(global_y_i)
   );

  
  // make connection
  // Proc;
  assign fwd_proc_link_li = proc_link_sif_in.fwd;
  assign rev_proc_link_li = proc_link_sif_in.rev;
  assign proc_link_sif_out.fwd = fwd_proc_link_lo;
  assign proc_link_sif_out.rev = rev_proc_link_lo;

  // ver;
  assign fwd_ver_link_li[S] = ver_link_sif_in[S].fwd;
  assign fwd_ver_link_li[N] = ver_link_sif_in[N].fwd;
  assign rev_ver_link_li[S] = ver_link_sif_in[S].rev;
  assign rev_ver_link_li[N] = ver_link_sif_in[N].rev;
  assign ver_link_sif_out[S].fwd = fwd_ver_link_lo[S];
  assign ver_link_sif_out[N].fwd = fwd_ver_link_lo[N];
  assign ver_link_sif_out[S].rev = rev_ver_link_lo[S];
  assign ver_link_sif_out[N].rev = rev_ver_link_lo[N];
  // hor;
  assign fwd_hor_link_li[E] = hor_link_sif_in[E].fwd;
  assign fwd_hor_link_li[W] = hor_link_sif_in[W].fwd;
  assign rev_hor_link_li[E] = hor_link_sif_in[E].rev;
  assign rev_hor_link_li[W] = hor_link_sif_in[W].rev;
  assign hor_link_sif_out[E].fwd = fwd_hor_link_lo[E];
  assign hor_link_sif_out[W].fwd = fwd_hor_link_lo[W];
  assign hor_link_sif_out[E].rev = rev_hor_link_lo[E];
  assign hor_link_sif_out[W].rev = rev_hor_link_lo[W];


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_half_torus_node)
