/**
 *  fpu_int.v
 *  
 *  FPU for instructions that writes back to integer regfile.
 *
 *  - FCLASS
 *  - FLE, FLT, FEQ
 *  - F2I, FMV
 */


`include "HardFloat_consts.vi"

module fpu_int
  import bsg_vanilla_pkg::*;
  #(parameter exp_width_p=fpu_recoded_exp_width_gp
    , parameter sig_width_p=fpu_recoded_sig_width_gp
    , parameter data_width_p=RV32_reg_data_width_gp // integer width
    , parameter recoded_data_width_lp=(1+exp_width_p+sig_width_p)
  )
  (
    input [recoded_data_width_lp-1:0] fp_rs1_i
    , input [recoded_data_width_lp-1:0] fp_rs2_i
    , input fpu_int_op_e fpu_int_op_i
    , input frm_e fp_rm_i
    
    , output logic [data_width_p-1:0] result_o
    , output fflags_s fflags_o
  );

  // decode fpu_int_op
  wire is_flt = fpu_int_op_i == eFLT;
  wire is_fle = fpu_int_op_i == eFLE;
  wire is_feq = fpu_int_op_i == eFEQ;
  wire is_fcvt_w_s = fpu_int_op_i == eFCVT_W_S;
  wire is_fcvt_wu_s = fpu_int_op_i == eFCVT_WU_S;
  wire is_fclass = fpu_int_op_i == eFCLASS;


  // compare
  // IEEE 754-2008
  // FLT and FLE perform "signaling" comparison, meaning invalid exception is set if either input is NaN.
  // FEQ does "quiet" comparison, and the invalid exception is only set when either input is signaling NaN.
  // For all three, the result is zero, if either input is NaN.
  logic cmp_lt_lo;
  logic cmp_eq_lo;
  logic cmp_unordered_lo;
  fflags_s cmp_fflags_lo;
  wire cmp_signaling_li = is_flt | is_fle;
  logic cmp_result;

  compareRecFN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) cmp0 (
    .a(fp_rs1_i)
    ,.b(fp_rs2_i)
    ,.signaling(cmp_signaling_li)
    ,.lt(cmp_lt_lo)
    ,.eq(cmp_eq_lo)
    ,.gt()
    ,.unordered(cmp_unordered_lo) // either input is NaN
    ,.exceptionFlags(cmp_fflags_lo)
  );

  always_comb begin
    cmp_result = 1'b0;

    if (cmp_unordered_lo) begin
      cmp_result = 1'b0;
    end
    else begin
      if (is_flt) begin
        cmp_result = cmp_lt_lo;
      end
      else if (is_fle) begin
        cmp_result = cmp_lt_lo | cmp_eq_lo;
      end
      else if (is_feq) begin
        cmp_result = cmp_eq_lo;
      end
    end
  end


  // F2I
  typedef struct packed {
    logic invalid;
    logic overflow;
    logic inexact;
  } f2i_fflags_s;

  logic [data_width_p-1:0] f2i_result_lo;
  f2i_fflags_s f2i_fflags_lo;

  recFNToIN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
    ,.intWidth(data_width_p)
  ) f2i (
    .control(`flControl_default)
    ,.in(fp_rs1_i)
    ,.roundingMode(fp_rm_i)
    ,.signedOut(is_fcvt_w_s)
    ,.out(f2i_result_lo)
    ,.intExceptionFlags(f2i_fflags_lo)
  ); 


  // FCLASS
  logic [9:0] fclass_result_lo;
  fpu_int_fclass #(
    .exp_width_p(exp_width_p)
    ,.sig_width_p(sig_width_p)
  ) fclass0 (
    .i(fp_rs1_i)
    ,.o(fclass_result_lo)
  );


  // For FMV, un-recode frs1.
  logic [data_width_p-1:0] fp_rs1_fn;

  recFNToFN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) toFN0 (
    .in(fp_rs1_i)
    ,.out(fp_rs1_fn)
  );


  // output logic
  always_comb begin
    fflags_o = '0;

    if (is_flt | is_fle | is_feq) begin
      result_o = {{(data_width_p-1){1'b0}}, cmp_result};
      fflags_o = cmp_fflags_lo;
    end
    else if (is_fcvt_w_s | is_fcvt_wu_s) begin
      result_o = f2i_result_lo;    
      fflags_o = '{
        invalid   : f2i_fflags_lo.invalid,
        div_zero  : 1'b0,
        overflow  : f2i_fflags_lo.overflow,
        underflow : 1'b0,
        inexact   : f2i_fflags_lo.inexact
      };
    end
    else if (is_fclass) begin
      result_o = {{(data_width_p-10){1'b0}}, fclass_result_lo};    
    end
    else begin
      // this covers fmv
      result_o = fp_rs1_fn;
    end
  end


endmodule
