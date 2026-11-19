/**
 * Terminate a Y ruche boundary using its stage-dependent wire polarity.
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_ruche_y_link_sif_tieoff
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(ruche_factor_Y_p)
    , `BSG_INV_PARAM(ruche_stage_p)
    , `BSG_INV_PARAM(bit north_not_south_p)

    , localparam bit factor_even_lp = (ruche_factor_Y_p % 2 == 0)
    , stage_even_lp = (ruche_stage_p % 2 == 0)
    , invert_output_lp = (ruche_stage_p > 0)
        & (factor_even_lp ? ~stage_even_lp
          : (north_not_south_p ? stage_even_lp : ~stage_even_lp))
    , invert_input_lp = (ruche_stage_p > 0)
        & (factor_even_lp ? ~stage_even_lp
          : (north_not_south_p ? ~stage_even_lp : stage_even_lp))
    , localparam ruche_y_link_sif_width_lp =
      `bsg_manycore_ruche_y_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
    , input [ruche_y_link_sif_width_lp-1:0] ruche_link_i
    , output [ruche_y_link_sif_width_lp-1:0] ruche_link_o
  );

  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_y_link_sif_s ruche_link_in;
  assign ruche_link_in = ruche_link_i;
  assign ruche_link_o = invert_output_lp ? '1 : '0;

  // synopsys translate_off
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      assert (!(invert_input_lp ^ ruche_link_in.fwd.v))
        else $error("[BSG_ERROR] Errant forward packet at Y ruche pod boundary (north=%0d, stage=%0d).",
                    north_not_south_p,ruche_stage_p);
      assert (!(invert_input_lp ^ ruche_link_in.rev.v))
        else $error("[BSG_ERROR] Errant reverse packet at Y ruche pod boundary (north=%0d, stage=%0d).",
                    north_not_south_p,ruche_stage_p);
    end
  end
  // synopsys translate_on
endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_ruche_y_link_sif_tieoff)
