/**
 *    fpu_int_fclass.v
 *
 */

`include "bsg_defines.v"

module fpu_int_fclass
  import bsg_vanilla_pkg::*;
  #(parameter exp_width_p=fpu_recoded_exp_width_gp
    , sig_width_p=fpu_recoded_sig_width_gp
    , localparam recoded_data_width_lp=(1+exp_width_p+sig_width_p)
  )
  (
    input [recoded_data_width_lp-1:0] i
    , output [9:0] o
  );

  logic is_nan;
  logic is_inf;
  logic is_zero;
  logic sign;
  logic [exp_width_p+1:0] exp;
  
  recFNToRawFN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) raw0 (
    .in(i)
    ,.isNaN(is_nan)
    ,.isInf(is_inf)
    ,.isZero(is_zero)
    ,.sign(sign)
    ,.sExp(exp)
    ,.sig()
  ); 

  wire is_subnormal = (exp < ((2**(exp_width_p-1))+2)) & ~is_nan & ~is_inf & ~is_zero;
  wire is_normal = ~(is_subnormal | is_inf | is_zero | is_nan);

  assign o[0] = sign & is_inf;                                // -oo
  assign o[1] = sign & is_normal;                             // -normal
  assign o[2] = sign & is_subnormal;                          // -subnormal
  assign o[3] = sign & is_zero;                               // -0
  assign o[4] = ~sign & is_zero;                              // +0
  assign o[5] = ~sign & is_subnormal;                         // +subnormal
  assign o[6] = ~sign & is_normal;                            // +normal
  assign o[7] = ~sign & is_inf;                               // +oo
  assign o[8] = is_nan & ~i[sig_width_p-2];                   // signaling NaN
  assign o[9] = is_nan & i[sig_width_p-2];                    // quiet NaN


endmodule

