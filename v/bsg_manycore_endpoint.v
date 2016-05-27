module bsg_manycore_endpoint #( x_cord_width_p          = "inv"
                                ,y_cord_width_p         = "inv"
                                ,fifo_els_p             = "inv"
                                ,data_width_p           = 32
                                ,addr_width_p           = 32
                                ,packet_width_lp        = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                ,return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
                                ,num_nets_lp            = 2
                                )
   (input clk_i
    , input reset_i

    // mesh network
    , input  [num_nets_lp-1:0]                       v_i
    , input  [packet_width_lp-1:0]                data_i
    , input  [return_packet_width_lp-1:0]  return_data_i
    , output [num_nets_lp-1:0]                   ready_o

    // mesh network (outgoing return)
    , output                                return_v_o
    , output [return_packet_width_lp-1:0]   return_data_o
    , input                                 return_ready_i

    // local interface
    , output [packet_width_lp-1:0]          fifo_data_o
    , output                                fifo_v_o
    , input                                 fifo_yumi_i

    // whether a credit was returned; not flow controlled
    , output                                credit_v_r_o
    );

   logic fifo_v;

   // buffer incoming non-return data

   bsg_fifo_1r1w_small #(.width_p(packet_width_lp)
                         ,.els_p (fifo_els_p)
                         ) fifo
     (.clk_i
      ,.reset_i

      ,.v_i     (v_i[0]      )
      ,.data_i  (data_i      )
      ,.ready_o (ready_o[0]  )

      ,.v_o     (fifo_v      )
      ,.data_o  (fifo_data_o )
      ,.yumi_i  (fifo_yumi_i )
      );

   // hide data if we do not have the ability to send credit packets
   assign fifo_v_o      = fifo_v & return_ready_i;

   // Handle outgoing credit packets
   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   assign return_v_o    = fifo_yumi_i;

   bsg_manycore_packet_s pkt;

   assign pkt           = fifo_data_o;
   assign return_data_o = pkt.return_pkt;

   // Handle incoming credit packets

   assign ready_o[1]   = 1'b1;

   logic  credit_v_r;

   always @(posedge clk_i)
     credit_v_r <= v_i[1];

   assign credit_v_r_o   = credit_v_r;

endmodule


