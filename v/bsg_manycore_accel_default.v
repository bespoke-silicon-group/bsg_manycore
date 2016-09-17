`include "bsg_manycore_packet.vh"

module bsg_manycore_accel_default #(x_cord_width_p   = "inv"
				    , y_cord_width_p = "inv"
				    , data_width_p   = 32
				    , addr_width_p   = "inv"
				    , debug_p        = 0
				    , bank_size_p    = "inv" // in words
				    , num_banks_p    = "inv"

				    // this credit counter is more for implementing memory fences
				    // than containing the number of outstanding remote stores

				    //, max_out_credits_p = (1<<13)-1  // 13 bit counter
				    , max_out_credits_p = 200  // 13 bit counter

				    // this is the size of the receive FIFO
				    , proc_fifo_els_p = 4
				    , num_nets_lp     = 2
				    
				    , hetero_type_p   = 0
				    , packet_width_lp                = `bsg_manycore_packet_width       (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
				    , return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
				    , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width     (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
				    )
   (input   clk_i
    , input reset_i

    // input and output links
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // tile coordinates
    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    , output logic freeze_o
    );

   wire freeze_r;
   assign freeze_o = freeze_r;

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   logic [packet_width_lp-1:0]             out_data;
   logic                                   out_v;
   logic                                   out_ready;
   logic [$clog2(max_out_credits_p+1)-1:0] out_credits;

   logic [data_width_p-1:0]                in_data;
   logic [(data_width_p>>3)-1:0] 	   in_mask;
   logic [addr_width_p-1:0] 		   in_addr;
   logic                                   in_v, in_yumi;

   bsg_manycore_endpoint_standard #(.x_cord_width_p (x_cord_width_p)
                                    ,.y_cord_width_p(y_cord_width_p)
                                    ,.fifo_els_p    (proc_fifo_els_p)
                                    ,.data_width_p  (data_width_p)
                                    ,.addr_width_p  (addr_width_p)
                                    ,.max_out_credits_p(max_out_credits_p)
                                    ,.debug_p(debug_p)
                                    ) endp
     (.clk_i
      ,.reset_i

      ,.link_sif_i
      ,.link_sif_o

      ,.in_v
      ,.in_yumi
      ,.in_data
      ,.in_mask
      ,.in_addr

      // we feed the endpoint with the data we want to send out
      // it will get inserted into the above link_sif

      ,.out_data_i (out_data )
      ,.out_v_i    (out_v    )
      ,.out_ready_o(out_ready)

      ,.out_credits_o(out_credits)

      ,.my_x_i
      ,.my_y_i
      ,.freeze_r_o(freeze_r)
      );

endmodule
