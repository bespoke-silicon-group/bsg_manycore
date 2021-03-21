/**
 *  bsg_manycore_tile_compute_ruche.v
 *
 */

module bsg_manycore_tile_compute_ruche
  import bsg_noc_pkg::*; // { P=0, W,E,N,S }
  import bsg_manycore_pkg::*;
  #(parameter dmem_size_p = "inv"
    , parameter vcache_size_p ="inv"
    , parameter icache_entries_p = "inv"
    , parameter icache_tag_width_p = "inv"
    , parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter pod_x_cord_width_p = "inv"
    , parameter pod_y_cord_width_p = "inv"

    // Number of tiles in a pod
    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    , parameter x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter ruche_factor_X_p = 3
    
    , parameter data_width_p = "inv"
    , parameter addr_width_p = "inv"

    , parameter num_vcache_rows_p = "inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_sets_p="inv"

    , parameter dims_p = 3
    , parameter dirs_lp = (dims_p*2)

    , parameter stub_p = {dirs_lp{1'b0}}           // {re,rw,s,n,e,w}
    , parameter repeater_output_p = {dirs_lp{1'b0}} // {re,rw,s,n,e,w}
    , parameter hetero_type_p = 0
    , parameter debug_p = 0

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
    , output logic reset_o

    // local links
    , input  [S:W][link_sif_width_lp-1:0] link_i
    , output [S:W][link_sif_width_lp-1:0] link_o

    // ruche links
    , input  [ruche_factor_X_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [ruche_factor_X_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_o

    // tile coordinates
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
    , output logic [x_cord_width_p-1:0] global_x_o
    , output logic [y_cord_width_p-1:0] global_y_o
  );


  //-------------------------------------------
  //As the manycore will distribute across large area, it will take long
  //time for the reset signal to propgate. We should register the reset
  //signal in each tile
  logic reset_r;

  bsg_dff #(
    .width_p(1)
  ) dff_reset (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );

  assign reset_o = reset_r;

  // feedthrough coordinate bits
  logic [x_subcord_width_lp-1:0] my_x_r;
  logic [y_subcord_width_lp-1:0] my_y_r;
  logic [pod_x_cord_width_p-1:0] pod_x_r;
  logic [pod_y_cord_width_p-1:0] pod_y_r;


  bsg_dff #(
    .width_p(x_cord_width_p)
  ) dff_x (
    .clk_i(clk_i)
    ,.data_i(global_x_i)
    ,.data_o({pod_x_r, my_x_r})
  );

  bsg_dff #(
    .width_p(y_cord_width_p)
  ) dff_y (
    .clk_i(clk_i)
    ,.data_i(global_y_i)
    ,.data_o({pod_y_r, my_y_r})
  );

  assign global_x_o = {pod_x_r, my_x_r};
  assign global_y_o = (y_cord_width_p)'(({pod_y_r, my_y_r}) + 1);


  // For vanilla core (hetero type = 0), it uses credit interface for the P ports,
  // which has three-element fifo because the credit returns with one extra cycle delay.
  localparam fwd_use_credits_lp = (hetero_type_p == 0)
    ? 7'b0000001
    : 7'b0000000;
  localparam int fwd_fifo_els_lp[dirs_lp:0] = (hetero_type_p == 0)
    ? '{2,2,2,2,2,2,3}
    : '{2,2,2,2,2,2,2};
  localparam rev_use_credits_lp = 7'b00000;
  localparam int rev_fifo_els_lp[dirs_lp:0] = '{2,2,2,2,2,2,2};
   
 
  // Instantiate router and the socket.
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo; 
  bsg_manycore_link_sif_s [dirs_lp-1:0] links_sif_li, links_sif_lo;

  bsg_manycore_mesh_node #(
    .stub_p(stub_p)
    ,.dims_p(dims_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(repeater_output_p) // select buffer for this particular node
    ,.ruche_factor_X_p(ruche_factor_X_p)
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
    ,.hetero_type_p(hetero_type_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp[0])
    ,.debug_p(debug_p)
  ) proc (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)

    ,.pod_x_i(pod_x_r)
    ,.pod_y_i(pod_y_r)

    ,.my_x_i(my_x_r)
    ,.my_y_i(my_y_r)
  );


  // connect local link
  assign links_sif_li[3:0] = link_i;
  assign link_o = links_sif_lo[3:0];

  
  // connect ruche link
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s [ruche_factor_X_p-1:0][E:W] ruche_link_li, ruche_link_lo;
  assign ruche_link_li = ruche_link_i;
  assign ruche_link_o = ruche_link_lo;


  // For incoming fwd, inject my_y_i as src_y.
  // For incoming rev, inject my_y_i as dest_y.
  assign links_sif_li[5].fwd =
    `bsg_manycore_ruche_x_link_fwd_inject_src_y(x_cord_width_p,y_cord_width_p,ruche_link_li[0][E].fwd,{pod_y_r, my_y_r});
  assign links_sif_li[5].rev =
    `bsg_manycore_ruche_x_link_rev_inject_dest_y(x_cord_width_p,y_cord_width_p,ruche_link_li[0][E].rev,{pod_y_r, my_y_r});
  assign links_sif_li[4].fwd =
    `bsg_manycore_ruche_x_link_fwd_inject_src_y(x_cord_width_p,y_cord_width_p,ruche_link_li[0][W].fwd,{pod_y_r, my_y_r});
  assign links_sif_li[4].rev =
    `bsg_manycore_ruche_x_link_rev_inject_dest_y(x_cord_width_p,y_cord_width_p,ruche_link_li[0][W].rev,{pod_y_r, my_y_r});


  // For outgoing fwd, filter out src_y.
  // For outgoing rev, filter out dest_y.
  assign ruche_link_lo[0][E].fwd =
    `bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_p,y_cord_width_p,links_sif_lo[5].fwd);
  assign ruche_link_lo[0][E].rev =
    `bsg_manycore_link_sif_rev_filter_dest_y(x_cord_width_p,y_cord_width_p,links_sif_lo[5].rev);
  assign ruche_link_lo[0][W].fwd =
    `bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_p,y_cord_width_p,links_sif_lo[4].fwd);
  assign ruche_link_lo[0][W].rev =
    `bsg_manycore_link_sif_rev_filter_dest_y(x_cord_width_p,y_cord_width_p,links_sif_lo[4].rev);


  // Connect feedthrough ruche links.
  for (genvar i = 1; i < ruche_factor_X_p; i++) begin
    assign ruche_link_lo[i][E] = ruche_link_li[i][W];
    assign ruche_link_lo[i][W] = ruche_link_li[i][E];
  end



endmodule
