// MBT 9/13/16
//
//  THIS IS A TEMPLATE THAT YOU CUSTOMIZE FOR YOUR HETERO MANYCORE
//
//  Edit the lines:
//
//  `HETERO_TYPE_MACRO(1,bsg_accelerator_add)
//
//  by replacing bsg_accelerator_add with your core's name
//
//  then change the makefile to use your modified file instead of
//  this one.
//

`define HETERO_TYPE_MACRO(BMC_TYPE,BMC_TYPE_MODULE)                                    \
   if (hetero_type_p == (BMC_TYPE))                                                    \
     begin: h                                                                          \
        BMC_TYPE_MODULE #(.x_cord_width_p(x_cord_width_p)                              \
                          ,.y_cord_width_p(y_cord_width_p)                             \
                          ,.data_width_p(data_width_p)                                 \
                          ,.addr_width_p(addr_width_p)                                 \
                          ,.dmem_size_p (dmem_size_p )                                 \
                          ,.num_vcache_rows_p(num_vcache_rows_p)                       \
                          ,.vcache_size_p(vcache_size_p)                               \
                          ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p) \
                          ,.vcache_sets_p(vcache_sets_p)                               \
                          ,.debug_p(debug_p)                                           \
                          ,.icache_entries_p(icache_entries_p)                         \
                          ,.icache_tag_width_p (icache_tag_width_p)                    \
                          ,.num_tiles_x_p(num_tiles_x_p)                               \
                          ,.num_tiles_y_p(num_tiles_y_p)                               \
                          ,.pod_x_cord_width_p(pod_x_cord_width_p)                     \
                          ,.pod_y_cord_width_p(pod_y_cord_width_p)                     \
                          ,.fwd_fifo_els_p(fwd_fifo_els_p)                             \
                          ,.rev_fifo_els_p(rev_fifo_els_p)                             \
                          ,.barrier_dirs_p(barrier_dirs_p)                             \
                          ) z                                                          \
          (.clk_i                                                                      \
           ,.reset_i                                                                   \
           ,.link_sif_i                                                                \
           ,.link_sif_o                                                                \
           ,.barrier_data_i                                                            \
           ,.barrier_data_o                                                            \
           ,.barrier_src_r_o                                                           \
           ,.barrier_dest_r_o                                                          \
           ,.my_x_i                                                                    \
           ,.my_y_i                                                                    \
           ,.pod_x_i                                                                    \
           ,.pod_y_i                                                                    \
           );                                                                          \
     end

`include "bsg_manycore_defines.vh"

module bsg_manycore_hetero_socket
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(x_cord_width_p )
    , `BSG_INV_PARAM(y_cord_width_p )
    , `BSG_INV_PARAM(data_width_p )
    , `BSG_INV_PARAM(addr_width_p )
    , `BSG_INV_PARAM(dmem_size_p )
    , `BSG_INV_PARAM(icache_entries_p ) // in words
    , `BSG_INV_PARAM(icache_tag_width_p )
    , `BSG_INV_PARAM(num_vcache_rows_p )
    , `BSG_INV_PARAM(vcache_size_p )
    , parameter debug_p = 0
    , parameter int hetero_type_p = 0
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , parameter x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(fwd_fifo_els_p )
    , `BSG_INV_PARAM(rev_fifo_els_p )
    , `BSG_INV_PARAM(barrier_dirs_p )
    , parameter barrier_lg_dirs_lp=`BSG_SAFE_CLOG2(barrier_dirs_p+1)

    , parameter bsg_manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // input and output links
    , input [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // barrier interface
    , input  barrier_data_i
    , output barrier_data_o
    , output [barrier_dirs_p-1:0]     barrier_src_r_o
    , output [barrier_lg_dirs_lp-1:0] barrier_dest_r_o


    // tile coordinates
    , input [x_subcord_width_lp-1:0] my_x_i
    , input [y_subcord_width_lp-1:0] my_y_i

    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i
  );

  // add as many types as you like...
  `HETERO_TYPE_MACRO(0,bsg_manycore_proc_vanilla) else
  `HETERO_TYPE_MACRO(1,bsg_manycore_gather_scatter) else
  `HETERO_TYPE_MACRO(2,bsg_manycore_accel_default) else
  `HETERO_TYPE_MACRO(3,bsg_manycore_accel_default) else
  `HETERO_TYPE_MACRO(4,bsg_manycore_accel_default) else
  `HETERO_TYPE_MACRO(5,bsg_manycore_accel_default) else
  `HETERO_TYPE_MACRO(6,bsg_manycore_accel_default) else
  `HETERO_TYPE_MACRO(7,bsg_manycore_accel_default) else
  `HETERO_TYPE_MACRO(8,bsg_manycore_accel_default) else
  begin : nh
  // synopsys translate_off
    initial begin
      $error("## unidentified hetero core type ",hetero_type_p);
      $finish();
    end
    // synopsys translate_on
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_hetero_socket)
