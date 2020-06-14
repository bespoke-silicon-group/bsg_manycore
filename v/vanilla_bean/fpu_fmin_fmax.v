/**
 *    fpu_fmin_fmax.v
 *  
 */


//  FMIN, FMAX
//  -0.0 is considered less than +0.0.
//  If both inputs are NaNs, the result is the canonical NaN.
//   If only one operand is a NaN, the result is non-NaN operand.
//  Signaling NaN inputs set the invalid exception flag, even when the result is not NaN.


module fpu_fmin_fmax 
  #(parameter exp_width_p="inv"
    , parameter sig_width_p="inv"

    , parameter recoded_data_width_lp=(exp_width_p+sig_width_p+1)
  )
  (
    input [recoded_data_width_lp-1:0] fp_rs1_i
    , input [recoded_data_width_lp-1:0] fp_rs2_i

    , input fmin_not_fmax_i // 1=FMIN, 0=FMAX

    , output logic invalid_o  // invalid exception
    , output logic [recoded_data_width_lp-1:0] result_o 
  
  );

  // Detect NaN, sig NaN.
  wire rs1_is_nan = &fp_rs1_i[exp_width_p+sig_width_p-3+:3];
  wire rs2_is_nan = &fp_rs2_i[exp_width_p+sig_width_p-3+:3];
  wire rs1_is_signan = rs1_is_nan & ~fp_rs1_i[sig_width_p-2];
  wire rs2_is_signan = rs2_is_nan & ~fp_rs2_i[sig_width_p-2];

  // Compare two values
  logic cmp_lt_lo;
  logic cmp_eq_lo;
  compareRecFN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) cmp0 (
    .a(fp_rs1_i)
    ,.b(fp_rs2_i)
    ,.signaling(1'b0)
    ,.lt(cmp_lt_lo)
    ,.eq(cmp_eq_lo)
    ,.gt()
    ,.unordered()
    ,.exceptionFlags()
  );

  wire rs1_sign = fp_rs1_i[recoded_data_width_lp-1];
  wire rs2_sign = fp_rs2_i[recoded_data_width_lp-1];

  wire both_zero_diff_sign = cmp_eq_lo & (rs1_sign ^ rs2_sign);


  always_comb begin
    if (rs1_is_nan & rs2_is_nan) begin
      result_o = `FPU_RECODED_CANONICAL_NAN;
    end
    else if (rs1_is_nan & ~rs2_is_nan) begin
      result_o = fp_rs2_i;
    end
    else if (~rs1_is_nan & rs2_is_nan) begin
      result_o = fp_rs1_i;
    end
    else if (both_zero_diff_sign) begin
      // fmin_i  rs1_sign  rs2_sign   result
      // -----------------------------------
      //   0        0         1         rs1
      //   0        1         0         rs2
      //   1        0         1         rs2
      //   1        1         0         rs1
      result_o = (fmin_not_fmax_i ^ rs1_sign)
        ? fp_rs2_i
        : fp_rs1_i;
    end
    else begin
      // a<b    min   result
      //--------------------
      //  0      0      a 
      //  0      1      b
      //  1      0      b
      //  1      1      a
      result_o = (cmp_lt_lo ^ fmin_not_fmax_i)
        ? fp_rs2_i
        : fp_rs1_i;
    end
  end 

  assign invalid_o = rs1_is_signan | rs2_is_signan;


endmodule
