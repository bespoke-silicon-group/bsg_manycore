module bsg_manycore_endpoint #( x_cord_width_p          = "inv"
                                ,y_cord_width_p         = "inv"
                                ,fifo_els_p             = "inv"
                                ,data_width_p           = 32
                                ,addr_width_p           = 32
                                ,packet_width_lp                 = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                ,return_packet_width_lp          = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
                                ,bsg_manycore_link_sif_width_lp  = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                ,num_nets_lp            = 2
                                )
   (  input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // local incoming data interface
    , output [packet_width_lp-1:0]          fifo_data_o
    , output                                fifo_v_o
    , input                                 fifo_yumi_i

    // local returned data interface
    // Like the memory interface, processor should always ready be to handle the returned data
    , output [return_packet_width_lp-1:0]   returned_packet_r_o
    , output                                returned_credit_v_r_o

    // The return packet interface
    , input [return_packet_width_lp-1:0]    returning_data_i
    , input                                 returning_v_i
    , output                                returning_ready_o

    // local outgoing data interface (does not include credits)

    , input  [packet_width_lp-1:0]           out_packet_i
    , input                                  out_v_i
    , output                                 out_ready_o

    , output                                in_fifo_full_o
    );

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p);

   // typecast
   bsg_manycore_link_sif_s link_sif_i_cast, link_sif_o_cast;
   assign link_sif_i_cast = link_sif_i;
   assign link_sif_o = link_sif_o_cast;

   // ----------------------------------------------------------------------------------------
   // Handle incoming request packets
   // ----------------------------------------------------------------------------------------
   //
   // buffer incoming non-return data
   // we should buffer this incoming request because the local memory might
   // not be able to handle the read/write request
   bsg_fifo_1r1w_small #(.width_p(packet_width_lp)
                         ,.els_p (fifo_els_p)
                         ) fifo
     ( .clk_i
      ,.reset_i

      ,.v_i     (link_sif_i_cast.fwd.v)
      ,.data_i  (link_sif_i_cast.fwd.data)
      ,.ready_o (link_sif_o_cast.fwd.ready_and_rev)

      ,.v_o     (fifo_v_o    )
      ,.data_o  (fifo_data_o )
      ,.yumi_i  (fifo_yumi_i )
      );

   // ----------------------------------------------------------------------------------------
   // Handle outgoing credit packets
   // ----------------------------------------------------------------------------------------
   assign link_sif_o_cast.rev.v             = returning_v_i        ;
   assign link_sif_o_cast.rev.data          = returning_data_i     ;
   assign returning_ready_o                 = link_sif_i_cast.rev.ready_and_rev ;

   // ----------------------------------------------------------------------------------------
   // Handle outgoing request packets
   // ----------------------------------------------------------------------------------------
   assign link_sif_o_cast.fwd.v     = out_v_i;
   assign link_sif_o_cast.fwd.data  = out_packet_i;
   assign out_ready_o               = link_sif_i_cast.fwd.ready_and_rev;

   // ----------------------------------------------------------------------------------------
   // Handle incoming credit packets
   // ----------------------------------------------------------------------------------------

   // We buffer the returned packet
   logic [return_packet_width_lp-1:0]   returned_packet_r     ;
   logic                                returned_credit_v_r        ;

   always @(posedge clk_i) begin
     returned_credit_v_r     <= link_sif_i_cast.rev.v    ;
     returned_packet_r  <= link_sif_i_cast.rev.data ;
   end

   // We can always receive the returned packet
   assign link_sif_o_cast.rev.ready_and_rev = 1'b1;
   assign returned_credit_v_r_o      = returned_credit_v_r        ;
   assign returned_packet_r_o = returned_packet_r     ;

   assign in_fifo_full_o = ~link_sif_o_cast.fwd.ready_and_rev;
endmodule


