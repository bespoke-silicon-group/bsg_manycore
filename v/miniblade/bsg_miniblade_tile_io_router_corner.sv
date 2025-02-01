/**
 *    bsg_miniblade_tile_io_router_corner.sv
 *
 */


`include "bsg_manycore_defines.svh"


module bsg_miniblade_tile_io_router_corner
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
  
    , parameter tag_els_p=1024
    , parameter tag_local_els_p=1
    , parameter tag_lg_width_p=4
    , localparam lg_tag_els_lp=`BSG_SAFE_CLOG2(tag_els_p)

    , localparam link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    // core clk;
    input clk_i
    
    // bsg_tag interface;
    , input tag_clk_i
    , input tag_data_i
    , input [lg_tag_els_lp-1:0] node_id_offset_i

    // reset_o[0] - south;
    // reset_o[1] - west;
    , output [1:0] reset_o

    // west only
    , input  [link_sif_width_lp-1:0] hor_link_sif_i
    , output [link_sif_width_lp-1:0] hor_link_sif_o

    // south only;
    , input  [link_sif_width_lp-1:0] ver_link_sif_i
    , output [link_sif_width_lp-1:0] ver_link_sif_o
 
    // proc;
    , input  [link_sif_width_lp-1:0] proc_link_sif_i
    , output [link_sif_width_lp-1:0] proc_link_sif_o
   
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
    , output [x_cord_width_p-1:0] global_x_o
    , output [y_cord_width_p-1:0] global_y_o
  );


  // BTM;
  bsg_tag_s clients_lo;

  bsg_tag_master_decentralized #(
    .els_p(tag_els_p)
    ,.local_els_p(tag_local_els_p)
    ,.lg_width_p(tag_lg_width_p)
  ) btm0 (
    .clk_i(tag_clk_i)
    ,.data_i(tag_data_i)
    ,.node_id_offset_i(node_id_offset_i)
    ,.clients_o(clients_lo)
  );


  // tag client;
  logic btc_core_reset_lo;

  bsg_tag_client #(
    .width_p(1)
  ) btc (
    .bsg_tag_i(clients_lo)
    ,.recv_clk_i(clk_i)
    ,.recv_new_r_o()
    ,.recv_data_r_o(btc_core_reset_lo)
  );


  // reset_dff;
  logic reset_r;
  bsg_dff #(
    .width_p(1)
  ) dff_reset (
    .clk_i(clk_i)
    ,.data_i(btc_core_reset_lo)
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


  localparam rev_use_credits_lp = 5'b00000;
  localparam int rev_fifo_els_lp[4:0] = '{2,2,2,2,2};

  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.stub_p(4'b0110) // snew
    ,.rev_use_credits_p(rev_use_credits_lp)
    ,.rev_fifo_els_p(rev_fifo_els_lp)
  ) io_rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    
    ,.links_sif_i(links_sif_li)
    ,.links_sif_o(links_sif_lo)

    ,.proc_link_sif_i(proc_link_sif_i)
    ,.proc_link_sif_o(proc_link_sif_o)

    ,.global_x_i(global_x_r)
    ,.global_y_i(global_y_r)
  );

 
  assign hor_link_sif_o = links_sif_lo[W];
  assign links_sif_li[W] = hor_link_sif_i;
  assign ver_link_sif_o = links_sif_lo[S];
  assign links_sif_li[S] = ver_link_sif_i;
  assign links_sif_li[E] = '0;
  assign links_sif_li[N] = '0;

endmodule
