`include "bsg_manycore_defines.vh"
`include "bsg_vanilla_defines.vh"
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

   ,output [RV32_reg_els_gp-1:0][e_vanilla_isb_n-1:0] int_sb_o
   ,output [RV32_reg_els_gp-1:0][e_vanilla_fsb_n-1:0] float_sb_o
   );

  // remote/local scoreboard tracking
  //
  // int_sb[3]: idiv
  // int_sb[2]: remote dram load
  // int_sb[1]: remote global load
  // int_sb[0]: remote group load
  //
  // float_sb[3]: fdiv / fsqrt
  // float_sb[2]: remote dram load
  // float_sb[1]: remote global load
  // float_sb[0]: remote group load

  logic [RV32_reg_els_gp-1:0][e_vanilla_isb_n-1:0] int_sb_r;
  logic [RV32_reg_els_gp-1:0][e_vanilla_fsb_n-1:0] float_sb_r;

  wire [data_width_p-1:0] id_mem_addr = rs1_val_to_exe + `BSG_SIGN_EXTEND(mem_addr_op2,data_width_p);
  wire remote_ld_dram_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd) | id_r.decode.is_amo_op) & id_mem_addr[data_width_p-1];
  wire remote_ld_global_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd) | id_r.decode.is_amo_op) & (id_mem_addr[data_width_p-1-:2] == 2'b01);
  wire remote_ld_group_in_id = ((id_r.decode.is_load_op & id_r.decode.write_rd) | id_r.decode.is_amo_op) & (id_mem_addr[data_width_p-1-:3] == 3'b001);

  wire remote_flw_dram_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd) & id_mem_addr[data_width_p-1];
  wire remote_flw_global_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd) & (id_mem_addr[data_width_p-1-:2] == 2'b01);
  wire remote_flw_group_in_id = (id_r.decode.is_load_op & id_r.decode.write_frd) & (id_mem_addr[data_width_p-1-:3] == 3'b001);

  wire [reg_addr_width_lp-1:0] id_rd = id_r.instruction.rd;


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      int_sb_r <= '0;
      float_sb_r <= '0;
    end
    else begin
      // int sb
      if (~stall_id & ~stall_all & ~flush) begin
        if (id_r.decode.is_idiv_op) begin
          int_sb_r[id_r.instruction.rd][e_vanilla_isb_idiv] <= 1'b1;
        end
        else if (remote_ld_dram_in_id) begin
          int_sb_r[id_r.instruction.rd][e_vanilla_isb_remote_dram_load] <= 1'b1;
        end
        else if (remote_ld_global_in_id) begin
          int_sb_r[id_r.instruction.rd][e_vanilla_isb_remote_global_load] <= 1'b1;
        end
        else if (remote_ld_group_in_id) begin
          int_sb_r[id_r.instruction.rd][e_vanilla_isb_remote_group_load] <= 1'b1;
        end
      end

      // float sb
      if (~stall_id & ~stall_all & ~flush) begin
        if (id_r.decode.is_fp_op & (id_r.fp_decode.is_fdiv_op | id_r.fp_decode.is_fsqrt_op)) begin
          float_sb_r[id_r.instruction.rd][e_vanilla_fsb_fdiv_fsqrt] <= 1'b1;
        end
        else if (remote_flw_dram_in_id) begin
          float_sb_r[id_r.instruction.rd][e_vanilla_fsb_remote_dram_load] <= 1'b1;
        end
        else if (remote_flw_global_in_id) begin
          float_sb_r[id_r.instruction.rd][e_vanilla_fsb_remote_global_load] <= 1'b1;
        end
        else if (remote_flw_group_in_id) begin
          float_sb_r[id_r.instruction.rd][e_vanilla_fsb_remote_group_load] <= 1'b1;
        end
      end

      // clear scoreboards
      if (int_sb_clear) begin
        int_sb_r[int_sb_clear_id] <= '0;
      end
      if (float_sb_clear) begin
        float_sb_r[float_sb_clear_id] <= '0;
      end

    end
  end // always_ff @ (posedge clk_i)

  assign int_sb_o = int_sb_r;
  assign float_sb_o = float_sb_r;
endmodule // vanilla_scoreboard_tracker

