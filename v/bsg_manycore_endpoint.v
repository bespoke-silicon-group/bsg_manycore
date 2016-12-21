module bsg_manycore_endpoint #( x_cord_width_p          = "inv"
                                ,y_cord_width_p         = "inv"
                                ,fifo_els_p             = "inv"
                                ,data_width_p           = 32
                                ,addr_width_p           = 32
                                ,packet_width_lp                 = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                ,return_packet_width_lp          = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
                                ,bsg_manycore_link_sif_width_lp  = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                ,num_nets_lp            = 2
                                )
   (input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // local incoming data interface
    , output [packet_width_lp-1:0]          fifo_data_o
    , output                                fifo_v_o
    , input                                 fifo_yumi_i

    // local outgoing data interface (does not include credits)

    , input  [packet_width_lp-1:0]           out_packet_i
    , input                                  out_v_i
    , output                                 out_ready_o

    // whether a credit was returned; not flow controlled
    , output                                credit_v_r_o
    , output                                in_fifo_full_o
    );

   logic fifo_v;

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p);

   // typecast
   bsg_manycore_link_sif_s link_sif_i_cast, link_sif_o_cast;
   assign link_sif_i_cast = link_sif_i;
   assign link_sif_o = link_sif_o_cast;

   // buffer incoming non-return data

   bsg_fifo_1r1w_small #(.width_p(packet_width_lp)
                         ,.els_p (fifo_els_p)
                         ) fifo
     (.clk_i
      ,.reset_i

      ,.v_i     (link_sif_i_cast.fwd.v)
      ,.data_i  (link_sif_i_cast.fwd.data)
      ,.ready_o (link_sif_o_cast.fwd.ready_and_rev)

      ,.v_o     (fifo_v      )
      ,.data_o  (fifo_data_o )
      ,.yumi_i  (fifo_yumi_i )
      );

   // hide data if we do not have the ability to send credit packets
   assign fifo_v_o      = fifo_v & link_sif_i_cast.rev.ready_and_rev;

   // Handle outgoing credit packets
   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   assign link_sif_o_cast.rev.v   = fifo_yumi_i;
   assign link_sif_o_cast.fwd.v   = out_v_i;

   bsg_manycore_packet_s pkt;

   assign pkt                       = fifo_data_o;
   assign link_sif_o_cast.rev.data  = pkt.return_pkt;
   assign link_sif_o_cast.fwd.data  = out_packet_i;
   assign out_ready_o               = link_sif_i_cast.fwd.ready_and_rev;

   // Handle incoming credit packets

   assign link_sif_o_cast.rev.ready_and_rev = 1'b1;

   logic  credit_v_r;

   always @(posedge clk_i)
     credit_v_r <= link_sif_i_cast.rev.v;

   assign credit_v_r_o   = credit_v_r;
   assign in_fifo_full_o = ~link_sif_o_cast.fwd.ready_and_rev;
endmodule


