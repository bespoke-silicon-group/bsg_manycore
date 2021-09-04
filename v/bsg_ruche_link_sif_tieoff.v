/**
 *    bsg_ruche_link_sif_tieoff.v
 *
 *    used for tieing off ruche links (wh) on the sides.
 */

`include "bsg_defines.v"
`include "bsg_noc_links.vh"

module bsg_ruche_link_sif_tieoff
  #(`BSG_INV_PARAM(link_data_width_p)
    , `BSG_INV_PARAM(ruche_factor_p)
    , `BSG_INV_PARAM(ruche_stage_p)
    , `BSG_INV_PARAM(bit west_not_east_p) // tie-off on west or east side??
  

    , parameter bit ruche_factor_even_lp = (ruche_factor_p % 2 == 0)
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


    , parameter link_width_lp=`bsg_ready_and_link_sif_width(link_data_width_p)
  )
  (
    // debug only
    input clk_i
    , input reset_i

    , input [link_width_lp-1:0] ruche_link_i
    , output [link_width_lp-1:0] ruche_link_o
  );


  `declare_bsg_ready_and_link_sif_s(link_data_width_p, ruche_link_sif_s);
  ruche_link_sif_s ruche_link_in;
  assign ruche_link_in = ruche_link_i;
  assign ruche_link_o = invert_output_lp ? '1 : '0; 


  // synopsys translate_off
  // For debugging only
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      
      if (invert_input_lp ^ ruche_link_in.v)
        $error("[BSG_ERROR] Errant packet detected at the tied off ruche link.");

    end
  end
  // synopsys translate_on






endmodule

`BSG_ABSTRACT_MODULE(bsg_ruche_link_sif_tieoff)
