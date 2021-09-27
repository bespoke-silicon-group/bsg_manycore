/**
 *    fpu_float.v
 *
 *    - FMA + imul
 *    - i2f
 *    - FSGNJ, FMV
 *
 *    fpu_float is 2-stage pipelined. IMUL result becomes available in the first stage.
 *    Other float operations becomes available in the second stage.
 */

`include "bsg_defines.v"

module fpu_float
  import bsg_vanilla_pkg::*;
  #(parameter exp_width_p=fpu_recoded_exp_width_gp
    , parameter sig_width_p=fpu_recoded_sig_width_gp
    , parameter data_width_p=RV32_reg_data_width_gp // integer width
    , parameter reg_addr_width_p=RV32_reg_addr_width_gp
    , parameter recoded_data_width_lp=(1+exp_width_p+sig_width_p)
  )
  (
    input clk_i
    , input reset_i
    
    , input stall_fpu1_i
    , input stall_fpu2_i

    // int mul input (from EXE)
    , input imul_v_i
    , input [data_width_p-1:0] imul_rs1_i
    , input [data_width_p-1:0] imul_rs2_i
    , input [reg_addr_width_p-1:0] imul_rd_i

    // FPU input (from FP_EXE)
    , input fp_v_i
    , input fpu_float_op_e fpu_float_op_i
    , input [recoded_data_width_lp-1:0] fp_rs1_i
    , input [recoded_data_width_lp-1:0] fp_rs2_i
    , input [recoded_data_width_lp-1:0] fp_rs3_i
    , input [reg_addr_width_p-1:0] fp_rd_i
    , input frm_e fp_rm_i 

    // int mul output
    , output logic imul_v_o
    , output logic [data_width_p-1:0] imul_result_o
    , output logic [reg_addr_width_p-1:0] imul_rd_o
   
    // FPU output
    , output logic fp_v_o
    , output logic [recoded_data_width_lp-1:0] fp_result_o
    , output fflags_s fp_fflags_o
    , output logic [reg_addr_width_p-1:0] fp_rd_o

    // used for fcsr fence and stall_fp_bypass
    , output logic fpu1_v_r_o
    , output logic [reg_addr_width_p-1:0] fpu1_rd_o
  );


  // FMA
  logic fma1_v_lo;
  frm_e fma1_rm_lo;
  logic invalidExc;
  logic out_isNaN;
  logic out_isInf;
  logic out_isZero;
  logic out_sign;
  logic [exp_width_p+1:0] out_sExp;
  logic [sig_width_p+2:0] out_sig;

  fpu_float_fma fma1 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.stall_fpu1_i(stall_fpu1_i) 

    ,.imul_v_i(imul_v_i)
    ,.imul_rs1_i(imul_rs1_i)
    ,.imul_rs2_i(imul_rs2_i)

    ,.fp_v_i(fp_v_i)
    ,.fpu_float_op_i(fpu_float_op_i)
    ,.fp_rs1_i(fp_rs1_i)
    ,.fp_rs2_i(fp_rs2_i)
    ,.fp_rs3_i(fp_rs3_i)
    ,.fp_rm_i(fp_rm_i)

    ,.imul_v_o(imul_v_o)
    ,.imul_result_o(imul_result_o)
    
    ,.fma1_v_o(fma1_v_lo)
    ,.fma1_rm_o(fma1_rm_lo)
    ,.invalidExc_o(invalidExc)
    ,.out_isNaN_o(out_isNaN)
    ,.out_isInf_o(out_isInf)
    ,.out_isZero_o(out_isZero)
    ,.out_sign_o(out_sign)
    ,.out_sExp_o(out_sExp)
    ,.out_sig_o(out_sig)
  );


  // FMA ROUND
  logic fma2_v_lo;
  logic [recoded_data_width_lp-1:0] fma2_result_lo;

  fflags_s fma2_fflags_lo;

  fpu_float_fma_round fma2 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
 
    ,.stall_fpu2_i(stall_fpu2_i)    

    ,.fma1_v_i(fma1_v_lo)
    ,.fma1_rm_i(fma1_rm_lo)

    ,.invalidExc_i(invalidExc)
    ,.in_isNaN_i(out_isNaN)
    ,.in_isInf_i(out_isInf)
    ,.in_isZero_i(out_isZero)
    ,.in_sign_i(out_sign)
    ,.in_sExp_i(out_sExp)
    ,.in_sig_i(out_sig)

    ,.fma2_v_o(fma2_v_lo)
    ,.fma2_result_o(fma2_result_lo)
    ,.fma2_fflags_o(fma2_fflags_lo)
  );


  // FPU FLOAT AUX
  logic aux_v_lo;
  logic [recoded_data_width_lp-1:0] aux_result_lo;
  fflags_s aux_fflags_lo;

  fpu_float_aux aux0 (
    .fp_v_i(fp_v_i)
    ,.fpu_float_op_i(fpu_float_op_i)
    ,.fp_rs1_i(fp_rs1_i)
    ,.fp_rs2_i(fp_rs2_i)
    ,.fp_rm_i(fp_rm_i)

    ,.v_o(aux_v_lo)
    ,.result_o(aux_result_lo)
    ,.fflags_o(aux_fflags_lo)
  );


  logic [reg_addr_width_p-1:0] fpu1_rd_r;
  logic [reg_addr_width_p-1:0] fpu2_rd_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      fpu1_rd_r <= '0;
      fpu2_rd_r <= '0;
    end
    else begin
      if (~stall_fpu1_i) begin
        if (fp_v_i) begin
          fpu1_rd_r <= fp_rd_i;
        end
        else if (imul_v_i) begin
          fpu1_rd_r <= imul_rd_i;
        end
      end

      if (~stall_fpu2_i) begin
        fpu2_rd_r <= fpu1_rd_r;
      end
    end
  end


  // fpu_float_aux pipeline
  logic [1:0] aux_v_r;
  logic [1:0][recoded_data_width_lp-1:0] aux_result_r;
  fflags_s [1:0] aux_fflags_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      aux_v_r <= '0;
    end
    else begin
      if (~stall_fpu1_i) begin
        aux_v_r[0] <= aux_v_lo;
        if (aux_v_lo) begin
          aux_result_r[0] <= aux_result_lo;
          aux_fflags_r[0] <= aux_fflags_lo;
        end
      end

      if (~stall_fpu2_i) begin
        aux_v_r[1] <= aux_v_r[0];
        if (aux_v_r[0]) begin
          aux_result_r[1] <= aux_result_r[0];
          aux_fflags_r[1] <= aux_fflags_r[0];
        end
      end
    end
  end


  // FPU1 output
  assign fpu1_v_r_o= fma1_v_lo | aux_v_r[0];
  assign fpu1_rd_o = fpu1_rd_r;
  assign imul_rd_o = fpu1_rd_r;


  // FPU2 output
  always_comb begin
    fp_v_o = fma2_v_lo | aux_v_r[1];
    fp_rd_o = fpu2_rd_r;
    if (fma2_v_lo) begin
      fp_result_o = fma2_result_lo;
      fp_fflags_o = fma2_fflags_lo;
    end
    else begin
      fp_result_o = aux_result_r[1];
      fp_fflags_o = aux_fflags_r[1];
    end
  end


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      assert(~(aux_v_r[0] & fma1_v_lo)) else $error("aux_v_r[0] and fma1_v_lo cannot be both 1.");
      assert(~(aux_v_r[1] & fma2_v_lo)) else $error("aux_v_r[1] and fma2_v_lo cannot be both 1.");
    end
  end
  // synopsys translate_on


  
endmodule

