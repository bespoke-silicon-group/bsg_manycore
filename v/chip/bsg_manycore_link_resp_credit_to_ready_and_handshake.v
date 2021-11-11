//
// bsg_manycore_link_resp_credit_to_ready_and_handshake.v
//
// For bsg_manycore_endpoint_standard or every module that instantiates
// bsg_manycore_endpoint, out response packets use credit-based insterface,
// which cannot be attached to regular bsg_manycore_links directly.
//
// This adapter converts credit-based interface to regular manycore links.
//

`include "bsg_manycore_defines.vh"

module bsg_manycore_link_resp_credit_to_ready_and_handshake

 import bsg_manycore_pkg::*;

 #(parameter `BSG_INV_PARAM(addr_width_p)
  ,parameter `BSG_INV_PARAM(data_width_p)
  ,parameter `BSG_INV_PARAM(x_cord_width_p)
  ,parameter `BSG_INV_PARAM(y_cord_width_p)
  // by default els_p=3 because credit-based interface has 2 cycle latency
  // reducing fifo size below 3 may introduce bubble cycle(s)
  ,parameter fifo_els_p     = 3
  ,parameter fwd_width_lp =
    `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,parameter rev_width_lp =
    `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  ,parameter manycore_link_width_lp =
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )

  (input clk_i
  ,input reset_i

  // Attach to bsg_manycore_endpoint
  ,input  [manycore_link_width_lp-1:0] credit_link_sif_i
  ,output [manycore_link_width_lp-1:0] credit_link_sif_o

  // Attach to regular manycore_links
  ,input  [manycore_link_width_lp-1:0] ready_and_link_sif_i
  ,output [manycore_link_width_lp-1:0] ready_and_link_sif_o
  );

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s credit_link_sif_li, credit_link_sif_lo;
  bsg_manycore_link_sif_s ready_and_link_sif_li, ready_and_link_sif_lo;

  assign credit_link_sif_li    = credit_link_sif_i;
  assign credit_link_sif_o     = credit_link_sif_lo;
  assign ready_and_link_sif_li = ready_and_link_sif_i;
  assign ready_and_link_sif_o  = ready_and_link_sif_lo;

  // bypass fwd manycore links
  assign ready_and_link_sif_lo.fwd = credit_link_sif_li.fwd;
  assign credit_link_sif_lo.fwd    = ready_and_link_sif_li.fwd;

  // bypass part of the rev manycore links
  assign credit_link_sif_lo.rev.v                = ready_and_link_sif_li.rev.v;
  assign credit_link_sif_lo.rev.data             = ready_and_link_sif_li.rev.data;
  assign ready_and_link_sif_lo.rev.ready_and_rev = credit_link_sif_li.rev.ready_and_rev;

  // sink fifo
  logic fifo_ready_lo, fifo_yumi_li;
  assign fifo_yumi_li = ready_and_link_sif_lo.rev.v & ready_and_link_sif_li.rev.ready_and_rev;

  bsg_fifo_1r1w_small
 #(.width_p (rev_width_lp                  )
  ,.els_p   (fifo_els_p                    )
  ) fifo
  (.clk_i   (clk_i                         )
  ,.reset_i (reset_i                       )
  ,.v_i     (credit_link_sif_li.rev.v      )
  ,.data_i  (credit_link_sif_li.rev.data   )
  ,.ready_o (fifo_ready_lo                 )
  ,.v_o     (ready_and_link_sif_lo.rev.v   )
  ,.data_o  (ready_and_link_sif_lo.rev.data)
  ,.yumi_i  (fifo_yumi_li                  )
  );

  bsg_dff_reset
 #(.width_p    (1)
  ,.reset_val_p(0)
  ) dff
  (.clk_i      (clk_i       )
  ,.reset_i    (reset_i     )
  ,.data_i     (fifo_yumi_li)
  ,.data_o     (credit_link_sif_lo.rev.ready_and_rev)
  );

  // synopsys translate_off
  always_ff @(negedge clk_i)
  begin
    if (~reset_i & credit_link_sif_li.rev.v)
      begin
        assert(fifo_ready_lo)
        else $error("Trying to enque when there is no space in FIFO, while using credit interface.");
      end
  end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_resp_credit_to_ready_and_handshake)

