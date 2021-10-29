/**
 *    fp_wb_arbiter.v
 */


`include "bsg_defines.v"


module fp_wb_arbiter
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(num_banks_p)
    , parameter data_width_lp=fpu_recoded_data_width_gp
    , parameter reg_addr_width_lp=RV32_reg_addr_width_gp
    , parameter bank_reg_addr_width_lp=`BSG_SAFE_CLOG2(RV32_reg_els_gp/num_banks_p)
    , parameter lg_num_banks_lp=`BSG_SAFE_CLOG2(num_banks_p)
  )
  (
    // from flw_wb stage (local)
    input flw_wb_v_i
    , input [reg_addr_width_lp-1:0] flw_wb_rd_i
    , input [data_width_lp-1:0] flw_wb_data_i

    // from float remote response
    , input [reg_addr_width_lp-1:0] float_remote_load_resp_rd_i
    , input [data_width_lp-1:0] float_remote_load_resp_data_i
    , input float_remote_load_resp_v_i
    , input float_remote_load_resp_force_i
    , output logic float_remote_load_resp_yumi_o
    
    // from fdiv_fsqrt
    , input fdiv_fsqrt_v_i
    , input [reg_addr_width_lp-1:0] fdiv_fsqrt_rd_i
    , input [data_width_lp-1:0] fdiv_fsqrt_data_i
    , output logic fdiv_fsqrt_yumi_o

    // from fpu_float
    , input fpu_float_v_i
    , input [reg_addr_width_lp-1:0] fpu_float_rd_i
    , input [data_width_lp-1:0] fpu_float_data_i

    // to pipeline
    , output logic stall_remote_flw_wb_o

    // to float_sb
    , output logic [num_banks_p-1:0] float_sb_clear_o

    // to float_rf
    , output logic [num_banks_p-1:0] float_rf_wen_o
    , output logic [num_banks_p-1:0][bank_reg_addr_width_lp-1:0] float_rf_waddr_o
    , output logic [num_banks_p-1:0][data_width_lp-1:0] float_rf_wdata_o
  );

  // synopsys translate_off
  initial begin 
    assert(`BSG_IS_POW2(num_banks_p)) else $error("Non power-of-2 banks not supported."); // but could be using bsg_hash_bank.
  end
  // synopsys translate_on


  //    crossbar inputs order
  //    [3] fpu_float
  //    [2] fdiv_fsqrt 
  //    [1] float remote resp
  //    [0] flw_wb (local)
  logic [num_banks_p-1:0][3:0] xbar_sel;

  bsg_crossbar_o_by_i #(
    .i_els_p(4)
    ,.o_els_p(num_banks_p)
    ,.width_p(data_width_lp)
  ) xbar_data (
    .i({fpu_float_data_i, fdiv_fsqrt_data_i, float_remote_load_resp_data_i, flw_wb_data_i})
    ,.sel_oi_one_hot_i(xbar_sel)
    ,.o(float_rf_wdata_o)
  );

  logic [3:0][bank_reg_addr_width_lp-1:0] xbar_waddr_li;
  assign xbar_waddr_li[3] = bank_reg_addr_width_lp'(fpu_float_rd_i / num_banks_p);
  assign xbar_waddr_li[2] = bank_reg_addr_width_lp'(fdiv_fsqrt_rd_i / num_banks_p);
  assign xbar_waddr_li[1] = bank_reg_addr_width_lp'(float_remote_load_resp_rd_i / num_banks_p);
  assign xbar_waddr_li[0] = bank_reg_addr_width_lp'(flw_wb_rd_i / num_banks_p);

  bsg_crossbar_o_by_i #(
    .i_els_p(4)
    ,.o_els_p(num_banks_p)
    ,.width_p(bank_reg_addr_width_lp)
  ) xbar_waddr (
    .i(xbar_waddr_li)
    ,.sel_oi_one_hot_i(xbar_sel)
    ,.o(float_rf_waddr_o)
  );

  // arbitration logic
  logic [3:0][lg_num_banks_lp-1:0] target_bank_id;
  assign target_bank_id[3] = lg_num_banks_lp'(fpu_float_rd_i % num_banks_p);
  assign target_bank_id[2] = lg_num_banks_lp'(fdiv_fsqrt_rd_i % num_banks_p);
  assign target_bank_id[1] = lg_num_banks_lp'(float_remote_load_resp_rd_i % num_banks_p);
  assign target_bank_id[0] = lg_num_banks_lp'(flw_wb_rd_i % num_banks_p);

  logic [3:0] requester_v;
  assign requester_v[3] = fpu_float_v_i;
  assign requester_v[2] = fdiv_fsqrt_v_i;
  assign requester_v[1] = float_remote_load_resp_v_i;
  assign requester_v[0] = flw_wb_v_i;

  // bank selection decoder
  logic [3:0][num_banks_p-1:0] target_bank_v;

  for (genvar i = 0; i < 4; i++) begin: req
    bsg_decode_with_v #(
      .num_out_p(num_banks_p)
    ) dv0 (
      .i(target_bank_id[i])
      ,.v_i(requester_v[i])
      ,.o(target_bank_v[i])
    );
  end


  // arbitrating writeback per bank
  logic [num_banks_p-1:0] float_remote_load_resp_yumi_bank;
  logic [num_banks_p-1:0] stall_remote_flw_wb_bank;
  logic [num_banks_p-1:0] fdiv_fsqrt_yumi_bank;

  assign float_remote_load_resp_yumi_o = |float_remote_load_resp_yumi_bank;
  assign stall_remote_flw_wb_o = |stall_remote_flw_wb_bank;
  assign fdiv_fsqrt_yumi_o = |fdiv_fsqrt_yumi_bank;

  always_comb begin
    float_rf_wen_o = '0;
    xbar_sel = '0;
    float_remote_load_resp_yumi_bank = '0;
    stall_remote_flw_wb_bank = '0;
    fdiv_fsqrt_yumi_bank = '0;
    float_sb_clear_o = '0;

    for (integer i = 0; i < num_banks_p; i++) begin

      if (float_remote_load_resp_force_i & target_bank_v[1][i]) begin
        // remote load emergency writeback that occurs when the fifo is full.
        float_rf_wen_o[i] = 1'b1;
        xbar_sel[i] = 4'b0010;
        float_remote_load_resp_yumi_bank[i] = 1'b1;
        stall_remote_flw_wb_bank[i] = target_bank_v[0][i] | target_bank_v[3][i];

        float_sb_clear_o[i] = 1'b1;
      end
      else if (target_bank_v[0][i]) begin
        // local flw
        float_rf_wen_o[i] = 1'b1;
        xbar_sel[i] = 4'b0001;
      end
      else if (target_bank_v[3][i]) begin
        // fpu_float (local flw and fpu_float are mutually exclusive events)
        float_rf_wen_o[i] = 1'b1;
        xbar_sel[i] = 4'b1000;
      end
      else begin
        if (target_bank_v[2][i]) begin
          // fdiv_fsqrt
          float_rf_wen_o[i] = 1'b1;
          fdiv_fsqrt_yumi_bank[i] = 1'b1;
          xbar_sel[i] = 4'b0100;
          float_sb_clear_o[i] = 1'b1;
        end 
        else if (target_bank_v[1][i]) begin
          // non-emergency remote load
          float_rf_wen_o[i] = 1'b1;
          xbar_sel[i] = 4'b0010;
          float_remote_load_resp_yumi_bank[i] = 1'b1;
          float_sb_clear_o[i] = 1'b1;
        end
      end
    end
  end


endmodule


`BSG_ABSTRACT_MODULE(fp_wb_arbiter)
