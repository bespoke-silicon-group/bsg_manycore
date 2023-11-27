`include "bsg_manycore_defines.svh"
`include "bsg_vanilla_defines.svh"
module vanilla_scoreboard_tracker
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  import vanilla_scoreboard_tracker_pkg::*;
  #(parameter `BSG_INV_PARAM(data_width_p)
    ,parameter reg_addr_width_lp=RV32_reg_addr_width_gp
    )
  (input clk_i
   ,input reset_i

   ,input flush
   ,input stall_all
   ,input stall_id

   ,input [data_width_p-1:0] rs1_val_to_exe
   ,input [RV32_Iimm_width_gp-1:0] mem_addr_op2

   ,input int_sb_clear
   ,input float_sb_clear
   ,input [reg_addr_width_lp-1:0] int_sb_clear_id
   ,input [reg_addr_width_lp-1:0] float_sb_clear_id

   ,input id_signals_s id_r
   ,input exe_signals_s exe_r
   ,input fp_exe_ctrl_signals_s fp_exe_ctrl_r

   ,input instruction_s instruction
   ,input decode_s decode

   ,output vanilla_isb_info_s [RV32_reg_els_gp-1:0] int_sb_o
   ,output vanilla_fsb_info_s [RV32_reg_els_gp-1:0] float_sb_o
   // is the load in ID sequential load?
   ,output logic is_id_seq_lw_o
   ,output logic is_id_seq_flw_o
   );

  wire [reg_addr_width_lp-1:0] if_rs1 = instruction.rs1;
  wire [reg_addr_width_lp-1:0] id_rs1 = id_r.instruction.rs1;
  wire [reg_addr_width_lp-1:0] id_rd = id_r.instruction.rd;
  wire [9:0] id_imm_plus4 = 1'b1 + mem_addr_op2[11:2];
  wire [11:0] if_load_imm = `RV32_Iimm_12extract(instruction);
  
  wire is_seq_lw  = id_r.decode.is_load_op & decode.is_load_op
                  & id_r.decode.write_rd & decode.write_rd
                  & (if_rs1 == id_rs1)
                  & (id_rd != id_rs1)
                  & ~(id_r.decode.is_byte_op | id_r.decode.is_hex_op | decode.is_byte_op | decode.is_hex_op)
                  & ((id_imm_plus4 == if_load_imm[11:2]) && (mem_addr_op2[11] | ~id_imm_plus4[9]));

  wire is_seq_flw = id_r.decode.is_load_op & decode.is_load_op
                  & id_r.decode.write_frd & decode.write_frd
                  & ((id_imm_plus4 == if_load_imm[11:2]) && (mem_addr_op2[11] | ~id_imm_plus4[9]));

  assign is_id_seq_lw_o = is_seq_lw;
  assign is_id_seq_flw_o = is_seq_flw;

  wire [data_width_p-1:0] id_mem_addr = rs1_val_to_exe + `BSG_SIGN_EXTEND(mem_addr_op2,data_width_p);
  wire remote_ld_dram_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd & ~is_seq_lw)) & id_mem_addr[data_width_p-1];
  wire remote_seq_ld_dram_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd & is_seq_lw)) & id_mem_addr[data_width_p-1];
  wire remote_amo_dram_in_id = (id_r.decode.write_rd & id_r.decode.is_amo_op) & id_mem_addr[data_width_p-1];
  wire remote_ld_global_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd)) & (id_mem_addr[data_width_p-1-:2] == 2'b01);
  wire remote_ld_group_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd)) & (id_mem_addr[data_width_p-1-:3] == 3'b001);

  wire remote_flw_dram_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd & ~is_seq_flw) & id_mem_addr[data_width_p-1];
  wire remote_seq_flw_dram_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd & is_seq_flw) & id_mem_addr[data_width_p-1];
  wire remote_flw_global_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd) & (id_mem_addr[data_width_p-1-:2] == 2'b01);
  wire remote_flw_group_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd) & (id_mem_addr[data_width_p-1-:3] == 3'b001);



  // remote/local scoreboard tracking
  vanilla_isb_info_s [RV32_reg_els_gp-1:0] int_sb_r;
  vanilla_fsb_info_s [RV32_reg_els_gp-1:0] float_sb_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      int_sb_r <= '0;
      float_sb_r <= '0;
    end
    else begin

      // int sb
      for (integer i = 0; i < RV32_reg_els_gp; i++) begin
        // idiv
        if (~stall_id & ~stall_all & ~flush & id_r.decode.is_idiv_op & (id_rd == i)) begin
          int_sb_r[i].idiv <= 1'b1;
        end
        else if (int_sb_clear & (int_sb_clear_id == i)) begin
          int_sb_r[i].idiv <= 1'b0;
        end
        // remote ld dram
        if (~stall_id & ~stall_all & ~flush & remote_ld_dram_in_id & (id_rd == i)) begin
          int_sb_r[i].remote_dram_load <= 1'b1;
        end
        else if (int_sb_clear & (int_sb_clear_id == i)) begin
          int_sb_r[i].remote_dram_load <= 1'b0;
        end
        // remote ld global
        if (~stall_id & ~stall_all & ~flush & remote_ld_global_in_id & (id_rd == i)) begin
          int_sb_r[i].remote_global_load <= 1'b1;
        end
        else if (int_sb_clear & (int_sb_clear_id == i)) begin
          int_sb_r[i].remote_global_load <= 1'b0;
        end
        // remote ld group
        if (~stall_id & ~stall_all & ~flush & remote_ld_group_in_id & (id_rd == i)) begin
          int_sb_r[i].remote_group_load <= 1'b1;
        end
        else if (int_sb_clear & (int_sb_clear_id == i)) begin
          int_sb_r[i].remote_group_load <= 1'b0;
        end
        // remote amo dram
        if (~stall_id & ~stall_all & ~flush & remote_amo_dram_in_id & (id_rd == i)) begin
          int_sb_r[i].remote_dram_amo <= 1'b1;
        end
        else if (int_sb_clear & (int_sb_clear_id == i)) begin
          int_sb_r[i].remote_dram_amo <= 1'b0;
        end
        // remote seq ld dram
        if (~stall_id & ~stall_all & ~flush & remote_seq_ld_dram_in_id & (id_rd == i)) begin
          int_sb_r[i].remote_dram_seq_load <= 1'b1;
        end
        else if (int_sb_clear & (int_sb_clear_id == i)) begin
          int_sb_r[i].remote_dram_seq_load <= 1'b0;
        end
      end

      // float sb
      for (integer i = 0; i < RV32_reg_els_gp; i++) begin
        // fdiv, fsqrt
        if (~stall_id & ~stall_all & ~flush & (id_r.decode.is_fp_op & (id_r.fp_decode.is_fdiv_op | id_r.fp_decode.is_fsqrt_op)) & (id_rd == i)) begin
          float_sb_r[i].fdiv_fsqrt <= 1'b1;
        end
        else if (float_sb_clear & (float_sb_clear_id == i)) begin
          float_sb_r[i].fdiv_fsqrt <= 1'b0;
        end
        // remote flw dram
        if (~stall_id & ~stall_all & ~flush & remote_flw_dram_in_id & (id_rd == i)) begin
          float_sb_r[i].remote_dram_load <= 1'b1;
        end
        else if (float_sb_clear & (float_sb_clear_id == i)) begin
          float_sb_r[i].remote_dram_load <= 1'b0;
        end
        // remote flw global
        if (~stall_id & ~stall_all & ~flush & remote_flw_global_in_id & (id_rd == i)) begin
          float_sb_r[i].remote_global_load <= 1'b1;
        end
        else if (float_sb_clear & (float_sb_clear_id == i)) begin
          float_sb_r[i].remote_global_load <= 1'b0;
        end
        // remote flw group
        if (~stall_id & ~stall_all & ~flush & remote_flw_group_in_id & (id_rd == i)) begin
          float_sb_r[i].remote_group_load <= 1'b1;
        end
        else if (float_sb_clear & (float_sb_clear_id == i)) begin
          float_sb_r[i].remote_group_load <= 1'b0;
        end
        // remote seq flw dram
        if (~stall_id & ~stall_all & ~flush & remote_seq_flw_dram_in_id & (id_rd == i)) begin
          float_sb_r[i].remote_dram_seq_load <= 1'b1;
        end
        else if (float_sb_clear & (float_sb_clear_id == i)) begin
          float_sb_r[i].remote_dram_seq_load <= 1'b0;
        end
      end

    end
  end

  assign int_sb_o = int_sb_r;
  assign float_sb_o = float_sb_r;
endmodule // vanilla_scoreboard_tracker

`BSG_ABSTRACT_MODULE(vanilla_scoreboard_tracker)
