// Module defining functional coverage groups for the Next PC logic

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
  ,input mem_signals_s mem_r
  ,input wb_signals_s  wb_r
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
  );

  covergroup cg_pc_reset @(negedge clk_i);
    coverpoint reset_down;
  endgroup

  covergroup cg_pc_wb_icache_miss @(negedge clk_i iff ~reset_down);
    coverpoint wb_r.icache_miss;
  endgroup

  covergroup cg_pc_interrupt_ready @(negedge clk_i iff ~reset_down & ~wb_r.icache_miss);
    coverpoint mstatus_r.mie;
    
    // remote_interrupt_ready
    coverpoint mie_r.remote;
    coverpoint mip_r.remote;
    cross mie_r.remote, mip_r.remote {
      ignore_bins no_remote_interrupt = 
        binsof(mie_r.remote) intersect {1'b0};
      }
    
    // trace_interrupt_ready
    coverpoint mie_r.trace;
    coverpoint mip_r.trace;
    cross mie_r.trace, mip_r.trace {
      ignore_bins no_trace_interrupt = 
        binsof(mie_r.trace) intersect {1'b0};
      }

    // interrupt_ready
    rem: coverpoint remote_interrupt_ready;
    trac: coverpoint trace_interrupt_ready;
    exe_icache: coverpoint exe_r.icache_miss;
    mem_icache: coverpoint mem_r.icache_miss;
    wb_icache: coverpoint wb_r.icache_miss;
    cross rem, trac, exe_icache, mem_icache, wb_icache, mstatus_r.mie {
      ignore_bins no_interrupts = 
        binsof(mstatus_r.mie) intersect {1'b0};
      bins icache_miss = 
        binsof(exe_icache) intersect {1'b1} && binsof(mem_icache) intersect {1'b0} && binsof(wb_icache) intersect {1'b0} ||
        binsof(exe_icache) intersect {1'b0} && binsof(mem_icache) intersect {1'b1} && binsof(wb_icache) intersect {1'b0} ||
        binsof(exe_icache) intersect {1'b0} && binsof(mem_icache) intersect {1'b0} && binsof(wb_icache) intersect {1'b1} ||
        binsof(exe_icache) intersect {1'b0} && binsof(mem_icache) intersect {1'b0} && binsof(wb_icache) intersect {1'b0};
    }
  
  endgroup

  covergroup cg_pc_mret @(negedge clk_i iff ~reset_down & ~wb_r.icache_miss & ~interrupt_ready);
    coverpoint exe_r.decode.is_mret_op;
  endgroup
   
  covergroup cg_pc_branch_mispredict @(negedge clk_i iff ~reset_down & ~wb_r.icache_miss & ~interrupt_ready & exe_r.decode.is_mret_op);
     
    alu_jump: coverpoint alu_jump_now;
    exe_instr0: coverpoint exe_r.instruction[0];

    // Branch mispredicts (under and over)
    cross alu_jump, exe_instr0;

    bup: coverpoint branch_under_predict;
    bop: coverpoint branch_over_predict;
    br_op: coverpoint exe_r.decode.is_branch_op;
    cross bup, bop, br_op {
      ignore_bins branch_cond = 
        binsof(bup) intersect {1'b1} &&
        binsof(bop) intersect {1'b1};
    }
  
  endgroup

  covergroup cg_pc_jalr_mispredict @(negedge clk_i iff ~reset_down & ~wb_r.icache_miss & ~interrupt_ready & exe_r.decode.is_mret_op & ~branch_mispredict);

    jalr_op: coverpoint exe_r.decode.is_jalr_op;
    addr: coverpoint (alu_jalr_addr != exe_r.pred_or_jump_addr[2+:pc_width_lp]);

    cross jalr_op, addr;

  endgroup

  covergroup cg_pc_take_jump @(negedge clk_i iff ~reset_down & ~wb_r.icache_miss & ~interrupt_ready & exe_r.decode.is_mret_op & ~branch_mispredict & ~jalr_mispredict);

    br_op: coverpoint decode.is_branch_op;
    instr0: coverpoint instruction[0];
    jal_op: coverpoint decode.is_jal_op;
    jalr_op: coverpoint decode.is_jalr_op;

    // Branch Op
    cross br_op, instr0;

    // Jal/Jalr Op
    cross jal_op, jalr_op, br_op, instr0 {
      ignore_bins jump_not_branch = 
        binsof(br_op) intersect {1'b1} &&
        binsof(instr0) intersect {1'b1};
    }
  
  endgroup

  initial
   begin
    cg_pc_reset pc_reset = new;
    cg_pc_wb_icache_miss pc_icache_miss = new;
    cg_pc_interrupt_ready pc_interrupt = new;
    cg_pc_mret pc_mret = new;
    cg_pc_branch_mispredict pc_branch_mispredict = new;
    cg_pc_jalr_mispredict pc_jalr_mispredict = new;
    cg_pc_take_jump pc_take_jump = new;
   end

endmodule