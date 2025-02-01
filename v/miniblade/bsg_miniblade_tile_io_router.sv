/**
 *    bsg_miniblade_tile_io_router.sv
 *
 */


`include "bsg_manycore_defines.svh"


module bsg_miniblade_tile_io_router
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
  
    , localparam link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // reset_o[0] - south;
    // reset_o[1] - west;
    , output [1:0] reset_o

    // horizontal links;
    , input  [E:W][link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][link_sif_width_lp-1:0] hor_link_sif_o

    // south only;
    , input  [link_sif_width_lp-1:0] ver_link_sif_i
    , output [link_sif_width_lp-1:0] ver_link_sif_o
    
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
    , output [x_cord_width_p-1:0] global_x_o
    , output [y_cord_width_p-1:0] global_y_o
  );

  // reset_dff;
  logic reset_r;
  bsg_dff #(
    .width_p(1)
  ) dff_reset (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );
  
  assign reset_o = {2{reset_r}};


  // coordinate dff;
  logic [x_cord_width_p-1:0] global_x_r;
  logic [y_cord_width_p-1:0] global_y_r;

  bsg_dff #(
    .width_p(x_cord_width_p)
  ) dff_x (
    .clk_i(clk_i)
    ,.data_i(global_x_i)
    ,.data_o(global_x_r)
  );

  bsg_dff #(
    .width_p(x_cord_width_p)
  ) dff_y (
    .clk_i(clk_i)
    ,.data_i(global_y_i)
    ,.data_o(global_y_r)
  );

  assign global_x_o = global_x_r;
  assign global_y_o = y_cord_width_p'(global_y_r + 1);


  // cast link_sif
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p);


  // Instantiate router;
  // north port stubbed;
  bsg_manycore_link_sif_s [S:W] links_sif_li, links_sif_lo;
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo;

  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.stub_p(4'b0100)
  ) io_rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    
    ,.links_sif_i(links_sif_li)
    ,.links_sif_o(links_sif_lo)

    ,.proc_link_sif_i(proc_link_sif_li)
    ,.proc_link_sif_o(proc_link_sif_lo) // not used;

    ,.global_x_i(global_x_r)
    ,.global_y_i(global_y_r)
  );


  assign hor_link_sif_o[E] = links_sif_lo[E];
  assign links_sif_li[E] = hor_link_sif_i[E];
  assign hor_link_sif_o[W] = links_sif_lo[W];
  assign links_sif_li[W] = hor_link_sif_i[W];
  assign ver_link_sif_o = links_sif_lo[S];
  assign links_sif_li[S] = ver_link_sif_i;

  assign links_sif_li[N] = '0;  // stubbed;
  assign proc_link_sif_li = '0; // stubbed;


endmodule
