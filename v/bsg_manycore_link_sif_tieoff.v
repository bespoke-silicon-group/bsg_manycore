/**
 *    bsg_manycore_link_sif_tieoff.v
 *
 *    This is used to tie off manycore links on the edge.
 *    If the tied off link receives a packet (request or return), it prints an error.
 *
 */

`include "bsg_manycore_defines.vh"

module bsg_manycore_link_sif_tieoff
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p )
    , `BSG_INV_PARAM(data_width_p )
    , `BSG_INV_PARAM(x_cord_width_p )
    , `BSG_INV_PARAM(y_cord_width_p )
    , localparam link_sif_width_lp =
    `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
  )
  (
    // debug only
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o
  );

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s link_sif_in;
  assign link_sif_in = link_sif_i;
  assign link_sif_o  = '0;

 `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_packet_s fwd_packet;
  bsg_manycore_return_packet_s rev_packet;
  assign fwd_packet = link_sif_in.fwd.data;
  assign rev_packet = link_sif_in.rev.data;

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      // handle errant fwd packet
      assert (~link_sif_in.fwd.v) else
        $error("[BSG_ERROR] Errant fwd packet detected: src_x=%0d, src_y=%0d, dest_x=%0d, dest_y=%0d.",
          fwd_packet.src_x_cord, fwd_packet.src_y_cord, fwd_packet.x_cord, fwd_packet.y_cord);

      // handle errant rev packet
      assert (~link_sif_in.rev.v) else
        $error("[BSG_ERROR] Errant rev packet detected: dest_x=%0d, dest_y=%0d.",
          rev_packet.x_cord, rev_packet.y_cord);
    end
  end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_sif_tieoff)
