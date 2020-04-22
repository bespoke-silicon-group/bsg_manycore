module nb_waw_detector 
  import bsg_vanilla_pkg::*;
  #(parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter reg_els_lp=RV32_reg_els_gp
    , parameter instr_width_lp=RV32_instr_width_gp
  )
  (
    input clk_i
    , input reset_i

    , input [data_width_p-1:0] exe_pc
    , input remote_req_s remote_req_o
    , input remote_req_v_o
    , input remote_req_yumi_i  

    , input int_remote_load_resp_v_i
    , input int_remote_load_resp_force_i
    , input [RV32_reg_addr_width_gp-1:0] int_remote_load_resp_rd_i
    
    , input mem_signals_s mem_r
    , input wb_signals_s wb_r

    , input stall_ifetch_wait
    , input stall_icache_store
    , input stall_lr_aq
    , input stall_fence
    , input stall_md
    , input stall_remote_req
    , input stall_local_flw

    , input exe_op_writes_rf
    , input exe_op_writes_fp_rf
    
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  logic [reg_els_lp-1:0][instr_width_lp-1:0] pc_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      pc_r <= '0;
    end
    else begin
      if (remote_req_v_o & remote_req_yumi_i & ~remote_req_o.write_not_read) begin
        pc_r[remote_req_o.reg_id] <= exe_pc;
      end
    end
  end

  logic [reg_els_lp-1:0][instr_width_lp-1:0] victim_pc_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      victim_pc_r <= '0;
    end
    else begin
      if (~(stall_ifetch_wait | stall_icache_store | stall_lr_aq | stall_fence | stall_md | stall_remote_req | stall_local_flw)) begin
        if (~(exe_op_writes_rf | exe_op_writes_fp_rf)) begin
          if (int_remote_load_resp_v_i) begin
            victim_pc_r[int_remote_load_resp_rd_i] <= pc_r[int_remote_load_resp_rd_i];
          end
        end
      end

    end
  end


  logic                    stall_force_wb_error;
  logic [data_width_p-1:0] rd_addr;
  logic [data_width_p-1:0] aggressor_pc;
  logic [data_width_p-1:0] victim_pc;

  always_comb begin
    stall_force_wb_error = 1'b0;
    rd_addr              = '0;
    aggressor_pc         = '0;
    victim_pc            = '0;

    if (int_remote_load_resp_v_i & int_remote_load_resp_force_i) begin
      if (mem_r.op_writes_rf) begin
        if (int_remote_load_resp_rd_i == mem_r.rd_addr) begin
          stall_force_wb_error = 1'b1;
          rd_addr              = mem_r.rd_addr;
          aggressor_pc         = pc_r[mem_r.rd_addr];
          victim_pc            = victim_pc_r[mem_r.rd_addr];
        end
      end

      if (wb_r.op_writes_rf) begin
        if (int_remote_load_resp_rd_i == wb_r.rd_addr) begin
          stall_force_wb_error = 1'b1;
          rd_addr              = wb_r.rd_addr;
          aggressor_pc         = pc_r[wb_r.rd_addr];
          victim_pc            = victim_pc_r[wb_r.rd_addr];
        end
      end
    end
  end

  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      assert(~stall_force_wb_error)
      else $error(
        "[ERROR][VCORE] STALL_FORCE_WB WAW HAZARD !!! time=%0t, x=%0d, y=%0d, rd=x%0d, aggressor_pc=%x, victim_pc=%x.\n",
        $time, my_x_i, my_y_i, rd_addr, aggressor_pc, victim_pc,
        "This condition will trigger a hardware bug, please include a WAW software patch to avoid this scenario at the victim pc.",
        " Please refer to BSG_FIX_WAW_HAZARD macro in bsg_manycore/software/bsg_manycore_lib/bsg_manycore_patch.h for details."
      );
    end
  end

endmodule
