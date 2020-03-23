/**
 *  vanilla_core_profiler.v
 *
 *  This profiler keeps track of what instructions/bubbles are in EXE and FP_EXE stage.
 *  When these instructions/bubbles moves out of EXE and FP_EXE stage, the corresponding counters are incremented.
 *  If EXE or FP_EXE stage is stalled for some reason, the corresponding stall counters are also incremented.
 *
 */


module vanilla_core_profiler
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  import bsg_manycore_profile_pkg::*;
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)

    , parameter data_width_p="inv"
    , parameter dmem_size_p="inv"
    , parameter dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)

    , parameter reg_addr_width_lp = RV32_reg_addr_width_gp
    , parameter reg_els_lp = RV32_reg_els_gp

    // determines who prints the csv header.
    , parameter origin_x_cord_p="inv"
    , parameter origin_y_cord_p="inv"
  )
  (
    input clk_i
    , input reset_i

    , input [pc_width_lp-1:0] pc_r
    , input [pc_width_lp-1:0] pc_n

    , input stall
    , input stall_depend
    , input stall_fp
    , input stall_ifetch_wait
    , input stall_icache_store
    , input stall_lr_aq
    , input stall_fence
    , input stall_md
    , input stall_force_wb
    , input stall_remote_req
    , input stall_local_flw
    , input stall_amo_aq
    , input stall_amo_rl
  
    , input stall_id
    , input branch_mispredict
    , input jalr_mispredict
    , input icache_miss_in_pipe

    , input id_signals_s id_r
    , input exe_signals_s exe_r
    , input exe_signals_s exe_n
    , input mem_signals_s mem_n
    , input wb_signals_s wb_n
    , input fp_exe_signals_s fp_exe_r
    , input fpu_float_ready_lo
    
    , input [data_width_p-1:0] mem_addr_op2
    , input [data_width_p-1:0] rs1_to_exe

    , input int_sb_score
    , input [1:0] int_sb_clear
    , input [1:0][reg_addr_width_lp-1:0] int_sb_clear_id

    , input float_sb_score
    , input float_sb_clear
    , input [reg_addr_width_lp-1:0] float_sb_clear_id 

    , input lsu_dmem_v_lo
    , input lsu_dmem_w_lo
  
    , input remote_req_s remote_req_o
    , input remote_req_v_o
    , input remote_req_yumi_i

    , input float_remote_load_resp_v_i
    , input local_flw_valid

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i

    , input trace_en_i // from toplevel testbench
  );


  // bsg_manycore_profile_pkg for the packed print_stat_tag_i signal
  // <stat type>  -  <y cord>  -  <x cord>  -  <tile group id>  -  <tag>
  bsg_manycore_vanilla_core_stat_tag_s print_stat_tag;
  assign print_stat_tag = print_stat_tag_i;


  // task to print a line of operation trace
  task print_operation_trace(integer fd, string op);
    $fwrite(fd, "%0t,%0d,%0d,%0h,%s", global_ctr_i, my_x_i - origin_x_cord_p, my_y_i - origin_y_cord_p, (exe_r.pc_plus4 - 'd4), op);
  endtask

  // event signals
  //
  wire instr_inc = (~stall) & (exe_r.instruction != '0) & ~exe_r.icache_miss;
  wire fp_instr_inc = fp_exe_r.valid & fpu_float_ready_lo;

  // fp_float
  //
  wire fadd_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fadd_op;
  wire fsub_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fsub_op;
  wire fmul_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fmul_op;
  wire fsgnj_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fsgnj_op;
  wire fsgnjn_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fsgnjn_op;
  wire fsgnjx_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fsgnjx_op;
  wire fmin_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fmin_op;
  wire fmax_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fmax_op;
  wire fcvt_s_w_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fcvt_s_w_op;
  wire fcvt_s_wu_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fcvt_s_wu_op;
  wire fmv_w_x_inc = fp_instr_inc & fp_exe_r.fp_float_decode.fmv_w_x_op; 

  // fp_int
  //
  wire fp_int_inc = instr_inc & exe_r.decode.is_fp_int_op;
  wire feq_inc = fp_int_inc & exe_r.fp_int_decode.feq_op;
  wire flt_inc = fp_int_inc & exe_r.fp_int_decode.flt_op;
  wire fle_inc = fp_int_inc & exe_r.fp_int_decode.fle_op;
  wire fcvt_w_s_inc = fp_int_inc & exe_r.fp_int_decode.fcvt_w_s_op;
  wire fcvt_wu_s_inc = fp_int_inc & exe_r.fp_int_decode.fcvt_wu_s_op;
  wire fclass_inc = fp_int_inc & exe_r.fp_int_decode.fclass_op;
  wire fmv_x_w_inc = fp_int_inc & exe_r.fp_int_decode.fmv_x_w_op;

  // LSU
  //
  wire local_ld_inc = lsu_dmem_v_lo & ~lsu_dmem_w_lo & ~stall & exe_r.decode.op_writes_rf;
  wire local_st_inc = lsu_dmem_v_lo & lsu_dmem_w_lo & ~stall & exe_r.decode.op_reads_rf2;
  wire remote_ld_inc = remote_req_v_o & remote_req_yumi_i & ~remote_req_o.write_not_read
    & ~remote_req_o.load_info.icache_fetch
    & exe_r.decode.op_writes_rf;
  wire remote_ld_dram_inc   = remote_ld_inc & (remote_req_o.addr[data_width_p-1]);
  wire remote_ld_global_inc = remote_ld_inc & ~remote_ld_dram_inc 
                              & (remote_req_o.addr[data_width_p-2]);
  wire remote_ld_group_inc  = remote_ld_inc & ~remote_ld_dram_inc & ~remote_ld_global_inc
                              & (remote_req_o.addr[data_width_p-3]);

  wire remote_st_inc = remote_req_v_o & remote_req_yumi_i & remote_req_o.write_not_read
    & exe_r.decode.op_reads_rf2;
  wire remote_st_dram_inc   = remote_st_inc & (remote_req_o.addr[data_width_p-1]);
  wire remote_st_global_inc = remote_st_inc & ~remote_st_dram_inc 
                              & (remote_req_o.addr[data_width_p-2]);
  wire remote_st_group_inc  = remote_st_inc & ~remote_st_dram_inc & ~remote_st_global_inc
                              & (remote_req_o.addr[data_width_p-3]);

  wire local_flw_inc = lsu_dmem_v_lo & ~lsu_dmem_w_lo & ~stall & exe_r.decode.op_writes_fp_rf;
  wire local_fsw_inc = lsu_dmem_v_lo & lsu_dmem_w_lo & ~stall & exe_r.decode.op_reads_fp_rf2;
  wire remote_flw_inc = remote_req_v_o & remote_req_yumi_i & ~remote_req_o.write_not_read
    & ~remote_req_o.load_info.icache_fetch
    & exe_r.decode.op_writes_fp_rf;
  wire remote_fsw_inc = remote_req_v_o & remote_req_yumi_i & remote_req_o.write_not_read
    & exe_r.decode.op_reads_fp_rf2;

  wire icache_miss_inc = remote_req_v_o & remote_req_yumi_i & ~remote_req_o.write_not_read
    & remote_req_o.load_info.icache_fetch;

  wire lr_inc = instr_inc & exe_r.decode.op_is_lr;
  wire lr_aq_inc = instr_inc & exe_r.decode.op_is_lr_aq;
  wire amoswap_inc = instr_inc & exe_r.decode.is_amo_op & (exe_r.decode.amo_type == e_amo_swap);
  wire amoor_inc = instr_inc & exe_r.decode.is_amo_op & (exe_r.decode.amo_type == e_amo_or);


  // branch & jump
  //
  wire beq_inc = instr_inc & exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BEQ);
  wire bne_inc = instr_inc & exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BNE);
  wire blt_inc = instr_inc & exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BLT);
  wire bge_inc = instr_inc & exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BGE);
  wire bltu_inc = instr_inc & exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BLTU);
  wire bgeu_inc = instr_inc & exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BGEU);

  wire jalr_inc = instr_inc & exe_r.decode.is_jalr_op;
  wire jal_inc = instr_inc & exe_r.decode.is_jal_op;
  
  wire beq_miss_inc = beq_inc & branch_mispredict;
  wire bne_miss_inc = bne_inc & branch_mispredict;
  wire blt_miss_inc = blt_inc & branch_mispredict;
  wire bge_miss_inc = bge_inc & branch_mispredict;
  wire bltu_miss_inc = bltu_inc & branch_mispredict;
  wire bgeu_miss_inc = bgeu_inc & branch_mispredict;

  wire jalr_miss_inc = jalr_inc & jalr_mispredict;
  
  // ALU
  //
  wire sll_inc = instr_inc & (exe_r.instruction ==? `RV32_SLL);
  wire slli_inc = instr_inc & (exe_r.instruction ==? `RV32_SLLI);
  wire srl_inc = instr_inc & (exe_r.instruction ==? `RV32_SRL);
  wire srli_inc = instr_inc & (exe_r.instruction ==? `RV32_SRLI);
  wire sra_inc = instr_inc & (exe_r.instruction ==? `RV32_SRA);
  wire srai_inc = instr_inc & (exe_r.instruction ==? `RV32_SRAI);

  wire add_inc = instr_inc & (exe_r.instruction ==? `RV32_ADD);
  wire addi_inc = instr_inc & (exe_r.instruction ==? `RV32_ADDI);
  wire sub_inc = instr_inc & (exe_r.instruction ==? `RV32_SUB);
  wire lui_inc = instr_inc & (exe_r.instruction ==? `RV32_LUI);
  wire auipc_inc = instr_inc & (exe_r.instruction ==? `RV32_AUIPC);
  wire xor_inc = instr_inc & (exe_r.instruction ==? `RV32_XOR);
  wire xori_inc = instr_inc & (exe_r.instruction ==? `RV32_XORI);
  wire or_inc = instr_inc & (exe_r.instruction ==? `RV32_OR);
  wire ori_inc = instr_inc & (exe_r.instruction ==? `RV32_ORI);
  wire and_inc = instr_inc & (exe_r.instruction ==? `RV32_AND);
  wire andi_inc = instr_inc & (exe_r.instruction ==? `RV32_ANDI);

  wire slt_inc = instr_inc & (exe_r.instruction ==? `RV32_SLT);
  wire slti_inc = instr_inc & (exe_r.instruction ==? `RV32_SLTI);
  wire sltu_inc = instr_inc & (exe_r.instruction ==? `RV32_SLTU);
  wire sltiu_inc = instr_inc & (exe_r.instruction ==? `RV32_SLTIU);


  // MULDIV
  //
  wire mul_inc = instr_inc & (exe_r.instruction ==? `RV32_MUL);
  wire mulh_inc = instr_inc & (exe_r.instruction ==? `RV32_MULH);
  wire mulhsu_inc = instr_inc & (exe_r.instruction ==? `RV32_MULHSU);
  wire mulhu_inc = instr_inc & (exe_r.instruction ==? `RV32_MULHU);
  wire div_inc = instr_inc & (exe_r.instruction ==? `RV32_DIV);
  wire divu_inc = instr_inc & (exe_r.instruction ==? `RV32_DIVU);
  wire rem_inc = instr_inc & (exe_r.instruction ==? `RV32_REM);
  wire remu_inc = instr_inc & (exe_r.instruction ==? `RV32_REMU);

  // fence
  //
  wire fence_inc = instr_inc & exe_r.decode.is_fence_op;

  // remote/local scoreboard tracking 
  //
  // int_sb[3]: remote dram load
  // int_sb[2]: remote global load
  // int_sb[1]: remote group load
  // int_sb[0]: local load
  //
  // float_sb[3]: remote dram load
  // float_sb[2]: remote global load
  // float_sb[1]: remote group load
  // float_sb[0]: local_load
  //
  logic [reg_els_lp-1:0][3:0] int_sb_r;
  logic [reg_els_lp-1:0][3:0] float_sb_r;
  
  logic remote_load_in_id;
  logic remote_load_dram_in_id;
  logic remote_load_global_in_id;
  logic remote_load_group_in_id;
  logic local_load_in_id;

  logic [data_width_p-1:0] load_addr;
  assign load_addr = mem_addr_op2 +
    (exe_n.rs1_in_mem
      ? mem_n.exe_result
      : (exe_n.rs1_in_wb
        ? wb_n.rf_data
        : rs1_to_exe));

  assign local_load_in_id = (load_addr ==? 32'b00000000_00000000_0001????_????????);

  assign remote_load_in_id = ~local_load_in_id;
  assign remote_load_dram_in_id = remote_load_in_id 
    & (load_addr[data_width_p-1]);
  assign remote_load_global_in_id = remote_load_in_id 
    & ~remote_load_dram_in_id
    & (load_addr[data_width_p-2]);
  assign remote_load_group_in_id = remote_load_in_id
    & ~remote_load_dram_in_id
    & ~remote_load_global_in_id
    & (load_addr[data_width_p-3]);


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      int_sb_r <= '0;
    end
    else begin

      if (int_sb_score & remote_load_dram_in_id) begin
        int_sb_r[id_r.instruction.rd][3] <= 1'b1;
      end
      else if (int_sb_clear[1]) begin
        int_sb_r[int_sb_clear_id[1]][3] <= 1'b0;
      end

      if (int_sb_score & remote_load_global_in_id) begin
        int_sb_r[id_r.instruction.rd][2] <= 1'b1;
      end
      else if (int_sb_clear[1]) begin
        int_sb_r[int_sb_clear_id[1]][2] <= 1'b0;
      end

      if (int_sb_score & remote_load_group_in_id) begin
        int_sb_r[id_r.instruction.rd][1] <= 1'b1;
      end
      else if (int_sb_clear[1]) begin
        int_sb_r[int_sb_clear_id[1]][1] <= 1'b0;
      end

      if (int_sb_score & local_load_in_id) begin
        int_sb_r[id_r.instruction.rd][0] <= 1'b1;
      end
      else if (int_sb_clear[0]) begin
        int_sb_r[int_sb_clear_id[0]][0] <= 1'b0;
      end

    end
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      float_sb_r <= '0;
    end
    else begin

      if (float_sb_score & id_r.decode.is_load_op & remote_load_dram_in_id) begin
        float_sb_r[id_r.instruction.rd][3] <= 1'b1;
      end
      else if (float_sb_clear) begin
        float_sb_r[float_sb_clear_id][3] <= 1'b0;
      end

      if (float_sb_score & id_r.decode.is_load_op & remote_load_global_in_id) begin
        float_sb_r[id_r.instruction.rd][2] <= 1'b1;
      end
      else if (float_sb_clear) begin
        float_sb_r[float_sb_clear_id][2] <= 1'b0;
      end

      if (float_sb_score & id_r.decode.is_load_op & remote_load_group_in_id) begin
        float_sb_r[id_r.instruction.rd][1] <= 1'b1;
      end
      else if (float_sb_clear) begin
        float_sb_r[float_sb_clear_id][1] <= 1'b0;
      end

      if (float_sb_score & id_r.decode.is_load_op & local_load_in_id) begin
        float_sb_r[id_r.instruction.rd][0] <= 1'b1;
      end
      else if (float_sb_clear) begin
        float_sb_r[float_sb_clear_id][0] <= 1'b0;
      end

    end
  end

  // stall depend bubble
  //
  logic stall_depend_bubble;
  logic stall_depend_local_load_bubble;
  //logic stall_depend_remote_load_bubble;
  logic stall_depend_remote_load_dram_bubble;
  logic stall_depend_remote_load_global_bubble;
  logic stall_depend_remote_load_group_bubble;

  assign stall_depend_bubble = stall_depend & ~(stall | stall_fp);

  assign stall_depend_local_load_bubble = stall_depend_bubble
    & ((id_r.decode.op_reads_rf1 & int_sb_r[id_r.instruction.rs1][0]) |
       (id_r.decode.op_reads_rf2 & int_sb_r[id_r.instruction.rs2][0]) |
       (id_r.decode.op_reads_fp_rf1 & float_sb_r[id_r.instruction.rs1][0]) |
       (id_r.decode.op_reads_fp_rf2 & float_sb_r[id_r.instruction.rs2][0]));
    
  assign stall_depend_remote_load_dram_bubble = stall_depend_bubble
    & ((id_r.decode.op_reads_rf1 & int_sb_r[id_r.instruction.rs1][3]) |
       (id_r.decode.op_reads_rf2 & int_sb_r[id_r.instruction.rs2][3]) |
       (id_r.decode.op_reads_fp_rf1 & float_sb_r[id_r.instruction.rs1][3]) |
       (id_r.decode.op_reads_fp_rf2 & float_sb_r[id_r.instruction.rs2][3]));
    
  assign stall_depend_remote_load_global_bubble = stall_depend_bubble
    & ((id_r.decode.op_reads_rf1 & int_sb_r[id_r.instruction.rs1][2]) |
       (id_r.decode.op_reads_rf2 & int_sb_r[id_r.instruction.rs2][2]) |
       (id_r.decode.op_reads_fp_rf1 & float_sb_r[id_r.instruction.rs1][2]) |
       (id_r.decode.op_reads_fp_rf2 & float_sb_r[id_r.instruction.rs2][2]));
    
  assign stall_depend_remote_load_group_bubble = stall_depend_bubble
    & ((id_r.decode.op_reads_rf1 & int_sb_r[id_r.instruction.rs1][1]) |
       (id_r.decode.op_reads_rf2 & int_sb_r[id_r.instruction.rs2][1]) |
       (id_r.decode.op_reads_fp_rf1 & float_sb_r[id_r.instruction.rs1][1]) |
       (id_r.decode.op_reads_fp_rf2 & float_sb_r[id_r.instruction.rs2][1]));
    
  //assign stall_depend_remote_load_bubble = stall_depend_remote_load_dram_bubble |
  //                                         stall_depend_remote_load_global_bubble |
  //                                         stall_depend_remote_load_group_bubble;

  wire stall_fp_remote_load_inc = stall_fp & ~(stall | stall_depend) & float_remote_load_resp_v_i;
  wire stall_fp_local_load_inc = stall_fp & ~(stall | stall_depend) & local_flw_valid;

  wire stall_force_wb_inc = stall_force_wb
    & ~(stall_ifetch_wait | stall_icache_store | stall_lr_aq
        | stall_fence | stall_md | stall_remote_req | stall_local_flw);

  // Keep track of what type of "bubble" is inserted in ID, EXE stage.

  // ID stage
  // [0] branch_mispredict bubble
  // [1] jalr_mispredict bubble
  // [2] icache_miss bubble
  typedef enum logic [1:0] {
    e_id_branch_mispredict,
    e_id_jalr_mispredict,
    e_id_icache_miss,
    e_id_no_bubble
  } id_bubble_type_e;

  id_bubble_type_e id_bubble_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      id_bubble_r <= e_id_no_bubble;
    end
    else begin
      if (~stall_id) begin
        if (branch_mispredict)
          id_bubble_r <= e_id_branch_mispredict;
        else if (jalr_mispredict)
          id_bubble_r <= e_id_jalr_mispredict;
        else if (icache_miss_in_pipe)
          id_bubble_r <= e_id_icache_miss;
        else
          id_bubble_r <= e_id_no_bubble;
      end
    end
  end

  // EXE stage
  // [0]  branch mispredict bubble
  // [1]  jalr mispredict bubble
  // [2]  icache miss bubble
  // [3]  stall_amo_aq
  // [4]  stall_amo_rl
  // [5]  fp_op bubble
  // [6]  stall_depend bubble
  //      - local_load
  //      - remote_load_dram
  //      - remote_load_global
  //      - remote_load_group
  //      - fpu
  typedef enum logic [2:0] {
    e_exe_branch_mispredict,
    e_exe_jalr_mispredict,
    e_exe_icache_miss,
    e_exe_fp_op,
    e_exe_stall_amo_aq,
    e_exe_stall_amo_rl,
    e_exe_stall_depend,
    e_exe_no_bubble
  } exe_bubble_type_e;

  exe_bubble_type_e exe_bubble_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      exe_bubble_r <= e_exe_no_bubble;
    end
    else begin
      if (~stall) begin
        if (branch_mispredict)
          exe_bubble_r <= e_exe_branch_mispredict;
        else if (jalr_mispredict)
          exe_bubble_r <= e_exe_jalr_mispredict;
        else if (id_bubble_r == e_id_branch_mispredict)
          exe_bubble_r <= e_exe_branch_mispredict;
        else if (id_bubble_r == e_id_jalr_mispredict)
          exe_bubble_r <= e_exe_jalr_mispredict;
        else if (id_bubble_r == e_id_icache_miss)
          exe_bubble_r <= e_exe_icache_miss;
        else if (stall_amo_aq)
          exe_bubble_r <= e_exe_stall_amo_aq;
        else if (stall_amo_rl)
          exe_bubble_r <= e_exe_stall_amo_rl;
        else if (stall_depend_bubble)
          exe_bubble_r <= e_exe_stall_depend;
        else if (id_r.decode.is_fp_float_op)
          exe_bubble_r <= e_exe_fp_op;
        else
          exe_bubble_r <= e_exe_no_bubble;
      end
    end
  end

  logic exe_stall_depend_local_load_r;
  logic exe_stall_depend_remote_load_dram_r;
  logic exe_stall_depend_remote_load_global_r;
  logic exe_stall_depend_remote_load_group_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      exe_stall_depend_local_load_r <= 1'b0;
      exe_stall_depend_remote_load_dram_r <= 1'b0;
      exe_stall_depend_remote_load_global_r <= 1'b0;
      exe_stall_depend_remote_load_group_r <= 1'b0;
    end
    else begin
      exe_stall_depend_local_load_r <= stall_depend_local_load_bubble;
      exe_stall_depend_remote_load_dram_r <= stall_depend_remote_load_dram_bubble;
      exe_stall_depend_remote_load_global_r <= stall_depend_remote_load_global_bubble;
      exe_stall_depend_remote_load_group_r <= stall_depend_remote_load_group_bubble;
    end
  end

  wire stall_amo_aq_inc = ~stall & (exe_bubble_r == e_exe_stall_amo_aq);
  wire stall_amo_rl_inc = ~stall & (exe_bubble_r == e_exe_stall_amo_rl);
  wire bubble_icache_inc = ~stall & (exe_bubble_r == e_exe_icache_miss); // TODO include me in logs
  wire bubble_branch_mispredict_inc = ~stall & (exe_bubble_r == e_exe_branch_mispredict); // TODO include me in logs
  wire bubble_jalr_mispredict_inc = ~stall & (exe_bubble_r == e_exe_jalr_mispredict); // TODO include me in logs
  wire bubble_fp_op_inc = ~stall & (exe_bubble_r == e_exe_fp_op); // TODO include me in logs

  wire stall_depend_inc = ~stall & (exe_bubble_r == e_exe_stall_depend); 
  wire stall_depend_local_load_inc = stall_depend_inc & exe_stall_depend_local_load_r;
  wire stall_depend_remote_load_dram_inc = stall_depend_inc & exe_stall_depend_remote_load_dram_r;
  wire stall_depend_remote_load_global_inc = stall_depend_inc & exe_stall_depend_remote_load_global_r;
  wire stall_depend_remote_load_group_inc = stall_depend_inc & exe_stall_depend_remote_load_group_r;
  wire stall_depend_remote_load_inc = stall_depend_remote_load_dram_inc |
                                      stall_depend_remote_load_global_inc |
                                      stall_depend_remote_load_group_inc;

  //  profiling counters
  //
  typedef struct packed {
    integer cycle; // total number of cycles since the reset went down (unfrozen).
    integer instr; // total number of instruction executed.

    // these are the counts of instructions executed for each type.
    integer fadd;
    integer fsub;
    integer fmul;
    integer fsgnj;
    integer fsgnjn;
    integer fsgnjx;
    integer fmin;
    integer fmax;
    integer fcvt_s_w;
    integer fcvt_s_wu;
    integer fmv_w_x;

    integer feq;
    integer flt;
    integer fle;
    integer fcvt_w_s;
    integer fcvt_wu_s;
    integer fclass;
    integer fmv_x_w;

    integer ld;                // local_load count
    integer st;                // local_store count
    integer remote_ld;         // remote_load count
    integer remote_ld_dram;    // remote_load to dram count
    integer remote_ld_global;  // remote_load to global tile count
    integer remote_ld_group;   // remote_load to group tile count
    integer remote_st;         // remote_store count
    integer remote_st_dram;    // remote_store to dram count
    integer remote_st_global;  // remote_store to global tile count
    integer remote_st_group;   // remote_store to group tile count
    integer local_flw;         // local_flw count
    integer local_fsw;         // local_fsw count
    integer remote_flw;        // remote_flw count
    integer remote_fsw;        // remote_fsw count

    // icache miss rate can be calculated by the expression:
    // icache_miss_rate = icache_miss / (icache_miss + instr)
    integer icache_miss;  // total number of icache miss request sent out

    integer lr;
    integer lr_aq;
    integer amoswap;
    integer amoor;

    // number of branch count (both correct and incorrect prediction)
    integer beq;
    integer bne;
    integer blt;
    integer bge;
    integer bltu;
    integer bgeu;
    integer jalr;
    integer jal;

    // number of incorrect branch prediction among all branch executed.
    // branch mispredict rate = {beq_miss+bne_miss+...+bgeu_miss}/{beq+bne+...+bgeu}
    // Similarly, jalr_mispredict_rate = {jalr_miss/jalr}
    integer beq_miss;
    integer bne_miss;
    integer blt_miss;
    integer bge_miss;
    integer bltu_miss;
    integer bgeu_miss;
    integer jalr_miss;

    integer sll;
    integer slli;
    integer srl;
    integer srli;
    integer sra;
    integer srai;

    integer add;
    integer addi;
    integer sub;
    integer lui;
    integer auipc;
    integer xor_;
    integer xori;
    integer or_;
    integer ori;
    integer and_;
    integer andi;
    integer slt;
    integer slti;
    integer sltu;
    integer sltiu;

    integer mul;
    integer mulh;
    integer mulhsu;
    integer mulhu;
    integer div;
    integer divu;
    integer rem;
    integer remu;

    integer fence;

    integer stall_fp_remote_load;     // FPU is stalled because of remote_load_response
    integer stall_fp_local_load;      // FPU is stalled because of local_load_response

    // total number of cycle stalled, because there is some data dependency that has not been resolved.
    // this can be a combination of:
    // 1) FPU result
    // 2) local load
    // 3) remote load
    integer stall_depend;             
    integer stall_depend_local_load; // among stall_depend count, ones that include local_load dependency.
    integer stall_depend_remote_load; // among stall_depend count, one that include remote_load dependency.
    integer stall_depend_remote_load_dram; // among stall_depend count, one that include remote_load to dram dependency.
    integer stall_depend_remote_load_global; // among stall_depend count, one that include remote_load to global tile dependency.
    integer stall_depend_remote_load_group; // among stall_depend count, one that include remote_load to group tile dependency.

    integer stall_force_wb;       // stalled because of remote_load_response forcing a writeback
    integer stall_ifetch_wait;    // stalled because of waiting for instruction fetch.
    integer stall_icache_store;   // stalled because of icache store 
    integer stall_lr_aq;          // stalled on lr_aq
    integer stall_md;             // stalled on muldiv
    integer stall_remote_req;     // stalled on waiting for the network to accept outgoing request.
    integer stall_local_flw;      // stalled because local_flw is blocked by remote_flw.

    integer stall_amo_aq;         // stalled on TODO 
    integer stall_amo_rl;         // stalled on TODO

    integer bubble_icache;                    // Bubble in pipeline (exe stalled) after i-cache miss is handled 
    integer bubble_branch_mispredict;         // Bubble in pipeline (exe stalled) after branch mispredict occurs
    integer bubble_jalr_mispredict;
    integer bubble_fp_op;                     // Bubble in floating point pipeline after TODO

  
  } vanilla_stat_s;

  vanilla_stat_s stat;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      stat <= '0;
    end
    else begin
      stat.cycle++;
      stat.instr <= stat.instr + instr_inc + fp_instr_inc;

      if (fadd_inc) stat.fadd++;
      if (fsub_inc) stat.fsub++;
      if (fmul_inc) stat.fmul++;
      if (fsgnj_inc) stat.fsgnj++;
      if (fsgnjn_inc) stat.fsgnjn++;
      if (fsgnjx_inc) stat.fsgnjx++;
      if (fmin_inc) stat.fmin++;
      if (fmax_inc) stat.fmax++;
      if (fcvt_s_w_inc) stat.fcvt_s_w++;
      if (fcvt_s_wu_inc) stat.fcvt_s_wu++;
      if (fmv_w_x_inc) stat.fmv_w_x++;

      if (feq_inc) stat.feq++;
      if (flt_inc) stat.flt++;
      if (fle_inc) stat.fle++;
      if (fcvt_w_s_inc) stat.fcvt_w_s++;
      if (fcvt_wu_s_inc) stat.fcvt_wu_s++;
      if (fclass_inc) stat.fclass++;
      if (fmv_x_w_inc) stat.fmv_x_w++;

      if (local_ld_inc) stat.ld++;
      if (local_st_inc) stat.st++;
      if (remote_ld_inc) stat.remote_ld++;
      if (remote_ld_dram_inc) stat.remote_ld_dram++;
      if (remote_ld_global_inc) stat.remote_ld_global++;
      if (remote_ld_group_inc) stat.remote_ld_group++;
      if (remote_st_inc) stat.remote_st++;
      if (remote_st_dram_inc) stat.remote_st_dram++;
      if (remote_st_global_inc) stat.remote_st_global++;
      if (remote_st_group_inc) stat.remote_st_group++;
      if (local_flw_inc) stat.local_flw++;
      if (local_fsw_inc) stat.local_fsw++;
      if (remote_flw_inc) stat.remote_flw++;
      if (remote_fsw_inc) stat.remote_fsw++;
      if (icache_miss_inc) stat.icache_miss++;

      if (lr_inc) stat.lr++;
      if (lr_aq_inc) stat.lr_aq++;
      if (amoswap_inc) stat.amoswap++;
      if (amoor_inc) stat.amoor++;
     
      if (beq_inc) stat.beq++; 
      if (bne_inc) stat.bne++; 
      if (blt_inc) stat.blt++; 
      if (bge_inc) stat.bge++; 
      if (bltu_inc) stat.bltu++; 
      if (bgeu_inc) stat.bgeu++; 
      if (jalr_inc) stat.jalr++; 
      if (jal_inc) stat.jal++; 

      if (beq_miss_inc) stat.beq_miss++; 
      if (bne_miss_inc) stat.bne_miss++; 
      if (blt_miss_inc) stat.blt_miss++; 
      if (bge_miss_inc) stat.bge_miss++; 
      if (bltu_miss_inc) stat.bltu_miss++; 
      if (bgeu_miss_inc) stat.bgeu_miss++; 
      if (jalr_miss_inc) stat.jalr_miss++; 
     
      if (sll_inc) stat.sll++; 
      if (slli_inc) stat.slli++; 
      if (srl_inc) stat.srl++; 
      if (srli_inc) stat.srli++; 
      if (sra_inc) stat.sra++; 
      if (srai_inc) stat.srai++; 

      if (add_inc) stat.add++;
      if (addi_inc) stat.addi++;
      if (sub_inc) stat.sub++;
      if (lui_inc) stat.lui++;
      if (auipc_inc) stat.auipc++;
      if (xor_inc) stat.xor_++;
      if (xori_inc) stat.xori++;
      if (or_inc) stat.or_++;
      if (ori_inc) stat.ori++;
      if (and_inc) stat.and_++;
      if (andi_inc) stat.andi++;
      if (slt_inc) stat.slt++;
      if (slti_inc) stat.slti++;
      if (sltu_inc) stat.sltu++;
      if (sltiu_inc) stat.sltiu++;

      if (mul_inc) stat.mul++;
      if (mulh_inc) stat.mulh++;
      if (mulhsu_inc) stat.mulhsu++;
      if (mulhu_inc) stat.mulhu++;
      if (div_inc) stat.div++;
      if (divu_inc) stat.divu++;
      if (rem_inc) stat.rem++;
      if (remu_inc) stat.remu++;

      if (fence_inc) stat.fence++;

      if (stall_fp_remote_load_inc) stat.stall_fp_remote_load++;
      if (stall_fp_local_load_inc) stat.stall_fp_local_load++;

      if (stall_depend_inc) stat.stall_depend++;
      if (stall_depend_local_load_inc) stat.stall_depend_local_load++;
      if (stall_depend_remote_load_inc) stat.stall_depend_remote_load++;
      if (stall_depend_remote_load_dram_inc) stat.stall_depend_remote_load_dram++;
      if (stall_depend_remote_load_global_inc) stat.stall_depend_remote_load_global++;
      if (stall_depend_remote_load_group_inc) stat.stall_depend_remote_load_group++;

      if (stall_force_wb_inc) stat.stall_force_wb++;
      if (stall_ifetch_wait) stat.stall_ifetch_wait++;
      if (stall_icache_store) stat.stall_icache_store++;
      if (stall_lr_aq) stat.stall_lr_aq++;
      if (stall_md) stat.stall_md++;
      if (stall_remote_req) stat.stall_remote_req++;
      if (stall_local_flw) stat.stall_local_flw++;

      if (stall_amo_aq_inc) stat.stall_amo_aq++;
      if (stall_amo_rl_inc) stat.stall_amo_rl++;

      if (bubble_icache_inc) stat.bubble_icache++;
      if (bubble_branch_mispredict_inc) stat.bubble_branch_mispredict++;
      if (bubble_jalr_mispredict_inc) stat.bubble_jalr_mispredict++;
      if (bubble_fp_op_inc) stat.bubble_fp_op++;


    end
  end 


  // file logging
  //
  localparam logfile_lp = "vanilla_stats.csv";
  localparam tracefile_lp = "vanilla_operation_trace.csv";

  integer fd, fd2;
  string header;

  initial begin

    #1; // we need to wait for one time unit so that my_x_i and my_y_i becomes a known value.

    // the origin tile opens the logfile and writes the csv header.
    if ((my_x_i == x_cord_width_p'(origin_x_cord_p)) & (my_y_i == y_cord_width_p'(origin_y_cord_p))) begin
      fd = $fopen(logfile_lp, "w");
      $fwrite(fd, "time,x,y,pc_r,pc_n,tag,global_ctr,cycle,");
      $fwrite(fd, "instr_total,instr_fadd,instr_fsub,instr_fmul,");
      $fwrite(fd, "instr_fsgnj,instr_fsgnjn,instr_fsgnjx,");
      $fwrite(fd, "instr_fmin,instr_fmax,instr_fcvt_s_w,instr_fcvt_s_wu,instr_fmv_w_x,");
      $fwrite(fd, "instr_feq,instr_flt,instr_fle,");
      $fwrite(fd, "instr_fcvt_w_s,instr_fcvt_wu_s,instr_fclass,instr_fmv_x_w,");
      $fwrite(fd, "instr_local_ld,instr_local_st,");
      $fwrite(fd, "instr_remote_ld_dram,instr_remote_ld_global,instr_remote_ld_group,");
      $fwrite(fd, "instr_remote_st_dram,instr_remote_st_global,instr_remote_st_group,");
      $fwrite(fd, "instr_local_flw,instr_local_fsw,");
      $fwrite(fd, "instr_remote_flw,instr_remote_fsw,");
      $fwrite(fd, "instr_lr,instr_lr_aq,instr_amoswap,instr_amoor,");
      $fwrite(fd, "instr_beq,instr_bne,instr_blt,instr_bge,");
      $fwrite(fd, "instr_bltu,instr_bgeu,instr_jalr,instr_jal,");
      $fwrite(fd, "instr_sll,instr_slli,instr_srl,instr_srli,instr_sra,instr_srai,");
      $fwrite(fd, "instr_add,instr_addi,instr_sub,instr_lui,instr_auipc,");
      $fwrite(fd, "instr_xor,instr_xori,instr_or,instr_ori,");
      $fwrite(fd, "instr_and,instr_andi,instr_slt,instr_slti,instr_sltu,instr_sltiu,");
      $fwrite(fd, "instr_mul,instr_mulh,instr_mulhsu,instr_mulhu,");
      $fwrite(fd, "instr_div,instr_divu,instr_rem,instr_remu,");
      $fwrite(fd, "instr_fence,");
      $fwrite(fd, "miss_icache,miss_beq,miss_bne,miss_blt,miss_bge,miss_bltu,miss_bgeu,miss_jalr,");
      $fwrite(fd, "stall_fp_remote_load,stall_fp_local_load,stall_depend,");
      $fwrite(fd, "stall_depend_remote_load_dram,");
      $fwrite(fd, "stall_depend_remote_load_global,");
      $fwrite(fd, "stall_depend_remote_load_group,");
      $fwrite(fd, "stall_depend_local_load,");
      $fwrite(fd, "stall_force_wb,stall_ifetch_wait,stall_icache_store,");
      $fwrite(fd, "stall_lr_aq,stall_md,stall_remote_req,stall_local_flw,");
      $fwrite(fd, "stall_amo_aq,stall_amo_rl,");
      $fwrite(fd, "bubble_icache,bubble_branch_mispredict,bubble_jalr_mispredict,bubble_fp_op");
      $fwrite(fd, "\n");
      $fclose(fd);
  

      if (trace_en_i) begin
        fd2 = $fopen(tracefile_lp, "w");
        $fwrite(fd2, "cycle,x,y,pc,operation\n");
        $fclose(fd2);
      end


    end



    forever begin
      @(negedge clk_i) begin

        if (~reset_i & trace_en_i) begin
          fd2= $fopen(tracefile_lp, "a");
          if (stall_depend_inc & ~stall_depend_local_load_inc & ~stall_depend_remote_load_inc)
            print_operation_trace(fd2, "stall_depend");
          else if (stall_depend_inc & stall_depend_local_load_inc & ~stall_depend_remote_load_inc)
            print_operation_trace(fd2, "stall_depend_local_load");
          else if (stall_depend_inc & ~stall_depend_local_load_inc & stall_depend_remote_load_inc) 
            // stall_depend_remote_load has 3 types of dram, global, group
            begin
              if (stall_depend_remote_load_dram_inc)
                print_operation_trace(fd2, "stall_depend_remote_load_dram");
              else if (stall_depend_remote_load_global_inc)
                print_operation_trace(fd2, "stall_depend_remote_load_global");
              else if (stall_depend_remote_load_group_inc)
                print_operation_trace(fd2, "stall_depend_remote_load_group");
            end
          else if (stall_depend_inc & stall_depend_local_load_inc & stall_depend_remote_load_inc)
            // stall_depend_local_remote_load, the remote request has 3 types of dram, global, group
            begin
              if (stall_depend_remote_load_dram_inc)
                print_operation_trace(fd2, "stall_depend_local_remote_load_dram");
              else if (stall_depend_remote_load_global_inc)
                print_operation_trace(fd2, "stall_depend_local_remote_load_global");
              else if (stall_depend_remote_load_group_inc)
                print_operation_trace(fd2, "stall_depend_local_remote_load_group");
            end
          else if (stall_fp_remote_load_inc)
            print_operation_trace(fd2, "stall_fp_remote_load");
          else if (stall_fp_local_load_inc)
            print_operation_trace(fd2, "stall_fp_local_load");
          else if (stall_force_wb_inc)
            print_operation_trace(fd2, "stall_force_wb");
          else if (stall_ifetch_wait)
            print_operation_trace(fd2, "stall_ifetch_wait");
          else if (stall_icache_store)
            print_operation_trace(fd2, "stall_icache_store");
          else if (stall_lr_aq)
            print_operation_trace(fd2, "stall_lr_aq");
          else if (stall_md)
            print_operation_trace(fd2, "stall_md");
          else if (stall_remote_req)
            print_operation_trace(fd2, "stall_remote_req");
          else if (stall_local_flw)
            print_operation_trace(fd2, "stall_local_flw");
          else if (stall_amo_aq)
            print_operation_trace(fd2, "stall_amo_aq");
          else if (stall_amo_rl)
            print_operation_trace(fd2, "stall_amo_rl");
          else
          begin

            if (local_ld_inc)
              print_operation_trace(fd2, "local_ld");
            else if (local_st_inc)
              print_operation_trace(fd2, "local_st");
            else if (remote_ld_inc)
            begin
              if (remote_ld_dram_inc)
                print_operation_trace(fd2, "remote_ld_dram");
              else if (remote_ld_global_inc)
                print_operation_trace(fd2, "remote_ld_global");
              else if (remote_ld_group_inc)
                print_operation_trace(fd2, "remote_ld_group");
            end
            else if (remote_st_inc)
            begin
              if (remote_st_dram_inc)
                print_operation_trace(fd2, "remote_st_dram");
              else if (remote_st_global_inc)
                print_operation_trace(fd2, "remote_st_global");
              else if (remote_st_group_inc)
                print_operation_trace(fd2, "remote_st_group");
            end
            else if (local_flw_inc)
              print_operation_trace(fd2, "local_flw");
            else if (local_fsw_inc)
              print_operation_trace(fd2, "local_fsw");
            else if (remote_flw_inc)
              print_operation_trace(fd2, "remote_flw");
            else if (remote_fsw_inc)
              print_operation_trace(fd2, "remote_fsw");
            else if (icache_miss_inc)
              print_operation_trace(fd2, "icache_miss");

            else if (lr_inc)
              print_operation_trace(fd2, "lr");
            else if (lr_aq_inc)
              print_operation_trace(fd2, "lr_aq");
            else if (amoswap_inc)
              print_operation_trace(fd2, "amoswap");
            else if (amoor_inc)
              print_operation_trace(fd2, "amoor");

            else if (beq_inc)
              print_operation_trace(fd2, "beq");
            else if (bne_inc)
              print_operation_trace(fd2, "bne");
            else if (blt_inc)
              print_operation_trace(fd2, "blt");
            else if (bge_inc)
              print_operation_trace(fd2, "bge");
            else if (bltu_inc)
              print_operation_trace(fd2, "bltu");
            else if (bgeu_inc)
              print_operation_trace(fd2, "bgeu");
            else if (jalr_inc)
              print_operation_trace(fd2, "jalr");
            else if (jal_inc)
              print_operation_trace(fd2, "jal");

            else if (beq_miss_inc)
              print_operation_trace(fd2, "beq_miss");
            else if (bne_miss_inc)
              print_operation_trace(fd2, "bne_miss");
            else if (blt_miss_inc)
              print_operation_trace(fd2, "blt_miss");
            else if (bge_miss_inc)
              print_operation_trace(fd2, "bge_miss");
            else if (bltu_miss_inc)
              print_operation_trace(fd2, "bltu_miss");
            else if (bgeu_miss_inc)
              print_operation_trace(fd2, "bgeu_miss");
            else if (jalr_miss_inc)
              print_operation_trace(fd2, "jalr_miss");

            else if (sll_inc)
              print_operation_trace(fd2, "sll");
            else if (slli_inc)
              print_operation_trace(fd2, "slli");
            else if (srl_inc)
              print_operation_trace(fd2, "srl");
            else if (srli_inc)
              print_operation_trace(fd2, "srli");
            else if (sra_inc)
              print_operation_trace(fd2, "sra");
            else if (srai_inc)
              print_operation_trace(fd2, "srai");

            else if (add_inc)
              print_operation_trace(fd2, "add");
            else if (addi_inc)
              print_operation_trace(fd2, "addi");
            else if (sub_inc)
              print_operation_trace(fd2, "sub");
            else if (lui_inc)
              print_operation_trace(fd2, "lui");
            else if (auipc_inc)
              print_operation_trace(fd2, "auipc");
            else if (xor_inc)
              print_operation_trace(fd2, "xor");
            else if (xori_inc)
              print_operation_trace(fd2, "xori");
            else if (or_inc)
              print_operation_trace(fd2, "or");
            else if (ori_inc)
              print_operation_trace(fd2, "ori");
            else if (and_inc)
              print_operation_trace(fd2, "and");
            else if (andi_inc)
              print_operation_trace(fd2, "andi");
            else if (slt_inc)
              print_operation_trace(fd2, "slt");
            else if (slti_inc)
              print_operation_trace(fd2, "slti");
            else if (sltu_inc)
              print_operation_trace(fd2, "sltu");
            else if (sltiu_inc)
              print_operation_trace(fd2, "sltiu");

            else if (mul_inc)
              print_operation_trace(fd2, "mul");
            else if (mulh_inc)
              print_operation_trace(fd2, "mulh");
            else if (mulhsu_inc)
              print_operation_trace(fd2, "mulhsu");
            else if (mulhu_inc)
              print_operation_trace(fd2, "mulhu");
            else if (div_inc)
              print_operation_trace(fd2, "div");
            else if (divu_inc)
              print_operation_trace(fd2, "divu");
            else if (rem_inc)
              print_operation_trace(fd2, "rem");
            else if (remu_inc)
              print_operation_trace(fd2, "remu");

            else if (fence_inc)
              print_operation_trace(fd2, "fence");

            else if (fadd_inc)
              print_operation_trace(fd2, "fadd");
            else if (fsub_inc)
              print_operation_trace(fd2, "fsub");
            else if (fmul_inc)
              print_operation_trace(fd2, "fmul");
            else if (fsgnj_inc)
              print_operation_trace(fd2, "fsgnj");
            else if (fsgnjn_inc)
              print_operation_trace(fd2, "fsgnjn");
            else if (fsgnjx_inc)
              print_operation_trace(fd2, "fsgnjx");
            else if (fmin_inc)
              print_operation_trace(fd2, "fmin");
            else if (fmax_inc)
              print_operation_trace(fd2, "fmax");
            else if (fcvt_s_w_inc)
              print_operation_trace(fd2, "fcvt_s_w");
            else if (fcvt_s_wu_inc)
              print_operation_trace(fd2, "fcvt_s_wu");
            else if (fmv_w_x_inc)
              print_operation_trace(fd2, "fmv_w_x");

            else if (feq_inc)
              print_operation_trace(fd2, "feq");
            else if (flt_inc)
              print_operation_trace(fd2, "flt");
            else if (fle_inc)
              print_operation_trace(fd2, "fle");
            else if (fcvt_w_s_inc)
              print_operation_trace(fd2, "fcvt_w_s");
            else if (fcvt_wu_s_inc)
              print_operation_trace(fd2, "fcvt_wu_s");
            else if (fclass_inc)
              print_operation_trace(fd2, "fclass");
            else if (fmv_x_w_inc)
              print_operation_trace(fd2, "fmv_x_w");


            else if (instr_inc | fp_instr_inc)
              print_operation_trace(fd2, "unknown");

             else
             begin
                if (bubble_icache_inc)
                  print_operation_trace(fd2, "bubble_icache");
                else if (bubble_branch_mispredict_inc)
                  print_operation_trace(fd2, "bubble_branch_mispredict");
                else if (bubble_jalr_mispredict_inc)
                  print_operation_trace(fd2, "bubble_jalr_mispredict");
                else if (bubble_fp_op_inc)
                  print_operation_trace(fd2, "bubble_fp_op");
                else
                  print_operation_trace(fd2, "bubble");
             end 
          end


          $fwrite(fd2, "\n"); 
          $fclose(fd2);
        end
    
        // The bsg_cuda_print_stat intrinsic sends a tag value to be printed 
        // along with the stats message. Inside the tag value, the x,y
        // coordinates of the tile calling the bsg_print_stats, along with its 
        // tile group id is incorporated in the following form"
        // <stat type>  -  <y cord>  -  <x cord>  -  <tile group id>  -  <tag>
        // A core's profiler only prints the stat if core's x,y coordinates 
        // matches the ones incorporated in the print_stat_tag_i
        if (~reset_i & print_stat_v_i & print_stat_tag.y_cord == my_y_i & print_stat_tag.x_cord == my_x_i) begin

          $display("[BSG_INFO][VCORE_PROFILER] t=%0t x,y=%02d,%02d printing stats.",
            $time, my_x_i, my_y_i);

          fd = $fopen(logfile_lp, "a");

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            $time,
            my_x_i - origin_x_cord_p,
            my_y_i - origin_y_cord_p,
            pc_r,
            pc_n,
            print_stat_tag_i,
            global_ctr_i,
            stat.cycle
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.instr,
            stat.fadd,
            stat.fsub,
            stat.fmul,
            stat.fsgnj,
            stat.fsgnjn,
            stat.fsgnjx,
            stat.fmin,
            stat.fmax,
            stat.fcvt_s_w,
            stat.fcvt_s_wu,
            stat.fmv_w_x
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.feq,
            stat.flt,
            stat.fle,
            stat.fcvt_w_s,
            stat.fcvt_wu_s,
            stat.fclass,
            stat.fmv_x_w
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.ld,
            stat.st,
            stat.remote_ld_dram,
            stat.remote_ld_global,
            stat.remote_ld_group,
            stat.remote_st_dram,
            stat.remote_st_global,
            stat.remote_st_group,
            stat.local_flw,
            stat.local_fsw,
            stat.remote_flw,
            stat.remote_fsw
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,",
            stat.lr,
            stat.lr_aq,
            stat.amoswap,
            stat.amoor
          );
        
          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.beq,
            stat.bne,
            stat.blt,
            stat.bge,
            stat.bltu,
            stat.bgeu,
            stat.jalr,
            stat.jal
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.sll,
            stat.slli,
            stat.srl,
            stat.srli,
            stat.sra,
            stat.srai
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.add,
            stat.addi,
            stat.sub,
            stat.lui,
            stat.auipc,
            stat.xor_,
            stat.xori,
            stat.or_,
            stat.ori, 
            stat.and_,
            stat.andi,
            stat.slt,
            stat.slti, 
            stat.sltu,
            stat.sltiu
          );

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.mul,
            stat.mulh,
            stat.mulhsu,
            stat.mulhu,
            stat.div,
            stat.divu,
            stat.rem,
            stat.remu
          );

          $fwrite(fd, "%0d,", stat.fence);

          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.icache_miss,
            stat.beq_miss,
            stat.bne_miss,
            stat.blt_miss,
            stat.bge_miss,
            stat.bltu_miss,
            stat.bgeu_miss,
            stat.jalr_miss
          );
     
          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat.stall_fp_remote_load,
            stat.stall_fp_local_load,
            stat.stall_depend,
            stat.stall_depend_remote_load_dram,
            stat.stall_depend_remote_load_global,
            stat.stall_depend_remote_load_group,
            stat.stall_depend_local_load,
            stat.stall_force_wb,
            stat.stall_ifetch_wait,
            stat.stall_icache_store,
            stat.stall_lr_aq,
            stat.stall_md,
            stat.stall_remote_req,
            stat.stall_local_flw,
            stat.stall_amo_aq,
            stat.stall_amo_rl
          );

           $fwrite(fd, "%0d,%0d,%0d,%0d",
            stat.bubble_icache,
            stat.bubble_branch_mispredict,
            stat.bubble_jalr_mispredict,
            stat.bubble_fp_op
          );
       
      
          $fwrite(fd, "\n");

          $fclose(fd);          

        end
      end
    end
  end



endmodule
