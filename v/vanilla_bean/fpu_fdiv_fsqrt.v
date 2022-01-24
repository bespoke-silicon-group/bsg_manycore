/**
 *    fpu_fdiv_fsqrt.v
 *
 *    FDIV, FSQRT
 *
 */

`include "bsg_defines.v"
`include "HardFloat_consts.vi"
`include "HardFloat_specialize.vi"

module fpu_fdiv_fsqrt 
  import bsg_vanilla_pkg::*;
  #(exp_width_p=fpu_recoded_exp_width_gp
    ,sig_width_p=fpu_recoded_sig_width_gp
    ,reg_addr_width_p=RV32_reg_addr_width_gp
    , localparam recoded_data_width_lp=(1+exp_width_p+sig_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input v_i
    , input [reg_addr_width_p-1:0] rd_i
    , input frm_e rm_i
    , input [recoded_data_width_lp-1:0] fp_rs1_i
    , input [recoded_data_width_lp-1:0] fp_rs2_i
    , input fsqrt_i   // 0=fdiv, 1=fsqrt
    , output logic ready_o

    , output logic v_o
    , output logic [recoded_data_width_lp-1:0] result_o
    , output fflags_s fflags_o
    , output logic [reg_addr_width_p-1:0] rd_o
    , input yumi_i
  );


  logic ready_lo;
  logic v_li;
  logic v_lo;

  divSqrtRecFN_small #(
    .expWidth(exp_width_p)
    ,.sigWidth(sig_width_p)
  ) ds0 (
    .nReset(~reset_i)
    ,.clock(clk_i)
    ,.control(`flControl_default)
    ,.inReady(ready_lo)
    ,.inValid(v_li)
    ,.sqrtOp(fsqrt_i)
    ,.a(fp_rs1_i)
    ,.b(fp_rs2_i)
    ,.roundingMode(rm_i)
    ,.outValid(v_lo)    // v_lo is high for one cycle, when the compuation is finished.
    ,.sqrtOpOut()
    ,.out(result_o)
    ,.exceptionFlags(fflags_o)
  );


  typedef enum logic [1:0] {
    eIDLE,
    eBUSY,
    eDONE
  } ds_state_e;
  
  ds_state_e ds_state_n, ds_state_r;

  logic rd_en;
  bsg_dff_reset_en #(
    .width_p(reg_addr_width_p)
    ,.reset_val_p(0)
  ) rd_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(rd_en)
    ,.data_i(rd_i)
    ,.data_o(rd_o)
  );
 
  always_comb begin
    v_li = 1'b0;
    ready_o = 1'b0;
    v_o = 1'b0;
    rd_en = 1'b0;
    ds_state_n = ds_state_r;

    case (ds_state_r)

      // wait for new input
      eIDLE: begin
        ready_o = ready_lo;
        v_li = v_i;
        rd_en = ready_lo & v_i;
        ds_state_n = (ready_lo & v_i)
          ? eBUSY
          : eIDLE;
      end
  
      eBUSY: begin
        // wait for v_lo.
        if (v_lo) begin
          v_o = 1'b1;
          ds_state_n = yumi_i
            ? eIDLE
            : eDONE;
        end
      end

      // very similar to eBUSY, but we already know the output is valid.
      eDONE: begin
        v_o = 1'b1;
        ds_state_n = yumi_i
          ? eIDLE
          : eDONE;
      end

      // this should never happen.
      default: begin
        ds_state_n = eIDLE;
      end
    endcase
  end 

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      ds_state_r <= eIDLE;
    end
    else begin
      ds_state_r <= ds_state_n;
    end
  end  

endmodule

