/**
 *  bsg_manycore_torus_node.v
 *
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_torus_node
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  #(`BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)

    , `BSG_INV_PARAM(base_x_cord_p)
    , `BSG_INV_PARAM(base_y_cord_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , parameter num_vc_p=2
    , parameter dims_p=2
    , localparam dirs_lp=(dims_p*2)+1

    , parameter stub_p            = {(dirs_lp-1){1'b0}} // {s,n,e,w}
    , repeater_output_p = {(dirs_lp-1){1'b0}} // {s,n,e,w}

    // bit vector to choose which direction in the router to use credit interface.
    , fwd_use_credits_p = {dirs_lp{1'b0}}
    , rev_use_credits_p = {dirs_lp{1'b0}}

    // number of elements in the input FIFO for each direction.
    , parameter int fwd_fifo_els_p[dirs_lp-1:0] = '{2,2,2,2,2}
    , parameter int rev_fifo_els_p[dirs_lp-1:0] = '{2,2,2,2,2}

    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , localparam bsg_manycore_vc_link_sif_width_lp =
      `bsg_manycore_vc_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,num_vc_p)
  )
  (
    input clk_i
    , input reset_i

    // input and output links
    , input  [dirs_lp-2:0][bsg_manycore_vc_link_sif_width_lp-1:0] links_sif_i
    , output [dirs_lp-2:0][bsg_manycore_vc_link_sif_width_lp-1:0] links_sif_o

    // proc links
    , input  [link_sif_width_lp-1:0] proc_link_sif_i
    , output [link_sif_width_lp-1:0] proc_link_sif_o

    // tile coordinates (relative to entire array of pods)
    , input  [x_cord_width_p-1:0] global_x_i
    , input  [y_cord_width_p-1:0] global_y_i
  );

  localparam packet_width_lp = 
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  localparam return_packet_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p);


  // Manycore link;
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s proc_link_sif_in, proc_link_sif_out;
  assign proc_link_sif_in = proc_link_sif_i;
  assign proc_link_sif_o = proc_link_sif_out;

  `declare_bsg_manycore_vc_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p,num_vc_p);
  bsg_manycore_vc_link_sif_s [dirs_lp-2:0] link_sif_in, link_sif_out;
  assign link_sif_in = links_sif_i;
  assign links_sif_o = link_sif_out;


  // FWD router;
  bsg_manycore_fwd_link_sif_s proc_fwd_link_li, proc_fwd_link_lo;
  bsg_manycore_fwd_vc_link_sif_s [dirs_lp-2:0] fwd_link_li, fwd_link_lo;

  bsg_torus_router #(
    .width_p(packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.base_x_cord_p(base_x_cord_p)
    ,.base_y_cord_p(base_y_cord_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.XY_order_p(1)
    ,.use_credits_p(fwd_use_credits_p[0])
    ,.fifo_els_p(fwd_fifo_els_p)
  ) fwd (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.proc_link_i(proc_fwd_link_li)
    ,.proc_link_o(proc_fwd_link_lo)
    ,.link_i(fwd_link_li)
    ,.link_o(fwd_link_lo)
    ,.my_x_i(global_x_i)
    ,.my_y_i(global_y_i)
  );


  // REV router;
  bsg_manycore_rev_link_sif_s proc_rev_link_li, proc_rev_link_lo;
  bsg_manycore_rev_vc_link_sif_s [dirs_lp-2:0] rev_link_li, rev_link_lo;

  bsg_torus_router #(
    .width_p(return_packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.base_x_cord_p(base_x_cord_p)
    ,.base_y_cord_p(base_y_cord_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.XY_order_p(0)
    ,.use_credits_p(rev_use_credits_p[0])
    ,.fifo_els_p(rev_fifo_els_p)
  ) rev (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.proc_link_i(proc_rev_link_li)
    ,.proc_link_o(proc_rev_link_lo)
    ,.link_i(rev_link_li)
    ,.link_o(rev_link_lo)
    ,.my_x_i(global_x_i)
    ,.my_y_i(global_y_i)
  );


  // Connect Proc;
  assign proc_fwd_link_li = proc_link_sif_in.fwd;
  assign proc_rev_link_li = proc_link_sif_in.rev;
  assign proc_link_sif_out.fwd = proc_fwd_link_lo;
  assign proc_link_sif_out.rev = proc_rev_link_lo;

  for (genvar i = 0; i < dirs_lp-1; i++) begin
    assign fwd_link_li[i] = link_sif_in[i].fwd;
    assign rev_link_li[i] = link_sif_in[i].rev;
    assign link_sif_out[i].fwd = fwd_link_lo[i];
    assign link_sif_out[i].rev = rev_link_lo[i];
  end


endmodule
