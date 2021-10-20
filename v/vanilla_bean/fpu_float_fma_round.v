/**
 *    fpu_float_fma_round.v
 *
 */

`include "bsg_defines.v"
`include "HardFloat_consts.vi"
`include "HardFloat_specialize.vi"

module fpu_float_fma_round
  import bsg_vanilla_pkg::*;
  #(parameter exp_width_p = fpu_recoded_exp_width_gp
    , parameter sig_width_p = fpu_recoded_sig_width_gp

    , parameter recoded_data_width_lp=(1+exp_width_p+sig_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input stall_fpu2_i
     
    , input fma1_v_i 
    , input frm_e fma1_rm_i

    , input invalidExc_i
    , input in_isNaN_i
    , input in_isInf_i
    , input in_isZero_i
    , input in_sign_i
    , input [exp_width_p+1:0] in_sExp_i
    , input [sig_width_p+2:0] in_sig_i

    , output logic fma2_v_o
    , output [recoded_data_width_lp-1:0] fma2_result_o
    , output fflags_s fma2_fflags_o
  );


  // FMA round
  logic [recoded_data_width_lp-1:0] result_lo;
  fflags_s fflags_lo;

  roundRawFNToRecFN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) round0 (
    .control(`flControl_default)
    ,.invalidExc(invalidExc_i)
    ,.infiniteExc(1'b0)
    ,.in_isNaN(in_isNaN_i)
    ,.in_isInf(in_isInf_i)
    ,.in_isZero(in_isZero_i)
    ,.in_sign(in_sign_i)
    ,.in_sExp(in_sExp_i)
    ,.in_sig(in_sig_i)
    ,.roundingMode(fma1_rm_i)

    ,.out(result_lo)
    ,.exceptionFlags(fflags_lo)
  );


  
  logic v_r;
  logic [recoded_data_width_lp-1:0] result_r;
  fflags_s fflags_r;



  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_r <= 1'b0;
    end
    else begin
      if (~stall_fpu2_i) begin
        v_r <= fma1_v_i;
        if (fma1_v_i) begin
          result_r <= result_lo;
          fflags_r <= fflags_lo;
        end
      end
    end
  end


  assign fma2_v_o = v_r;
  assign fma2_result_o = result_r;
  assign fma2_fflags_o = fflags_r;
  

endmodule

