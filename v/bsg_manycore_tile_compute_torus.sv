/**
 *  bsg_manycore_tile_compute_torus.sv
 *
 */


`include "bsg_manycore_defines.svh"

module bsg_manycore_tile_compute_torus
  import bsg_noc_pkg::*; // { P=0, W,E,N,S }
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(dmem_size_p )
    , `BSG_INV_PARAM(vcache_size_p )
    , `BSG_INV_PARAM(icache_entries_p )
    , `BSG_INV_PARAM(icache_tag_width_p )
    , `BSG_INV_PARAM(icache_block_size_in_words_p)
    , `BSG_INV_PARAM(x_cord_width_p )
    , `BSG_INV_PARAM(y_cord_width_p )
    , `BSG_INV_PARAM(pod_x_cord_width_p )
    , `BSG_INV_PARAM(pod_y_cord_width_p )

    // Number of tiles in a pod
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , localparam y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p )

    , `BSG_INV_PARAM(barrier_ruche_factor_X_p)

    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(ipoly_hashing_p)

    , parameter num_vc_p = 2
    , parameter dims_p = 2
    , localparam dirs_lp = (dims_p*2)
    // The topology of the barrier network is matched to the one of manycore links, so that we don't add any additional timing path complexity.
    , parameter barrier_dirs_p=7
    , localparam barrier_lg_dirs_lp=`BSG_SAFE_CLOG2(barrier_dirs_p+1)

    , parameter stub_p = {dirs_lp{1'b0}}           // {re,rw,s,n,e,w}
    , repeater_output_p = {dirs_lp{1'b0}} // {re,rw,s,n,e,w}
    , hetero_type_p = 0
    , debug_p = 0

    , localparam vc_link_sif_width_lp =
      `bsg_manycore_vc_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, num_vc_p)
  )
  (
    input clk_i
    , input reset_i
    , output logic reset_o

    // local links
    , input  [S:W][vc_link_sif_width_lp-1:0] link_i
    , output [S:W][vc_link_sif_width_lp-1:0] link_o

    // barrier links
    , input  [S:W] barrier_link_i
    , output [S:W] barrier_link_o

    // barrier ruche links
    , input  [E:W] barrier_ruche_link_i
    , output [E:W] barrier_ruche_link_o

    // tile coordinates
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
    , output logic [x_cord_width_p-1:0] global_x_o
    , output logic [y_cord_width_p-1:0] global_y_o
  );



  // reset;
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
    ? 5'b00001
    : 5'b00000;
  localparam int fwd_fifo_els_lp[dirs_lp:0] = (hetero_type_p == 0)
    ? '{2,2,2,2,64}
    : '{2,2,2,2,2};
  localparam rev_use_credits_lp = (hetero_type_p == 0)
    ? 5'b00001
    : 5'b00000;
  localparam int rev_fifo_els_lp[dirs_lp:0] = (hetero_type_p == 0)
    ? '{2,2,2,2,3}
    : '{2,2,2,2,2};


  // Instantiate router and the socket.
  `declare_bsg_manycore_vc_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,num_vc_p);
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo; 
  bsg_manycore_vc_link_sif_s [dirs_lp-1:0] links_sif_li, links_sif_lo;

  bsg_manycore_torus_node #(
    .stub_p(stub_p)
    ,.dims_p(dims_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p+4)
    ,.base_x_cord_p(num_tiles_x_p)
    ,.base_y_cord_p(num_tiles_y_p-2)
    ,.repeater_output_p(repeater_output_p) // select buffer for this particular node
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



  logic [barrier_dirs_p-1:0] barr_data_li;
  logic [barrier_dirs_p-1:0] barr_data_lo;
  logic [barrier_dirs_p-1:0] barr_src_r_li;
  logic [barrier_lg_dirs_lp-1:0] barr_dest_r_li;
  bsg_barrier #(
    .dirs_p(barrier_dirs_p)
  ) barr (
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
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp[0])
    ,.rev_fifo_els_p(rev_fifo_els_lp[0])
    ,.barrier_dirs_p(barrier_dirs_p)
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
  );


  // connect local links;
  assign link_o = links_sif_lo[3:0];
  assign links_sif_li[3:0] = link_i;

  // connect barrier local;
  assign barr_data_li[4:1] =  barrier_link_i;
  assign barrier_link_o = barr_data_lo[4:1];
  // connect barrier ruche;
  assign barr_data_li[6:5] =  barrier_ruche_link_i;
  assign barrier_ruche_link_o = barr_data_lo[6:5];



endmodule
