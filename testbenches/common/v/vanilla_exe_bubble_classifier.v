`include "bsg_manycore_defines.vh"
`include "bsg_vanilla_defines.vh"
module vanilla_exe_bubble_classifier
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  import vanilla_exe_bubble_classifier_pkg::*;
  #(parameter `BSG_INV_PARAM(pc_width_p)
    ,parameter `BSG_INV_PARAM(data_width_p)
    )
  (
   input clk_i
   ,input reset_i

   ,input [data_width_p-1:0] if_pc
   ,input [data_width_p-1:0] id_pc
   ,input [data_width_p-1:0] exe_pc

   ,input flush
   ,input icache_miss
   ,input icache_miss_in_pipe
   ,input stall_all
   ,input stall_id
   ,input stall_depend_long_op
   ,input stall_depend_local_load
   ,input stall_depend_imul
   ,input stall_bypass
   ,input stall_lr_aq
   ,input stall_fence
   ,input stall_amo_aq
   ,input stall_amo_rl
   ,input stall_fdiv_busy
   ,input stall_idiv_busy
   ,input stall_fcsr
   ,input stall_remote_req
   ,input stall_remote_credit

   ,input stall_barrier

   ,input stall_remote_ld_wb
   ,input stall_ifetch_wait
   ,input stall_remote_flw_wb

   ,input branch_mispredict
   ,input jalr_mispredict

   ,input [data_width_p-1:0] rs1_val_to_exe
   ,input [RV32_Iimm_width_gp-1:0] mem_addr_op2

   ,input int_sb_clear
   ,input float_sb_clear
   ,input [RV32_reg_addr_width_gp-1:0] int_sb_clear_id
   ,input [RV32_reg_addr_width_gp-1:0] float_sb_clear_id

   ,input id_signals_s id_r
   ,input exe_signals_s exe_r
   ,input fp_exe_ctrl_signals_s fp_exe_ctrl_r

   ,output [pc_width_p-1:0] exe_bubble_pc_o
   ,output [31:0] exe_bubble_type_o
   );

  // icache miss PC tracker
  logic [data_width_p-1:0] icache_miss_pc_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      icache_miss_pc_r <= '0;
    end
    else begin
      if (icache_miss) begin
        icache_miss_pc_r <= if_pc;
      end
    end
  end

  // ID stage bubble
  typedef enum logic [31:0] {
    e_id_bubble_branch_miss,
    e_id_bubble_jalr_miss,
    e_id_bubble_icache_miss,
    e_id_no_bubble
  } id_bubble_type_e;

  id_bubble_type_e id_bubble_r;
  logic [data_width_p-1:0] id_bubble_pc_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      id_bubble_r <= e_id_no_bubble;
      id_bubble_pc_r <= '0;
    end
    else begin
      if (~stall_all) begin
        if (branch_mispredict) begin
          id_bubble_r <= e_id_bubble_branch_miss;
          id_bubble_pc_r <= exe_pc;
        end
        else if (jalr_mispredict) begin
          id_bubble_r <= e_id_bubble_jalr_miss;
          id_bubble_pc_r <= exe_pc;
        end
        else if (icache_miss_in_pipe) begin
          id_bubble_r <= e_id_bubble_icache_miss;
          id_bubble_pc_r <= icache_miss_pc_r;
        end
        else begin
          id_bubble_r <= e_id_no_bubble;
          id_bubble_pc_r <= '0;
        end
      end
    end
  end

  // EXE stage bubble
  exe_bubble_type_e exe_bubble_r;
  logic [data_width_p-1:0] exe_bubble_pc_r;

  logic [RV32_reg_els_gp-1:0][3:0] int_sb;
  logic [RV32_reg_els_gp-1:0][3:0] float_sb;

  vanilla_scoreboard_tracker
    #(.data_width_p(data_width_p))
  sb_tracker
    (.*
     ,.int_sb_o(int_sb)
     ,.float_sb_o(float_sb)
     );

  wire stall_depend_group_load = stall_depend_long_op
       & ((id_r.decode.read_rs1 & int_sb[id_r.instruction.rs1][0]) |
          (id_r.decode.read_rs2 & int_sb[id_r.instruction.rs2][0]) |
          (id_r.decode.write_rd & int_sb[id_r.instruction.rd][0]) |
          (id_r.decode.read_frs1 & float_sb[id_r.instruction.rs1][0]) |
          (id_r.decode.read_frs2 & float_sb[id_r.instruction.rs2][0]) |
          (id_r.decode.write_frd & float_sb[id_r.instruction.rd][0]));

  wire stall_depend_global_load = stall_depend_long_op
       & ((id_r.decode.read_rs1 & int_sb[id_r.instruction.rs1][1]) |
          (id_r.decode.read_rs2 & int_sb[id_r.instruction.rs2][1]) |
          (id_r.decode.write_rd & int_sb[id_r.instruction.rd][1]) |
          (id_r.decode.read_frs1 & float_sb[id_r.instruction.rs1][1]) |
          (id_r.decode.read_frs2 & float_sb[id_r.instruction.rs2][1]) |
          (id_r.decode.write_frd & float_sb[id_r.instruction.rd][1]));

  wire stall_depend_dram_load = stall_depend_long_op
       & ((id_r.decode.read_rs1 & int_sb[id_r.instruction.rs1][2]) |
          (id_r.decode.read_rs2 & int_sb[id_r.instruction.rs2][2]) |
          (id_r.decode.write_rd & int_sb[id_r.instruction.rd][2]) |
          (id_r.decode.read_frs1 & float_sb[id_r.instruction.rs1][2]) |
          (id_r.decode.read_frs2 & float_sb[id_r.instruction.rs2][2]) |
          (id_r.decode.write_frd & float_sb[id_r.instruction.rd][2]));

  wire stall_depend_idiv = stall_depend_long_op
       & ((id_r.decode.read_rs1 & int_sb[id_r.instruction.rs1][3]) |
          (id_r.decode.read_rs2 & int_sb[id_r.instruction.rs2][3]) |
          (id_r.decode.write_rd & int_sb[id_r.instruction.rd][3]));

  wire stall_depend_fdiv = stall_depend_long_op
       & ((id_r.decode.read_frs1 & float_sb[id_r.instruction.rs1][3]) |
          (id_r.decode.read_frs2 & float_sb[id_r.instruction.rs2][3]) |
          (id_r.decode.write_frd & float_sb[id_r.instruction.rd][3]));

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      exe_bubble_r <= e_exe_no_bubble;
      exe_bubble_pc_r <= '0;
    end
    else begin
      if (~stall_all) begin
        if (branch_mispredict) begin
          exe_bubble_r <= e_exe_bubble_branch_miss;
          exe_bubble_pc_r <= exe_pc;
        end
        else if (jalr_mispredict) begin
          exe_bubble_r <= e_exe_bubble_jalr_miss;
          exe_bubble_pc_r <= exe_pc;
        end
        else if (id_bubble_r == e_id_bubble_branch_miss) begin
          exe_bubble_r <= e_exe_bubble_branch_miss;
          exe_bubble_pc_r <= id_bubble_pc_r;
        end
        else if (id_bubble_r == e_id_bubble_jalr_miss) begin
          exe_bubble_r <= e_exe_bubble_jalr_miss;
          exe_bubble_pc_r <= id_bubble_pc_r;
        end
        else if (id_bubble_r == e_id_bubble_icache_miss) begin
          exe_bubble_r <= e_exe_bubble_icache_miss;
          exe_bubble_pc_r <= id_bubble_pc_r;
        end
        else if (stall_depend_dram_load) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_dram;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_depend_group_load) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_group;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_depend_global_load) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_global;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_depend_idiv) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_idiv;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_depend_fdiv) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_fdiv;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_depend_local_load) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_local_load;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_depend_imul) begin
          exe_bubble_r <= e_exe_bubble_stall_depend_imul;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_amo_aq) begin
          exe_bubble_r <= e_exe_bubble_stall_amo_aq;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_amo_rl) begin
          exe_bubble_r <= e_exe_bubble_stall_amo_rl;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_bypass) begin
          exe_bubble_r <= e_exe_bubble_stall_bypass;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_lr_aq) begin
          exe_bubble_r <= e_exe_bubble_stall_lr_aq;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_fence) begin
          exe_bubble_r <= e_exe_bubble_stall_fence;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_remote_req) begin
          exe_bubble_r <= e_exe_bubble_stall_remote_req;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_remote_credit) begin
          exe_bubble_r <= e_exe_bubble_stall_remote_credit;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_fdiv_busy) begin
          exe_bubble_r <= e_exe_bubble_stall_fdiv_busy;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_idiv_busy) begin
          exe_bubble_r <= e_exe_bubble_stall_idiv_busy;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_fcsr) begin
          exe_bubble_r <= e_exe_bubble_stall_fcsr;
          exe_bubble_pc_r <= id_pc;
        end
        else if (stall_barrier) begin
          exe_bubble_r <= e_exe_bubble_stall_barrier;
          exe_bubble_pc_r <= id_pc;
        end
        else begin
          exe_bubble_r <= e_exe_no_bubble;
          exe_bubble_pc_r <= '0;
        end
      end // if (~stall_all)
    end // else: !if(reset_i)
  end // always_ff @ (posedge clk_i)

  assign exe_bubble_type_o = exe_bubble_r;
  assign exe_bubble_pc_o = exe_bubble_pc_r;

endmodule // vanilla_exe_bubble_classifier

