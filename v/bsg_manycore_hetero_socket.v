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
                          ,.epa_byte_addr_width_p(epa_byte_addr_width_p)               \
                          ,.vcache_size_p(vcache_size_p)                               \
                          ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p) \
                          ,.vcache_sets_p(vcache_sets_p)                               \
                          ,.debug_p(debug_p)                                           \
                          ,.branch_trace_en_p(branch_trace_en_p)                                 \
			                    ,.icache_entries_p(icache_entries_p)                         \
                          ,.icache_tag_width_p (icache_tag_width_p)                    \
            		          ,.max_out_credits_p(max_out_credits_p)                       \
                          ,.num_tiles_x_p(num_tiles_x_p)                               \
                          ) z                                                          \
          (.clk_i                                                                      \
           ,.reset_i                                                                   \
           ,.link_sif_i                                                                \
           ,.link_sif_o                                                                \
           ,.my_x_i                                                                    \
           ,.my_y_i                                                                    \
           );                                                                          \
     end

module bsg_manycore_hetero_socket
  import bsg_manycore_pkg::*;
  #(parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter data_width_p = "inv"
    , parameter addr_width_p = "inv"
    , parameter dmem_size_p = "inv"
    , parameter epa_byte_addr_width_p  = "inv"
		, parameter icache_entries_p = "inv" // in words
    , parameter icache_tag_width_p = "inv"
    , parameter vcache_size_p = "inv"
    , parameter debug_p = 0
    , parameter branch_trace_en_p = 0
    , parameter max_out_credits_p = 200
    , parameter hetero_type_p = 0
    , parameter num_tiles_x_p="inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_sets_p="inv"

    , parameter bsg_manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // input and output links
    , input [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // tile coordinates
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
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
