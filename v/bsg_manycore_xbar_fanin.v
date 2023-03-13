/**
 *    bsg_manycore_xbar_fanin.v
 *
 */


`include "bsg_manycore_defines.vh"


module bsg_manycore_xbar_fanin
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(fwd_not_rev_p)
  
    , localparam num_in_lp = fwd_not_rev_p
                           ? (1+(num_tiles_x_p*num_tiles_y_p))
                           : (1+(num_tiles_x_p*num_tiles_y_p)+(2*num_tiles_x_p))
    , localparam packet_width_lp = fwd_not_rev_p
                                  ? `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                  : `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_in_lp-1:0] v_i
    , input [num_in_lp-1:0][packet_width_lp-1:0] packet_i
    , output logic [num_in_lp-1:0] yumi_o

    , output logic v_o
    , output logic [packet_width_lp-1:0] packet_o
    , input ready_i
  );


  // round robin;
  logic [num_in_lp-1:0] grants;

  bsg_arb_round_robin #(
    .width_p(num_in_lp)
  ) rr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.reqs_i(v_i)
    ,.grants_o(grants)
    ,.yumi_i(v_o & ready_i)
  );


  // data mux
  bsg_mux_one_hot #(
    .els_p(num_in_lp)
    ,.width_p(packet_width_lp)
  ) mux0 (
    .data_i(packet_i)
    ,.sel_one_hot_i(grants)
    ,.data_o(packet_o)
  );

  
  assign v_o = |v_i;
  assign yumi_o = grants & {num_in_lp{v_o & ready_i}};


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_xbar_fanin)
