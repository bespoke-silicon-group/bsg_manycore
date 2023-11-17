// Module defining functional coverage groups for the Next PC logic

`include "bsg_defines.sv"

module bsg_nonsynth_manycore_vanilla_core_pc_cov
  import bsg_vanilla_pkg::*;
  import bsg_manycore_addr_pkg::*;
  #(parameter icache_tag_width_p = "inv"
   ,parameter icache_entries_p = "inv"
   ,localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
   ,localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
  )
  (input clk_i

  // reset condition to initialize the PC
  ,input reset_down

  // Instruction
  ,input instruction_s instruction

  // Pipeline registers
  ,input id_signals_s  id_r
  ,input exe_signals_s exe_r
  ,input mem_ctrl_signals_s mem_ctrl_r
  ,input wb_ctrl_signals_s  wb_ctrl_r
  // Decoder output
  ,input decode_s      decode

  // Machine mode CSRs
  ,input csr_mstatus_s          mstatus_r
  ,input csr_interrupt_vector_s mie_r
  ,input csr_interrupt_vector_s mip_r

  // Interrupt ready signals
  ,input remote_interrupt_ready
  ,input trace_interrupt_ready
  ,input interrupt_ready

  // Branch signals
  ,input                    alu_jump_now
  ,input                    branch_under_predict
  ,input                    branch_over_predict
  ,input                    branch_mispredict
  ,input                    jalr_mispredict
  ,input [pc_width_lp-1:0]  alu_jalr_addr

  ,input coverage_en_i
  );

  wire take_br = decode.is_branch_op & instruction[0];
  wire take_jalr = decode.is_jal_op | decode.is_jalr_op;

  covergroup cg_pc_reset @(negedge clk_i);
    coverpoint reset_down;
  endgroup

  covergroup cg_pc_wb_icache_miss @(negedge clk_i iff ~reset_down);
    coverpoint wb_ctrl_r.icache_miss;
  endgroup

  covergroup cg_pc_interrupt_ready @(negedge clk_i);
    mstat: coverpoint mstatus_r.mie {
      bins interrupt = {1'b1};
    }
    
    // remote_interrupt_ready
    mie_rem: coverpoint mie_r.remote {
      bins rem_enable = {1'b1};
    }
    mip_rem: coverpoint mip_r.remote;
    mie_rem_x_mip_rem: cross mie_rem, mip_rem; 
    
    // trace_interrupt_ready
    mie_trac: coverpoint mie_r.trace {
      bins trac_enable = {1'b1};
    }
    mip_trac: coverpoint mip_r.trace;
    mie_trac_x_mip_trac: cross mie_trac, mip_trac;

    // interrupt_ready
    rem: coverpoint remote_interrupt_ready;
    trac: coverpoint trace_interrupt_ready;
    icache_miss: coverpoint {wb_ctrl_r.icache_miss, mem_ctrl_r.icache_miss, exe_r.icache_miss} {
      bins wb_imiss = {3'b100};
      bins mem_imiss = {3'b010};
      bins exe_imiss = {3'b001};
      bins no_imiss = {3'b000};
    }
    rem_x_trac_x_icache_miss_x_mstat: cross rem, trac, icache_miss, mstat;
  
  endgroup

  covergroup cg_pc_mret @(negedge clk_i iff ~reset_down);
    coverpoint exe_r.decode.is_mret_op;
  endgroup
   
  covergroup cg_pc_branch_mispredict @(negedge clk_i iff ~reset_down);
     
    alu_jump: coverpoint alu_jump_now;
    exe_instr0: coverpoint exe_r.instruction[0];

    // Branch mispredicts (under and over)
    alu_x_instr0: cross alu_jump, exe_instr0;

    bup: coverpoint branch_under_predict;
    bop: coverpoint branch_over_predict;
    br_op: coverpoint exe_r.decode.is_branch_op;
    bup_x_bop_x_br_op: cross bup, bop, br_op {
      // Can't simultaneously be branch under and over predict
      ignore_bins branch_cond = 
        binsof(bup) intersect {1'b1} && 
        binsof(bop) intersect {1'b1};
      // There is no meaning to branch under and over predict when it is not a branch op
      ignore_bins no_branch = 
        binsof(br_op) intersect {1'b0} &&
        (binsof(bup) intersect {1'b1} || 
        binsof(bop) intersect {1'b1});
    }
  
  endgroup

  covergroup cg_pc_jalr_mispredict @(negedge clk_i iff ~reset_down);

    jalr_op: coverpoint exe_r.decode.is_jalr_op;
    addr: coverpoint (alu_jalr_addr != exe_r.pred_or_jump_addr[2+:pc_width_lp]);

    jalr_op_x_addr: cross jalr_op, addr;

  endgroup

  covergroup cg_pc_take_jump @(negedge clk_i iff ~reset_down);

    br_op: coverpoint decode.is_branch_op;
    instr0: coverpoint instruction[0];
    jal_op: coverpoint decode.is_jal_op;
    jalr_op: coverpoint decode.is_jalr_op;

    // Jal/Jalr Op
    jal_op_x_jalr_op_x_br_op_x_instr0: cross jal_op, jalr_op, br_op, instr0 {
      // Jal and Jalr can't happen at the same time
      ignore_bins no_simul_jalr =  
        binsof(jal_op) intersect {1'b1} &&
        binsof(jalr_op) intersect {1'b1};
      // Jal and Branch can't happen at the same time
      ignore_bins no_br_and_jal =  
        binsof(jal_op) intersect {1'b1} &&
        binsof(br_op) intersect {1'b1};
      // Jalr and Branch can't happen at the same time
      ignore_bins no_br_and_jalr =  
        binsof(jalr_op) intersect {1'b1} &&
        binsof(br_op) intersect {1'b1};
      // Jal and Jalr have their lower bits equal to 1 always
      ignore_bins no_instr0_when_jal_jalr = 
        (binsof(jalr_op) intersect {1'b1} || 
        binsof(jal_op) intersect {1'b1}) && 
        binsof(instr0) intersect {1'b0};
    }
  
  endgroup

  covergroup cg_pc_conditions @(negedge clk_i);

    all_cond: coverpoint {reset_down, wb_ctrl_r.icache_miss, interrupt_ready, exe_r.decode.is_mret_op, branch_mispredict, jalr_mispredict, take_br, take_jalr} {
      bins reset = {8'h80};
      bins icache_miss = {8'h40};
      bins intr = {8'h20};
      bins mret = {8'h10};
      bins br_mispredict = {8'h08};
      bins jalr_mispredict = {8'h04};
      bins br = {8'h02};
      bins jalr = {8'h01};
      bins pc_plus4 = {8'h00};
    }

  endgroup

  initial
   begin
     if (coverage_en_i) begin
      cg_pc_reset pc_reset = new;
      cg_pc_wb_icache_miss pc_icache_miss = new;
      cg_pc_interrupt_ready pc_interrupt = new;
      cg_pc_mret pc_mret = new;
      cg_pc_branch_mispredict pc_branch_mispredict = new;
      cg_pc_jalr_mispredict pc_jalr_mispredict = new;
      cg_pc_take_jump pc_take_jump = new;
      cg_pc_conditions pc_cond = new;
     end
   end

endmodule
