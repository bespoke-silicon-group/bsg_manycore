/**
 *    vanilla_core.v
 *
 *    Link to schematic:
 *    https://docs.google.com/presentation/d/1ZeRHYhqMHJQ0mRgDTilLuWQrZF7On-Be_KNNosgeW0c/edit?usp=sharing
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

    , parameter max_out_credits_p="inv"

    // Enables branch & jalr target-addr stream on stderr
    , parameter branch_trace_en_p=0

    // For network input FIFO credit counting
      // By default, 3 credits are needed, because the round trip to get the credit back takes three cycles.
      // ID->EXE->FIFO->CREDIT.
    , parameter fwd_fifo_els_p="inv"
    , parameter lg_fwd_fifo_els_lp=`BSG_WIDTH(fwd_fifo_els_p)

    , parameter dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    , parameter reg_addr_width_lp = RV32_reg_addr_width_gp
    , parameter data_mask_width_lp=(data_width_p>>3)

    , parameter credit_counter_width_lp=$clog2(max_out_credits_p+1)

    , parameter debug_p=0
  )
  (
    input clk_i
    , input reset_i

    , input [pc_width_lp-1:0] pc_init_val_i

    // to network
    , output remote_req_s remote_req_o
    , output logic remote_req_v_o
    , input remote_req_credit_i

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
    , input float_remote_load_resp_force_i
    , output logic float_remote_load_resp_yumi_o

    , input [reg_addr_width_lp-1:0] int_remote_load_resp_rd_i
    , input [data_width_p-1:0] int_remote_load_resp_data_i
    , input int_remote_load_resp_v_i
    , input int_remote_load_resp_force_i
    , output logic int_remote_load_resp_yumi_o

    , input invalid_eva_access_i

    // remaining credits
    , input [credit_counter_width_lp-1:0] out_credits_i    

    // For debugging
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );

  // pipeline signals
  //
  id_signals_s id_r, id_n;
  exe_signals_s exe_r, exe_n;
  mem_signals_s mem_r, mem_n;
  wb_signals_s wb_r, wb_n;
  fp_exe_signals_s fp_exe_n, fp_exe_r;
  flw_wb_signals_s flw_wb_n, flw_wb_r;

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
  logic icache_flush_r_lo;

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
    ,.icache_flush_r_o(icache_flush_r_lo)
  );

  wire [pc_width_lp-1:0] pc_plus4 = pc_r + 1'b1;

  // debug pc
  // synopsys translate_off
  wire [data_width_p-1:0] if_pc = {{(data_width_p-pc_width_lp-2){1'b0}}, pc_r, 2'b00};
  wire [data_width_p-1:0] id_pc = (id_r.pc_plus4 - 'd4);
  wire [data_width_p-1:0] exe_pc = (exe_r.pc_plus4 - 'd4);
  // synopsys translate_on

  // instruction decode
  //
  decode_s decode;
  fp_decode_s fp_decode;

  cl_decode decode0 (
    .instruction_i(instruction)
    ,.decode_o(decode)
    ,.fp_decode_o(fp_decode)
  ); 


  //////////////////////////////
  //                          //
  //        ID STAGE          //
  //                          //
  //////////////////////////////

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
 
  logic [1:0] int_rf_read;
  logic [1:0][data_width_p-1:0] int_rf_rdata;

  regfile #(
    .width_p(data_width_p)
    ,.els_p(RV32_reg_els_gp)
    ,.num_rs_p(2)
    ,.x0_tied_to_zero_p(1)
  ) int_rf (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.w_v_i(int_rf_wen)
    ,.w_addr_i(int_rf_waddr)
    ,.w_data_i(int_rf_wdata)

    ,.r_v_i(int_rf_read)
    ,.r_addr_i({instruction.rs2, instruction.rs1})
    ,.r_data_o(int_rf_rdata)
  );
  

  //  int scoreboard
  //
  logic int_dependency;
  logic int_sb_score;
  logic [reg_addr_width_lp-1:0] int_sb_score_id;
  logic int_sb_clear;
  logic [reg_addr_width_lp-1:0] int_sb_clear_id;

  scoreboard #(
    .els_p(RV32_reg_els_gp)
    ,.num_src_port_p(2)
    ,.num_clear_port_p(1)
    ,.x0_tied_to_zero_p(1)
  ) int_sb (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.src_id_i({id_r.instruction.rs2, id_r.instruction.rs1})
    ,.dest_id_i(id_r.instruction.rd)

    ,.op_reads_rf_i({id_r.decode.read_rs2, id_r.decode.read_rs1})
    ,.op_writes_rf_i(id_r.decode.write_rd)

    ,.score_i(int_sb_score)
    ,.score_id_i(int_sb_score_id)

    ,.clear_i(int_sb_clear)
    ,.clear_id_i(int_sb_clear_id)

    ,.dependency_o(int_dependency)
  );


  // FP regfile
  //
  logic float_rf_wen;
  logic [reg_addr_width_lp-1:0] float_rf_waddr;
  logic [fpu_recoded_data_width_gp-1:0] float_rf_wdata;
 
  logic [2:0] float_rf_read;
  logic [2:0][fpu_recoded_data_width_gp-1:0] float_rf_rdata;

  regfile #(
    .width_p(fpu_recoded_data_width_gp)
    ,.els_p(RV32_reg_els_gp)
    ,.num_rs_p(3)
    ,.x0_tied_to_zero_p(0)
  ) float_rf (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.w_v_i(float_rf_wen)
    ,.w_addr_i(float_rf_waddr)
    ,.w_data_i(float_rf_wdata)

    ,.r_v_i(float_rf_read)
    ,.r_addr_i({instruction[31:27], instruction.rs2, instruction.rs1})
    ,.r_data_o(float_rf_rdata)
  );


  // FP scoreboard
  //
  logic float_dependency;
  logic float_sb_score;
  logic [reg_addr_width_lp-1:0] float_sb_score_id;
  logic float_sb_clear;
  logic [reg_addr_width_lp-1:0] float_sb_clear_id;

  scoreboard #(
    .els_p(RV32_reg_els_gp)
    ,.x0_tied_to_zero_p(0)
    ,.num_src_port_p(3)
    ,.num_clear_port_p(1)
  ) float_sb (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.src_id_i({id_r.instruction[31:27], id_r.instruction.rs2, id_r.instruction.rs1})
    ,.dest_id_i(id_r.instruction.rd)

    ,.op_reads_rf_i({id_r.decode.read_frs3, id_r.decode.read_frs2, id_r.decode.read_frs1})
    ,.op_writes_rf_i(id_r.decode.write_frd)

    ,.score_i(float_sb_score)
    ,.score_id_i(float_sb_score_id)

    ,.clear_i(float_sb_clear)
    ,.clear_id_i(float_sb_clear_id)

    ,.dependency_o(float_dependency)
  );

  // FCSR
  //
  logic fcsr_v_li;
  logic [2:0] fcsr_funct3_li;
  logic [reg_addr_width_lp-1:0] fcsr_rs1_li;
  fcsr_s fcsr_data_li;
  logic [11:0] fcsr_addr_li;
  fcsr_s fcsr_data_lo;
  logic [1:0] fcsr_fflags_v_li;
  fflags_s [1:0] fcsr_fflags_li;
  frm_e frm_r;

  fcsr fcsr0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.v_i(fcsr_v_li)
    ,.funct3_i(fcsr_funct3_li)
    ,.rs1_i(fcsr_rs1_li)
    ,.data_i(fcsr_data_li)
    ,.addr_i(fcsr_addr_li)
    ,.data_o(fcsr_data_lo)
    // [0] fpu_int -> MEM
    // [1] fpu_float, fdiv -> FP_WB
    ,.fflags_v_i(fcsr_fflags_v_li)
    ,.fflags_i(fcsr_fflags_li)
    ,.frm_o(frm_r)
  );


  // calculate mem address offset
  //
  wire is_amo_or_lr_op = id_r.decode.is_lr_op
    | id_r.decode.is_lr_aq_op
    | id_r.decode.is_amo_op;

  wire [data_width_p-1:0] mem_addr_op2 = is_amo_or_lr_op
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


  // FP_EXE forwarding muxes
  //
  
  // select between rs1 and frs1
  logic [fpu_recoded_data_width_gp-1:0] frs1_select_val;
  logic select_rs1_to_fp_exe;

  bsg_mux #(
    .els_p(2)
    ,.width_p(fpu_recoded_data_width_gp)
  ) frs1_select_mux (
    .data_i({{1'b0, int_rf_rdata[0]}, float_rf_rdata[0]})
    ,.sel_i(select_rs1_to_fp_exe)
    ,.data_o(frs1_select_val)
  );
  
  logic frs1_forward_v;
  logic frs2_forward_v;
  logic frs3_forward_v;
  logic [fpu_recoded_data_width_gp-1:0] frs1_to_fp_exe;
  logic [fpu_recoded_data_width_gp-1:0] frs2_to_fp_exe;
  logic [fpu_recoded_data_width_gp-1:0] frs3_to_fp_exe;

  bsg_mux #(
    .els_p(2)
    ,.width_p(fpu_recoded_data_width_gp)
  ) frs1_fwd_mux (
    .data_i({float_rf_wdata, frs1_select_val})
    ,.sel_i(frs1_forward_v)
    ,.data_o(frs1_to_fp_exe)
  );

  bsg_mux #(
    .els_p(2)
    ,.width_p(fpu_recoded_data_width_gp)
  ) frs2_fwd_mux (
    .data_i({float_rf_wdata, float_rf_rdata[1]})
    ,.sel_i(frs2_forward_v)
    ,.data_o(frs2_to_fp_exe)
  );

  bsg_mux #(
    .els_p(2)
    ,.width_p(fpu_recoded_data_width_gp)
  ) frs3_fwd_mux (
    .data_i({float_rf_wdata, float_rf_rdata[2]})
    ,.sel_i(frs3_forward_v)
    ,.data_o(frs3_to_fp_exe)
  );


  // EXE FORWARDING MUX
  logic [data_width_p-1:0] fsw_data;
  recFNToFN #(
    .expWidth(fpu_recoded_exp_width_gp)
    ,.sigWidth(fpu_recoded_sig_width_gp) 
  ) frs2_to_fn (
    .in(float_rf_rdata[1])
    ,.out(fsw_data)
  );

  logic [data_width_p-1:0] exe_result;
  logic [data_width_p-1:0] mem_result;
  logic [1:0] rs1_forward_sel;
  logic [1:0] rs2_forward_sel;
  logic [data_width_p-1:0] rs1_forward_val;
  logic [data_width_p-1:0] rs2_forward_val;
  logic rs1_forward_v;
  logic rs2_forward_v;

  bsg_mux #(
    .els_p(3)
    ,.width_p(data_width_p)
  ) exe_rs1_fwd_mux (
    .data_i({wb_r.rf_data, mem_result, exe_result})
    ,.sel_i(rs1_forward_sel)
    ,.data_o(rs1_forward_val)
  );
  
  bsg_mux #(
    .els_p(3)
    ,.width_p(data_width_p)
  ) exe_rs2_fwd_mux (
    .data_i({wb_r.rf_data, mem_result, exe_result})
    ,.sel_i(rs2_forward_sel)
    ,.data_o(rs2_forward_val)
  );

  logic [data_width_p-1:0] rs1_val_to_exe;
  logic [data_width_p-1:0] rs2_val_to_exe;

  assign rs1_val_to_exe = rs1_forward_v
    ? rs1_forward_val
    : int_rf_rdata[0];
  
  assign rs2_val_to_exe = id_r.decode.read_frs2
    ? fsw_data
    : (rs2_forward_v
      ? rs2_forward_val
      : int_rf_rdata[1]);


  //////////////////////////////
  //                          //
  //        EXE STAGE         //
  //                          //
  //////////////////////////////

  bsg_dff_reset #(
    .width_p($bits(exe_signals_s))
  ) exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(exe_n)
    ,.data_o(exe_r)
  );


  // ALU
  //
  logic [data_width_p-1:0] alu_result;
  logic [pc_width_lp-1:0] alu_jalr_addr;
  logic alu_jump_now;

  alu #(
    .pc_width_p(pc_width_lp)
  ) alu0 (
    .rs1_i(exe_r.rs1_val)
    ,.rs2_i(exe_r.rs2_val)
    ,.pc_plus4_i(exe_r.pc_plus4)
    ,.op_i(exe_r.instruction)
    ,.result_o(alu_result)
    ,.jalr_addr_o(alu_jalr_addr)
    ,.jump_now_o(alu_jump_now)
  );

  wire branch_under_predict = alu_jump_now & ~exe_r.instruction[0]; 
  wire branch_over_predict = ~alu_jump_now & exe_r.instruction[0]; 
  wire branch_mispredict = exe_r.decode.is_branch_op & (branch_under_predict | branch_over_predict);
  wire jalr_mispredict = exe_r.decode.is_jalr_op & (alu_jalr_addr != exe_r.pred_or_jump_addr[2+:pc_width_lp]);

  // Compute branch/jalr target address
  logic [pc_width_lp-1:0] exe_pc_target;

  always_comb begin
    if (exe_r.decode.is_branch_op) begin
      exe_pc_target = branch_under_predict
        ? exe_r.pred_or_jump_addr[2+:pc_width_lp]
        : exe_r.pc_plus4[2+:pc_width_lp];
    end
    else begin
      exe_pc_target = alu_jalr_addr;
    end
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

  // alu/csr result mux
  wire [data_width_p-1:0] alu_or_csr_result = exe_r.decode.is_csr_op
    ? {24'b0, exe_r.fcsr_data}
    : alu_result;


  // IDIV
  //
  logic idiv_v_li;
  logic idiv_ready_lo;
  logic idiv_v_lo;
  logic [reg_addr_width_lp-1:0] idiv_rd_lo;
  logic [data_width_p-1:0] idiv_result_lo;
  logic idiv_yumi_li;

  idiv idiv0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(idiv_v_li)
    ,.rs1_i(exe_r.rs1_val)
    ,.rs2_i(exe_r.rs2_val)
    ,.rd_i(exe_r.instruction.rd)
    ,.op_i(exe_r.decode.idiv_op)
    ,.ready_o(idiv_ready_lo)
  
    ,.v_o(idiv_v_lo)
    ,.rd_o(idiv_rd_lo)
    ,.result_o(idiv_result_lo)
    ,.yumi_i(idiv_yumi_li)
  );
  

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
    ,.exe_rs1_i(exe_r.rs1_val)
    ,.exe_rs2_i(exe_r.rs2_val)
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


  //////////////////////////////
  //                          //
  //      FP EXE STAGE        //
  //                          //
  //////////////////////////////

  bsg_dff_reset #(
    .width_p($bits(fp_exe_signals_s))
  ) fp_exe_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(fp_exe_n)
    ,.data_o(fp_exe_r)
  );

  // FPU FLOAT
  //
  logic stall_fpu1_li;
  logic stall_fpu2_li;

  logic imul_v_lo;
  logic [data_width_p-1:0] imul_result_lo;
  logic [reg_addr_width_lp-1:0] imul_rd_lo;

  logic fpu_float_v_lo;
  logic [fpu_recoded_data_width_gp-1:0] fpu_float_result_lo;
  fflags_s fpu_float_fflags_lo;
  logic [reg_addr_width_lp-1:0] fpu_float_rd_lo;

  logic fpu1_v_r;
  logic [reg_addr_width_lp-1:0] fpu1_rd_r;

  fpu_float fpu_float0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.stall_fpu1_i(stall_fpu1_li)
    ,.stall_fpu2_i(stall_fpu2_li)

    ,.imul_v_i(exe_r.decode.is_imul_op)
    ,.imul_rs1_i(exe_r.rs1_val)
    ,.imul_rs2_i(exe_r.rs2_val)
    ,.imul_rd_i(exe_r.instruction.rd)

    ,.fp_v_i(fp_exe_r.fp_decode.is_fpu_float_op)
    ,.fpu_float_op_i(fp_exe_r.fp_decode.fpu_float_op)
    ,.fp_rs1_i(fp_exe_r.rs1_val)
    ,.fp_rs2_i(fp_exe_r.rs2_val)
    ,.fp_rs3_i(fp_exe_r.rs3_val)
    ,.fp_rd_i(fp_exe_r.rd)
    ,.fp_rm_i(fp_exe_r.rm)

    ,.imul_v_o(imul_v_lo)
    ,.imul_result_o(imul_result_lo)
    ,.imul_rd_o(imul_rd_lo)

    ,.fp_v_o(fpu_float_v_lo)
    ,.fp_result_o(fpu_float_result_lo)
    ,.fp_fflags_o(fpu_float_fflags_lo)
    ,.fp_rd_o(fpu_float_rd_lo)
  
    ,.fpu1_v_r_o(fpu1_v_r)
    ,.fpu1_rd_o(fpu1_rd_r)
  );
 
  // FPU INT - computes float op that writes back to INT regfile. 
  logic [data_width_p-1:0] fpu_int_result_lo;
  fflags_s fpu_int_fflags_lo;

  fpu_int fpu_int0(
    .fp_rs1_i(fp_exe_r.rs1_val)
    ,.fp_rs2_i(fp_exe_r.rs2_val)
    ,.fpu_int_op_i(fp_exe_r.fp_decode.fpu_int_op)
    ,.fp_rm_i(fp_exe_r.rm)

    ,.result_o(fpu_int_result_lo)
    ,.fflags_o(fpu_int_fflags_lo)
  );

  // FPU div sqrt - this writes back to FP regfile.
  logic fdiv_fsqrt_v_li;
  logic fdiv_fsqrt_ready_lo;
  logic fdiv_fsqrt_v_lo;
  logic [fpu_recoded_data_width_gp-1:0] fdiv_fsqrt_result_lo;
  fflags_s fdiv_fsqrt_fflags_lo;
  logic [reg_addr_width_lp-1:0] fdiv_fsqrt_rd_lo;
  logic fdiv_fsqrt_yumi_li;

  fpu_fdiv_fsqrt fpu_fdiv_fsqrt0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(fdiv_fsqrt_v_li)
    ,.rd_i(fp_exe_r.rd)
    ,.rm_i(fp_exe_r.rm)
    ,.fp_rs1_i(fp_exe_r.rs1_val)
    ,.fp_rs2_i(fp_exe_r.rs2_val)
    ,.fsqrt_i(fp_exe_r.fp_decode.is_fsqrt_op)
    ,.ready_o(fdiv_fsqrt_ready_lo)

    ,.v_o(fdiv_fsqrt_v_lo)
    ,.result_o(fdiv_fsqrt_result_lo)
    ,.fflags_o(fdiv_fsqrt_fflags_lo)
    ,.rd_o(fdiv_fsqrt_rd_lo)
    ,.yumi_i(fdiv_fsqrt_yumi_li)
  );


  

  //////////////////////////////
  //                          //
  //        MEM STAGE         //
  //                          //
  //////////////////////////////

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

  // load reservation registers
  logic reserved_r;
  logic [dmem_addr_width_lp-1:0] reserved_addr_r;

  logic make_reserve;
  logic break_reserve;

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      reserved_r <= 1'b0;
      reserved_addr_r <= '0;
    end
    else begin
      if (make_reserve) begin
        reserved_r <= 1'b1;
        reserved_addr_r <= dmem_addr_li;
        // synopsys translate_off
        if (debug_p)
          $display("[INFO][VCORE] making reservation. t=%0t, addr=%x, x=%0d, y=%0d", $time, dmem_addr_li, global_x_i, global_y_i);
        // synopsys translate_on
      end
      else if (break_reserve) begin
        reserved_r <= 1'b0;
        // synopsys translate_off
        if (debug_p)
          $display("[INFO][VCORE] breaking reservation. t=%0t, x=%0d, y=%0d.", $time, global_x_i, global_y_i);
        // synopsys translate_on
      end
    end
  end


  //////////////////////////////
  //                          //
  //        WB STAGE          //
  //                          //
  //////////////////////////////

  bsg_dff_reset #(
    .width_p($bits(wb_signals_s))
  ) wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(wb_n)
    ,.data_o(wb_r)
  );


  //////////////////////////////
  //                          //
  //    FLW WB STAGE          //
  //                          //
  //////////////////////////////

  bsg_dff_reset #(
    .width_p($bits(flw_wb_signals_s))
  ) flw_wb_pipeline (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(flw_wb_n)
    ,.data_o(flw_wb_r)
  );

  logic select_remote_flw;
  logic [data_width_p-1:0] flw_data;
  bsg_mux #(
    .width_p(data_width_p)
    ,.els_p(2)
  ) flw_recFN_mux (
    .data_i({float_remote_load_resp_data_i, flw_wb_r.rf_data})
    ,.sel_i(select_remote_flw)
    ,.data_o(flw_data)
  );

  logic [fpu_recoded_data_width_gp-1:0] flw_recoded_data;
  fNToRecFN #(
    .expWidth(fpu_recoded_exp_width_gp)
    ,.sigWidth(fpu_recoded_sig_width_gp)
  ) flw_to_RecFN (
    .in(flw_data)
    ,.out(flw_recoded_data)
  );


  //////////////////////////////
  //                          //
  //      CONTROL LOGIC       //
  //                          //
  //////////////////////////////

  // IF stall signals
  logic stall_icache_store;

  // ID stall signals
  logic stall_depend_long_op;
  logic stall_depend_local_load;
  logic stall_depend_imul;
  logic stall_bypass;
  logic stall_lr_aq;
  logic stall_fence;
  logic stall_amo_aq;
  logic stall_amo_rl;
  logic stall_remote_req;
  logic stall_remote_credit;
  logic stall_fdiv_busy;
  logic stall_idiv_busy;
  logic stall_fcsr;

  // MEM stall signals
  logic stall_idiv_wb;
  logic stall_remote_ld_wb;
  logic stall_ifetch_wait;
  
  // FP_WB stall signals
  logic stall_fdiv_wb;
  logic stall_remote_flw_wb;

  wire stall_id = stall_depend_long_op
    | stall_depend_local_load
    | stall_depend_imul
    | stall_bypass
    | stall_lr_aq
    | stall_fence
    | stall_amo_aq
    | stall_amo_rl
    | stall_remote_req
    | stall_remote_credit
    | stall_fdiv_busy
    | stall_idiv_busy
    | stall_fcsr;

  wire stall_all = stall_icache_store
    | stall_idiv_wb
    | stall_remote_ld_wb
    | stall_ifetch_wait
    | stall_fdiv_wb
    | stall_remote_flw_wb;


  // flush condition
  wire flush = (branch_mispredict | jalr_mispredict);
  wire icache_miss_in_pipe = id_r.icache_miss | exe_r.icache_miss | mem_r.icache_miss | wb_r.icache_miss;

  // reset edge down detect
  logic reset_r;
  bsg_dff #(.width_p(1)) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );  

  wire reset_down = reset_r & ~reset_i;

  always_comb begin
    if (reset_down)
      pc_n = pc_init_val_i;
    else if (wb_r.icache_miss)
      pc_n = wb_r.icache_miss_pc[2+:pc_width_lp];
    else if (flush)
      pc_n = exe_pc_target;
    else if (decode.is_branch_op & instruction[0])
      pc_n = pred_or_jump_addr;
    else if (decode.is_jal_op | decode.is_jalr_op)
      pc_n = pred_or_jump_addr;
    else
      pc_n = pc_plus4;
  end
  

  // icache logic
  wire read_icache = (icache_miss_in_pipe & ~flush)
    ? wb_r.icache_miss
    : 1'b1;

  assign icache_v_li = icache_v_i | ifetch_v_i
    | (read_icache & ~stall_all & ~(stall_id & ~flush));

  assign icache_w_li = icache_v_i | ifetch_v_i;

  assign icache_w_pc = ifetch_v_i
    ? mem_r.mem_addr_sent[2+:pc_width_lp]
    : icache_pc_i;

  assign icache_winstr = ifetch_v_i
    ? ifetch_instr_i
    : icache_instr_i;

  assign icache_yumi_o = icache_v_i & ~ifetch_v_i;

  assign icache_flush = flush | icache_miss_in_pipe;
  
  assign stall_icache_store = icache_v_i & icache_yumi_o;


  // IF -> ID
  always_comb begin
    if (stall_all) begin
      id_n = id_r;
    end
    else begin
      if (reset_down | flush) begin
        id_n = '0;
      end    
      else if (stall_id) begin
        id_n = id_r;
      end
      // When stall_id is high, icache miss should not be flushing ID.
      else if (icache_miss_in_pipe | icache_flush_r_lo) begin
        id_n = '0;
      end
      else if (icache_miss) begin
        id_n = '{
          pc_plus4: {{(data_width_p-pc_width_lp-2){1'b0}}, pc_plus4, 2'b0},
          pred_or_jump_addr: '0,
          instruction: '0,
          decode: '0,
          fp_decode: '0,
          icache_miss: 1'b1
        };
      end
      else begin
        id_n = '{
          pc_plus4: {{(data_width_p-pc_width_lp-2){1'b0}}, pc_plus4, 2'b0},
          pred_or_jump_addr: {{(data_width_p-pc_width_lp-2){1'b0}}, pred_or_jump_addr, 2'b0},
          instruction: instruction,
          decode: decode,
          fp_decode: fp_decode,
          icache_miss: 1'b0
        };
      end
    end
  end


  // regfile read
  assign int_rf_read[0] = id_n.decode.read_rs1 & ~(stall_id | stall_all);
  assign int_rf_read[1] = id_n.decode.read_rs2 & ~(stall_id | stall_all);
  assign float_rf_read[0] = id_n.decode.read_frs1 & ~(stall_id | stall_all);
  assign float_rf_read[1] = id_n.decode.read_frs2 & ~(stall_id | stall_all);
  assign float_rf_read[2] = id_n.decode.read_frs3 & ~(stall_id | stall_all);

  // helpful control signals;
  wire [reg_addr_width_lp-1:0] id_rs1 = id_r.instruction.rs1;
  wire [reg_addr_width_lp-1:0] id_rs2 = id_r.instruction.rs2;
  wire [reg_addr_width_lp-1:0] id_rs3 = id_r.instruction[31:27];
  wire [reg_addr_width_lp-1:0] id_rd = id_r.instruction.rd;
  wire remote_req_in_exe = lsu_remote_req_v_lo;
  wire local_load_in_exe = lsu_dmem_v_lo & ~lsu_dmem_w_lo;
  wire id_rs1_non_zero = id_rs1 != '0;
  wire id_rs2_non_zero = id_rs2 != '0;
  wire id_rd_non_zero = id_rd != '0;
  wire int_remote_load_in_exe = remote_req_in_exe & exe_r.decode.is_load_op & exe_r.decode.write_rd;
  wire float_remote_load_in_exe = remote_req_in_exe & exe_r.decode.is_load_op & exe_r.decode.write_frd;
  wire fdiv_fsqrt_in_fp_exe = fp_exe_r.fp_decode.is_fdiv_op | fp_exe_r.fp_decode.is_fsqrt_op;
  wire remote_credit_pending = (out_credits_i != max_out_credits_p);

  // stall_depend_long_op (idiv, fdiv, remote_load, atomic)
  wire rs1_sb_clear_now = id_r.decode.read_rs1 & (id_rs1 == int_sb_clear_id) & int_sb_clear & id_rs1_non_zero; 
  wire frs2_sb_clear_now = id_r.decode.read_frs2 & (id_rs2 == float_sb_clear_id) & float_sb_clear;

  assign stall_depend_long_op = (int_dependency | float_dependency)
    | (id_r.decode.is_fp_op
        ? rs1_sb_clear_now
        : frs2_sb_clear_now);
  

  // stall_depend_local_load (lw, flw, lr, lr.aq)
  assign stall_depend_local_load = local_load_in_exe &
    ((id_r.decode.read_rs1 & (id_rs1 == exe_r.instruction.rd) & exe_r.decode.write_rd & id_rs1_non_zero)
    |(id_r.decode.read_rs2 & (id_rs2 == exe_r.instruction.rd) & exe_r.decode.write_rd & id_rs2_non_zero)
    |(id_r.decode.read_frs1 & (id_rs1 == exe_r.instruction.rd) & exe_r.decode.write_frd)
    |(id_r.decode.read_frs2 & (id_rs2 == exe_r.instruction.rd) & exe_r.decode.write_frd)
    |(id_r.decode.read_frs3 & (id_rs3 == exe_r.instruction.rd) & exe_r.decode.write_frd));


  // stall_depend_imul
  assign stall_depend_imul = exe_r.decode.is_imul_op &
    ((id_r.decode.read_rs1 & (id_rs1 == exe_r.instruction.rd) & id_rs1_non_zero)
    |(id_r.decode.read_rs2 & (id_rs2 == exe_r.instruction.rd) & id_rs2_non_zero));


  // stall_bypass
  wire stall_bypass_fp_frs = 
    (id_r.decode.read_frs1 & (id_rs1 == fp_exe_r.rd) & fp_exe_r.fp_decode.is_fpu_float_op)
    |(id_r.decode.read_frs2 & (id_rs2 == fp_exe_r.rd) & fp_exe_r.fp_decode.is_fpu_float_op)
    |(id_r.decode.read_frs3 & (id_rs3 == fp_exe_r.rd) & fp_exe_r.fp_decode.is_fpu_float_op)
    |(id_r.decode.read_frs1 & (id_rs1 == fpu1_rd_r) & fpu1_v_r)
    |(id_r.decode.read_frs2 & (id_rs2 == fpu1_rd_r) & fpu1_v_r)
    |(id_r.decode.read_frs3 & (id_rs3 == fpu1_rd_r) & fpu1_v_r)
    |(id_r.decode.read_frs1 & (id_rs1 == mem_r.rd_addr) & mem_r.write_frd)
    |(id_r.decode.read_frs2 & (id_rs2 == mem_r.rd_addr) & mem_r.write_frd)
    |(id_r.decode.read_frs3 & (id_rs3 == mem_r.rd_addr) & mem_r.write_frd);

  wire stall_bypass_fp_rs1 = (id_r.decode.read_rs1 & id_rs1_non_zero) &
    (((id_rs1 == fp_exe_r.rd) & fp_exe_r.fp_decode.is_fpu_int_op)
    |((id_rs1 == imul_rd_lo) & imul_v_lo)
    |((id_rs1 == exe_r.instruction.rd) & exe_r.decode.write_rd)
    |((id_rs1 == mem_r.rd_addr) & mem_r.write_rd)
    |((id_rs1 == wb_r.rd_addr) & wb_r.write_rd));
  

  wire stall_bypass_int_frs2 = id_r.decode.read_frs2 &
    (((id_rs2 == fp_exe_r.rd) & fp_exe_r.fp_decode.is_fpu_float_op)
    |((id_rs2 == fpu1_rd_r) & fpu1_v_r)
    |((id_rs2 == fpu_float_rd_lo) & fpu_float_v_lo)
    |((id_rs2 == mem_r.rd_addr) & mem_r.write_frd)
    |((id_rs2 == flw_wb_r.rd_addr) & flw_wb_r.valid));
    

  assign stall_bypass = id_r.decode.is_fp_op
    ? (stall_bypass_fp_frs | stall_bypass_fp_rs1)
    : stall_bypass_int_frs2;

  // stall_lr_aq
  assign stall_lr_aq = id_r.decode.is_lr_aq_op & (reserved_r | lsu_reserve_lo) & ~break_reserve;

  // stall_fence
  assign stall_fence = id_r.decode.is_fence_op & (remote_credit_pending | remote_req_in_exe);
  
  // stall_amo_aq
  assign stall_amo_aq = aq_r & ~aq_clear &
    (id_r.decode.is_load_op
    |id_r.decode.is_store_op
    |id_r.decode.is_amo_op
    |id_r.decode.is_lr_aq_op
    |id_r.decode.is_lr_op);

  // stall_amo_rl
  // If there is a remote request in EXE, there is a technically remote request pending, even if the credit counter has not yet been decremented.
  assign stall_amo_rl = id_r.decode.is_amo_op & id_r.decode.is_amo_rl
    & (remote_credit_pending | remote_req_in_exe);


  // stall_remote_req
  logic [lg_fwd_fifo_els_lp-1:0] remote_req_counter_r;
  wire local_mem_op_restore = (lsu_dmem_v_lo & ~exe_r.decode.is_lr_op & ~exe_r.decode.is_lr_aq_op) & ~stall_all;
  wire id_remote_req_op = (id_r.decode.is_load_op | id_r.decode.is_store_op | id_r.decode.is_amo_op | id_r.icache_miss);
  wire memory_op_issued = id_remote_req_op & ~flush & ~stall_id & ~stall_all;
  wire [lg_fwd_fifo_els_lp-1:0] remote_req_available =
    remote_req_counter_r +
    remote_req_credit_i +
    local_mem_op_restore +
    invalid_eva_access_i;

  always_ff @ (posedge clk_i) begin
    if (reset_i)
      remote_req_counter_r <= (lg_fwd_fifo_els_lp)'(fwd_fifo_els_p);
    else
      remote_req_counter_r <= remote_req_available - memory_op_issued;
  end 

  assign stall_remote_req = id_remote_req_op & (remote_req_available == '0);
  
  // stall_remote_credit
  assign stall_remote_credit = id_remote_req_op & ((out_credits_i - remote_req_in_exe) < 2);

  // stall_fdiv_busy
  assign stall_fdiv_busy = (id_r.fp_decode.is_fdiv_op | id_r.fp_decode.is_fsqrt_op) & (fdiv_fsqrt_ready_lo
    ? (fp_exe_r.fp_decode.is_fdiv_op | fp_exe_r.fp_decode.is_fsqrt_op)
    : 1'b1);

  // stall_idiv_busy
  assign stall_idiv_busy = id_r.decode.is_idiv_op & (idiv_ready_lo
    ? exe_r.decode.is_idiv_op
    : 1'b1);

  // stall_fcsr
  assign stall_fcsr = (id_r.decode.is_csr_op)
    & ((id_r.instruction[31:20] == `RV32_CSR_FFLAGS_ADDR)
      |(id_r.instruction[31:20] == `RV32_CSR_FCSR_ADDR))
    & (fp_exe_r.fp_decode.is_fpu_float_op
      |fp_exe_r.fp_decode.is_fpu_int_op
      |fp_exe_r.fp_decode.is_fdiv_op
      |fp_exe_r.fp_decode.is_fsqrt_op
      |(~fdiv_fsqrt_ready_lo)
      |fdiv_fsqrt_v_lo
      |fpu1_v_r
      |fpu_float_v_lo);


  // FP_EXE forwarding mux control logic
  //
  assign select_rs1_to_fp_exe = id_r.decode.read_rs1;
  assign frs1_forward_v = id_r.decode.read_frs1 & (id_rs1 == float_rf_waddr) & float_rf_wen;
  assign frs2_forward_v = id_r.decode.read_frs2 & (id_rs2 == float_rf_waddr) & float_rf_wen;
  assign frs3_forward_v = id_r.decode.read_frs3 & (id_rs3 == float_rf_waddr) & float_rf_wen;

  // EXE forwarding mux control logic
  // [0] = exe
  // [1] = mem
  // [2] = wb
  logic [2:0] has_forward_data_rs1;
  logic [2:0] has_forward_data_rs2;

  assign has_forward_data_rs1[0] =
    ((exe_r.decode.write_rd & (exe_r.instruction.rd == id_rs1))
    |(fp_exe_r.fp_decode.is_fpu_int_op & (fp_exe_r.rd == id_rs1)))
    & id_rs1_non_zero;
  assign has_forward_data_rs1[1] =
    ((mem_r.write_rd & (mem_r.rd_addr == id_rs1))
    |(imul_v_lo & (imul_rd_lo == id_rs1)))
    & id_rs1_non_zero;
  assign has_forward_data_rs1[2] =
    wb_r.write_rd & (wb_r.rd_addr == id_rs1)
    & id_rs1_non_zero;

  bsg_priority_encode #(
    .width_p(3)
    ,.lo_to_hi_p(1)
  ) rs1_forward_pe0 (
    .i(has_forward_data_rs1)
    ,.addr_o(rs1_forward_sel)
    ,.v_o(rs1_forward_v)
  );

  assign has_forward_data_rs2[0] =
    ((exe_r.decode.write_rd & (exe_r.instruction.rd == id_rs2))
    |(fp_exe_r.fp_decode.is_fpu_int_op & (fp_exe_r.rd == id_rs2)))
    & id_rs2_non_zero;
  assign has_forward_data_rs2[1] =
    ((mem_r.write_rd & (mem_r.rd_addr == id_rs2))
    |(imul_v_lo & (imul_rd_lo == id_rs2)))
    & id_rs2_non_zero;
  assign has_forward_data_rs2[2] =
    wb_r.write_rd & (wb_r.rd_addr == id_rs2)
    & id_rs2_non_zero;

  bsg_priority_encode #(
    .width_p(3)
    ,.lo_to_hi_p(1)
  ) rs2_forward_pe0 (
    .i(has_forward_data_rs2)
    ,.addr_o(rs2_forward_sel)
    ,.v_o(rs2_forward_v)
  );


  // AMO aq control
  assign aq_set = (id_r.decode.is_amo_op & id_r.decode.is_amo_aq) & ~flush & ~stall_all & ~stall_id;
  assign aq_clear = int_rf_wen & (int_rf_waddr == aq_rd_r);


  // FCSR control
  assign fcsr_v_li = (id_r.decode.is_csr_op) & ~flush & ~stall_all & ~stall_id; 
  assign fcsr_funct3_li = id_r.instruction.funct3;
  assign fcsr_rs1_li = id_r.instruction.rs1;
  assign fcsr_data_li = rs1_val_to_exe[7:0];
  assign fcsr_addr_li = id_r.instruction[31:20];


  // ID -> EXE
  always_comb begin
    if (stall_all) begin
      exe_n = exe_r;
    end
    else begin
      if (flush | stall_id | id_r.decode.is_fp_op) begin
        exe_n = '0;
      end
      else begin
        exe_n = '{
          pc_plus4: id_r.pc_plus4,
          pred_or_jump_addr: id_r.pred_or_jump_addr,
          instruction: id_r.instruction,
          decode: id_r.decode,
          rs1_val: rs1_val_to_exe,
          rs2_val: rs2_val_to_exe,
          mem_addr_op2: mem_addr_op2,
          icache_miss: id_r.icache_miss,
          fcsr_data: fcsr_data_lo
        };
      end
    end
  end

  // idiv input control
  assign idiv_v_li = exe_r.decode.is_idiv_op & ~stall_all;

  // int scoreboard set logic
  assign int_sb_score = ~stall_all & (exe_r.decode.is_idiv_op | exe_r.decode.is_amo_op | int_remote_load_in_exe);
  assign int_sb_score_id = exe_r.instruction.rd;  

  // exe_result
  assign exe_result = fp_exe_r.fp_decode.is_fpu_int_op
    ? fpu_int_result_lo
    : alu_or_csr_result;

  // remote request control
  assign remote_req_v_o = lsu_remote_req_v_lo & ~stall_all;

  // ID -> FP_EXE
  frm_e fpu_rm;
  assign fpu_rm = (id_r.instruction.funct3 == eDYN)
    ? frm_r
    : frm_e'(id_r.instruction.funct3);

  always_comb begin
    if (stall_all) begin
      fp_exe_n = fp_exe_r;
    end
    else begin
      if (flush | stall_id | ~id_r.decode.is_fp_op) begin
        fp_exe_n = '0;
      end
      else begin
        fp_exe_n = '{
          rs1_val: frs1_to_fp_exe,
          rs2_val: frs2_to_fp_exe,
          rs3_val: frs3_to_fp_exe,
          rd: id_r.instruction.rd,
          fp_decode: id_r.fp_decode,
          rm: fpu_rm
        };
      end
    end
  end  

  // fdiv control 
  assign fdiv_fsqrt_v_li = fdiv_fsqrt_in_fp_exe & ~stall_all;

  // FP scoreboard set logic
  assign float_sb_score = ~stall_all & (fdiv_fsqrt_in_fp_exe | float_remote_load_in_exe);
  assign float_sb_score_id = fdiv_fsqrt_in_fp_exe
    ? fp_exe_r.rd
    : exe_r.instruction.rd;


  // EXE,FP_EXE -> MEM
  always_comb begin

    fcsr_fflags_v_li[0] = 1'b0;
    fcsr_fflags_li[0] = fpu_int_fflags_lo;

    if (stall_all) begin
      mem_n = mem_r;
    end
    else if (exe_r.decode.is_idiv_op | (remote_req_in_exe & ~exe_r.icache_miss)) begin
      mem_n = '0;
    end
    else if (fp_exe_r.fp_decode.is_fpu_int_op) begin
      fcsr_fflags_v_li[0] = 1'b1;
      mem_n = '{
        rd_addr: fp_exe_r.rd,
        exe_result: fpu_int_result_lo,
        write_rd: 1'b1,
        write_frd: 1'b0,
        is_byte_op: 1'b0,
        is_hex_op: 1'b0,
        is_load_unsigned: 1'b0,
        local_load: 1'b0,
        mem_addr_sent: '0,
        icache_miss: 1'b0
      };      
    end
    else begin
      mem_n = '{
        rd_addr: exe_r.instruction.rd,
        exe_result: alu_or_csr_result,
        write_rd: exe_r.decode.write_rd,
        write_frd: exe_r.decode.write_frd,
        is_byte_op: exe_r.decode.is_byte_op,
        is_hex_op: exe_r.decode.is_hex_op,
        is_load_unsigned: exe_r.decode.is_load_unsigned,
        local_load: local_load_in_exe,
        mem_addr_sent: lsu_mem_addr_sent_lo,
        icache_miss: exe_r.icache_miss
      };      
    end
  end  

 
  // DMEM ctrl logic
  always_comb begin
    if (stall_all) begin
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

  // reservation logic
  // lr creates a reservation on DMEM address.
  // Any store to this address breaks the reservation.
  // When the reservation is valid, lr.aq stalls until the reservation is broken. 
  assign make_reserve = lsu_reserve_lo & ~stall_all;
  assign break_reserve = reserved_r & (reserved_addr_r == dmem_addr_li) & dmem_v_li & dmem_w_li;

  // stall_ifetch_wait
  assign stall_ifetch_wait = mem_r.icache_miss & ~ifetch_v_i;

  // mem_result
  assign mem_result = imul_v_lo
    ? imul_result_lo
    : (mem_r.local_load
      ? local_load_packed_data
      : mem_r.exe_result);

  wire mem_result_valid = imul_v_lo | mem_r.write_rd | mem_r.write_frd;
 
 
  // MEM -> WB
  always_comb begin
    wb_n.write_rd = 1'b0;
    wb_n.rd_addr = '0;
    wb_n.rf_data = '0;
    wb_n.icache_miss = 1'b0;
    wb_n.icache_miss_pc = '0;
    wb_n.clear_sb = 1'b0;
    int_remote_load_resp_yumi_o = 1'b0;
    idiv_yumi_li = 1'b0;
    stall_idiv_wb = 1'b0;
    stall_remote_ld_wb = 1'b0;

    // int remote_load_resp and icache response are mutually exclusive events.
    if (int_remote_load_resp_force_i) begin
      wb_n.write_rd = 1'b1;
      wb_n.rd_addr = int_remote_load_resp_rd_i;
      wb_n.rf_data = int_remote_load_resp_data_i;
      wb_n.clear_sb = 1'b1;
      stall_remote_ld_wb = mem_result_valid | mem_r.icache_miss;
      int_remote_load_resp_yumi_o = 1'b1;
    end
    else if (mem_r.icache_miss & ifetch_v_i) begin
      wb_n.icache_miss = 1'b1;
      wb_n.icache_miss_pc = mem_r.mem_addr_sent;
    end
    else begin
      if (imul_v_lo) begin
        wb_n.write_rd = 1'b1;
        wb_n.rd_addr = imul_rd_lo;
        wb_n.rf_data = imul_result_lo;
      end
      else if (mem_r.write_rd) begin
        wb_n.write_rd = 1'b1;
        wb_n.rd_addr = mem_r.rd_addr;
        wb_n.rf_data = mem_r.local_load
          ? local_load_packed_data
          : mem_r.exe_result;
      end
      else begin
        if (int_remote_load_resp_v_i) begin
          wb_n.write_rd = 1'b1;
          wb_n.rd_addr = int_remote_load_resp_rd_i;
          wb_n.rf_data = int_remote_load_resp_data_i;
          wb_n.clear_sb = 1'b1;
          int_remote_load_resp_yumi_o = 1'b1;
        end
        else if (idiv_v_lo) begin
          wb_n.write_rd = 1'b1;
          wb_n.rd_addr = idiv_rd_lo;
          wb_n.rf_data = idiv_result_lo;
          wb_n.clear_sb = 1'b1;
          idiv_yumi_li = 1'b1;
        end
      end
    end
  end


  // WB 
  assign int_rf_wdata = wb_r.rf_data;
  assign int_rf_waddr = wb_r.rd_addr;
  assign int_rf_wen = wb_r.write_rd;

  // int scoreboard clear logic
  assign int_sb_clear = wb_r.write_rd & wb_r.clear_sb;
  assign int_sb_clear_id = wb_r.rd_addr;


  // MEM -> FLW_WB
  always_comb begin
    if (stall_all) begin
      flw_wb_n = flw_wb_r;
    end
    else begin
      flw_wb_n = '{
        valid: mem_r.write_frd,
        rd_addr: mem_r.rd_addr,
        rf_data: local_load_data_r
      };
    end
  end

  
  // FP_WB
  // fcsr exception handling
  // float scoreboard clear logic
  always_comb begin
    stall_remote_flw_wb = 1'b0;
    stall_fdiv_wb = 1'b0;

    float_remote_load_resp_yumi_o = 1'b0;
    fdiv_fsqrt_yumi_li = 1'b0;

    float_rf_wen = 1'b0;
    float_rf_waddr = '0;
    float_rf_wdata = '0;
    select_remote_flw = 1'b0;

    float_sb_clear = 1'b0;
    float_sb_clear_id = float_remote_load_resp_rd_i;

    fcsr_fflags_v_li[1] = 1'b0;
    fcsr_fflags_li[1] = fpu_float_fflags_lo;
    

    if (float_remote_load_resp_force_i) begin
      select_remote_flw = 1'b1;
      float_rf_wen = 1'b1;
      float_rf_waddr = float_remote_load_resp_rd_i;
      float_rf_wdata = flw_recoded_data;
      float_remote_load_resp_yumi_o = 1'b1;
      stall_remote_flw_wb = flw_wb_r.valid | fpu_float_v_lo;

      float_sb_clear = 1'b1;
      float_sb_clear_id = float_remote_load_resp_rd_i;
    end
    else if (flw_wb_r.valid) begin
      select_remote_flw = 1'b0;
      float_rf_wen = 1'b1;
      float_rf_waddr = flw_wb_r.rd_addr;
      float_rf_wdata = flw_recoded_data; 
    end
    else if (fpu_float_v_lo) begin
      float_rf_wen = 1'b1;
      float_rf_waddr = fpu_float_rd_lo;
      float_rf_wdata = fpu_float_result_lo;
      fcsr_fflags_v_li[1] = 1'b1;
      fcsr_fflags_li[1] = fpu_float_fflags_lo;
    end
    else begin
      if (fdiv_fsqrt_v_lo) begin
        fdiv_fsqrt_yumi_li = 1'b1;
        float_rf_wen = 1'b1;
        float_rf_waddr = fdiv_fsqrt_rd_lo;
        float_rf_wdata = fdiv_fsqrt_result_lo;

        float_sb_clear = 1'b1;
        float_sb_clear_id = fdiv_fsqrt_rd_lo;

        fcsr_fflags_v_li[1] = 1'b1;
        fcsr_fflags_li[1] = fdiv_fsqrt_fflags_lo;
      end
      else if (float_remote_load_resp_v_i) begin
        select_remote_flw = 1'b1;
        float_rf_wen = 1'b1;
        float_rf_waddr = float_remote_load_resp_rd_i;
        float_rf_wdata = flw_recoded_data;
        float_remote_load_resp_yumi_o = 1'b1;

        float_sb_clear = 1'b1;
        float_sb_clear_id = float_remote_load_resp_rd_i;
      end
    end
  end

  // fpu_float stall control
  assign stall_fpu1_li = stall_all;
  assign stall_fpu2_li = stall_fdiv_wb | stall_remote_flw_wb;





  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin

      if (idiv_v_li) begin
        assert(idiv_ready_lo) else $error("idiv_op issued when idiv is not ready.");
      end

      if (fdiv_fsqrt_v_li) begin
        assert(fdiv_fsqrt_ready_lo) else $error("fdiv_fsqrt_op issued, when fdiv_fsqrt is not ready.");
      end

      assert(~id_r.decode.unsupported) else $error("Unsupported instruction: %8x", id_r.instruction);
    end
  end
  // synopsys translate_on



endmodule
