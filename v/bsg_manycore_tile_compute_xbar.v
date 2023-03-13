/**
 *    bsg_manycore_tile_compute_xbar.v
 *
 */


`include "bsg_manycore_defines.vh" 


module bsg_manycore_tile_compute_xbar
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(dmem_size_p )

    , `BSG_INV_PARAM(icache_entries_p )
    , `BSG_INV_PARAM(icache_tag_width_p )
    , `BSG_INV_PARAM(icache_block_size_in_words_p)

    , `BSG_INV_PARAM(vcache_size_p )
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_sets_p)

    , `BSG_INV_PARAM(x_cord_width_p )
    , `BSG_INV_PARAM(y_cord_width_p )
    , `BSG_INV_PARAM(pod_x_cord_width_p )
    , `BSG_INV_PARAM(pod_y_cord_width_p )

    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , `BSG_INV_PARAM(data_width_p )
    , `BSG_INV_PARAM(addr_width_p )

    , `BSG_INV_PARAM(barrier_ruche_factor_X_p)

    // FIFO els on the router;
    , `BSG_INV_PARAM(fwd_fifo_els_p)
    , `BSG_INV_PARAM(rev_fifo_els_p)

    , parameter barrier_dirs_p=7
    , localparam barrier_lg_dirs_lp=`BSG_SAFE_CLOG2(barrier_dirs_p+1)

    , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , localparam y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)
    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
   
    // local links;
    , input [link_sif_width_lp-1:0] link_i
    , output logic [link_sif_width_lp-1:0] link_o

    // barrier links;
    , input  [S:W] barrier_link_i
    , output [S:W] barrier_link_o
    , input  [barrier_ruche_factor_X_p-1:0][E:W] barrier_ruche_link_i
    , output [barrier_ruche_factor_X_p-1:0][E:W] barrier_ruche_link_o

    // tile coordinates
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );


  // coordinates
  logic [x_subcord_width_lp-1:0] my_x;
  logic [y_subcord_width_lp-1:0] my_y;
  logic [pod_x_cord_width_p-1:0] pod_x;
  logic [pod_y_cord_width_p-1:0] pod_y;
  assign {pod_x, my_x} = global_x_i;
  assign {pod_y, my_y} = global_y_i;


  // barrier node;
  logic [barrier_dirs_p-1:0] barr_data_li, barr_data_lo, barr_src_r_li;
  logic [barrier_lg_dirs_lp-1:0] barr_dest_r_li;
    
  bsg_barrier #(
    .dirs_p(barrier_dirs_p)
  ) barr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(barr_data_li)
    ,.data_o(barr_data_lo)
    ,.src_r_i(barr_src_r_li)
    ,.dest_r_i(barr_dest_r_li)
  );


  // vanilla core;
  bsg_manycore_proc_vanilla #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)

    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

    ,.dmem_size_p(dmem_size_p)
    ,.num_vcache_rows_p(1)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    
    ,.rev_fifo_els_p(rev_fifo_els_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_p)

    ,.barrier_dirs_p(barrier_dirs_p)
    ,.debug_p(0)
  ) proc (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.link_sif_i(link_i)
    ,.link_sif_o(link_o)

    ,.barrier_data_i(barr_data_lo[0])
    ,.barrier_data_o(barr_data_li[0])
    ,.barrier_src_r_o(barr_src_r_li)
    ,.barrier_dest_r_o(barr_dest_r_li)

    ,.my_x_i(my_x)
    ,.my_y_i(my_y)
    ,.pod_x_i(pod_x)
    ,.pod_y_i(pod_y)
  );


  // connect barrier links;
  assign barr_data_li[4:1] = barrier_link_i;
  assign barrier_link_o = barr_data_lo[4:1];
  assign barr_data_li[5] = barrier_ruche_link_i[0][W];
  assign barr_data_li[6] = barrier_ruche_link_i[0][E];
  assign barrier_ruche_link_o[0][W] = barr_data_lo[5];
  assign barrier_ruche_link_o[0][E] = barr_data_lo[6];
  
  for (genvar i = 1; i < barrier_ruche_factor_X_p; i++) begin
    assign barrier_ruche_link_o[i][W] = barrier_ruche_link_i[i][E];
    assign barrier_ruche_link_o[i][E] = barrier_ruche_link_i[i][W];
  end


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_compute_xbar)
