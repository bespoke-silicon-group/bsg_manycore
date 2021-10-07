/**
 *    fpu_float_aux.v
 *
 */

`include "bsg_defines.v"
`include "HardFloat_consts.vi"
`include "HardFloat_specialize.vi"

module fpu_float_aux 
  import bsg_vanilla_pkg::*;
  #(parameter sig_width_p=fpu_recoded_sig_width_gp
    , parameter exp_width_p=fpu_recoded_exp_width_gp
    , parameter data_width_p=RV32_reg_data_width_gp

    , parameter recoded_data_width_lp=(1+sig_width_p+exp_width_p)
  )
  (
    input fp_v_i
    , input fpu_float_op_e fpu_float_op_i
    , input [recoded_data_width_lp-1:0] fp_rs1_i
    , input [recoded_data_width_lp-1:0] fp_rs2_i
    , input frm_e fp_rm_i 
    
    , output logic v_o
    , output logic [recoded_data_width_lp-1:0] result_o
    , output fflags_s fflags_o
  );
  
  // fpu_float_op decode
  wire is_fmin = fpu_float_op_i == eFMIN;
  wire is_fcvt_s_w = fpu_float_op_i == eFCVT_S_W;

  // i2f
  logic [recoded_data_width_lp-1:0] i2f_result_lo;
  fflags_s i2f_fflags_lo;

  iNToRecFN #(
    .intWidth(data_width_p)
    ,.expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) i2f (
    .control(`flControl_default)
    ,.signedIn(is_fcvt_s_w)
    ,.in(fp_rs1_i[0+:data_width_p])
    ,.roundingMode(fp_rm_i)
    ,.out(i2f_result_lo)
    ,.exceptionFlags(i2f_fflags_lo)
  );

  // FMIN/FMAX
  logic fmin_fmax_invalid_lo;
  logic [recoded_data_width_lp-1:0] fmin_fmax_result_lo;

  fpu_fmin_fmax #(
    .exp_width_p(exp_width_p)
    ,.sig_width_p(sig_width_p)
  ) minmax0 (
    .fp_rs1_i(fp_rs1_i)
    ,.fp_rs2_i(fp_rs2_i)
    ,.fmin_not_fmax_i(is_fmin)
    ,.invalid_o(fmin_fmax_invalid_lo)
    ,.result_o(fmin_fmax_result_lo)
  );
 

  // SIGN INJECT
  logic [recoded_data_width_lp-1:0] fsgnj_result;

  always_comb begin
    fsgnj_result[recoded_data_width_lp-2:0] = fp_rs1_i[recoded_data_width_lp-2:0];

    case (fpu_float_op_i)
      eFSGNJ: begin
        fsgnj_result[recoded_data_width_lp-1] = fp_rs2_i[recoded_data_width_lp-1];
      end
    
      eFSGNJN: begin
        fsgnj_result[recoded_data_width_lp-1] = ~fp_rs2_i[recoded_data_width_lp-1];
      end

      eFSGNJX: begin
        fsgnj_result[recoded_data_width_lp-1] = fp_rs1_i[recoded_data_width_lp-1] ^ fp_rs2_i[recoded_data_width_lp-1];
      end

      default: begin
        fsgnj_result[recoded_data_width_lp-1] = fp_rs1_i[recoded_data_width_lp-1];
      end
    endcase
  end


  // FMV
  logic [recoded_data_width_lp-1:0] rs1_recoded_val;
  fNToRecFN #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) recFN_rs1 (
    .in(fp_rs1_i[0+:data_width_p])
    ,.out(rs1_recoded_val)
  );


  always_comb begin

    case (fpu_float_op_i)
      eFMIN, eFMAX: begin
        v_o = fp_v_i;
        result_o = fmin_fmax_result_lo;
        fflags_o = '{
          invalid: fmin_fmax_invalid_lo,
          div_zero: 1'b0,
          overflow: 1'b0,
          underflow: 1'b0,
          inexact: 1'b0
        };
      end
    
      eFCVT_S_W, eFCVT_S_WU: begin
        v_o = fp_v_i;
        result_o = i2f_result_lo;
        fflags_o = i2f_fflags_lo;
      end
    
      eFSGNJ, eFSGNJN, eFSGNJX: begin
        v_o = fp_v_i;
        result_o = fsgnj_result;
        fflags_o = '0;
      end

      eFMV_W_X: begin
        v_o = fp_v_i;
        result_o = rs1_recoded_val;
        fflags_o = '0;
      end

      default: begin
        v_o = 1'b0;
        result_o = i2f_result_lo;
        fflags_o = i2f_fflags_lo;
      end
    endcase

  end


endmodule

