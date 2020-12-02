/**
 *  bsg_manycore_tile_ruche.v
 *
 */

module bsg_manycore_tile_ruche
  import bsg_noc_pkg::*; // { P=0, W,E,N,S }
  import bsg_manycore_pkg::*;
  #(parameter dmem_size_p = "inv"
    , parameter vcache_size_p ="inv"
    , parameter icache_entries_p = "inv"
    , parameter icache_tag_width_p = "inv"
    , parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"

    , parameter ruche_factor_X_p = 3
    
    , parameter data_width_p = "inv"
    , parameter addr_width_p = "inv"

    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_sets_p="inv"

    , parameter dims_p = 3
    , parameter dirs_lp = (dims_p*2)

    , parameter stub_p = {dirs_lp{1'b0}}           // {re,rw,s,n,e,w}
    , parameter repeater_output_p = {dirs_lp{1'b0}} // {re,rw,s,n,e,w}
    , parameter hetero_type_p = 0
    , parameter debug_p = 0

    , parameter branch_trace_en_p = 0

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    
    , parameter ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i


    // local links
    , input  [S:W][link_sif_width_lp-1:0] link_i
    , output [S:W][link_sif_width_lp-1:0] link_o


    // ruche links
    , input  [ruche_factor_X_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [ruche_factor_X_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_o


    // tile coordinates
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
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
    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );

  bsg_manycore_hetero_socket #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)

    ,.dmem_size_p(dmem_size_p)
    ,.vcache_size_p(vcache_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.hetero_type_p(hetero_type_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp[0])

    ,.branch_trace_en_p(branch_trace_en_p)

    ,.debug_p(debug_p)
  ) proc (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
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
  assign links_sif_li[5].fwd = {
    ruche_link_li[0][E].fwd[$bits(bsg_manycore_fwd_ruche_x_link_s)-1:(2*x_cord_width_p)+y_cord_width_p],
    my_y_i,
    ruche_link_li[0][E].fwd[(2*x_cord_width_p)+y_cord_width_p-1:0]
  }; 
  assign links_sif_li[5].rev = {
    ruche_link_li[0][E].rev[$bits(bsg_manycore_rev_ruche_x_link_s)-1:x_cord_width_p],
    my_y_i,
    ruche_link_li[0][E].rev[x_cord_width_p-1:0]
  };
  assign links_sif_li[4].fwd = {
    ruche_link_li[0][W].fwd[$bits(bsg_manycore_fwd_ruche_x_link_s)-1:(2*x_cord_width_p)+y_cord_width_p],
    my_y_i,
    ruche_link_li[0][W].fwd[(2*x_cord_width_p)+y_cord_width_p-1:0]
  }; 
  assign links_sif_li[4].rev = {
    ruche_link_li[0][W].rev[$bits(bsg_manycore_rev_ruche_x_link_s)-1:x_cord_width_p],
    my_y_i,
    ruche_link_li[0][W].rev[x_cord_width_p-1:0]
  };

  // For outgoing fwd, filter out src_y.
  // For outgoing rev, filter out dest_y.
  assign ruche_link_lo[0][E].fwd = {
    links_sif_lo[5].fwd[$bits(bsg_manycore_fwd_link_sif_s)-1:2*(x_cord_width_p+y_cord_width_p)],
    links_sif_lo[5].fwd[(2*x_cord_width_p)+y_cord_width_p-1:0]
  };
  assign ruche_link_lo[0][E].rev = {
    links_sif_lo[5].rev[$bits(bsg_manycore_rev_link_sif_s)-1:x_cord_width_p+y_cord_width_p],
    links_sif_lo[5].rev[x_cord_width_p-1:0]
  };
  assign ruche_link_lo[0][W].fwd = {
    links_sif_lo[4].fwd[$bits(bsg_manycore_fwd_link_sif_s)-1:2*(x_cord_width_p+y_cord_width_p)],
    links_sif_lo[4].fwd[(2*x_cord_width_p)+y_cord_width_p-1:0]
  };
  assign ruche_link_lo[0][W].rev = {
    links_sif_lo[4].rev[$bits(bsg_manycore_rev_link_sif_s)-1:x_cord_width_p+y_cord_width_p],
    links_sif_lo[4].rev[x_cord_width_p-1:0]
  };

  for (genvar i = 1; i < ruche_factor_X_p; i++) begin
    assign ruche_link_lo[i][E] = ruche_link_li[i][W];
    assign ruche_link_lo[i][W] = ruche_link_li[i][E];
  end




endmodule
