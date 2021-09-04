/**
 *    bsg_ruche_buffer.v
 *
 */

`include "bsg_defines.v"

module bsg_ruche_buffer
  #(parameter width_p="inv"
    , parameter ruche_factor_p="inv"
    , parameter ruche_stage_p="inv"

    , parameter bit invert_lp = (ruche_stage_p == 0)
      ? (ruche_factor_p % 2 == 0)
      : 1'b1

    , parameter harden_p=1
  )
  (
    input [width_p-1:0] i
    , output [width_p-1:0] o
  );


  if (invert_lp) begin: inv

    bsg_inv #(
      .width_p(width_p)
      ,.harden_p(harden_p)
    ) inv0 (
      .i(i)
      ,.o(o)
    );

  end
  else begin: bf

    bsg_buf #(
      .width_p(width_p)
      ,.harden_p(harden_p)
    ) buf0 (
      .i(i)
      ,.o(o)
    );

  end



endmodule
