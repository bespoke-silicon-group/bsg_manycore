/**
 *    vanilla_core.v
 *
 */



module vanilla_core

  import bsg_vanilla_pkg::*;
  import bsg_manycore_addr_pkg::*;

  #(parameter data_width_p="inv"
    , parameter dmem_size_p="inv"
    
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    // Enables branch & jalr target-addr stream on stderr
    , parameter branch_trace_en_p=0

    , parameter dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    , parameter reg_addr_width_lp = RV32_reg_addr_width_gp
    , parameter data_mask_width_lp=(data_width_p>>3)
  )
  (
    input clk_i
    , input reset_i

    , input [pc_width_lp-1:0] pc_init_val_i

    // to network
    , output remote_req_s remote_req_o
    , output logic remote_req_v_o
    , input remote_req_yumi_i

    // from network
    , input icache_v_i
    , input [pc_width_lp-1:0] icache_pc_i
    , input [data_width_p-1:0] icache_instr_i
    , output logic icache_yumi_o
    
    , input ifetch_v_i
    , input [data_width_p-1:0] ifetch_instr_i
  
    , input remote_dmem_v_i
    , input remote_dmem_w_i
    , input [dmem_addr_width_lp-1:0] remote_dmem_addr_i
    , input [data_mask_width_lp-1:0] remote_dmem_mask_i
    , input [data_width_p-1:0] remote_dmem_data_i
    , output logic [data_width_p-1:0] remote_dmem_data_o
    , output logic remote_dmem_yumi_o

    , input [reg_addr_width_lp-1:0] float_remote_load_resp_rd_i
    , input [data_width_p-1:0] float_remote_load_resp_data_i
    , input float_remote_load_resp_v_i

    , input [reg_addr_width_lp-1:0] int_remote_load_resp_rd_i
    , input [data_width_p-1:0] int_remote_load_resp_data_i
    , input int_remote_load_resp_v_i
    , input int_remote_load_resp_force_i
    , output logic int_remote_load_resp_yumi_o

    , input outstanding_req_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // pipeline signals
  //
  id_signals_s id_r, id_n;
  exe_signals_s exe_r, exe_n;
  mem_signals_s mem_r, mem_n;
  wb_signals_s wb_r, wb_n;
  fp_exe_signals_s fp_exe_n, fp_exe_r;
  fp_wb_signals_s fp_wb_n, fp_wb_r;


  // icache
  //
  logic icache_v_li;
  logic icache_w_li;

  logic [pc_width_lp-1:0] icache_w_pc;
  logic [data_width_p-1:0] icache_winstr;

  logic [pc_width_lp-1:0] pc_n, pc_r;
  instruction_s instruction;
  logic icache_miss;
  logic icache_flush;

  logic [pc_width_lp-1:0] jalr_prediction; 
  logic [pc_width_lp-1:0] pred_or_jump_addr; 
 
 
  icache #(
    .icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
  ) icache0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
   
    ,.v_i(icache_v_li)
    ,.w_i(icache_w_li)
    ,.flush_i(icache_flush)

    ,.w_pc_i(icache_w_pc)
    ,.w_instr_i(icache_winstr)

    ,.pc_i(pc_n)
    ,.jalr_prediction_i(jalr_prediction)

    ,.instr_o(instruction)
    ,.pred_or_jump_addr_o(pred_or_jump_addr)
    ,.pc_r_o(pc_r)
    ,.icache_miss_o(icache_miss)
  );

  logic [pc_width_lp-1:0] pc_plus4;
  assign pc_plus4 = pc_r + 1'b1;
  // synopsys translate_off
  logic [data_width_p-1:0] pc_00;
  assign pc_00 = {1'b1,{(data_width_p-pc_width_lp-3){1'b0}}, pc_r, 2'b00};
  // synopsys translate_on
  

  // instruction decode
  //
  decode_s decode;
  fp_float_decode_s fp_float_decode;
  fp_int_decode_s fp_int_decode;

  cl_decode decode0 (
    .instruction_i(instruction)
    ,.decode_o(decode)
    ,.fp_float_decode_o(fp_float_decode)
    ,.fp_int_decode_o(fp_int_decode)
  ); 


  //                          //
  //        ID STAGE          //
  //                          //


  bsg_dff_reset #(
    .width_p($bits(id_signals_s))
  ) id_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(id_n)
    ,.data_o(id_r)
  );
  
  // int regfile
  //
  logic int_rf_wen;
  logic [reg_addr_width_lp-1:0] int_rf_waddr;
  logic [data_width_p-1:0] int_rf_wdata;
 
  logic int_rf_read_rs1;
  logic [data_width_p-1:0] int_rf_rs1_data;; 

  logic int_rf_read_rs2;
  logic [data_width_p-1:0] int_rf_rs2_data;; 

  regfile #(
    .width_p(data_width_p)
    ,.els_p(32)
    ,.is_float_p(0)
  ) int_rf (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.w_v_i(int_rf_wen)
    ,.w_addr_i(int_rf_waddr)
    ,.w_data_i(int_rf_wdata)

    ,.r0_v_i(int_rf_read_rs1)
    ,.r0_addr_i(instruction.rs1)
    ,.r0_data_o(int_rf_rs1_data)

    ,.r1_v_i(int_rf_read_rs2)
    ,.r1_addr_i(instruction.rs2)
    ,.r1_data_o(int_rf_rs2_data)
  );
  

  // int scoreboard
  //
  // this has two clear ports:
  // [1] remote load clear
  // [0] local load clear
  logic int_dependency;
  logic int_sb_score;
  logic [1:0] int_sb_clear;
  logic [1:0][reg_addr_width_lp-1:0] int_sb_clear_id;

  scoreboard #(
    .els_p(32)
    ,.is_float_p(0)
    ,.num_clear_port_p(2)
  ) int_sb (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.src1_id_i(id_r.instruction.rs1)
    ,.src2_id_i(id_r.instruction.rs2)
    ,.dest_id_i(id_r.instruction.rd)

    ,.op_reads_rf1_i(id_r.decode.op_reads_rf1)
    ,.op_reads_rf2_i(id_r.decode.op_reads_rf2)
    ,.op_writes_rf_i(id_r.decode.op_writes_rf)

    ,.score_i(int_sb_score)
    ,.clear_i(int_sb_clear)
    ,.clear_id_i(int_sb_clear_id)

    ,.dependency_o(int_dependency)
  );

  // FP regfile
  // f0 is not tied to zero.
  logic float_rf_wen;
  logic [reg_addr_width_lp-1:0] float_rf_waddr;
  logic [data_width_p-1:0] float_rf_wdata;
 
  logic float_rf_read_rs1;
  logic [data_width_p-1:0] float_rf_rs1_data;; 

  logic float_rf_read_rs2;
  logic [data_width_p-1:0] float_rf_rs2_data;; 

  regfile #(
    .width_p(data_width_p)
    ,.els_p(32)
    ,.is_float_p(1)
  ) float_rf (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.w_v_i(float_rf_wen)
    ,.w_addr_i(float_rf_waddr)
    ,.w_data_i(float_rf_wdata)

    ,.r0_v_i(float_rf_read_rs1)
    ,.r0_addr_i(instruction.rs1)
    ,.r0_data_o(float_rf_rs1_data)

    ,.r1_v_i(float_rf_read_rs2)
    ,.r1_addr_i(instruction.rs2)
    ,.r1_data_o(float_rf_rs2_data)
  );

  // FP scoreboard
  //
  logic float_dependency;
  logic float_sb_score;
  logic float_sb_clear;
  logic [reg_addr_width_lp-1:0] float_sb_clear_id;

  scoreboard #(
    .els_p(32)
    ,.is_float_p(1)
    ,.num_clear_port_p(1)
  ) float_sb (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.src1_id_i(id_r.instruction.rs1)
    ,.src2_id_i(id_r.instruction.rs2)
    ,.dest_id_i(id_r.instruction.rd)

    ,.op_reads_rf1_i(id_r.decode.op_reads_fp_rf1)
    ,.op_reads_rf2_i(id_r.decode.op_reads_fp_rf2)
    ,.op_writes_rf_i(id_r.decode.op_writes_fp_rf)

    ,.score_i(float_sb_score)
    ,.clear_i(float_sb_clear)
    ,.clear_id_i(float_sb_clear_id)

    ,.dependency_o(float_dependency)
  );

  // calculate mem address offset
  //

  wire is_amo_or_lr_op = id_r.decode.op_is_lr
    | id_r.decode.op_is_lr_aq
    | id_r.decode.is_amo_op;

  logic [data_width_p-1:0] mem_addr_op2;
  assign mem_addr_op2 = is_amo_or_lr_op
    ? '0
    : (id_r.decode.is_store_op
      ? `RV32_signext_Simm(id_r.instruction)
      : `RV32_signext_Iimm(id_r.instruction));


  // 'aq' register
  // When amo_op with aq is issued to EXE, 'aq' register is set.
  // While 'aq' is set, subsequent memory ops (e.g. load, store, lr, AMO) cannot be isssued, until 'aq' is cleared.
  // When the amoswap result returns and clears the scoreboard, it also clears the 'aq'.
  // Even if amoswap.w.aq has x0 as rd, 'aq' bit is set.
  // Since AMO op is only supported for remote, only remote resp can clear the 'aq'.
  logic aq_r;
  logic aq_clear;
  logic aq_set;
  logic [reg_addr_width_lp-1:0] aq_rd_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      aq_r <= 1'b0;
      aq_rd_r <= '0;
    end
    else begin
      if (aq_set) begin
        aq_r <= 1'b1;
        aq_rd_r <= id_r.instruction.rd;
      end
      else if (aq_clear) begin
        aq_r <= 1'b0;
      end
    end
  end



  //                          //
  //        EXE STAGE         //
  //                          //



  bsg_dff_reset #(
    .width_p($bits(exe_signals_s))
  ) exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(exe_n)
    ,.data_o(exe_r)
  );

  // synopsys translate_off
  logic [data_width_p-1:0] exe_pc;
  assign exe_pc = (exe_r.pc_plus4 - 'd4) | bsg_dram_npa_prefix_gp;
  // synopsys translate_on

  // EXE forwarding muxes
  //
  logic exe_rs1_forward;
  logic exe_rs2_forward;
  logic [data_width_p-1:0] exe_rs1_forward_val;
  logic [data_width_p-1:0] exe_rs2_forward_val;
  logic [data_width_p-1:0] exe_rs1_final; // post-forward rs1
  logic [data_width_p-1:0] exe_rs2_final; // post-forward rs2

  assign exe_rs1_forward = exe_r.rs1_in_mem | exe_r.rs1_in_wb;
  assign exe_rs2_forward = exe_r.rs2_in_mem | exe_r.rs2_in_wb;

  bsg_mux #(
    .width_p(data_width_p) 
    ,.els_p(2)
  ) exe_rs1_forward_val_mux (
    .data_i({mem_r.exe_result, wb_r.rf_data})
    ,.sel_i(exe_r.rs1_in_mem)
    ,.data_o(exe_rs1_forward_val)
  );

  bsg_mux #(
    .width_p(data_width_p)
    ,.els_p(2)
  ) exe_rs1_final_mux (
    .data_i({exe_rs1_forward_val, exe_r.rs1_val})
    ,.sel_i(exe_rs1_forward)
    ,.data_o(exe_rs1_final)
  );

  bsg_mux #(
    .width_p(data_width_p) 
    ,.els_p(2)
  ) exe_rs2_forward_val_mux (
    .data_i({mem_r.exe_result, wb_r.rf_data})
    ,.sel_i(exe_r.rs2_in_mem)
    ,.data_o(exe_rs2_forward_val)
  );

  bsg_mux #(
    .width_p(data_width_p)
    ,.els_p(2)
  ) exe_rs2_final_mux (
    .data_i({exe_rs2_forward_val, exe_r.rs2_val})
    ,.sel_i(exe_rs2_forward)
    ,.data_o(exe_rs2_final)
  );

  // ALU
  //
  logic [data_width_p-1:0] alu_result;
  logic [pc_width_lp-1:0] alu_jalr_addr;
  logic alu_jump_now;

  alu #(
    .pc_width_p(pc_width_lp)
  ) alu0 (
    .rs1_i(exe_rs1_final)
    ,.rs2_i(exe_rs2_final)
    ,.pc_plus4_i(exe_r.pc_plus4)
    ,.op_i(exe_r.instruction)
    ,.result_o(alu_result)
    ,.jalr_addr_o(alu_jalr_addr)
    ,.jump_now_o(alu_jump_now)
  );

  logic branch_under_predict;
  logic branch_over_predict;
  logic branch_mispredict;
  logic jalr_mispredict;

  assign branch_under_predict = alu_jump_now & ~exe_r.instruction[0]; 
  assign branch_over_predict = ~alu_jump_now & exe_r.instruction[0]; 
  assign branch_mispredict = exe_r.decode.is_branch_op & (branch_under_predict | branch_over_predict);
  assign jalr_mispredict = exe_r.decode.is_jalr_op &
    (alu_jalr_addr != exe_r.pred_or_jump_addr[2+:pc_width_lp]);

  // Compute branch/jalr target address
  logic [pc_width_lp-1:0] exe_pc_target;

  always_comb
  begin
    if (exe_r.decode.is_branch_op) begin
      exe_pc_target = branch_under_predict
        ? exe_r.pred_or_jump_addr[2+:pc_width_lp]
        : exe_r.pc_plus4[2+:pc_width_lp];
    end else
      exe_pc_target = alu_jalr_addr;
  end

  // save pc+4 of jalr/jal for predicting jalr branch target
  logic [pc_width_lp-1:0] jalr_prediction_r;

  assign jalr_prediction = (exe_r.decode.is_jal_op | exe_r.decode.is_jalr_op)
    ? exe_r.pc_plus4[2+:pc_width_lp]
    : jalr_prediction_r;

  bsg_dff_reset #(
    .width_p(pc_width_lp)
  ) jalr_pred_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(jalr_prediction)
    ,.data_o(jalr_prediction_r)
  ); 


  // FPU int
  //

  logic [data_width_p-1:0] fpu_int_result;

  fpu_int fpu_int0 (
    .a_i(exe_rs1_final)
    ,.b_i(exe_rs2_final)
    ,.fp_int_decode_i(exe_r.fp_int_decode)
    ,.result_o(fpu_int_result)
  );


  // MULDIV
  //
  logic md_v_li;
  logic md_ready_lo;
  logic md_v_lo;
  logic [data_width_p-1:0] md_result;
  logic md_yumi_li;

  imul_idiv_iterative #(
    .width_p(data_width_p)
  ) muldiv (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(md_v_li)
    ,.ready_o(md_ready_lo)

    ,.opA_i(exe_rs1_final)
    ,.opB_i(exe_rs2_final)
    ,.funct3(exe_r.instruction.funct3)

    ,.v_o(md_v_lo)
    ,.result_o(md_result)
    ,.yumi_i(md_yumi_li)
  );

  // exe result (outputs from either ALU, FPU_int, or MD)
  //
  logic [data_width_p-1:0] exe_result;

  assign exe_result = exe_r.decode.is_md_op
    ? md_result
    : (exe_r.decode.is_fp_int_op
      ? fpu_int_result
      : alu_result);

  // LSU
  //
  logic lsu_remote_req_v_lo;
  logic lsu_dmem_v_lo;
  logic lsu_dmem_w_lo;
  logic [dmem_addr_width_lp-1:0] lsu_dmem_addr_lo;
  logic [data_width_p-1:0] lsu_dmem_data_lo;
  logic [data_mask_width_lp-1:0] lsu_dmem_mask_lo;
  logic lsu_reserve_lo;
  logic [data_width_p-1:0] lsu_mem_addr_sent_lo;

  lsu #(
    .data_width_p(data_width_p)
    ,.pc_width_p(pc_width_lp)
    ,.dmem_size_p(dmem_size_p)
    ,.branch_trace_en_p(branch_trace_en_p)
  ) lsu0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.exe_decode_i(exe_r.decode)
    ,.exe_rs1_i(exe_rs1_final)
    ,.exe_rs2_i(exe_rs2_final)
    ,.exe_rd_i(exe_r.instruction.rd)
    ,.mem_offset_i(exe_r.mem_addr_op2)
    ,.pc_plus4_i(exe_r.pc_plus4)
    ,.icache_miss_i(exe_r.icache_miss)
    ,.pc_target_i(exe_pc_target)

    ,.remote_req_o(remote_req_o)
    ,.remote_req_v_o(lsu_remote_req_v_lo)

    ,.dmem_v_o(lsu_dmem_v_lo)
    ,.dmem_w_o(lsu_dmem_w_lo)
    ,.dmem_addr_o(lsu_dmem_addr_lo)
    ,.dmem_data_o(lsu_dmem_data_lo)
    ,.dmem_mask_o(lsu_dmem_mask_lo)

    ,.reserve_o(lsu_reserve_lo)
    ,.mem_addr_sent_o(lsu_mem_addr_sent_lo)
  );

  logic reserved_r;
  logic [dmem_addr_width_lp-1:0] reserved_addr_r;


  //                          //
  //        MEM STAGE         //
  //                          //


  bsg_dff_reset #(
    .width_p($bits(mem_signals_s))
  ) mem_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(mem_n)
    ,.data_o(mem_r)
  );

  logic dmem_v_li;
  logic dmem_w_li;
  logic [data_width_p-1:0] dmem_data_li;
  logic [dmem_addr_width_lp-1:0] dmem_addr_li;
  logic [data_mask_width_lp-1:0] dmem_mask_li;
  logic [data_width_p-1:0] dmem_data_lo;

  bsg_mem_1rw_sync_mask_write_byte #(
    .els_p(dmem_size_p)
    ,.data_width_p(data_width_p)
    ,.latch_last_read_p(1)
  ) dmem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(dmem_v_li)
    ,.w_i(dmem_w_li)

    ,.addr_i(dmem_addr_li)
    ,.data_i(dmem_data_li)
    ,.write_mask_i(dmem_mask_li)

    ,.data_o(dmem_data_lo)
  );

  assign remote_dmem_data_o = dmem_data_lo;

  // local load buffer
  //
  logic local_load_en;
  logic local_load_en_r;
  logic [data_width_p-1:0] local_load_data_r;

  bsg_dff_reset #(
    .width_p(1)
  ) local_load_en_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(local_load_en)
    ,.data_o(local_load_en_r)
  );

  bsg_dff_en_bypass #(
    .width_p(data_width_p)
  ) local_load_buffer (
    .clk_i(clk_i)
    ,.en_i(local_load_en_r)
    ,.data_i(dmem_data_lo)
    ,.data_o(local_load_data_r)
  );

  // local load packer
  //
  logic [data_width_p-1:0] local_load_packed_data;

  load_packer local_lp (
    .mem_data_i(local_load_data_r)
    ,.unsigned_load_i(mem_r.is_load_unsigned)
    ,.byte_load_i(mem_r.is_byte_op)
    ,.hex_load_i(mem_r.is_hex_op)
    ,.part_sel_i(mem_r.mem_addr_sent[1:0])
    ,.load_data_o(local_load_packed_data) 
  );


  //                          //
  //        WB STAGE          //
  //                          //

  
  bsg_dff_reset #(
    .width_p($bits(wb_signals_s))
  ) wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(wb_n)
    ,.data_o(wb_r)
  );


  //                          //
  //      FP EXE STAGE        //
  //                          //


  bsg_dff_reset #(
    .width_p($bits(fp_exe_signals_s))
  ) fp_exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(fp_exe_n)
    ,.data_o(fp_exe_r)
  );

  logic fpu_float_ready_lo;
  logic fpu_float_v_lo;
  logic [data_width_p-1:0] fpu_float_result_lo;
  logic [reg_addr_width_lp-1:0] fpu_float_rd_lo;
  logic fpu_float_yumi_li;

  fpu_float fpu_float0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(fp_exe_r.valid)
    ,.fp_float_decode_i(fp_exe_r.fp_float_decode)
    ,.a_i(fp_exe_r.rs1_val)
    ,.b_i(fp_exe_r.rs2_val)
    ,.rd_i(fp_exe_r.rd)
    ,.ready_o(fpu_float_ready_lo)

    ,.v_o(fpu_float_v_lo)
    ,.result_o(fpu_float_result_lo)
    ,.rd_o(fpu_float_rd_lo)
    ,.yumi_i(fpu_float_yumi_li)
  );


  //                          //
  //      FP WB  STAGE        //
  //                          //


  bsg_dff_reset #(
    .width_p($bits(fp_wb_signals_s))
  ) fp_wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(fp_wb_n)
    ,.data_o(fp_wb_r)
  );


  //                          //
  //      CONTROL LOGIC       //
  //                          //


  // stall conditions
  //
  logic stall;
  logic stall_fp;           // stall on float pipeline
  logic stall_depend;       // stall on issuing instr to either EXE or FP_EXE
  logic stall_ifetch_wait;  // stall on ifetch in MEM
  logic stall_icache_store; // stall on icache remote store
  logic stall_lr_aq;        // stall on lrw reservation
  logic stall_fence;        // stall on fence in EXE
  logic stall_md;           // stall on muldiv in EXE
  logic stall_force_wb;     // stall on force remote load wb 
  logic stall_remote_req;   // stall on sending remote request
  logic stall_local_flw;    // stall on local flw
  logic stall_amo_aq;       // memory ops stalled in ID because of 'aq' register
  logic stall_amo_rl;       // amoswap.w.rl stalled in ID because of pending remote requests.

  assign stall = stall_ifetch_wait
    | stall_icache_store
    | stall_lr_aq
    | stall_fence
    | stall_md
    | stall_force_wb
    | stall_remote_req
    | stall_local_flw;

  assign stall_lr_aq = exe_r.decode.op_is_lr_aq & reserved_r;
  assign stall_fence = exe_r.decode.is_fence_op & outstanding_req_i;
  assign stall_remote_req = remote_req_v_o & ~remote_req_yumi_i;
  assign stall_ifetch_wait = mem_r.icache_miss & ~ifetch_v_i;
  assign stall_amo_aq = aq_r & ~aq_clear &
    (id_r.decode.is_load_op | id_r.decode.is_store_op | id_r.decode.is_amo_op | id_r.decode.op_is_lr_aq | id_r.decode.op_is_lr);
  assign stall_amo_rl = id_r.decode.is_amo_op & id_r.decode.is_amo_rl & outstanding_req_i;

  // flush condition
  //
  logic flush;
  logic icache_miss_in_pipe;

  assign flush = (branch_mispredict | jalr_mispredict);
  assign icache_miss_in_pipe = id_r.icache_miss | exe_r.icache_miss
      | mem_r.icache_miss | wb_r.icache_miss;

  // next pc logic
  //
  logic reset_r;
  logic reset_down;

  bsg_dff #(.width_p(1)) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );

  assign reset_down = reset_r & ~reset_i;
  
  always_comb begin
    if (reset_down)
      pc_n = pc_init_val_i;
    else if (wb_r.icache_miss)
      pc_n = wb_r.icache_miss_pc[2+:pc_width_lp];
    else if (branch_mispredict | jalr_mispredict)
      pc_n = exe_pc_target;
    else if (decode.is_branch_op & instruction[0])
      pc_n = pred_or_jump_addr;
    else if (decode.is_jal_op | decode.is_jalr_op)
      pc_n = pred_or_jump_addr;
    else
      pc_n = pc_plus4;
  end


  //  icache ctrl logic
  //
  //  icache can be written by:
  //  1) remote store from host or another tile.
  //  2) icache miss response.
  //
  //  icache fetch gets higher priority than icache remote store.
  //  
  //  when there is an incoming icache remote store, the pipeline stalls, and
  //  allows writing into the icache.
  //
  //  PC update and icache read happen together.
  //
  //  icache can be flushed when:
  //  1) there is branch/jump mispredict.
  //  2) icache bubble in the pipeline.
  //
  //  icache can be flushed and read at the same time, and it will output the
  //  read value.
  //
  logic read_icache;

  assign read_icache = (icache_miss_in_pipe & ~flush)
    ? wb_r.icache_miss 
    : 1'b1;

  assign icache_v_li = icache_v_i | ifetch_v_i 
    | (~stall & ~stall_depend & ~stall_fp & read_icache & ~stall_amo_aq & ~stall_amo_rl);

  assign icache_w_li = icache_v_i | ifetch_v_i;

  assign icache_w_pc = ifetch_v_i
    ? mem_r.mem_addr_sent[2+:pc_width_lp]
    : icache_pc_i[0+:pc_width_lp];

  assign icache_winstr = ifetch_v_i
    ? ifetch_instr_i
    : icache_instr_i;

  assign icache_yumi_o = icache_v_i & (~ifetch_v_i);

  assign icache_flush = flush | icache_miss_in_pipe;

  assign stall_icache_store = icache_v_i & icache_yumi_o;
 
  // IF -> ID
  //
  wire stall_id = stall | stall_depend | stall_fp | stall_amo_aq | stall_amo_rl;

  always_comb begin
    if (stall_id) begin
      id_n = id_r;
    end
    else begin
      if (flush | icache_miss_in_pipe) begin
        id_n.pc_plus4 = '0;
        id_n.pred_or_jump_addr = '0;
        id_n.instruction = '0;
        id_n.decode = '0;
        id_n.fp_int_decode = '0;
        id_n.fp_float_decode = '0;
        id_n.icache_miss = 1'b0;
      end
      else if (icache_miss) begin
        // insert "icache bubble"
        id_n.pc_plus4 = {{(data_width_p-pc_width_lp-2){1'b0}}, pc_plus4, 2'b0};
        id_n.pred_or_jump_addr = '0;
        id_n.instruction = '0;
        id_n.decode = '0;
        id_n.fp_int_decode = '0;
        id_n.fp_float_decode = '0;
        id_n.icache_miss = 1'b1;
      end
      else begin
        id_n.pc_plus4 = {{(data_width_p-pc_width_lp-2){1'b0}}, pc_plus4, 2'b0};
        id_n.pred_or_jump_addr = {{(data_width_p-pc_width_lp-2){1'b0}}, pred_or_jump_addr, 2'b0};
        id_n.instruction = instruction;
        id_n.decode = decode;
        id_n.fp_int_decode = fp_int_decode;
        id_n.fp_float_decode = fp_float_decode;
        id_n.icache_miss = 1'b0;
      end
    end
  end

  // regfile read
  //
  assign int_rf_read_rs1 = id_n.decode.op_reads_rf1 & ~stall_id;
  assign int_rf_read_rs2 = id_n.decode.op_reads_rf2 & ~stall_id;
  assign float_rf_read_rs1 = id_n.decode.op_reads_fp_rf1 & ~stall_id;
  assign float_rf_read_rs2 = id_n.decode.op_reads_fp_rf2 & ~stall_id;

  // scoreboard
  //
  assign int_sb_score =
    ((id_r.decode.is_load_op & id_r.decode.op_writes_rf) | id_r.decode.is_amo_op | id_r.decode.op_is_lr | id_r.decode.op_is_lr_aq)
    & ~(flush | stall | stall_depend | stall_fp | stall_amo_rl | stall_amo_aq); // LW

  assign float_sb_score = (id_r.decode.op_writes_fp_rf)
    & ~(flush | stall | stall_depend | stall_fp | stall_amo_rl | stall_amo_aq);

  // int scoreboard clears when
  // [1] force wb, insert in exe-mem
  // [0] local load
  assign int_sb_clear[1] = (int_remote_load_resp_v_i & int_remote_load_resp_yumi_o);
  assign int_sb_clear[0] = (mem_r.local_load & mem_r.op_writes_rf & ~stall);

  assign int_sb_clear_id[1] = int_remote_load_resp_rd_i;
  assign int_sb_clear_id[0] = mem_r.rd_addr;

  assign float_sb_clear = fp_wb_r.valid;
  assign float_sb_clear_id = fp_wb_r.rd;

  assign aq_clear = int_sb_clear[1] & (int_sb_clear_id[1] == aq_rd_r);

  // stall_depend logic
  // 1. Is it float or int pipeline instruction?
  // 2. If it's float instruction, check float and integer scoreboard for dependency.
  //    If it reads integer regfile (rs1), check that rs1 does not match
  //    rd in EXE, MEM, WB, and rs1 not being cleared in integer scoreboard now. 
  // 3. If it's int instruction, check integer and float scoreboard for dependency.
  //    If it reads float regfile (rs1 or rs2), check that rs1 or rs2 does not match
  //    rd in FP_WB, and rs1 or rs2 is not being cleared in float scoreboard
  //    now.

  logic stall_depend_float;
  logic stall_depend_int;

  logic fp_float_int_rs1_in_exe;
  logic fp_float_int_rs1_in_mem;
  logic fp_float_int_rs1_in_wb;
  logic fp_float_int_rs1_clear_now;
  
  assign fp_float_int_rs1_in_exe = (id_r.instruction.rs1 == exe_r.instruction.rd)
    & exe_r.decode.op_writes_rf;

  assign fp_float_int_rs1_in_mem = (id_r.instruction.rs1 == mem_r.rd_addr)
    & mem_r.op_writes_rf;

  assign fp_float_int_rs1_in_wb = (id_r.instruction.rs1 == wb_r.rd_addr)
    & wb_r.op_writes_rf;

  assign fp_float_int_rs1_clear_now =
    ((id_r.instruction.rs1 == int_sb_clear_id[1]) & int_sb_clear[1])
    | ((id_r.instruction.rs1 == int_sb_clear_id[0]) & int_sb_clear[0]);

  assign stall_depend_float = (int_dependency | float_dependency)
    | (id_r.decode.op_reads_rf1 & (id_r.instruction.rs1 != '0)
      & (fp_float_int_rs1_in_exe
        | fp_float_int_rs1_in_mem
        | fp_float_int_rs1_in_wb
        | fp_float_int_rs1_clear_now));

  logic float_rs1_clear_now;
  logic float_rs2_clear_now;

  assign float_rs1_clear_now = id_r.decode.op_reads_fp_rf1
    & (id_r.instruction.rs1 == float_sb_clear_id)
    & float_sb_clear;
  assign float_rs2_clear_now = id_r.decode.op_reads_fp_rf2
    & (id_r.instruction.rs2 == float_sb_clear_id)
    & float_sb_clear;

  assign stall_depend_int = int_dependency | float_dependency
    | float_rs1_clear_now | float_rs2_clear_now;

  assign stall_depend = (id_r.decode.is_fp_float_op
    ? stall_depend_float
    : stall_depend_int) & ~(branch_mispredict | jalr_mispredict);


  // ID int forwarding
  //
  logic id_rs1_forward_wb;
  logic id_rs2_forward_wb;

  assign id_rs1_forward_wb = id_r.decode.op_reads_rf1
    & (id_r.instruction.rs1 == wb_r.rd_addr)
    & wb_r.op_writes_rf
    & (id_r.instruction.rs1 != '0);

  assign id_rs2_forward_wb = id_r.decode.op_reads_rf2
    & (id_r.instruction.rs2 == wb_r.rd_addr)
    & wb_r.op_writes_rf
    & (id_r.instruction.rs2 != '0);

  logic [data_width_p-1:0] rs1_to_exe;
  logic [data_width_p-1:0] rs2_to_exe;

  assign rs1_to_exe = id_r.decode.op_reads_fp_rf1
    ? float_rf_rs1_data
    : (id_rs1_forward_wb
      ? wb_r.rf_data
      : int_rf_rs1_data);

  assign rs2_to_exe = id_r.decode.op_reads_fp_rf2
    ? float_rf_rs2_data
    : (id_rs2_forward_wb
      ? wb_r.rf_data
      : int_rf_rs2_data);


  // ID -> EXE
  //
  
  logic exe_rs1_in_mem; // pre-compute EXE forwarding
  logic exe_rs2_in_mem;
  logic exe_rs1_in_wb;
  logic exe_rs2_in_wb;

  assign exe_rs1_in_mem = id_r.decode.op_reads_rf1
    & mem_n.op_writes_rf
    & (mem_n.rd_addr == id_r.instruction.rs1)
    & (mem_n.rd_addr != '0);

  assign exe_rs2_in_mem = id_r.decode.op_reads_rf2
    & mem_n.op_writes_rf
    & (mem_n.rd_addr == id_r.instruction.rs2)
    & (mem_n.rd_addr != '0);

  assign exe_rs1_in_wb = id_r.decode.op_reads_rf1
    & wb_n.op_writes_rf
    & (wb_n.rd_addr == id_r.instruction.rs1)
    & (wb_n.rd_addr != '0);

  assign exe_rs2_in_wb = id_r.decode.op_reads_rf2
    & wb_n.op_writes_rf
    & (wb_n.rd_addr == id_r.instruction.rs2)
    & (wb_n.rd_addr != '0);

  always_comb begin
    if (stall) begin
      exe_n = exe_r;
      aq_set = 1'b0;
    end
    else begin
      if (stall_depend | flush | id_r.decode.is_fp_float_op | stall_amo_aq | stall_amo_rl) begin
        exe_n = '0;
        aq_set = 1'b0;
      end
      else begin
        exe_n = '{
          pc_plus4: id_r.pc_plus4,
          pred_or_jump_addr: id_r.pred_or_jump_addr,
          instruction: id_r.instruction,
          decode: id_r.decode,
          rs1_val: rs1_to_exe,
          rs2_val: rs2_to_exe,
          mem_addr_op2: mem_addr_op2,
          rs1_in_mem: exe_rs1_in_mem,
          rs1_in_wb: exe_rs1_in_wb,
          rs2_in_mem: exe_rs2_in_mem,
          rs2_in_wb: exe_rs2_in_wb,
          icache_miss: id_r.icache_miss,
          fp_int_decode: id_r.fp_int_decode
        };

        aq_set = id_r.decode.is_amo_op & id_r.decode.is_amo_aq;
      end
    end
  end

  // MULDIV logic
  //
  logic md_sent_r, md_sent_n;

  assign stall_md = exe_r.decode.is_md_op & ~md_v_lo;
  assign md_v_li = exe_r.decode.is_md_op & ~md_sent_r;
  assign md_yumi_li = md_v_lo & ~stall;

  // making sure that md_op does not use muldiv twice.
  always_comb begin
    if (md_sent_r) begin
      md_sent_n = ~md_yumi_li;
    end
    else begin
      md_sent_n = md_v_li & md_ready_lo;
    end
  end
 
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      md_sent_r <= 1'b0;
    end
    else begin
      md_sent_r <= md_sent_n;
    end
  end

  // remote_req_o logic
  //
  assign remote_req_v_o = lsu_remote_req_v_lo & ~(stall_local_flw | stall_icache_store);
 

  // EXE -> MEM
  //

  // DMEM access arbiter
  //
  always_comb begin
    // if the pipeline is stalled, remote DMEM gets the way.
    if (stall) begin
      dmem_v_li = remote_dmem_v_i;
      dmem_w_li = remote_dmem_w_i;
      dmem_addr_li = remote_dmem_addr_i; 
      dmem_data_li = remote_dmem_data_i;
      dmem_mask_li = remote_dmem_mask_i;
      remote_dmem_yumi_o = remote_dmem_v_i;
      local_load_en = 1'b0;
    end
    else begin
      if (lsu_dmem_v_lo) begin
        dmem_v_li = 1'b1;
        dmem_w_li = lsu_dmem_w_lo;
        dmem_addr_li = lsu_dmem_addr_lo; 
        dmem_data_li = lsu_dmem_data_lo;
        dmem_mask_li = lsu_dmem_mask_lo;
        remote_dmem_yumi_o = 1'b0;
        local_load_en = ~lsu_dmem_w_lo;
      end
      else begin
        dmem_v_li = remote_dmem_v_i;
        dmem_w_li = remote_dmem_w_i;
        dmem_addr_li = remote_dmem_addr_i; 
        dmem_data_li = remote_dmem_data_i;
        dmem_mask_li = remote_dmem_mask_i;
        remote_dmem_yumi_o = remote_dmem_v_i;
        local_load_en = 1'b0;
      end
    end
  end

  wire local_load_in_exe = lsu_dmem_v_lo & ~lsu_dmem_w_lo &
    (exe_r.decode.is_load_op | exe_r.decode.op_is_lr | exe_r.decode.op_is_lr_aq) ;  
  wire remote_load_in_exe = (exe_r.decode.is_load_op | exe_r.decode.is_amo_op) & lsu_remote_req_v_lo;
  wire exe_op_writes_rf = exe_r.decode.op_writes_rf & ~remote_load_in_exe;
  wire exe_op_writes_fp_rf = exe_r.decode.op_writes_fp_rf & ~remote_load_in_exe;

  always_comb begin
    if (stall_ifetch_wait | stall_icache_store | stall_lr_aq
      | stall_fence | stall_md | stall_remote_req | stall_local_flw) begin
      // cannot insert here
      mem_n = mem_r;
      int_remote_load_resp_yumi_o = int_remote_load_resp_v_i & int_remote_load_resp_force_i;
      stall_force_wb = int_remote_load_resp_v_i & int_remote_load_resp_force_i;
    end
    else begin
      // remote_load insertable, if exe_r is not writeback.
      if (exe_op_writes_rf | exe_op_writes_fp_rf) begin
        // not insertable
        if (int_remote_load_resp_v_i & int_remote_load_resp_force_i) begin
          stall_force_wb = 1'b1;
          int_remote_load_resp_yumi_o = 1'b1;
          mem_n = mem_r;
        end 
        else begin
          mem_n = '{
            rd_addr: exe_r.instruction.rd,
            exe_result: exe_result,
            mem_addr_sent: lsu_mem_addr_sent_lo,
            op_writes_rf: exe_op_writes_rf,
            op_writes_fp_rf: exe_op_writes_fp_rf,
            is_byte_op: exe_r.decode.is_byte_op,
            is_hex_op: exe_r.decode.is_hex_op,
            is_load_unsigned: exe_r.decode.is_load_unsigned,
            local_load: local_load_in_exe,
            icache_miss: exe_r.icache_miss
          };
          int_remote_load_resp_yumi_o = 1'b0;
          stall_force_wb = 1'b0;
        end
      end
      else begin
        // insertable
        mem_n = '{
          rd_addr: int_remote_load_resp_v_i ? int_remote_load_resp_rd_i : '0,
          exe_result: int_remote_load_resp_v_i ? int_remote_load_resp_data_i : '0,
          op_writes_rf: int_remote_load_resp_v_i,
          op_writes_fp_rf: 1'b0,
          mem_addr_sent: lsu_mem_addr_sent_lo,
          is_byte_op: 1'b0,
          is_hex_op: 1'b0,
          is_load_unsigned: 1'b0,
          local_load: 1'b0,
          icache_miss: exe_r.icache_miss
        };
        int_remote_load_resp_yumi_o = int_remote_load_resp_v_i;
        stall_force_wb = 1'b0;
      end
    end
  end

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      reserved_r <= 1'b0;
      reserved_addr_r <= '0;
    end
    else begin
      if (dmem_v_li & ~dmem_w_li & lsu_reserve_lo & ~stall) begin
        reserved_r <= 1'b1;
        reserved_addr_r <= dmem_addr_li;
        // synopsys translate_off
        $display("[INFO][VCORE] making reservation. t=%0t, addr=%x", $time, dmem_addr_li);
        // synopsys translate_on
      end
      else if ((reserved_r == 1'b1)
        & dmem_v_li & dmem_w_li & (dmem_addr_li == reserved_addr_r)) begin
        reserved_r <= 1'b0;
        // synopsys translate_off
        $display("[INFO][VCORE] breaking reservation. t=%0t.", $time);
        // synopsys translate_on
      end
    end
  end


  // MEM -> WB
  //
  always_comb begin
    if (stall) begin
      wb_n = wb_r;
    end
    else begin
      wb_n = '{
        op_writes_rf: mem_r.op_writes_rf,
        rd_addr: mem_r.rd_addr,
        rf_data: mem_r.local_load ? local_load_packed_data : mem_r.exe_result,
        icache_miss: mem_r.icache_miss,
        icache_miss_pc: mem_r.mem_addr_sent
      };
    end
  end

  
  // int regfile writeback logic
  //
  always_comb begin
    if (stall_force_wb) begin
      int_rf_wen = 1'b1;
      int_rf_waddr = int_remote_load_resp_rd_i;
      int_rf_wdata = int_remote_load_resp_data_i;
    end
    else begin
      int_rf_wen = wb_r.op_writes_rf & (~stall);
      int_rf_waddr = wb_r.rd_addr;
      int_rf_wdata = wb_r.rf_data;
    end
  end 


  // FP EXE forwarding
  //
  logic [data_width_p-1:0] rs1_to_fp_exe;
  logic [data_width_p-1:0] rs2_to_fp_exe;
  logic fp_exe_rs1_forward;
  logic fp_exe_rs2_forward;

  assign fp_exe_rs1_forward = fp_wb_r.valid 
    & (fp_wb_r.rd == id_r.instruction.rs1);

  assign fp_exe_rs2_forward = fp_wb_r.valid 
    & (fp_wb_r.rd == id_r.instruction.rs2);

  assign rs1_to_fp_exe = id_r.decode.op_reads_rf1
    ? int_rf_rs1_data
    : (fp_exe_rs1_forward 
      ? fp_wb_r.wb_data
      : float_rf_rs1_data);

  assign rs2_to_fp_exe = fp_exe_rs2_forward
    ? fp_wb_r.wb_data
    : float_rf_rs2_data;


  // ID -> FP_EXE
  //
  logic fp_exe_valid;
  assign fp_exe_valid = id_r.decode.is_fp_float_op & ~(flush | stall_depend | stall);  

  always_comb begin
    if (fp_exe_r.valid) begin
      if (fpu_float_ready_lo) begin
        stall_fp = 1'b0;
        fp_exe_n = '{
          rs1_val: rs1_to_fp_exe,
          rs2_val: rs2_to_fp_exe,
          rd: id_r.instruction.rd,
          fp_float_decode: id_r.fp_float_decode,
          valid: fp_exe_valid
        };
      end
      else begin
        fp_exe_n = fp_exe_r;
        stall_fp = fp_exe_valid;
      end
    end
    else begin
      stall_fp = 1'b0;
      fp_exe_n = '{
        rs1_val: rs1_to_fp_exe,
        rs2_val: rs2_to_fp_exe,
        rd: id_r.instruction.rd,
        fp_float_decode: id_r.fp_float_decode,
        valid: fp_exe_valid
      };
    end
  end
  

  // FPU -> FP_WB
  //
  logic local_flw_valid;
  assign local_flw_valid = mem_r.op_writes_fp_rf & mem_r.local_load;

  always_comb begin
    if (float_remote_load_resp_v_i) begin
      // remote load resp
      stall_local_flw = local_flw_valid;
      fpu_float_yumi_li = 1'b0;
      fp_wb_n = '{
        wb_data: float_remote_load_resp_data_i,
        rd: float_remote_load_resp_rd_i,
        valid: 1'b1
      };
    end
    else if (local_flw_valid) begin
      // local load resp
      stall_local_flw = 1'b0;
      fpu_float_yumi_li = 1'b0;
      fp_wb_n = '{
        wb_data: local_load_data_r,
        rd: mem_r.rd_addr,
        valid: 1'b1
      };
    end
    else if (fpu_float_v_lo) begin
      // fpu_float
      stall_local_flw = 1'b0;
      fpu_float_yumi_li = 1'b1;
      fp_wb_n = '{
        wb_data: fpu_float_result_lo,
        rd: fpu_float_rd_lo,
        valid: 1'b1
      };
    end
    else begin
      // none
      stall_local_flw = 1'b0;
      fpu_float_yumi_li = 1'b0;
      fp_wb_n = '{
        wb_data: '0,
        rd: '0,
        valid: '0
      };
    end
  end


  // float regfile writeback logic (this never stalls)
  //
  assign float_rf_wen = fp_wb_r.valid;
  assign float_rf_waddr = fp_wb_r.rd;
  assign float_rf_wdata = fp_wb_r.wb_data;


endmodule
