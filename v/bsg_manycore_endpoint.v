/**
 *    bsg_manycore_endpoint.v
 *
 */

`include "bsg_defines.v"

module bsg_manycore_endpoint
  import bsg_manycore_pkg::*;
  #(parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter fifo_els_p = "inv"
    , parameter data_width_p = 32
    , parameter addr_width_p = "inv"
    
    , parameter packet_width_lp = 
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter return_packet_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
    , parameter bsg_manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // incoming request
    , output [packet_width_lp-1:0]          packet_o
    , output                                packet_v_o
    , input                                 packet_yumi_i

    // outgoing response
    , input  [return_packet_width_lp-1:0]   return_packet_i
    , input                                 return_packet_v_i
    , output                                return_packet_credit_or_ready_o

    // outgoing request
    , input  [packet_width_lp-1:0]          packet_i
    , input                                 packet_v_i
    , output                                packet_credit_or_ready_o

    // incoming response
    , output [return_packet_width_lp-1:0]   return_packet_o
    , output                                return_packet_v_o
    , input                                 return_packet_yumi_i
    , output                                return_packet_fifo_full_o

  );

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  // typecast
  bsg_manycore_link_sif_s link_sif_in, link_sif_out;
  assign link_sif_in = link_sif_i;
  assign link_sif_o = link_sif_out;

   // ----------------------------------------------------------------------------------------
   // Handle incoming request packets
   // ----------------------------------------------------------------------------------------
   //
   // buffer incoming non-return data
   // we should buffer this incoming request because the local memory might
   // not be able to handle the read/write request
   bsg_fifo_1r1w_small #(
    .width_p(packet_width_lp)
    ,.els_p (fifo_els_p)
   ) fifo
     ( .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.v_i     (link_sif_in.fwd.v)
      ,.data_i  (link_sif_in.fwd.data)
      ,.ready_o (link_sif_out.fwd.ready_and_rev)


      ,.v_o     (packet_v_o    )
      ,.data_o  (packet_o )
      ,.yumi_i  (packet_yumi_i )
      );

   // ----------------------------------------------------------------------------------------
   // Handle outgoing response
   // ----------------------------------------------------------------------------------------
   assign link_sif_out.rev.v             = return_packet_v_i;
   assign link_sif_out.rev.data          = return_packet_i;
   assign return_packet_credit_or_ready_o          = link_sif_in.rev.ready_and_rev ;

   // ----------------------------------------------------------------------------------------
   // Handle outgoing request packets
   // ----------------------------------------------------------------------------------------
   assign link_sif_out.fwd.v     = packet_v_i;
   assign link_sif_out.fwd.data  = packet_i;
   assign packet_credit_or_ready_o         = link_sif_in.fwd.ready_and_rev;

   // ----------------------------------------------------------------------------------------
   // Handle incoming credit packets
   // ----------------------------------------------------------------------------------------

   // We buffer the returned packet
   logic returned_fifo_ready;

   bsg_two_fifo #(
    .width_p(return_packet_width_lp)
    ,.allow_enq_deq_on_full_p(1)
   ) returned_fifo
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i     (link_sif_in.rev.v)
        ,.data_i  (link_sif_in.rev.data)
        ,.ready_o (returned_fifo_ready)

        ,.v_o     (return_packet_v_o)
        ,.data_o  (return_packet_o)
        ,.yumi_i  (return_packet_yumi_i)
        );

   assign return_packet_fifo_full_o = ~returned_fifo_ready;


   // We should always receive the returned packet
   assign link_sif_out.rev.ready_and_rev = 1'b1;


  // synopsys translate_off

  always_ff @ (negedge clk_i) begin

    if (~reset_i & ~returned_fifo_ready)
      assert(return_packet_yumi_i) else
        $error("[BSG_ERROR] return fifo has to be dequeued, when it's full.");

  end

  // synopsys translate_on


endmodule


