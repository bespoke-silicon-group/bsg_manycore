// 
// bsg_manycore_endpoint_fc.v
//
// This module allows endpoint clients to speak to the manycore network
//   directly with bsg_manycore_packets, while obeying the flow control
//   requirements of the network. In this sense, it's a safer version of
//   bsg_manycore_endpoint and a more flexible version of
//   bsg_manycore_endpoint_standard.
// See: https://docs.google.com/document/d/1-i62N72pfx2Cd_xKT3hiTuSilQnuC0ZOaSQMG8UPkto/edit?usp=sharing
//   for more details on the endpoint standard interface
//

`include "bsg_defines.v"

module bsg_manycore_endpoint_fc
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(x_cord_width_p          )
    , `BSG_INV_PARAM(y_cord_width_p         )
    , `BSG_INV_PARAM(fifo_els_p             )
    , parameter data_width_p           = 32
    , `BSG_INV_PARAM(addr_width_p           )

    , parameter credit_counter_width_p = `BSG_WIDTH(32)
    , parameter warn_out_of_credits_p  = 1

    // size of outgoing response fifo
    , parameter rev_fifo_els_p         = 3
    , parameter lg_rev_fifo_els_lp     = `BSG_WIDTH(rev_fifo_els_p)

    // fwd fifo interface
    , parameter use_credits_for_local_fifo_p = 0

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

    // connect to mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // incoming request
    , output [packet_width_lp-1:0]          packet_o
    , output                                packet_v_o
    , input                                 packet_yumi_i

    // outgoing response
    , input  [return_packet_width_lp-1:0]   return_packet_i
    , input                                 return_packet_v_i

    // outgoing request
    , input  [packet_width_lp-1:0]          packet_i
    , input                                 packet_v_i
    , output                                packet_credit_or_ready_o

    // incoming response
    , output [return_packet_width_lp-1:0]   return_packet_o
    , output                                return_packet_v_o
    , input                                 return_packet_yumi_i
    , output                                return_packet_fifo_full_o

    // This holds the number of credits that we are expecting to (eventually) come back to us.
    // Note: Prior to March 2021, this used to hold the number of credits
    // that were currently available to send. This change allows the clients to have more control
    // over their credits.
    , output [credit_counter_width_p-1:0] out_credits_used_o

  );

  // Instantiate the endpoint.
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  // These signals are overridden locally for flow control
  logic packet_v_lo;
  logic return_packet_credit_or_ready_lo;
  bsg_manycore_endpoint #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.fifo_els_p(fifo_els_p)
  ) bme (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    // RX
    ,.packet_o(packet_o)
    ,.packet_v_o(packet_v_lo)
    ,.packet_yumi_i(packet_yumi_i)

    // NB: endpoint standard uses this as credit-valid interface.
    ,.return_packet_i(return_packet_i)
    ,.return_packet_v_i(return_packet_v_i)
    ,.return_packet_credit_or_ready_o(return_packet_credit_or_ready_lo)

    // TX
    ,.packet_i(packet_i)
    ,.packet_v_i(packet_v_i)
    ,.packet_credit_or_ready_o(packet_credit_or_ready_o)

    ,.return_packet_o(return_packet_o)
    ,.return_packet_v_o(return_packet_v_o)
    ,.return_packet_fifo_full_o(return_packet_fifo_full_o)
    ,.return_packet_yumi_i(return_packet_yumi_i)

  );



  // ----------------------------------------------------------------------------------------
  // Handle incoming request packets
  // ----------------------------------------------------------------------------------------

  // credit counting on response fifo
  // By using credit interface, we are guaranteeing that any incoming request from FWD_FIFO will have a space in 
  // REV_FIFO, guaranteeing that the transaction will always go through once it starts.
  // By default, 3 credits are needed, because the round trip to get the credit back takes three cycles.
  // FWD_FIFO->CORE->REV_FIFO->CREDIT.
  logic [lg_rev_fifo_els_lp-1:0] rev_fifo_credit_r;
  wire [lg_rev_fifo_els_lp-1:0] rev_fifo_credit_available = rev_fifo_credit_r + return_packet_credit_or_ready_lo;
  wire rev_fifo_has_space = (rev_fifo_credit_available != '0);

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      rev_fifo_credit_r <= (lg_rev_fifo_els_lp)'(rev_fifo_els_p);
    end
    else begin
      rev_fifo_credit_r <= rev_fifo_credit_available - (packet_v_lo & packet_yumi_i);
    end
  end

  // present the incoming packet to the core, if there are credits left and  it is load or store.
  assign packet_v_o = packet_v_lo & rev_fifo_has_space;

  // ----------------------------------------------------------------------------------------
  // Handle outgoing request packets
  // ----------------------------------------------------------------------------------------

  // credit counter starts from zero.
  // sending out a request increments and receiving a response decrements.

  wire launching_out = packet_v_i & ((use_credits_for_local_fifo_p == 1) | packet_credit_or_ready_o);
  wire returned_credit = return_packet_v_o & return_packet_yumi_i;

  bsg_counter_up_down #(
    .max_val_p((1<<credit_counter_width_p)-1)
    ,.init_val_p(0)
    ,.max_step_p(1)
  ) out_credit_ctr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.down_i(returned_credit) // receive credit back
    ,.up_i(launching_out)     // launch remote packet
    ,.count_o(out_credits_used_o)
  );


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_endpoint_fc)


