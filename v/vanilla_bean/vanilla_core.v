/**
 *    vanilla_core.v
 *
 */

`include "definitions.vh"
`include "parameters.vh"

module vanilla_core
  #(parameter data_width_p="inv"
    , parameter dmem_size_p="inv"
    
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    , localparam reg_addr_width_lp = RV32_reg_addr_width_gp
    , localparam data_mask_width_lp=(data_width_p>>3)
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

    , input remote_load_resp_s remote_load_resp_i
    , input remote_load_resp_v_i
    , input remote_load_resp_force_i
    , output logic remote_load_resp_yumi_o

    , input outstanding_req_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );


  // icache
  //
  logic icache_cen, icache_wen;
  logic [icache_addr_width_lp-1:0] icache_waddr;
  logic [icache_tag_width_p-1:0] icache_wtag;
  logic [data_width_p-1:0] icache_winstr;

  logic [pc_width_lp-1:0] pc_n, pc_r;
  logic pc_wen;
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
    
    ,.icache_cen_i(icache_cen)
    ,.icache_wen_i(icache_wen)
    ,.icache_w_addr_i(icache_waddr)
    ,.icache_w_tag_i(icache_wtag)
    ,.icache_w_instr_i(icache_winstr)

    ,.pc_i(pc_n)
    ,.pc_wen_i(pc_wen)
    ,.pc_r_o(pc_r)
    ,.icache_miss_o(icache_miss)
    ,.instruction_o(instruction)

    ,.flush_i(icache_flush)

    ,.jalr_prediction_i(jalr_prediction)
    ,.pred_or_jump_addr_o(pred_or_jump_addr)
  );

  logic [pc_width_lp-1:0] pc_plus4;
  assign pc_plus4 = pc_r + 1'b1;

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

  id_signals_s id_r, id_n;
  logic id_en;

  bsg_dff_reset_en #(
    .width_p($bits(id_signals_s))
  ) id_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(id_en)
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
  logic int_dependency;
  logic int_sb_score;
  logic int_sb_clear;
  logic [reg_addr_width_lp-1:0] int_sb_clear_id;

  scoreboard #(
    .els_p(32)
    ,.is_float_p(0)
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
  ) float_sb (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.src1_id_i(id_r.instruction.rs1)
    ,.src2_id_i(id_r.instruction.rs2)
    ,.dest_id_i(id_r.instruction.rd)

    ,.op_reads_rf1_i(id_r.decode.op_reads_rf1)
    ,.op_reads_rf2_i(id_r.decode.op_reads_rf2)
    ,.op_writes_rf_i(id_r.decode.op_writes_rf)

    ,.score_i(float_sb_score)
    ,.clear_i(float_sb_clear)
    ,.clear_id_i(float_sb_clear_id)

    ,.dependency_o(float_dependency)
  );

  // calculate mem address offset
  //
  logic is_amo_op;
  logic [data_width_p-1:0] mem_addr_op2;

  assign is_amo_op = id_r.decode.op_is_lr
    | id_r.decode.op_is_lr_aq
    | id_r.decode.op_is_swap_aq
    | id_r.decode.op_is_swap_rl;

  assign mem_addr_op2 = is_amo_op
    ? '0
    : (id_r.decode.is_store_op
      ? `RV32_signext_Simm(id_r.instruction)
      : `RV32_signext_Iimm(id_r.instruction));


  //                          //
  //        EXE STAGE         //
  //                          //


  exe_signals_s exe_r, exe_n;

  bsg_dff_reset_en #(
    .width_p($bits(exe_signals_s))
  ) exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(~stall)
    ,.data_i(exe_n)
    ,.data_o(exe_r)
  );



  // EXE forwarding muxes
  //
  logic exe_rs1_forward;
  logic exe_rs2_forward;
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
  assign jalr_mispredict = (exe_r.instruction.op == `RV32_JALR_OP) &
    (alu_jalr_addr != exe_r.pred_or_jump_addr[2+:pc_width_lp]);

  // save pc+4 of jump_op for predicting jalr branch target
  logic [pc_width_lp-1:0] jalr_prediction_r;

  assign jalr_prediction = exe_r.decode.is_jump_op
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
  logic [data_width_p-1:0] lsu_fp_remote_load_data_lo;
  logic lsu_fp_remote_load_v_lo;

  logic [data_width_p-1:0] lsu_int_remote_load_data_lo;
  logic lsu_int_remote_load_v_lo;
  logic lsu_int_remote_load_force_lo;
  logic lsu_int_remote_load_yumi_li;


  logic lsu_remote_req_v_lo;
  logic lsu_dmem_v_lo;
  logic lsu_dmem_w_lo;
  logic [dmem_addr_width_lp-1:0] lsu_dmem_addr_lo;
  logic [data_width_p-1:0] lsu_dmem_data_lo;
  logic [data_mask_width_lp-1:0] lsu_dmem_mask_lo;
  load_info_s lsu_dmem_load_info_lo;
  logic lsu_reserve_lo;
  logic [data_width_p-1:0] lsu_mem_addr_send_lo;

  lsu #(
    .data_width_p(data_width_p)
    ,.pc_width_p(pc_width_lp)
    ,.dmem_size_p(dmem_size_p)
  ) lsu0 (

    .remote_load_resp_i(remote_local_resp_i)
    ,.remote_load_resp_v_i(remote_load_resp_v_i)
    ,.remote_load_resp_force_i(remote_load_resp_force_i)
    ,.remote_load_resp_yumi_o(remote_load_resp_yumi_o)

    ,.fp_remote_load_data_o(lsu_fp_remote_load_data_lo)
    ,.fp_remote_load_v_o(lsu_fp_remote_load_v_lo)

    ,.int_remote_load_data_o(lsu_int_remote_load_data_lo)
    ,.int_remote_load_v_o(lsu_int_remote_load_v_lo)
    ,.int_remote_load_force_o(lsu_int_remote_load_force_lo)
    ,.int_remote_load_yumi_i(lsu_int_remote_load_yumi_li)

    ,.exe_decode_i(exe_r.decode)
    ,.exe_rs1_i(exe_rs1_final)
    ,.exe_rs2_i(exe_rs2_final)
    ,.exe_rd_i(exe_r.instruction.rd)
    ,.mem_offset_i(exe_r.mem_addr_op2)
    ,.pc_plus4_i(exe_r.pc_plus4)
    ,.icache_miss_i(exe_r.icache_miss)

    ,.remote_req_o(remote_req_o)
    ,.remote_req_v_o(lsu_remote_req_v_lo)

    ,.dmem_v_o(lsu_dmem_v_lo)
    ,.dmem_w_o(lsu_dmem_w_lo)
    ,.dmem_addr_o(lsu_dmem_addr_lo)
    ,.dmem_data_o(lsu_dmem_data_lo)
    ,.dmem_mask_o(lsu_dmem_mask_lo)
    ,.dmem_load_info_o(lsu_dmem_load_info_lo)

    ,.reserve_o(lsu_reserve_lo)
    ,.mem_addr_send_o(lsu_mem_addr_send_lo)
  );

  logic reserved_r, reserved_n;
  logic [dmem_addr_width_lp-1:0] reserved_addr_r, reserved_addr_n;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      reserved_r <= 1'b0;
      reserved_addr_r <= '0;
    end
    else begin
      reserved_r <= reserved_n;
      reserved_addr_r <= reserved_addr_n;
    end
  end


  //                          //
  //        MEM STAGE         //
  //                          //


  mem_signals_s mem_r, mem_n;

  bsg_dff_reset_en #(
    .width_p($bits(mem_signals_s))
  ) mem_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(~stall)
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


  // remote load handler
  //
  logic [data_width_p-1:0] fp_remote_load_data_lo;
  logic fp_remote_load_v_lo;

  logic [data_width_p-1:0] int_remote_load_data_lo;
  logic int_remote_load_v_lo;
  logic int_remote_load_force_lo;
  logic int_remote_load_yumi_li;

  remote_load_handler #(
    .data_width_p(data_width_p)
  ) rlh (
    .remote_load_resp_i(remote_load_resp_i)
    ,.remote_load_resp_v_i(remote_load_resp_v_i)
    ,.remote_load_resp_force_i(remote_load_resp_force_i)
    ,.remote_load_resp_yumi_o(remote_load_resp_yumi_o)

    ,.fp_remote_load_data_o(fp_remote_load_data_lo)
    ,.fp_remote_load_v_o(fp_remote_load_v_lo)

    ,.int_remote_load_data_o(int_remote_load_data_lo)
    ,.int_remote_load_v_o(int_remote_load_v_lo)
    ,.int_remote_load_force_o(int_remote_load_force_lo)
    ,.int_remote_load_yumi_i(int_remote_load_yumi_li)
  );


  //                          //
  //        WB STAGE          //
  //                          //


  wb_signals_s wb_r, wb_n;
  
  bsg_dff_reset_en #(
    .width_p($bits(wb_signals_s))
  ) wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(~stall)
    ,.data_i(wb_n)
    ,.data_o(wb_r)
  );


  //                          //
  //      FP EXE STAGE        //
  //                          //

  fp_exe_signals_s fp_exe_n, fp_exe_r;
  logic fp_exe_en;

  bsg_dff_reset_en #(
    .width_p($bits(fp_exe_signals_s))
  ) fp_exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(fp_exe_en)
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

  fp_wb_signals_s fp_wb_n, fp_wb_r;

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
  logic stall;              // stall integer pipeline
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

  assign stall = stall_ifetch_wait // stall the entire int pipeline
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
  assign stall_ifetch_wait = mem_r.icache_miss & ~ifetch_v_i; // ifetch and remote_load_resp cannot arrive simultaneously.

  // flush condition
  //
  logic flush;
  assign flush = (branch_mispredict | jalr_mispredict)
    | (id_r.icache_miss | exe_r.icache_miss
      | mem_r.icache_miss | wb_r.icache_miss);

  // next pc logic
  //
  logic reset_r;
  bsg_dff #(.width_p(1)) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );
  
  always_comb begin
    if (reset_r & ~reset_i) // reset went down.
      pc_n = pc_init_val_i;
    else if (wb_r.icache_miss)
      pc_n = wb_r.icache_miss_pc[2+:pc_width_lp];
    else if (branch_mispredict)
      if (branch_under_predict)
        pc_n = exe_r.pred_or_jump_addr[2+:pc_width_lp];
      else
        pc_n = exe_r.pc_plus4[2+:pc_width_lp];
    end
    else if (jalr_mispredict)
      pc_n = alu_jalr_addr;
    else if ((decode.is_branch_op & instruction[0]) | (instruction.op == `RV32_JAL_OP))
      pc_n = pred_or_jump_addr;
    else if (decode.is_jump_op)
      pc_n = pred_or_jump_addr;
    else
      pc_n = pc_plus4;
  end


  // icache ctrl
  // icache fetch gets higher priority then icache remote store.
  assign icache_cen = (~stall & ~stall_depend) | icache_v_i | ifetch_v_i;
  assign icache_wen = icache_v_i | ifetch_v_i;
  assign icache_waddr = ifetch_v_i
    ? mem_r.mem_addr_send[2+:icache_addr_width_lp]
    : icache_pc_i[0+:icache_addr_width_lp];
  assign icache_wtag = ifetch_v_i
    ? mem_r.mem_addr_send[(2+icache_addr_width_lp)+:icache_tag_width_p]
    : icache_pc_i[icache_addr_width_lp+:icache_tag_width_p];
  assign icache_winstr = ifetch_v_i
    ? ifetch_instr_i
    : icache_instr_i;
  assign icache_yumi_o = icache_v_i & (~ifetch_v_i);

  assign icache_flush = flush;

  assign pc_wen = ~(stall | stall_depend | stall_fp);

  
  // IF -> ID
  //
  always_comb begin
    id_n.pc_plus4 = {{(data_width_p-pc_width_lp-2){1'b0}}, pc_plus4, 2'b0};
    id_n.pred_or_jump_addr = {{(data_width_p-pc_width_lp-2){1'b0}}, pred_or_jump_addr, 2'b0};

    if (icache_miss) begin
      // insert "icache bubble"
      id_n.instruction = '0;
      id_n.decode = '0;
      id_n.fp_int_decode = '0;
      id_n.fp_float_decode = '0;
      id_n.icache_miss = 1'b1;
    end
    else if (flush) begin
      id_n.instruction = '0;
      id_n.decode = '0;
      id_n.fp_int_decode = '0;
      id_n.fp_float_decode = '0;
      id_n.icache_miss = 1'b0;
    end
    else begin
      id_n.instruction = instruction;
      id_n.decode = decode;
      id_n.fp_int_decode = fp_int_decode;
      id_n.fp_float_decode = fp_float_decode;
      id_n.icache_miss = 1'b0;
    end
  end

  assign id_en = ~(stall | stall_depend | stall_fp);

  // regfile read
  //
  assign int_rf_read_rs1 = id_n.decode.op_reads_rf1 & id_en;
  assign int_rf_read_rs2 = id_n.decode.op_reads_rf2 & id_en;
  assign float_rf_read_rs1 = id_n.decode.op_reads_fp_rf1 & id_en;
  assign float_rf_read_rs2 = id_n.decode.op_reads_fp_rf2 & id_en;

  // scoreboard
  //
  assign int_sb_score = (id_r.decode.is_load_op & id_r.decode.op_writes_rf)
    & ~(flush | stall | stall_depend); // LW

  assign float_sb_score = (id_r.decode.op_writes_fp_rf)
    & ~(flush | stall | stall_depend | stall_fp);

  assign int_sb_clear = (remote_load_resp_v_i & remote_load_resp_yumi_o
    & ~remote_load_resp_i.load_info.float_wb); // TODO: local load also clears

  assign int_sb_clear_id = remote_load_resp_i.load_info.reg_id; // TODO: local load reg id

  assign float_sb_clear = fp_wb_r.valid;
  assign float_sb_clear_id = fp_wb_r.rd;


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

  assign fp_float_int_rs1_clear_now = (id_r.instruction.rs1 == int_sb_clear_id)
    & int_sb_clear;

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

  assign exe_rs1_in_mem = mem_n.op_writes_rf
    & (mem_n.rd_addr == id_r.decode.rs1)
    & (men_n.rd_addr != '0);

  assign exe_rs2_in_mem = mem_n.op_writes_rf
    & (mem_n.rd_addr == id_r.decode.rs2)
    & (men_n.rd_addr != '0);

  assign exe_rs1_in_wb = wb_n.op_writes_rf
    & (wb_n.rd_addr == id_r.decode.rs1)
    & (wb_n.rd_addr != '0);

  assign exe_rs2_in_wb = wb_n.op_writes_rf
    & (wb_n.rd_addr == id_r.decode.rs2)
    & (wb_n.rd_addr != '0);

  always_comb begin
    if (stall_depend | flush | id_r.decode.is_fp_float_op) begin
      exe_n = '0;
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
        fp_int_decode: id_r.fp_int_decode,
      };
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
 

  // EXE -> MEM
  //
  logic remote_load_in_exe; // these are mutually exclusive events.
  logic remote_store_in_exe;
  logic local_load_in_exe;
  logic local_store_in_exe;
  logic icache_miss_in_exe;
  logic lr_in_exe;
  logic lr_aq_in_exe;  
  logic flw_in_exe;
  logic fsw_in_exe;

  logic remote_load_insert; // this can happen anytime.

  assign remote_load_in_exe = exe_r.decode.is_load_op & lsu_remote_req_v_lo;
  assign local_load_in_exe = exe_r.decode.is_load_op & lsu_dmem_v_lo;
  assign icache_miss_in_exe = exe_r.icache_miss & lsu_dmem_v_lo;
  assign lr_in_exe = exe_r.decode.op_is_lr & lsu_dmem_v_lo;
  assign lr_aq_in_exe = exe_r.decode.op_is_lr_aq & lsu_dmem_v_lo;

  assign remote_load_insert = 


  // local load_packer
  //
  logic [data_width_p-1:0] local_load_wb_data;

  load_packer local_load_packer (
    .mem_data_i(dmem_data_lo)
    ,.unsigned_load_i(mem_r.is_load_unsigned)
    ,.byte_load_i(mem_r.is_byte_op)
    ,.hex_load_i(mem_r.is_hex_op)
    ,.part_sel_i(mem_r.mem_addr_send[1:0])
    ,.load_data_o(local_load_wb_data)
  );


  // MEM -> WB
  //
  assign wb_n = '{
    op_writes_rf: mem_r.op_writes_rf,
    rd_addr: mem_r.rd_addr,
    rf_data: mem_r.local_load ? local_load_wb_data : mem_r.exe_result,
    icache_miss: mem_r.icache_miss,
    icache_miss_pc: mem_r.mem_addr_send
  };
  
  // int regfile writeback logic
  //
  assign stall_force_wb = remote_load_resp_v_i & remote_load_resp_force_i
    & ~exe_free_for_remote_load & ~remote_load_resp_i.load_info.float_wb;

  logic [data_width_p-1:0] force_wb_data;

  load_packer remote_load_packer (
    .mem_data_i(remote_load_resp_i.load_data)
    ,.unsigned_load_i(remote_load_resp_i.load_info.is_unsigned_op)
    ,.byte_load_i(remote_load_resp_i.load_info.is_byte_op)
    ,.hex_load_i(remote_load_resp_i.load_info.is_hex_op)
    ,.part_sel_i(remote_load_resp_i.load_info.part_sel)
    ,.load_data_o(force_wb_data)
  );

  always_comb begin
    if (stall_force_wb) begin
      int_rf_wen = 1'b1;
      int_rf_waddr = remote_load_resp_i.load_info.reg_id;
      int_rf_wdata = force_wb_data;
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

  assign fp_exe_rs1_forward = fp_wb_r.valid & 
    & (fp_wb_r.rd == id_r.instruction.rs1);

  assign fp_exe_rs2_forward = fp_wb_r.valid & 
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
  assign stall_fp = fp_exe_r.valid & ~fpu_float_ready_lo;
  assign fp_exe_en = ~(stall_fp | stall_depend);

  assign fp_exe_n = '{
    rs1_val: rs1_to_fp_exe,
    rs2_val: rs2_to_fp_exe,
    rd: id_r.instruction.rd,
    fp_float_decode: id_r.fp_float_decode,
    valid: id_r.decode.is_fp_float_op  
  };
  

  // FPU -> FP_WB
  //
  always_comb begin
    if (remote_load_resp_v_i & remote_load_resp_i.load_info.float_wb) begin
      fpu_float_yumi_li = 1'b0;
      fp_wb_n = '{
        wb_data: remote_load_resp_i.load_data,
        rd: remote_load_resp_i.load_info.reg_id,
        valid: 1'b1
      };
    end
    else if (mem_r.op_writes_fp_rf & mem_r.local_load & ~stall) begin
      fpu_float_yumi_li = 1'b0;
      fp_wb_n = '{
        wb_data: dmem_data_lo,
        rd: mem_r.rd_addr,
        valid: 1'b1
      };
    end
    else begin
      fpu_float_yumi_li = 1'b1;
      fp_wb_n = '{
        wb_data: fpu_float_result_lo,
        rd: fpu_float_rd_lo,
        valid: fpu_float_v_lo
      };
    end
  end


  // float regfile writeback logic
  //
  assign float_rf_wen = fp_wb_r.valid;
  assign float_rf_waddr = fp_wb_r.rd;
  assign float_rf_wdata = fp_wb_r.wb_data;


endmodule
