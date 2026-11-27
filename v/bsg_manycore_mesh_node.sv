/**
 *  bsg_manycore_mesh_node.v
 *
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_mesh_node
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  #(`BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)

    , dims_p=2
    , localparam dirs_lp=(dims_p*2)+1

    , parameter ruche_factor_X_p=0
    , ruche_factor_Y_p=0

    , stub_p            = {(dirs_lp-1){1'b0}} // {s,n,e,w}
    , repeater_output_p = {(dirs_lp-1){1'b0}} // {s,n,e,w}

    // bit vector to choose which direction in the router to use credit interface.
    , fwd_use_credits_p = {dirs_lp{1'b0}}
    , rev_use_credits_p = {dirs_lp{1'b0}}

    // number of elements in the input FIFO for each direction.
    , parameter int fwd_fifo_els_p[dirs_lp-1:0] = '{2,2,2,2,2}
    , parameter int rev_fifo_els_p[dirs_lp-1:0] = '{2,2,2,2,2}

    , debug_p = 0

    , localparam packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , return_packet_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
    , bsg_manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  ( 
    input clk_i
    , input reset_i

    // input and output links
    , input  [dirs_lp-2:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_i
    , output [dirs_lp-2:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_o

    // proc links
    , input  [bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_o

    // tile coordinates (relative to entire array of pods)
    , input  [x_cord_width_p-1:0] global_x_i
    , input  [y_cord_width_p-1:0] global_y_i
  );


  // cast link_sif
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s [dirs_lp-2:0] links_sif_in, links_sif_out;
  assign links_sif_in = links_sif_i;
  assign links_sif_o  = links_sif_out;

  bsg_manycore_link_sif_s proc_link_sif_in, proc_link_sif_out;
  assign proc_link_sif_in = proc_link_sif_i;
  assign proc_link_sif_o  = proc_link_sif_out;




  // FWD router
  bsg_manycore_fwd_link_sif_s [dirs_lp-1:0] link_fwd_sif_li, link_fwd_sif_lo;

  bsg_mesh_router_buffered #(
    .width_p(packet_width_lp)
    ,.dims_p(dims_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.debug_p(debug_p)
    ,.stub_p({stub_p, 1'b0})
    ,.XY_order_p(1)
    ,.repeater_output_p({repeater_output_p,1'b0})
    ,.use_credits_p(fwd_use_credits_p)
    ,.fifo_els_p(fwd_fifo_els_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
  ) fwd (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_i(link_fwd_sif_li)
    ,.link_o(link_fwd_sif_lo)

    ,.my_x_i(global_x_i)
    ,.my_y_i(global_y_i)
   );

 


 
  // REV router
  bsg_manycore_rev_link_sif_s [dirs_lp-1:0] link_rev_sif_li, link_rev_sif_lo;

  bsg_mesh_router_buffered #(
    .width_p(return_packet_width_lp)
    ,.dims_p(dims_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.debug_p(debug_p)
    ,.stub_p({stub_p, 1'b0})
    ,.XY_order_p(0)
    ,.repeater_output_p({repeater_output_p,1'b0})
    ,.use_credits_p(rev_use_credits_p)
    ,.fifo_els_p(rev_fifo_els_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
  ) rev (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_i(link_rev_sif_li)
    ,.link_o(link_rev_sif_lo)

    ,.my_x_i(global_x_i)
    ,.my_y_i(global_y_i)
   );

  
  // make connection
  //
  // Y ruche across pod rows (future work):
  // With T = num_tiles_y_p (a power of two) and V = num_vcache_rows_p, pod row
  // k's tiles sit at Y coordinates {2k, T-V..T-1} (north vcaches),
  // {2k+1, 0..T-1} (compute) and {2k+2, 0..V-1} (south vcaches). The
  // G = T-2V coordinates {2k+2, V..T-V-1} between pod rows have no tile, but
  // the Y ruche lanes join the physically adjacent rows on either side, while
  // bsg_mesh_router counts the gap as G extra rows. Only some
  // (V, ruche_factor_Y_p) combinations route correctly despite this; see the
  // check in bsg_manycore_pod_ruche_full_array.
  //
  // To lift that restriction without changing bsg_mesh_router, translate Y
  // coordinates to physical rows at this P port, so the routers see a
  // contiguous column:
  //   phys(y) = y - G*((y / 2T) + ((y % 2T) >= T-V))
  //   - Drive my_y_i of both routers with phys(global_y_i).
  //   - Rewrite the destination Y of packets from proc_link_sif_in (fwd and
  //     rev) to phys(dest). The routers read it at
  //     [x_cord_width_p+:y_cord_width_p]; source Y fields stay logical.
  //   - Set the destination Y of packets to proc_link_sif_out back to
  //     global_y_i; bsg_manycore_endpoint_standard asserts that returned
  //     packets carry its own coordinates.
  // Gap coordinates map to the row after the gap, so the host I/O row (the
  // first gap coordinate after the last pod row) stays one row past the south
  // vcaches. Every router a packet crosses in Y must translate the same way;
  // tiles, vcaches and the Y ruche I/O router all use this module, but check
  // any other router before relying on it. This costs one translator per
  // network per node, less than translating at every router input. Packets in
  // flight then carry physical Y in traces and tieoff error messages. A packet
  // sent to an unused gap coordinate would reach the next pod row's first
  // vcache row instead of erroring, so also assert that injected
  // destinations are not gap coordinates other than the host row.
  assign link_fwd_sif_li[0] = proc_link_sif_in.fwd;
  assign link_rev_sif_li[0] = proc_link_sif_in.rev;
  assign proc_link_sif_out.fwd = link_fwd_sif_lo[0];
  assign proc_link_sif_out.rev = link_rev_sif_lo[0];


  for (genvar k = 1; k < dirs_lp; k++) begin
    assign link_fwd_sif_li[k] = links_sif_in[k-1].fwd;
    assign link_rev_sif_li[k] = links_sif_in[k-1].rev;
    assign links_sif_out[k-1].fwd = link_fwd_sif_lo[k];
    assign links_sif_out[k-1].rev = link_rev_sif_lo[k];

  end


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_mesh_node)

