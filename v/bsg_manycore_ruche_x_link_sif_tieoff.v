/**
 *    bsg_manycore_ruche_x_link_sif_tieoff.v
 *
 *    This module is used to tie off ruche x link on the edge.
 *    Depending on the ruche factor and ruche stage, the signals on the link could have been inverted.
 *    This module inverts back the signal without using any hardware.
 *    If the tied off link receives a packet (request or return), it prints an error.
 *
 */

`include "bsg_manycore_defines.vh"

module bsg_manycore_ruche_x_link_sif_tieoff
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(ruche_factor_X_p)
    , `BSG_INV_PARAM(ruche_stage_p)
    , `BSG_INV_PARAM(bit west_not_east_p) // 1'b0 or 1'b1
  
    , parameter bit ruche_factor_even_lp = (ruche_factor_X_p % 2 == 0)
    , parameter bit ruche_stage_even_lp = (ruche_stage_p % 2 == 0)

    , parameter bit invert_output_lp = (ruche_stage_p > 0)
        & (ruche_factor_even_lp
          ? ~ruche_stage_even_lp
          : (west_not_east_p
            ? ruche_stage_even_lp
            : ~ruche_stage_even_lp))
    , parameter bit invert_input_lp = (ruche_stage_p > 0)
        & (ruche_factor_even_lp
          ? ~ruche_stage_even_lp
          : (west_not_east_p
            ? ~ruche_stage_even_lp
            : ruche_stage_even_lp))
/*
    , parameter bit invert_output_lp = (ruche_stage_p > 0)
        & (west_not_east_p
          ? (ruche_factor_X_even_lp ^ ruche_stage_even_lp)
          : (ruche_factor_X_even_lp ^ ~ruche_stage_even_lp))
    , parameter bit invert_input_lp = (ruche_stage_p > 0)
        & (west_not_east_p
          ? (ruche_factor_X_even_lp ^ ~ruche_stage_even_lp)
          : (ruche_factor_X_even_lp ^ ruche_stage_even_lp))
*/
    , parameter ruche_x_link_sif_width_lp=
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    // debug only
    input clk_i
    , input reset_i

    , input  [ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [ruche_x_link_sif_width_lp-1:0] ruche_link_o
  );


  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s ruche_link_in;
  assign ruche_link_in = ruche_link_i;
  assign ruche_link_o = invert_output_lp ? '1 : '0; 


  // synopsys translate_off
 
  // For debugging only
  logic [x_cord_width_p-1:0] fwd_src_x;
  logic [y_cord_width_p-1:0] fwd_dest_y;
  logic [x_cord_width_p-1:0] fwd_dest_x;
  assign {fwd_src_x, fwd_dest_y, fwd_dest_x} = ruche_link_in.fwd.data[0+:(2*x_cord_width_p)+y_cord_width_p];
  
  logic [x_cord_width_p-1:0] rev_dest_x;
  assign rev_dest_x = ruche_link_in.rev.data[0+:x_cord_width_p];

  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      
      if (invert_input_lp ^ ruche_link_in.fwd.v)
        $error("[BSG_ERROR] Errant fwd packet detected. src_x=%0d, dest_y=%0d, dest_x=%0d.",
          fwd_src_x, fwd_dest_y, fwd_dest_x);

      if (invert_input_lp ^ ruche_link_in.rev.v)
        $error("[BSG_ERROR] Errant rev packet detected. dest_x=%0d.", rev_dest_x);
    end
  end
  // synopsys translate_on
  



endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_ruche_x_link_sif_tieoff)
