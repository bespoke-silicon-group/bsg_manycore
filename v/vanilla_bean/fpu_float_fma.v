/**
 *    fpu_float_fma.v
 *
 */


`include "bsg_vanilla_defines.vh"
`include "HardFloat_consts.vi"
`include "HardFloat_specialize.vi"

module fpu_float_fma
  import bsg_vanilla_pkg::*;
  import bsg_hardfloat_pkg::*;
  #(parameter exp_width_p=fpu_recoded_exp_width_gp
    , sig_width_p=fpu_recoded_sig_width_gp
    , data_width_p=RV32_reg_data_width_gp
    , localparam recoded_data_width_lp=(1+exp_width_p+sig_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input stall_fpu1_i

    // int mul input (from EXE)
    , input imul_v_i
    , input [data_width_p-1:0] imul_rs1_i
    , input [data_width_p-1:0] imul_rs2_i

    // FPU input (from FP_EXE)
    , input fp_v_i
    , input fpu_float_op_e fpu_float_op_i
    , input [recoded_data_width_lp-1:0] fp_rs1_i
    , input [recoded_data_width_lp-1:0] fp_rs2_i
    , input [recoded_data_width_lp-1:0] fp_rs3_i
    , input frm_e fp_rm_i 
    
    // int mul output
    , output logic imul_v_o
    , output logic [data_width_p-1:0] imul_result_o

    // used for fcsr fence and stall_fp_bypass
    , output logic fma1_v_o
    , output frm_e fma1_rm_o
    , output logic invalidExc_o
    , output logic out_isNaN_o
    , output logic out_isInf_o
    , output logic out_isZero_o
    , output logic out_sign_o
    , output logic [exp_width_p+1:0] out_sExp_o
    , output logic [sig_width_p+2:0] out_sig_o
  );


  logic [recoded_data_width_lp-1:0] fma_a_li;
  logic [recoded_data_width_lp-1:0] fma_b_li;
  logic [recoded_data_width_lp-1:0] fma_c_li;
  fma_opcode_e fma_op_li;
  logic is_fma_op;

  always_comb begin
    fma_a_li = fp_rs1_i;
    fma_b_li = fp_rs2_i;
    fma_c_li = fp_rs3_i;
    fma_op_li = ePM_PB;
    is_fma_op = 1'b0;

    // FPU gets imul inputs only when there is imul in EXE.
    // so that it does not cause spurious toggles in FPU by normal integer ops.

    // assumption: imul_v_i is coming straight of a register and does not glitch
    if (imul_v_i) begin
      fma_a_li = {1'b0, imul_rs1_i};
      fma_b_li = {1'b0, imul_rs2_i};
      fma_c_li = 33'h0;
      fma_op_li = eIMUL;
    end
    else begin
      case (fpu_float_op_i)
        eFADD: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = `FPU_RECODED_ONE;
          fma_c_li = fp_rs2_i;
          fma_op_li = ePM_PB;
          is_fma_op = 1'b1;
        end
        eFSUB: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = `FPU_RECODED_ONE;
          fma_c_li = fp_rs2_i;
          fma_op_li = ePM_NB;
          is_fma_op = 1'b1;
        end
        eFMUL: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = fp_rs2_i;
          fma_c_li = `FPU_RECODED_ZERO;
          fma_op_li = ePM_PB;
          is_fma_op = 1'b1;
        end
        eFMADD: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = fp_rs2_i;
          fma_c_li = fp_rs3_i;
          fma_op_li = ePM_PB;
          is_fma_op = 1'b1;
        end
        eFMSUB: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = fp_rs2_i;
          fma_c_li = fp_rs3_i;
          fma_op_li = ePM_NB;
          is_fma_op = 1'b1;

        end
        eFNMSUB: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = fp_rs2_i;
          fma_c_li = fp_rs3_i;
          fma_op_li = eNM_PB;
          is_fma_op = 1'b1;

        end
        eFNMADD: begin
          fma_a_li = fp_rs1_i;
          fma_b_li = fp_rs2_i;
          fma_c_li = fp_rs3_i;
          fma_op_li = eNM_NB;
          is_fma_op = 1'b1;
        end
        default: begin
          is_fma_op = 1'b0;
        end
      endcase
    end
  end


  // FMA pre-round
  logic invalidExc;
  logic out_isNaN;
  logic out_isInf;
  logic out_isZero;
  logic out_sign;
  logic [exp_width_p+1:0] out_sExp;
  logic [sig_width_p+2:0] out_sig;
  logic [exp_width_p+sig_width_p-1:0] out_imul;  

  mulAddRecFNToRaw #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) mulAdd0 (
    .control(`flControl_default)
    ,.clock (clk_i) // not used.
    ,.op(fma_op_li)
    ,.a(fma_a_li)
    ,.b(fma_b_li)
    ,.c(fma_c_li)
    ,.roundingMode(fp_rm_i)

    ,.invalidExc(invalidExc)
    ,.out_isNaN(out_isNaN)
    ,.out_isInf(out_isInf)
    ,.out_isZero(out_isZero)
    ,.out_sign(out_sign)
    ,.out_sExp(out_sExp)
    ,.out_sig(out_sig)
    ,.out_imul(out_imul)
  );


  logic fma1_v_r;
  logic invalidExc_r;
  logic out_isNaN_r;
  logic out_isInf_r;
  logic out_isZero_r;
  logic out_sign_r;
  logic [exp_width_p+1:0] out_sExp_r;
  logic [sig_width_p+2:0] out_sig_r;
  frm_e fma1_rm_r;

  logic imul_v_r;
  logic [data_width_p-1:0] out_imul_r;


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      fma1_v_r <= 1'b0;
      fma1_rm_r <= eDYN;
      imul_v_r <= 1'b0;
    end
    else begin
      if (~stall_fpu1_i) begin

        fma1_v_r <= fp_v_i & is_fma_op;
        if (fp_v_i & is_fma_op) begin
          fma1_rm_r <= fp_rm_i;
          invalidExc_r <= invalidExc;
          out_isNaN_r <= out_isNaN;
          out_isInf_r <= out_isInf;
          out_isZero_r <= out_isZero;
          out_sign_r <= out_sign;
          out_sExp_r <= out_sExp;
          out_sig_r <= out_sig;
        end
       
        imul_v_r <= imul_v_i; 
        if (imul_v_i) begin
          out_imul_r <= out_imul;
        end

      end
    end
  end


  assign fma1_v_o = fma1_v_r;
  assign fma1_rm_o = fma1_rm_r;

  assign invalidExc_o = invalidExc_r;
  assign out_isNaN_o = out_isNaN_r;
  assign out_isInf_o = out_isInf_r;
  assign out_isZero_o = out_isZero_r;
  assign out_sign_o = out_sign_r;
  assign out_sExp_o = out_sExp_r;
  assign out_sig_o = out_sig_r;

  assign imul_v_o = imul_v_r;
  assign imul_result_o = out_imul_r;


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      assert(~(fp_v_i & imul_v_i)) else $error("Can't have both FPU and IMUL at the same time.");
    end
  end
  // synopsys translate_on


endmodule

