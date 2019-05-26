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
  logic icache_cen;
  logic icache_wen;
  logic [icache_addr_width_lp-1:0] icache_w_addr;
  logic [icache_tag_width_p-1:0] icache_w_tag;
  logic [data_width_p-1:0] icache_w_instr;

  logic [pc_width_lp-1:0] pc_n;
  logic [pc_width_lp-1:0] pc_r
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
    ,.icache_w_addr_i(icache_w_addr)
    ,.icache_w_tag_i(icache_w_tag)
    ,.icache_w_instr_i(icache_w_instr)

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

  cl_decode (
    .instruction_i(instruction)
    ,.decode_o(decode)
    ,.fp_float_decode_o(fp_float_decode)
    ,.fp_int_decode_o(fp_int_decode)
  ); 


  //                          //
  //        ID STAGE          //
  //                          //

  id_signals_s id_r, id_n;
  logic id_flush;
  logic id_en;

  bsg_dff_reset_en #(
    .width_p($bits(id_signals_s))
  ) id_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i | id_flush)
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
  //
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

  // calcualte mem address offset
  //
  logic is_amo_op;
  logic [data_width_p-1:0] mem_addr_op2;

  assign is_amo_op = id_r.decode.op_is_load_reservation
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
  logic exe_flush;
  logic exe_en;

  bsg_dff_reset_en #(
    .width_p($bits(exe_signals_s))
  ) exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i | exe_flush)
    ,.en_i(exe_en)
    ,.data_i(exe_n)
    ,.data_o(exe_r)
  );


  // post forward values
  //
  logic [data_width_p-1:0] exe_rs1_forwarded;
  logic [data_width_p-1:0] exe_rs2_forwarded;


  // ALU
  //
  logic [data_width_p-1:0] alu_result;
  logic alu_jalr_addr;
  logic alu_jump_now;

  alu #(
    .pc_width_p(pc_width_lp)
  ) alu0 (
    .rs1_i(exe_rs1_forwarded)
    ,.rs2_i(exe_rs2_forwarded)
    ,.pc_plus4_i(exe_r.pc_plus4)
    ,.op_i(exe_r.instruction)
    ,.result_o(alu_result)
    ,.jalr_addr_o(alu_jalr_addr)
    ,.jump_now_o(alu_jump_now)
  );


  // FPU int
  //

  logic [data_width_p-1:0] fpu_int_result;

  fpu_int fpu_int0 (
    .a_i(exe_rs1_forwarded)
    ,.b_i(exe_rs2_forwarded)
    ,.fp_int_decode_i(exe_r.fp_int_decode)
    ,.result_o(fpu_int_result)
  );


  // MUL DIV
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

    ,.opA_i(exe_rs1_forwarded)
    ,.opB_i(exe_rs2_forwarded)
    ,.funct3(exe_r.instruction.funct3)

    ,.v_o(md_v_lo)
    ,.result_o(md_result)
    ,.yumi_i(md_yumi_li)
  );


  // LSU
  //
  logic lsu_remote_req_v_lo;
  logic lsu_dmem_v_lo;
  logic lsu_dmem_w_lo;
  logic [dmem_addr_width_lp-1:0] lsu_dmem_addr_lo;
  logic [data_width_p-1:0] dmem_data_lo;
  logic [data_mask_width_lp-1:0] dmem_mask_lo;
  logic lsu_reserve_lo;

  lsu #(
    .data_width_p(data_width_p)
    ,.pc_width_p(pc_width_lp)
    ,.dmem_size_p(dmem_size_p)
  ) lsu0 (
    .exe_decode_i(exe_r.decode)
    ,.exe_rs1_i(exe_rs1_forwarded)
    ,.exe_rs2_i(exe_rs2_forwarded)
    ,.exe_rd_i(exe_r.instruction.rd)
    ,.mem_offset_o(exe_r.mem_addr_op2)
    ,.icache_miss_i(exe_r.icache_miss)
    ,.pc_plus4_i(exe_r.pc_plus4)

    ,.remote_req_o(remote_req_o)
    ,.remote_req_v_o(lsu_remote_req_v_lo)

    ,.dmem_v_o(lsu_dmem_v_lo)
    ,.dmem_w_o(lsu_dmem_w_lo)
    ,.dmem_addr_o(lsu_dmem_addr_lo)
    ,.dmem_data_o(lsu_dmem_data_lo)
    ,.dmem_mask_o(lsu_dmem_mask_lo)
    ,.reserve_o(lsu_reserve_lo)
  );

  logic reserved_r;
  logic [dmem_addr_width_lp-1:0] reserve_addr_r;


  //                          //
  //        MEM STAGE         //
  //                          //


  mem_signals_s mem_r, mem_n;
  logic mem_en;

  bsg_dff_reset_en #(
    .width_p($bits(mem_signals_s))
  ) mem_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(mem_en)
    ,.data_i(mem_n)
    ,.data_o(mem_r)
  );

  logic dmem_v_li;
  logic dmem_w_li;
  logic [data_width_p-1:0] dmem_data_li;
  logic [dmem_addr_width_lp-1:0] dmem_addr_li;
  logic [data_mask_width_lp-1:0] dmem_mask_li;
  logic [data_width_p-1:0] dmem_data_lo;

  bsg_mem_1rw_sync_write_mask_byte #(
    .els_p(dmem_size_p)
    ,.data_width_p(data_width_p)
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

  //                          //
  //        WB STAGE          //
  //                          //

  wb_signals_s wb_r, wb_n;
  logic wb_en;
  
  bsg_dff_reset_en #(
    .width_p($bits(wb_signals_s))
  ) wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(wb_en)
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
  logic fp_wb_en;

  bsg_dff_reset_en #(
    .width_p($bits(fp_wb_signals_s))
  ) fp_wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(fp_wb_en)
    ,.data_i(fp_wb_n)
    ,.data_o(fp_wb_r)
  );



  //                          //
  //      CONTROL LOGIC       //
  //                          //




endmodule
