/**
 *    exe_pipeline.v
 *
 *    This module implements a reset, clear, clock-gating logic (business logic) at a struct-field level for energy-saving.
 *
 */


`include "bsg_vanilla_defines.vh"


module exe_pipeline
  import bsg_vanilla_pkg::*;
  #(parameter data_width_p=RV32_reg_data_width_gp
  )
  (
    input clk_i
    , input reset_i
    , input en_i
    , input clear_i
    
    , input  exe_signals_s exe_i
    , output exe_signals_s exe_o
  );


  // Enable logic
  wire pc_plus4_en = en_i & (exe_i.valid | exe_i.icache_miss);
  wire pred_or_jump_addr_en = en_i & (exe_i.decode.is_branch_op | exe_i.decode.is_jal_op | exe_i.decode.is_jalr_op);
  wire instr_en = en_i;
  wire rs1_val_en = en_i & exe_i.decode.read_rs1;
  wire rs2_val_en = en_i & (exe_i.decode.read_rs2 | exe_i.decode.is_csr_op | (exe_i.decode.read_frs2 & exe_i.decode.is_store_op));
  wire mem_addr_op2_en = en_i & (exe_i.decode.is_load_op | exe_i.decode.is_store_op
                            | exe_i.decode.is_lr_op | exe_i.decode.is_lr_aq_op | exe_i.decode.is_amo_op);

  // pc_plus4 DFF
  bsg_dff_reset_en #(
    .width_p(data_width_p)
    ,.reset_val_p(0)
  ) dff_pc_plus4 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(pc_plus4_en)
    ,.data_i(exe_i.pc_plus4)
    ,.data_o(exe_o.pc_plus4)
  );
  
  // pred_or_jump_addr DFF
  bsg_dff_reset_en #(
    .width_p(data_width_p)
    ,.reset_val_p(0)
  ) dff_pred_or_jump_addr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(pred_or_jump_addr_en)
    ,.data_i(exe_i.pred_or_jump_addr)
    ,.data_o(exe_o.pred_or_jump_addr)
  );
  
  // rs1, rs2 val DFF
  bsg_dff_reset_en #(
    .width_p(data_width_p)
    ,.reset_val_p(0)
  ) rs1_val_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(rs1_val_en)
    ,.data_i(exe_i.rs1_val)
    ,.data_o(exe_o.rs1_val)
  );

  bsg_dff_reset_en #(
    .width_p(data_width_p)
    ,.reset_val_p(0)
  ) rs2_val_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(rs2_val_en)
    ,.data_i(exe_i.rs2_val)
    ,.data_o(exe_o.rs2_val)
  );

  // mem_addr_op2 DFF
  bsg_dff_reset_en #(
    .width_p(RV32_Iimm_width_gp)
    ,.reset_val_p(0)
  ) mem_addr_op2_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(mem_addr_op2_en)
    ,.data_i(exe_i.mem_addr_op2)
    ,.data_o(exe_o.mem_addr_op2)
  );

  // CONTRL FLOPS
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      exe_o.decode <= '0;
      exe_o.instruction <= '0;
      exe_o.icache_miss <= 1'b0;
      exe_o.valid <= 1'b0;
      exe_o.branch_predicted_taken <= 1'b0;
    end
    else begin
      if (en_i) begin
        exe_o.decode <= exe_i.decode;
        exe_o.instruction <= exe_i.instruction;
        exe_o.icache_miss <= exe_i.icache_miss;
        exe_o.valid <= exe_i.valid;
        exe_o.branch_predicted_taken <= exe_i.branch_predicted_taken;
      end
      else if (clear_i) begin
        exe_o.decode <= '0;
        exe_o.instruction <= '0;
        exe_o.icache_miss <= 1'b0;
        exe_o.valid <= 1'b0;
        exe_o.branch_predicted_taken <= 1'b0;
      end
    end
  end


endmodule
