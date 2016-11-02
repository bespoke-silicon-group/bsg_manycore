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

`include "bsg_manycore_packet.vh"

`ifdef bsg_FPU
`include "float_definitions.v"
`endif

`define HETERO_TYPE_MACRO(BMC_TYPE,BMC_TYPE_MODULE)             \
   if (hetero_type_p == (BMC_TYPE))                             \
     begin: h                                                   \
        BMC_TYPE_MODULE #(.x_cord_width_p(x_cord_width_p)       \
                          ,.y_cord_width_p(y_cord_width_p)      \
                          ,.data_width_p(data_width_p)          \
                          ,.addr_width_p(addr_width_p)          \
                          ,.debug_p(debug_p)                    \
                          ,.bank_size_p(bank_size_p)            \
                          ,.num_banks_p(num_banks_p)            \
			  ,.imem_size_p(imem_size_p)            \
            		  ,.max_out_credits_p(max_out_credits_p)\
                          ,.hetero_type_p(hetero_type_p)        \
                          ) z                                   \
          (.clk_i                                               \
           ,.reset_i                                            \
           ,.link_sif_i                                         \
           ,.link_sif_o                                         \
           ,.my_x_i                                             \
           ,.my_y_i                                             \
           ,.freeze_o                                           \
 `ifdef bsg_FPU                                                 \
           ,.fam_out_s_i                                        \
           ,.fam_in_s_o                                         \
 `endif                                                         \
           );                                                   \
     end

module bsg_manycore_hetero_socket #(x_cord_width_p      = "inv"
                                    , y_cord_width_p    = "inv"
                                    , data_width_p      = 32
                                    , addr_width_p      = "inv"
                                    , debug_p           = 0
                                    , bank_size_p       = "inv" // in words
				    , imem_size_p       = "inv" // in words
                                    , num_banks_p       = "inv"
                				    , max_out_credits_p = 200
                                    , hetero_type_p     = 1
                                    , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                    )
   (  input   clk_i
    , input reset_i

    // input and output links
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // tile coordinates
    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i
    , output logic freeze_o

 `ifdef bsg_FPU
    , input  f_fam_out_s                         fam_out_s_i 
    , output f_fam_in_s                          fam_in_s_o 
 `endif

    );

   // add as many types as you like...
   `HETERO_TYPE_MACRO(0,bsg_manycore_proc_vanilla) else
   `HETERO_TYPE_MACRO(1,bsg_manycore_proc_vscale) else
   `HETERO_TYPE_MACRO(2,bsg_manycore_accel_default) else
   `HETERO_TYPE_MACRO(3,bsg_manycore_accel_default) else
   `HETERO_TYPE_MACRO(4,bsg_manycore_accel_default) else
   `HETERO_TYPE_MACRO(5,bsg_manycore_accel_default) else
   `HETERO_TYPE_MACRO(6,bsg_manycore_accel_default) else
   `HETERO_TYPE_MACRO(7,bsg_manycore_accel_default) else
   `HETERO_TYPE_MACRO(8,bsg_manycore_accel_default) else
     begin : nh
	// synopsys translate_off
        initial
          begin
             $error("## unidentified hetero core type ",hetero_type_p);
             $finish();
          end
        // synopsys translate_on
     end

endmodule
