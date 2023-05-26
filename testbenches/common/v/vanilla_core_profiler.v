/**
 *    vanilla_core_profiler.v
 *
 */


//  Operation trace format = global_counter,x,y,pc,op
//  PC field will print out the PC of the executed instruction in this cycle (i.e. instruction in EXE stage)
//  When there is a bubble in EXE stage, it will print out the PC of the stalled instruction in ID.
//  Or in case there was a bubble because of branch mispredict, it will print out the PC of the mispredicted branch instruction.
//  If the pipeline gets stalled by incoming remote load response or idiv/fdiv, it will print out whatever PC is in the EXE stage.


`include "bsg_manycore_defines.vh"
`include "bsg_vanilla_defines.vh"
`include "profiler.vh"

module vanilla_core_profiler
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  import bsg_manycore_profile_pkg::*;
  import vanilla_exe_bubble_classifier_pkg::*;  
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)

    , parameter `BSG_INV_PARAM(icache_tag_width_p)
    , parameter `BSG_INV_PARAM(icache_entries_p)
    , parameter `BSG_INV_PARAM(origin_x_cord_p)
    , parameter `BSG_INV_PARAM(origin_y_cord_p)

    , parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)

    , parameter reg_els_lp = RV32_reg_els_gp
    , parameter reg_addr_width_lp = RV32_reg_addr_width_gp

    , parameter period_p = 250
  )
  (
    input clk_i
    , input reset_i

    , input [pc_width_lp-1:0] pc_r
    , input [pc_width_lp-1:0] pc_n

    , input [data_width_p-1:0] if_pc
    , input [data_width_p-1:0] id_pc
    , input [data_width_p-1:0] exe_pc

    , input flush
    , input icache_miss
    , input icache_miss_in_pipe
    , input stall_all
    , input stall_id
    , input stall_depend_long_op
    , input stall_depend_local_load
    , input stall_depend_imul
    , input stall_bypass
    , input stall_lr_aq
    , input stall_fence
    , input stall_amo_aq
    , input stall_amo_rl
    , input stall_fdiv_busy
    , input stall_idiv_busy
    , input stall_fcsr
    , input stall_remote_req
    , input stall_remote_credit

    , input stall_barrier

    , input stall_remote_ld_wb
    , input stall_ifetch_wait
    , input stall_remote_flw_wb


    , input branch_mispredict
    , input jalr_mispredict
    , input lsu_dmem_v_lo
    , input lsu_remote_req_v_lo
    , input remote_req_s remote_req_o

    , input [data_width_p-1:0] rs1_val_to_exe
    , input [RV32_Iimm_width_gp-1:0] mem_addr_op2

    , input int_sb_clear
    , input float_sb_clear
    , input [reg_addr_width_lp-1:0] int_sb_clear_id
    , input [reg_addr_width_lp-1:0] float_sb_clear_id

    , input id_signals_s id_r
    , input exe_signals_s exe_r
    , input fp_exe_ctrl_signals_s fp_exe_ctrl_r

    // IF stage
    , input instruction_s instruction
    , input decode_s decode

    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i

    , input trace_en_i
  );

  // bsg_manycore_profile_pkg for the packed print_stat_tag_i signal
  // <stat type>  -  <y cord>  -  <x cord>  -  <tile group id>  -  <tag>
  bsg_manycore_vanilla_core_stat_tag_s print_stat_tag;
  assign print_stat_tag = print_stat_tag_i;

  `DEFINE_PROFILER(bsg_vanilla_core_profiler
                   , "vanilla_operation_trace.csv"
                   , "cycle,x,y,pc,operation\n"
                   )

  // task to print a line of operation trace
  task print_operation_trace(string op, logic [data_width_p-1:0] pc);
    $fwrite
      (bsg_vanilla_core_profiler_trace_fd()
       , "%0d,%0d,%0d,%0h,%s\n"
       , global_ctr_i
       , global_x_i - origin_x_cord_p
       , global_y_i - origin_y_cord_p
       , pc
       , op
       );
  endtask


  // event signals
  //
  wire instr_inc = (~stall_all) & (exe_r.instruction != '0) & ~exe_r.icache_miss;
  wire fp_instr_inc = (fp_exe_ctrl_r.fp_decode.is_fpu_float_op
    | fp_exe_ctrl_r.fp_decode.is_fpu_int_op
    | fp_exe_ctrl_r.fp_decode.is_fdiv_op
    | fp_exe_ctrl_r.fp_decode.is_fsqrt_op) & ~stall_all;

  // fpu_float
  wire fpu_float_inc = fp_exe_ctrl_r.fp_decode.is_fpu_float_op;
  wire fadd_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFADD);
  wire fsub_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFSUB);
  wire fmul_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFMUL);
  wire fsgnj_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFSGNJ);
  wire fsgnjn_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFSGNJN);
  wire fsgnjx_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFSGNJX);
  wire fmin_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFMIN);
  wire fmax_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFMAX);
  wire fcvt_s_w_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFCVT_S_W);
  wire fcvt_s_wu_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFCVT_S_WU);
  wire fmv_w_x_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFMV_W_X);
  wire fmadd_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFMADD);
  wire fmsub_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFMSUB);
  wire fnmsub_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFNMSUB);
  wire fnmadd_inc = fpu_float_inc & (fp_exe_ctrl_r.fp_decode.fpu_float_op == eFNMADD);
 
  // fpu_int
  wire fpu_int_inc = fp_exe_ctrl_r.fp_decode.is_fpu_int_op;
  wire feq_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFEQ);
  wire fle_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFLE);
  wire flt_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFLT);
  wire fcvt_w_s_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFCVT_W_S);
  wire fcvt_wu_s_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFCVT_WU_S);
  wire fclass_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFCLASS);
  wire fmv_x_w_inc = fpu_int_inc & (fp_exe_ctrl_r.fp_decode.fpu_int_op == eFMV_X_W);

  // fdiv/fsqrt
  wire fdiv_inc = fp_exe_ctrl_r.fp_decode.is_fdiv_op;
  wire fsqrt_inc = fp_exe_ctrl_r.fp_decode.is_fsqrt_op;

  // LSU
  wire local_ld_inc = exe_r.decode.is_load_op & lsu_dmem_v_lo & exe_r.decode.write_rd;
  wire local_st_inc = exe_r.decode.is_store_op & lsu_dmem_v_lo & exe_r.decode.read_rs2;

  wire remote_ld_inc = exe_r.decode.is_load_op & lsu_remote_req_v_lo & exe_r.decode.write_rd;
  wire remote_ld_dram_inc = remote_ld_inc & remote_req_o.addr[data_width_p-1]; 
  wire remote_ld_global_inc = remote_ld_inc & (remote_req_o.addr[data_width_p-1-:2] == 2'b01);
  wire remote_ld_group_inc = remote_ld_inc & (remote_req_o.addr[data_width_p-1-:3] == 3'b001);

  wire remote_st_inc = exe_r.decode.is_store_op & lsu_remote_req_v_lo & exe_r.decode.read_rs2;
  wire remote_st_dram_inc = remote_st_inc & remote_req_o.addr[data_width_p-1];
  wire remote_st_global_inc = remote_st_inc & (remote_req_o.addr[data_width_p-1-:2] == 2'b01);
  wire remote_st_group_inc = remote_st_inc & (remote_req_o.addr[data_width_p-1-:3] == 3'b001);

  wire local_flw_inc = exe_r.decode.is_load_op & lsu_dmem_v_lo & exe_r.decode.write_frd;
  wire local_fsw_inc = exe_r.decode.is_store_op & lsu_dmem_v_lo & exe_r.decode.read_frs2;

  wire remote_flw_inc = exe_r.decode.is_load_op & lsu_remote_req_v_lo & exe_r.decode.write_frd;
  wire remote_flw_dram_inc = remote_flw_inc & remote_req_o.addr[data_width_p-1];
  wire remote_flw_global_inc = remote_flw_inc & (remote_req_o.addr[data_width_p-1-:2] == 2'b01);
  wire remote_flw_group_inc = remote_flw_inc & (remote_req_o.addr[data_width_p-1-:3] == 3'b001);

  wire remote_fsw_inc = exe_r.decode.is_store_op & lsu_remote_req_v_lo & exe_r.decode.read_frs2;
  wire remote_fsw_dram_inc = remote_fsw_inc & remote_req_o.addr[data_width_p-1];
  wire remote_fsw_global_inc = remote_fsw_inc & (remote_req_o.addr[data_width_p-1-:2] == 2'b01);
  wire remote_fsw_group_inc = remote_fsw_inc & (remote_req_o.addr[data_width_p-1-:3] == 3'b001);

  wire icache_miss_inc = exe_r.icache_miss;

  wire lr_inc = exe_r.decode.is_lr_op;
  wire lr_aq_inc = exe_r.decode.is_lr_aq_op;
  wire amoswap_inc = exe_r.decode.is_amo_op & (exe_r.decode.amo_type == e_vanilla_amoswap);
  wire amoor_inc = exe_r.decode.is_amo_op & (exe_r.decode.amo_type == e_vanilla_amoor);
  wire amoadd_inc = exe_r.decode.is_amo_op & (exe_r.decode.amo_type == e_vanilla_amoadd);

  // branch & jump
  wire beq_inc = exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BEQ);
  wire bne_inc = exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BNE);
  wire blt_inc = exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BLT);
  wire bge_inc = exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BGE);
  wire bltu_inc = exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BLTU);
  wire bgeu_inc = exe_r.decode.is_branch_op & (exe_r.instruction ==? `RV32_BGEU);

  wire jal_inc = exe_r.decode.is_jal_op;
  wire jalr_inc = exe_r.decode.is_jalr_op;

  wire beq_miss_inc = beq_inc & branch_mispredict;
  wire bne_miss_inc = bne_inc & branch_mispredict;
  wire blt_miss_inc = blt_inc & branch_mispredict;
  wire bge_miss_inc = bge_inc & branch_mispredict;
  wire bltu_miss_inc = bltu_inc & branch_mispredict;
  wire bgeu_miss_inc = bgeu_inc & branch_mispredict;

  wire jalr_miss_inc = jalr_inc & jalr_mispredict;

  // ALU
  wire sll_inc = (exe_r.instruction ==? `RV32_SLL);
  wire slli_inc = (exe_r.instruction ==? `RV32_SLLI);
  wire srl_inc = (exe_r.instruction ==? `RV32_SRL);
  wire srli_inc = (exe_r.instruction ==? `RV32_SRLI);
  wire sra_inc = (exe_r.instruction ==? `RV32_SRA);
  wire srai_inc = (exe_r.instruction ==? `RV32_SRAI);

  wire add_inc = (exe_r.instruction ==? `RV32_ADD);
  wire addi_inc = (exe_r.instruction ==? `RV32_ADDI);
  wire sub_inc = (exe_r.instruction ==? `RV32_SUB);
  wire lui_inc = (exe_r.instruction ==? `RV32_LUI);
  wire auipc_inc = (exe_r.instruction ==? `RV32_AUIPC);
  wire xor_inc = (exe_r.instruction ==? `RV32_XOR);
  wire xori_inc = (exe_r.instruction ==? `RV32_XORI);
  wire or_inc = (exe_r.instruction ==? `RV32_OR);
  wire ori_inc = (exe_r.instruction ==? `RV32_ORI);
  wire and_inc = (exe_r.instruction ==? `RV32_AND);
  wire andi_inc = (exe_r.instruction ==? `RV32_ANDI);

  wire slt_inc = (exe_r.instruction ==? `RV32_SLT);
  wire slti_inc = (exe_r.instruction ==? `RV32_SLTI);
  wire sltu_inc = (exe_r.instruction ==? `RV32_SLTU);
  wire sltiu_inc = (exe_r.instruction ==? `RV32_SLTIU);
 
  // IDIV
  wire div_inc = exe_r.decode.is_idiv_op & (exe_r.decode.idiv_op == eDIV);
  wire divu_inc = exe_r.decode.is_idiv_op & (exe_r.decode.idiv_op == eDIVU);
  wire rem_inc = exe_r.decode.is_idiv_op & (exe_r.decode.idiv_op == eREM);
  wire remu_inc = exe_r.decode.is_idiv_op & (exe_r.decode.idiv_op == eREMU);

  // MUL
  wire mul_inc = exe_r.decode.is_imul_op;

  // FENCE
  wire fence_inc = exe_r.decode.is_fence_op;

  // CSR
  wire csrrw_inc = (exe_r.instruction ==? `RV32_CSRRW);
  wire csrrs_inc = (exe_r.instruction ==? `RV32_CSRRS);
  wire csrrc_inc = (exe_r.instruction ==? `RV32_CSRRC);
  wire csrrwi_inc = (exe_r.instruction ==? `RV32_CSRRWI);
  wire csrrsi_inc = (exe_r.instruction ==? `RV32_CSRRSI);
  wire csrrci_inc = (exe_r.instruction ==? `RV32_CSRRCI);

  // Barrier Instruction
  wire barsend_inc = (exe_r.instruction ==? `RV32_FENCE_OP) & (exe_r.instruction[31:28] == `RV32_BARSEND_FM);
  wire barrecv_inc = (exe_r.instruction ==? `RV32_FENCE_OP) & (exe_r.instruction[31:28] == `RV32_BARRECV_FM);

  // Track bubbles in the EXE stage
  // and their associated PC
  logic [data_width_p-1:0] exe_bubble_pc_r;
  exe_bubble_type_e exe_bubble_r;
  logic is_exe_seq_lw, is_exe_seq_flw;

  vanilla_exe_bubble_classifier
    #(.pc_width_p(pc_width_lp)
      ,.data_width_p(data_width_p)
      )
  classifier
    (.*
     ,.exe_bubble_pc_o(exe_bubble_pc_r)
     ,.exe_bubble_type_o(exe_bubble_r)
     ,.is_exe_seq_lw_o(is_exe_seq_lw)
     ,.is_exe_seq_flw_o(is_exe_seq_flw)
     );


  // FP_EXE pc tracker (also for imul)
  logic [data_width_p-1:0] fp_exe_pc_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      fp_exe_pc_r <= '0;
    end
    else begin
      if (~stall_all & ~stall_id) begin
        fp_exe_pc_r <= id_pc;
      end  
    end
  end


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



  wire branch_miss_bubble_inc = (exe_bubble_r == e_exe_bubble_branch_miss);
  wire jalr_miss_bubble_inc = (exe_bubble_r == e_exe_bubble_jalr_miss);
  wire icache_miss_bubble_inc = (exe_bubble_r == e_exe_bubble_icache_miss);
  wire stall_depend_dram_load_inc = (exe_bubble_r == e_exe_bubble_stall_depend_dram);
  wire stall_depend_dram_seq_load_inc = (exe_bubble_r == e_exe_bubble_stall_depend_seq_dram);
  wire stall_depend_dram_amo_inc = (exe_bubble_r == e_exe_bubble_stall_depend_dram_amo);
  wire stall_depend_group_load_inc = (exe_bubble_r == e_exe_bubble_stall_depend_group);
  wire stall_depend_global_load_inc = (exe_bubble_r == e_exe_bubble_stall_depend_global);
  wire stall_depend_idiv_inc = (exe_bubble_r == e_exe_bubble_stall_depend_idiv);
  wire stall_depend_fdiv_inc = (exe_bubble_r == e_exe_bubble_stall_depend_fdiv);
  wire stall_depend_local_load_inc = (exe_bubble_r == e_exe_bubble_stall_depend_local_load);
  wire stall_depend_imul_inc = (exe_bubble_r == e_exe_bubble_stall_depend_imul);
  wire stall_amo_aq_inc = (exe_bubble_r == e_exe_bubble_stall_amo_aq);
  wire stall_amo_rl_inc = (exe_bubble_r == e_exe_bubble_stall_amo_rl);
  wire stall_bypass_inc = (exe_bubble_r == e_exe_bubble_stall_bypass);
  wire stall_lr_aq_inc = (exe_bubble_r == e_exe_bubble_stall_lr_aq);
  wire stall_fence_inc = (exe_bubble_r == e_exe_bubble_stall_fence);
  wire stall_remote_req_inc = (exe_bubble_r == e_exe_bubble_stall_remote_req);
  wire stall_remote_credit_inc = (exe_bubble_r == e_exe_bubble_stall_remote_credit);
  wire stall_fdiv_busy_inc = (exe_bubble_r == e_exe_bubble_stall_fdiv_busy);
  wire stall_idiv_busy_inc = (exe_bubble_r == e_exe_bubble_stall_idiv_busy);
  wire stall_fcsr_inc = (exe_bubble_r == e_exe_bubble_stall_fcsr);
  wire stall_barrier_inc = (exe_bubble_r == e_exe_bubble_stall_barrier);
  
  
  // profiling counters
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
    integer fmadd;
    integer fmsub;
    integer fnmsub;
    integer fnmadd;

    integer feq;
    integer flt;
    integer fle;
    integer fcvt_w_s;
    integer fcvt_wu_s;
    integer fclass;
    integer fmv_x_w;
    
    integer fdiv;
    integer fsqrt;

    integer local_ld;
    integer local_st;
    integer remote_ld_dram;
    integer remote_seq_ld_dram;
    integer remote_ld_global;
    integer remote_ld_group;
    integer remote_st_dram;
    integer remote_st_global;
    integer remote_st_group;

    integer local_flw;
    integer local_fsw;
    integer remote_flw_dram;
    integer remote_seq_flw_dram;
    integer remote_flw_global;
    integer remote_flw_group;
    integer remote_fsw_dram;
    integer remote_fsw_global;
    integer remote_fsw_group;

    integer icache_miss;
    integer lr;
    integer lr_aq;
    integer amoswap;
    integer amoor;
    integer amoadd;

    integer beq;
    integer bne;
    integer blt;
    integer bge;
    integer bltu;
    integer bgeu;
    integer jal;
    integer jalr;
    
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
    
    integer div;
    integer divu;
    integer rem;
    integer remu;
    integer mul;

    integer fence;
  
    integer csrrw;
    integer csrrs;
    integer csrrc;
    integer csrrwi;
    integer csrrsi;
    integer csrrci;
      
    integer barsend;
    integer barrecv;

    integer branch_miss_bubble;
    integer jalr_miss_bubble;
    integer icache_miss_bubble;
    integer stall_depend_dram_load;
    integer stall_depend_dram_seq_load;
    integer stall_depend_dram_amo;
    integer stall_depend_group_load;
    integer stall_depend_global_load;
    integer stall_depend_idiv;
    integer stall_depend_fdiv;
    integer stall_depend_local_load;
    integer stall_depend_imul;
    integer stall_amo_aq;
    integer stall_amo_rl;
    integer stall_bypass;
    integer stall_lr_aq;
    integer stall_fence;
    integer stall_remote_req;
    integer stall_remote_credit;
    integer stall_fdiv_busy;
    integer stall_idiv_busy;
    integer stall_fcsr;
    integer stall_barrier;

    integer stall_remote_ld_wb;
    integer stall_ifetch_wait;
    integer stall_remote_flw_wb;

  } vanilla_stat_s;

  vanilla_stat_s stat_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
         stat_r = '0;
    end
    else begin
      stat_r.cycle++;
         stat_r.instr = stat_r.instr + instr_inc + fp_instr_inc;

      if (stall_all) begin
        if (stall_remote_ld_wb) stat_r.stall_remote_ld_wb++;
        else if (stall_ifetch_wait) stat_r.stall_ifetch_wait++;
        else if (stall_remote_flw_wb) stat_r.stall_remote_flw_wb++;
      end
      else begin
        if (fadd_inc) stat_r.fadd++;
        else if (fsub_inc) stat_r.fsub++;
        else if (fmul_inc) stat_r.fmul++;
        else if (fsgnj_inc) stat_r.fsgnj++;
        else if (fsgnjn_inc) stat_r.fsgnjn++;
        else if (fsgnjx_inc) stat_r.fsgnjx++;
        else if (fmin_inc) stat_r.fmin++;
        else if (fmax_inc) stat_r.fmax++;
        else if (fcvt_s_w_inc) stat_r.fcvt_s_w++;
        else if (fcvt_s_wu_inc) stat_r.fcvt_s_wu++;
        else if (fmv_w_x_inc) stat_r.fmv_w_x++;
        else if (fmadd_inc) stat_r.fmadd++;
        else if (fmsub_inc) stat_r.fmsub++;
        else if (fnmsub_inc) stat_r.fnmsub++;
        else if (fnmadd_inc) stat_r.fnmadd++;
      
        else if (feq_inc) stat_r.feq++;
        else if (flt_inc) stat_r.flt++;
        else if (fle_inc) stat_r.fle++;
        else if (fcvt_w_s_inc) stat_r.fcvt_w_s++;
        else if (fcvt_wu_s_inc) stat_r.fcvt_wu_s++;
        else if (fclass_inc) stat_r.fclass++;
        else if (fmv_x_w_inc) stat_r.fmv_x_w++;

        else if (fdiv_inc) stat_r.fdiv++;
        else if (fsqrt_inc) stat_r.fsqrt++;

        else if (local_ld_inc) stat_r.local_ld++;
        else if (local_st_inc) stat_r.local_st++;
        else if (remote_ld_dram_inc & ~is_exe_seq_lw) stat_r.remote_ld_dram++;
        else if (remote_ld_dram_inc & is_exe_seq_lw) stat_r.remote_seq_ld_dram++;
        else if (remote_ld_global_inc) stat_r.remote_ld_global++;
        else if (remote_ld_group_inc) stat_r.remote_ld_group++;
        else if (remote_st_dram_inc) stat_r.remote_st_dram++;
        else if (remote_st_global_inc) stat_r.remote_st_global++;
        else if (remote_st_group_inc) stat_r.remote_st_group++;

        else if (local_flw_inc) stat_r.local_flw++;
        else if (local_fsw_inc) stat_r.local_fsw++;
        else if (remote_flw_dram_inc & ~is_exe_seq_flw) stat_r.remote_flw_dram++;
        else if (remote_flw_dram_inc & is_exe_seq_flw) stat_r.remote_seq_flw_dram++;
        else if (remote_flw_global_inc) stat_r.remote_flw_global++;
        else if (remote_flw_group_inc) stat_r.remote_flw_group++;
        else if (remote_fsw_dram_inc) stat_r.remote_fsw_dram++;
        else if (remote_fsw_global_inc) stat_r.remote_fsw_global++;
        else if (remote_fsw_group_inc) stat_r.remote_fsw_group++;

        else if (icache_miss_inc) stat_r.icache_miss++;
        else if (lr_inc) stat_r.lr++;
        else if (lr_aq_inc) stat_r.lr_aq++;
        else if (amoswap_inc) stat_r.amoswap++;
        else if (amoor_inc) stat_r.amoor++; 
        else if (amoadd_inc) stat_r.amoadd++; 

        else if (beq_inc) begin
          stat_r.beq++;
          if (beq_miss_inc) stat_r.beq_miss++;
        end
        else if (bne_inc) begin
          stat_r.bne++;
          if (bne_miss_inc) stat_r.bne_miss++;
        end
        else if (blt_inc) begin
          stat_r.blt++;
          if (blt_miss_inc) stat_r.blt_miss++;
        end
        else if (bge_inc) begin
          stat_r.bge++;
          if (bge_miss_inc) stat_r.bge_miss++;
        end
        else if (bltu_inc) begin
          stat_r.bltu++;
          if (bltu_miss_inc) stat_r.bltu_miss++;
        end
        else if (bgeu_inc) begin
          stat_r.bgeu++;
          if (bgeu_miss_inc) stat_r.bgeu_miss++;
        end
        else if (jal_inc) begin
          stat_r.jal++;
        end
        else if (jalr_inc) begin
          stat_r.jalr++;
          if (jalr_miss_inc) stat_r.jalr_miss++;
        end
     
        else if (sll_inc) stat_r.sll++; 
        else if (slli_inc) stat_r.slli++; 
        else if (srl_inc) stat_r.srl++; 
        else if (srli_inc) stat_r.srli++; 
        else if (sra_inc) stat_r.sra++; 
        else if (srai_inc) stat_r.srai++; 

        else if (add_inc) stat_r.add++;
        else if (addi_inc) stat_r.addi++;
        else if (sub_inc) stat_r.sub++;
        else if (lui_inc) stat_r.lui++;
        else if (auipc_inc) stat_r.auipc++;
        else if (xor_inc) stat_r.xor_++;
        else if (xori_inc) stat_r.xori++;
        else if (or_inc) stat_r.or_++;
        else if (ori_inc) stat_r.ori++;
        else if (and_inc) stat_r.and_++;
        else if (andi_inc) stat_r.andi++;
        else if (slt_inc) stat_r.slt++;
        else if (slti_inc) stat_r.slti++;
        else if (sltu_inc) stat_r.sltu++;
        else if (sltiu_inc) stat_r.sltiu++;

        else if (div_inc) stat_r.div++;
        else if (divu_inc) stat_r.divu++;
        else if (rem_inc) stat_r.rem++;
        else if (remu_inc) stat_r.remu++;
        else if (mul_inc) stat_r.mul++;

        else if (fence_inc) stat_r.fence++;

        else if (csrrw_inc) stat_r.csrrw++;
        else if (csrrs_inc) stat_r.csrrs++;
        else if (csrrc_inc) stat_r.csrrc++;
        else if (csrrwi_inc) stat_r.csrrwi++;
        else if (csrrsi_inc) stat_r.csrrsi++;
        else if (csrrci_inc) stat_r.csrrci++;

        else if (barsend_inc) stat_r.barsend++;
        else if (barrecv_inc) stat_r.barrecv++;

        else if (branch_miss_bubble_inc) stat_r.branch_miss_bubble++;
        else if (jalr_miss_bubble_inc) stat_r.jalr_miss_bubble++;
        else if (icache_miss_bubble_inc) stat_r.icache_miss_bubble++;
        else if (stall_depend_dram_load_inc) stat_r.stall_depend_dram_load++;
        else if (stall_depend_dram_seq_load_inc) stat_r.stall_depend_dram_seq_load++;
        else if (stall_depend_dram_amo_inc) stat_r.stall_depend_dram_amo++;
        else if (stall_depend_group_load_inc) stat_r.stall_depend_group_load++;
        else if (stall_depend_global_load_inc) stat_r.stall_depend_global_load++;
        else if (stall_depend_idiv_inc) stat_r.stall_depend_idiv++;
        else if (stall_depend_fdiv_inc) stat_r.stall_depend_fdiv++;
        else if (stall_depend_local_load_inc) stat_r.stall_depend_local_load++;
        else if (stall_depend_imul_inc) stat_r.stall_depend_imul++;
        else if (stall_amo_aq_inc) stat_r.stall_amo_aq++;
        else if (stall_amo_rl_inc) stat_r.stall_amo_rl++;
        else if (stall_bypass_inc) stat_r.stall_bypass++;
        else if (stall_lr_aq_inc) stat_r.stall_lr_aq++;
        else if (stall_fence_inc) stat_r.stall_fence++;
        else if (stall_remote_req_inc) stat_r.stall_remote_req++;
        else if (stall_remote_credit_inc) stat_r.stall_remote_credit++;
        else if (stall_fdiv_busy_inc) stat_r.stall_fdiv_busy++;
        else if (stall_idiv_busy_inc) stat_r.stall_idiv_busy++;
        else if (stall_fcsr_inc) stat_r.stall_fcsr++;
        else if (stall_barrier_inc) stat_r.stall_barrier++;

      end



    end
  end



  // file logging
  localparam string logfile_lp = "vanilla_stats.csv";
  localparam string tracefile_lp = "vanilla_operation_trace.csv";
  localparam string periodicfile_lp = "vanilla_periodic_stats.csv";

  integer fd;
  string header;
   initial begin
      fd = $fopen(logfile_lp, "w");
      $fwrite(fd,"");
      $fclose(fd);
      fd = $fopen(periodicfile_lp, "w");
      $fwrite(fd,"");
      $fclose(fd);
   end

  task print_header(input string filename);
      fd = $fopen(filename, "a");
      $fwrite(fd, "time,");
      $fwrite(fd, "x,");
      $fwrite(fd, "y,");
      $fwrite(fd, "pc_r,");
      $fwrite(fd, "pc_n,");
      $fwrite(fd, "tag,");
      $fwrite(fd, "global_ctr,");
      $fwrite(fd, "cycle,");
      $fwrite(fd, "instr_total,");

      $fwrite(fd, "instr_fadd,");
      $fwrite(fd, "instr_fsub,");
      $fwrite(fd, "instr_fmul,");
      $fwrite(fd, "instr_fsgnj,");
      $fwrite(fd, "instr_fsgnjn,");
      $fwrite(fd, "instr_fsgnjx,");
      $fwrite(fd, "instr_fmin,");
      $fwrite(fd, "instr_fmax,");
      $fwrite(fd, "instr_fcvt_s_w,");
      $fwrite(fd, "instr_fcvt_s_wu,");
      $fwrite(fd, "instr_fmv_w_x,");
      $fwrite(fd, "instr_fmadd,");
      $fwrite(fd, "instr_fmsub,");
      $fwrite(fd, "instr_fnmsub,");
      $fwrite(fd, "instr_fnmadd,");

      $fwrite(fd, "instr_feq,");
      $fwrite(fd, "instr_flt,");
      $fwrite(fd, "instr_fle,");
      $fwrite(fd, "instr_fcvt_w_s,");
      $fwrite(fd, "instr_fcvt_wu_s,");
      $fwrite(fd, "instr_fclass,");
      $fwrite(fd, "instr_fmv_x_w,");

      $fwrite(fd, "instr_fdiv,");
      $fwrite(fd, "instr_fsqrt,");

      $fwrite(fd, "instr_local_ld,");
      $fwrite(fd, "instr_local_st,");
      $fwrite(fd, "instr_remote_ld_dram,");
      $fwrite(fd, "instr_remote_seq_ld_dram,");
      $fwrite(fd, "instr_remote_ld_global,");
      $fwrite(fd, "instr_remote_ld_group,");
      $fwrite(fd, "instr_remote_st_dram,");
      $fwrite(fd, "instr_remote_st_global,");
      $fwrite(fd, "instr_remote_st_group,");
    
      $fwrite(fd, "instr_local_flw,");
      $fwrite(fd, "instr_local_fsw,");
      $fwrite(fd, "instr_remote_flw_dram,");
      $fwrite(fd, "instr_remote_seq_flw_dram,");
      $fwrite(fd, "instr_remote_flw_global,");
      $fwrite(fd, "instr_remote_flw_group,");
      $fwrite(fd, "instr_remote_fsw_dram,");
      $fwrite(fd, "instr_remote_fsw_global,");
      $fwrite(fd, "instr_remote_fsw_group,");

      $fwrite(fd, "miss_icache,");
      $fwrite(fd, "instr_lr,");
      $fwrite(fd, "instr_lr_aq,");
      $fwrite(fd, "instr_amoswap,");
      $fwrite(fd, "instr_amoor,");
      $fwrite(fd, "instr_amoadd,");

      $fwrite(fd, "instr_beq,");
      $fwrite(fd, "instr_bne,");
      $fwrite(fd, "instr_blt,");
      $fwrite(fd, "instr_bge,");
      $fwrite(fd, "instr_bltu,");
      $fwrite(fd, "instr_bgeu,");
      $fwrite(fd, "instr_jal,");
      $fwrite(fd, "instr_jalr,");

      $fwrite(fd, "miss_beq,");
      $fwrite(fd, "miss_bne,");
      $fwrite(fd, "miss_blt,");
      $fwrite(fd, "miss_bge,");
      $fwrite(fd, "miss_bltu,");
      $fwrite(fd, "miss_bgeu,");
      $fwrite(fd, "miss_jalr,");

      $fwrite(fd, "instr_sll,");
      $fwrite(fd, "instr_slli,");
      $fwrite(fd, "instr_srl,");
      $fwrite(fd, "instr_srli,");
      $fwrite(fd, "instr_sra,");
      $fwrite(fd, "instr_srai,");

      $fwrite(fd, "instr_add,");
      $fwrite(fd, "instr_addi,");
      $fwrite(fd, "instr_sub,");
      $fwrite(fd, "instr_lui,");
      $fwrite(fd, "instr_auipc,");
      $fwrite(fd, "instr_xor,");
      $fwrite(fd, "instr_xori,");
      $fwrite(fd, "instr_or,");
      $fwrite(fd, "instr_ori,");
      $fwrite(fd, "instr_and,");
      $fwrite(fd, "instr_andi,");

      $fwrite(fd, "instr_slt,");
      $fwrite(fd, "instr_slti,");
      $fwrite(fd, "instr_sltu,");
      $fwrite(fd, "instr_sltiu,");

      $fwrite(fd, "instr_div,");
      $fwrite(fd, "instr_divu,");
      $fwrite(fd, "instr_rem,");
      $fwrite(fd, "instr_remu,");
      $fwrite(fd, "instr_mul,");

      $fwrite(fd, "instr_fence,");

      $fwrite(fd, "instr_csrrw,");
      $fwrite(fd, "instr_csrrs,");
      $fwrite(fd, "instr_csrrc,");
      $fwrite(fd, "instr_csrrwi,");
      $fwrite(fd, "instr_csrrsi,");
      $fwrite(fd, "instr_csrrci,");

      $fwrite(fd, "instr_barsend,");
      $fwrite(fd, "instr_barrecv,");

      $fwrite(fd, "bubble_branch_miss,");
      $fwrite(fd, "bubble_jalr_miss,");
      $fwrite(fd, "bubble_icache_miss,");
      $fwrite(fd, "stall_depend_dram_load,");
      $fwrite(fd, "stall_depend_dram_seq_load,");
      $fwrite(fd, "stall_depend_dram_amo,");
      $fwrite(fd, "stall_depend_group_load,");
      $fwrite(fd, "stall_depend_global_load,");
      $fwrite(fd, "stall_depend_idiv,");
      $fwrite(fd, "stall_depend_fdiv,");
      $fwrite(fd, "stall_depend_local_load,");
      $fwrite(fd, "stall_depend_imul,");
      $fwrite(fd, "stall_amo_aq,");
      $fwrite(fd, "stall_amo_rl,");
      $fwrite(fd, "stall_bypass,");
      $fwrite(fd, "stall_lr_aq,");
      $fwrite(fd, "stall_fence,");
      $fwrite(fd, "stall_remote_req,");
      $fwrite(fd, "stall_remote_credit,");
      $fwrite(fd, "stall_fdiv_busy,");
      $fwrite(fd, "stall_idiv_busy,");
      $fwrite(fd, "stall_fcsr,");
      $fwrite(fd, "stall_barrier,");

      $fwrite(fd, "stall_remote_ld_wb,");
      $fwrite(fd, "stall_ifetch_wait,");
      $fwrite(fd, "stall_remote_flw_wb");
      $fwrite(fd, "\n");
      $fclose(fd);

  endtask

  task print_stat(input string filename);

          fd = $fopen(filename, "a");
          $fwrite(fd, "%0d,", $time);
          $fwrite(fd, "%0d,", global_x_i - origin_x_cord_p);
          $fwrite(fd, "%0d,", global_y_i - origin_y_cord_p);
          $fwrite(fd, "%0d,", pc_r);
          $fwrite(fd, "%0d,", pc_n);
          $fwrite(fd, "%0d,", print_stat_tag_i);
          $fwrite(fd, "%0d,", global_ctr_i);
          $fwrite(fd, "%0d,", stat_r.cycle );
          $fwrite(fd, "%0d,", stat_r.instr);

          $fwrite(fd, "%0d,", stat_r.fadd);
          $fwrite(fd, "%0d,", stat_r.fsub);
          $fwrite(fd, "%0d,", stat_r.fmul);
          $fwrite(fd, "%0d,", stat_r.fsgnj);
          $fwrite(fd, "%0d,", stat_r.fsgnjn);
          $fwrite(fd, "%0d,", stat_r.fsgnjx);
          $fwrite(fd, "%0d,", stat_r.fmin);
          $fwrite(fd, "%0d,", stat_r.fmax);
          $fwrite(fd, "%0d,", stat_r.fcvt_s_w);
          $fwrite(fd, "%0d,", stat_r.fcvt_s_wu);
          $fwrite(fd, "%0d,", stat_r.fmv_w_x);
          $fwrite(fd, "%0d,", stat_r.fmadd);
          $fwrite(fd, "%0d,", stat_r.fmsub);
          $fwrite(fd, "%0d,", stat_r.fnmsub);
          $fwrite(fd, "%0d,", stat_r.fnmadd);

          $fwrite(fd, "%0d,", stat_r.feq);
          $fwrite(fd, "%0d,", stat_r.flt);
          $fwrite(fd, "%0d,", stat_r.fle);
          $fwrite(fd, "%0d,", stat_r.fcvt_w_s);
          $fwrite(fd, "%0d,", stat_r.fcvt_wu_s);
          $fwrite(fd, "%0d,", stat_r.fclass);
          $fwrite(fd, "%0d,", stat_r.fmv_x_w);

          $fwrite(fd, "%0d,", stat_r.fdiv);
          $fwrite(fd, "%0d,", stat_r.fsqrt);

          $fwrite(fd, "%0d,", stat_r.local_ld);
          $fwrite(fd, "%0d,", stat_r.local_st);
          $fwrite(fd, "%0d,", stat_r.remote_ld_dram);
          $fwrite(fd, "%0d,", stat_r.remote_seq_ld_dram);
          $fwrite(fd, "%0d,", stat_r.remote_ld_global);
          $fwrite(fd, "%0d,", stat_r.remote_ld_group);
          $fwrite(fd, "%0d,", stat_r.remote_st_dram);
          $fwrite(fd, "%0d,", stat_r.remote_st_global);
          $fwrite(fd, "%0d,", stat_r.remote_st_group);

          $fwrite(fd, "%0d,", stat_r.local_flw);
          $fwrite(fd, "%0d,", stat_r.local_fsw);
          $fwrite(fd, "%0d,", stat_r.remote_flw_dram);
          $fwrite(fd, "%0d,", stat_r.remote_seq_flw_dram);
          $fwrite(fd, "%0d,", stat_r.remote_flw_global);
          $fwrite(fd, "%0d,", stat_r.remote_flw_group);
          $fwrite(fd, "%0d,", stat_r.remote_fsw_dram);
          $fwrite(fd, "%0d,", stat_r.remote_fsw_global);
          $fwrite(fd, "%0d,", stat_r.remote_fsw_group);

          $fwrite(fd, "%0d,", stat_r.icache_miss);
          $fwrite(fd, "%0d,", stat_r.lr);
          $fwrite(fd, "%0d,", stat_r.lr_aq);
          $fwrite(fd, "%0d,", stat_r.amoswap);
          $fwrite(fd, "%0d,", stat_r.amoor);
          $fwrite(fd, "%0d,", stat_r.amoadd);

          $fwrite(fd, "%0d,", stat_r.beq);
          $fwrite(fd, "%0d,", stat_r.bne);
          $fwrite(fd, "%0d,", stat_r.blt);
          $fwrite(fd, "%0d,", stat_r.bge);
          $fwrite(fd, "%0d,", stat_r.bltu);
          $fwrite(fd, "%0d,", stat_r.bgeu);
          $fwrite(fd, "%0d,", stat_r.jal);
          $fwrite(fd, "%0d,", stat_r.jalr);
          
          $fwrite(fd, "%0d,", stat_r.beq_miss);
          $fwrite(fd, "%0d,", stat_r.bne_miss);
          $fwrite(fd, "%0d,", stat_r.blt_miss);
          $fwrite(fd, "%0d,", stat_r.bge_miss);
          $fwrite(fd, "%0d,", stat_r.bltu_miss);
          $fwrite(fd, "%0d,", stat_r.bgeu_miss);
          $fwrite(fd, "%0d,", stat_r.jalr_miss);

          $fwrite(fd, "%0d,", stat_r.sll);
          $fwrite(fd, "%0d,", stat_r.slli);
          $fwrite(fd, "%0d,", stat_r.srl);
          $fwrite(fd, "%0d,", stat_r.srli);
          $fwrite(fd, "%0d,", stat_r.sra);
          $fwrite(fd, "%0d,", stat_r.srai);

          $fwrite(fd, "%0d,", stat_r.add);
          $fwrite(fd, "%0d,", stat_r.addi);
          $fwrite(fd, "%0d,", stat_r.sub);
          $fwrite(fd, "%0d,", stat_r.lui);
          $fwrite(fd, "%0d,", stat_r.auipc);
          $fwrite(fd, "%0d,", stat_r.xor_);
          $fwrite(fd, "%0d,", stat_r.xori);
          $fwrite(fd, "%0d,", stat_r.or_);
          $fwrite(fd, "%0d,", stat_r.ori);
          $fwrite(fd, "%0d,", stat_r.and_);
          $fwrite(fd, "%0d,", stat_r.andi);

          $fwrite(fd, "%0d,", stat_r.slt);
          $fwrite(fd, "%0d,", stat_r.slti);
          $fwrite(fd, "%0d,", stat_r.sltu);
          $fwrite(fd, "%0d,", stat_r.sltiu);

          $fwrite(fd, "%0d,", stat_r.div);
          $fwrite(fd, "%0d,", stat_r.divu);
          $fwrite(fd, "%0d,", stat_r.rem);
          $fwrite(fd, "%0d,", stat_r.remu);
          $fwrite(fd, "%0d,", stat_r.mul);

          $fwrite(fd, "%0d,", stat_r.fence);

          $fwrite(fd, "%0d,", stat_r.csrrw);
          $fwrite(fd, "%0d,", stat_r.csrrs);
          $fwrite(fd, "%0d,", stat_r.csrrc);
          $fwrite(fd, "%0d,", stat_r.csrrwi);
          $fwrite(fd, "%0d,", stat_r.csrrsi);
          $fwrite(fd, "%0d,", stat_r.csrrci);

          $fwrite(fd, "%0d,", stat_r.barsend);
          $fwrite(fd, "%0d,", stat_r.barrecv);
   
          $fwrite(fd, "%0d,", stat_r.branch_miss_bubble); 
          $fwrite(fd, "%0d,", stat_r.jalr_miss_bubble); 
          $fwrite(fd, "%0d,", stat_r.icache_miss_bubble); 
          $fwrite(fd, "%0d,", stat_r.stall_depend_dram_load); 
          $fwrite(fd, "%0d,", stat_r.stall_depend_dram_seq_load);
          $fwrite(fd, "%0d,", stat_r.stall_depend_dram_amo);   
          $fwrite(fd, "%0d,", stat_r.stall_depend_group_load);   
          $fwrite(fd, "%0d,", stat_r.stall_depend_global_load);   
          $fwrite(fd, "%0d,", stat_r.stall_depend_idiv);
          $fwrite(fd, "%0d,", stat_r.stall_depend_fdiv);
          $fwrite(fd, "%0d,", stat_r.stall_depend_local_load);
          $fwrite(fd, "%0d,", stat_r.stall_depend_imul);
          $fwrite(fd, "%0d,", stat_r.stall_amo_aq);
          $fwrite(fd, "%0d,", stat_r.stall_amo_rl);
          $fwrite(fd, "%0d,", stat_r.stall_bypass);
          $fwrite(fd, "%0d,", stat_r.stall_lr_aq);
          $fwrite(fd, "%0d,", stat_r.stall_fence);
          $fwrite(fd, "%0d,", stat_r.stall_remote_req);
          $fwrite(fd, "%0d,", stat_r.stall_remote_credit);
          $fwrite(fd, "%0d,", stat_r.stall_fdiv_busy);
          $fwrite(fd, "%0d,", stat_r.stall_idiv_busy);
          $fwrite(fd, "%0d,", stat_r.stall_fcsr);
          $fwrite(fd, "%0d,", stat_r.stall_barrier);
    
          $fwrite(fd, "%0d,", stat_r.stall_remote_ld_wb);
          $fwrite(fd, "%0d,", stat_r.stall_ifetch_wait);
          $fwrite(fd, "%0d\n", stat_r.stall_remote_flw_wb);

          $fclose(fd);
  endtask


   always @(negedge reset_i) begin      
    // the origin tile opens the logfile and writes the csv header.
    if ((global_x_i == x_cord_width_p'(origin_x_cord_p)) & (global_y_i == y_cord_width_p'(origin_y_cord_p))) begin
      print_header(logfile_lp);
      print_header(periodicfile_lp);
    end
   end
   


   always @(negedge clk_i)  begin
        // stat printing
        if (~reset_i & print_stat_v_i & print_stat_tag.y_cord == (global_y_i) & print_stat_tag.x_cord == (global_x_i)) begin
          $display("[BSG_INFO][VCORE_PROFILER] t=%0t x,y=%02d,%02d printing stats.", $time, global_x_i, global_y_i);
          print_stat(logfile_lp);
        end
      
     
        // trace logging
        if (~reset_i & trace_en_i) begin

          if (fadd_inc) print_operation_trace("fadd", fp_exe_pc_r);
          else if (fsub_inc) print_operation_trace("fsub", fp_exe_pc_r);
          else if (fmul_inc) print_operation_trace("fmul", fp_exe_pc_r);
          else if (fsgnj_inc) print_operation_trace("fsgnj", fp_exe_pc_r);
          else if (fsgnjn_inc) print_operation_trace("fsgnjn", fp_exe_pc_r);
          else if (fsgnjx_inc) print_operation_trace("fsgnjx", fp_exe_pc_r);
          else if (fmin_inc) print_operation_trace("fmin", fp_exe_pc_r);
          else if (fmax_inc) print_operation_trace("fmax", fp_exe_pc_r);
          else if (fcvt_s_w_inc) print_operation_trace("fcvt_s_w", fp_exe_pc_r);
          else if (fcvt_s_wu_inc) print_operation_trace("fcvt_s_wu", fp_exe_pc_r);
          else if (fmv_w_x_inc) print_operation_trace("fmv_w_x", fp_exe_pc_r);
          else if (fmadd_inc) print_operation_trace("fmadd", fp_exe_pc_r);
          else if (fmsub_inc) print_operation_trace("fmsub", fp_exe_pc_r);
          else if (fnmsub_inc) print_operation_trace("fnmsub", fp_exe_pc_r);
          else if (fnmadd_inc) print_operation_trace("fnmadd", fp_exe_pc_r);

          else if (feq_inc) print_operation_trace("feq", exe_pc);
          else if (flt_inc) print_operation_trace("flt", exe_pc);
          else if (fle_inc) print_operation_trace("fle", exe_pc);
          else if (fcvt_w_s_inc) print_operation_trace("fcvt_w_s", exe_pc);
          else if (fcvt_wu_s_inc) print_operation_trace("fcvt_wu_s", exe_pc);
          else if (fclass_inc) print_operation_trace("fclass", exe_pc);
          else if (fmv_x_w_inc) print_operation_trace("fmv_x_w", exe_pc);

          else if (fdiv_inc) print_operation_trace("fdiv", exe_pc);
          else if (fsqrt_inc) print_operation_trace("fsqrt", exe_pc);

          else if (local_ld_inc) print_operation_trace("local_ld", exe_pc);
          else if (local_st_inc) print_operation_trace("local_st", exe_pc);
          else if (remote_ld_dram_inc) print_operation_trace("remote_ld_dram", exe_pc);
          else if (remote_ld_global_inc) print_operation_trace("remote_ld_global", exe_pc);
          else if (remote_ld_group_inc) print_operation_trace("remote_ld_group", exe_pc);
          else if (remote_st_dram_inc) print_operation_trace("remote_st_dram", exe_pc);
          else if (remote_st_global_inc) print_operation_trace("remote_st_global", exe_pc);
          else if (remote_st_group_inc) print_operation_trace("remote_st_group", exe_pc);

          else if (local_flw_inc) print_operation_trace("local_flw", exe_pc);
          else if (local_fsw_inc) print_operation_trace("local_fsw", exe_pc);
          else if (remote_flw_dram_inc) print_operation_trace("remote_flw_dram", exe_pc);
          else if (remote_flw_global_inc) print_operation_trace("remote_flw_global", exe_pc);
          else if (remote_flw_group_inc) print_operation_trace("remote_flw_group", exe_pc);
          else if (remote_fsw_dram_inc) print_operation_trace("remote_fsw_dram", exe_pc);
          else if (remote_fsw_global_inc) print_operation_trace("remote_fsw_global", exe_pc);
          else if (remote_fsw_group_inc) print_operation_trace("remote_fsw_group", exe_pc);

          else if (icache_miss_inc) print_operation_trace("icache_miss", exe_pc);
          else if (lr_inc) print_operation_trace("lr", exe_pc);
          else if (lr_aq_inc) print_operation_trace("lr_aq", exe_pc);
          else if (amoswap_inc) print_operation_trace("amoswap", exe_pc);
          else if (amoor_inc) print_operation_trace("amoor", exe_pc); 
          else if (amoadd_inc) print_operation_trace("amoadd", exe_pc); 

          else if (beq_inc) print_operation_trace("beq", exe_pc);
          else if (bne_inc) print_operation_trace("bne", exe_pc);
          else if (blt_inc) print_operation_trace("blt", exe_pc);
          else if (bge_inc) print_operation_trace("bge", exe_pc);
          else if (bltu_inc) print_operation_trace("bltu", exe_pc);
          else if (bgeu_inc) print_operation_trace("bgeu", exe_pc);
          else if (jal_inc) print_operation_trace("jal", exe_pc);
          else if (jalr_inc) print_operation_trace("jalr", exe_pc);

          else if (beq_miss_inc) print_operation_trace("beq_miss", exe_pc);
          else if (bne_miss_inc) print_operation_trace("bne_miss", exe_pc);
          else if (blt_miss_inc) print_operation_trace("blt_miss", exe_pc);
          else if (bge_miss_inc) print_operation_trace("bge_miss", exe_pc);
          else if (bltu_miss_inc) print_operation_trace("bltu_miss", exe_pc);
          else if (bgeu_miss_inc) print_operation_trace("bgeu_miss", exe_pc);
          else if (jalr_miss_inc) print_operation_trace("jalr_miss", exe_pc);
     
          else if (sll_inc) print_operation_trace("sll", exe_pc); 
          else if (slli_inc) print_operation_trace("slli", exe_pc); 
          else if (srl_inc) print_operation_trace("srl", exe_pc); 
          else if (srli_inc) print_operation_trace("srli", exe_pc); 
          else if (sra_inc) print_operation_trace("sra", exe_pc); 
          else if (srai_inc) print_operation_trace("srai", exe_pc); 

          else if (add_inc) print_operation_trace("add", exe_pc);
          else if (addi_inc) print_operation_trace("addi", exe_pc);
          else if (sub_inc) print_operation_trace("sub", exe_pc);
          else if (lui_inc) print_operation_trace("lui", exe_pc);
          else if (auipc_inc) print_operation_trace("auipc", exe_pc);
          else if (xor_inc) print_operation_trace("xor", exe_pc);
          else if (xori_inc) print_operation_trace("xori", exe_pc);
          else if (or_inc) print_operation_trace("or", exe_pc);
          else if (ori_inc) print_operation_trace("ori", exe_pc);
          else if (and_inc) print_operation_trace("and", exe_pc);
          else if (andi_inc) print_operation_trace("andi", exe_pc);
          else if (slt_inc) print_operation_trace("slt", exe_pc);
          else if (slti_inc) print_operation_trace("slti", exe_pc);
          else if (sltu_inc) print_operation_trace("sltu", exe_pc);
          else if (sltiu_inc) print_operation_trace("sltiu", exe_pc);

          else if (div_inc) print_operation_trace("div", exe_pc);
          else if (divu_inc) print_operation_trace("divu", exe_pc);
          else if (rem_inc) print_operation_trace("rem", exe_pc);
          else if (remu_inc) print_operation_trace("remu", exe_pc);
          else if (mul_inc) print_operation_trace("mul", exe_pc);

          else if (fence_inc) print_operation_trace("fence", exe_pc);

          else if (csrrw_inc) print_operation_trace("csrrw", exe_pc);
          else if (csrrs_inc) print_operation_trace("csrrs", exe_pc);
          else if (csrrc_inc) print_operation_trace("csrrc", exe_pc);
          else if (csrrwi_inc) print_operation_trace("csrrwi", exe_pc);
          else if (csrrsi_inc) print_operation_trace("csrrsi", exe_pc);
          else if (csrrci_inc) print_operation_trace("csrrci", exe_pc);

          else if (barsend_inc) print_operation_trace("barsend", exe_pc);
          else if (barrecv_inc) print_operation_trace("barrecv", exe_pc);

          // Traces that can be attributed to stall_all should have higher priority of being printed
          // than stall_id, flush traces.
          else if (stall_remote_ld_wb) print_operation_trace("stall_remote_ld_wb", exe_pc);
          else if (stall_ifetch_wait) print_operation_trace("stall_ifetch_wait", exe_pc);
          else if (stall_remote_flw_wb) print_operation_trace("stall_remote_flw_wb", exe_pc);

          // flush/bubble, stall_id traces
          else if (branch_miss_bubble_inc) print_operation_trace("bubble_branch_miss", exe_bubble_pc_r);
          else if (jalr_miss_bubble_inc) print_operation_trace("bubble_jalr_miss", exe_bubble_pc_r);
          else if (icache_miss_bubble_inc) print_operation_trace("bubble_icache_miss", exe_bubble_pc_r);
          else if (stall_depend_dram_load_inc) print_operation_trace("stall_depend_dram_load", exe_bubble_pc_r);
          else if (stall_depend_dram_seq_load_inc) print_operation_trace("stall_depend_dram_seq_load", exe_bubble_pc_r);
          else if (stall_depend_dram_amo_inc) print_operation_trace("stall_depend_dram_amo", exe_bubble_pc_r);
          else if (stall_depend_group_load_inc) print_operation_trace("stall_depend_group_load", exe_bubble_pc_r);
          else if (stall_depend_global_load_inc) print_operation_trace("stall_depend_global_load", exe_bubble_pc_r);
          else if (stall_depend_idiv_inc) print_operation_trace("stall_depend_idiv", exe_bubble_pc_r);
          else if (stall_depend_fdiv_inc) print_operation_trace("stall_depend_fdiv", exe_bubble_pc_r);
          else if (stall_depend_local_load_inc) print_operation_trace("stall_depend_local_load", exe_bubble_pc_r);
          else if (stall_depend_imul_inc) print_operation_trace("stall_depend_imul", exe_bubble_pc_r);
          else if (stall_amo_aq_inc) print_operation_trace("stall_amo_aq", exe_bubble_pc_r);
          else if (stall_amo_rl_inc) print_operation_trace("stall_amo_rl", exe_bubble_pc_r);
          else if (stall_bypass_inc) print_operation_trace("stall_bypass", exe_bubble_pc_r);
          else if (stall_lr_aq_inc) print_operation_trace("stall_lr_aq", exe_bubble_pc_r);
          else if (stall_fence_inc) print_operation_trace("stall_fence", exe_bubble_pc_r);
          else if (stall_remote_req_inc) print_operation_trace("stall_remote_req", exe_bubble_pc_r);
          else if (stall_remote_credit_inc) print_operation_trace("stall_remote_credit", exe_bubble_pc_r);
          else if (stall_fdiv_busy_inc) print_operation_trace("stall_fdiv_busy", exe_bubble_pc_r);
          else if (stall_idiv_busy_inc) print_operation_trace("stall_idiv_busy", exe_bubble_pc_r);
          else if (stall_fcsr_inc) print_operation_trace("stall_fcsr", exe_bubble_pc_r);
          else if (stall_barrier_inc) print_operation_trace("stall_barrier", exe_bubble_pc_r);
          else print_operation_trace("unknown", 0);

        end
   end // always @ (negedge clk_i)


  // periodic stat;
  logic kernel_start_received_r;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      kernel_start_received_r <= 1'b0;
    end
    else begin
      if (print_stat_v_i && print_stat_tag_i[31:30] == 2'b10) begin
        kernel_start_received_r <= 1'b1;
      end
    end
  end

  always @ (negedge clk_i) begin
    if ((reset_i === 1'b0) && kernel_start_received_r && ((global_ctr_i % period_p) == 0)) begin
          print_stat(periodicfile_lp);
    end
  end


   // DPI Profiler interface. See interface comments below.
   export "DPI-C" function bsg_dpi_init;
   export "DPI-C" function bsg_dpi_fini;
   export "DPI-C" function bsg_dpi_vanilla_core_profiler_is_window;
   export "DPI-C" function bsg_dpi_vanilla_core_profiler_get_instr_count;

   // We track the polarity of the current edge so that we can call
   // $fatal when credits_get_cur is called during the wrong phase
   // of clk_i.
   logic edgepol_l;
   always @(posedge clk_i or negedge clk_i) begin
      edgepol_l <= clk_i;
   end

   // We use init_l to track whether the module has been
   // initialized by C/C++.
   logic init_l;
   initial begin
      init_l = 0;
      $display("BSG INFO: Profiler %M");
      
   end

   // Initialize this Manycore DPI Interface
   function void bsg_dpi_init();
      if(init_l)
        $fatal(1, "BSG ERROR (%M): init() already called");

      init_l = 1;
   endfunction

   // Terminate this Manycore DPI Interface
   function void bsg_dpi_fini();
      if(~init_l)
        $fatal(1, "BSG ERROR (%M): fini() already called");

      init_l = 0;
   endfunction

   // The function vanilla_core_profiler_is_window returns true if the
   // interface is in a valid time-window to call
   // vanilla_core_profiler_* functions
   function bit bsg_dpi_vanilla_core_profiler_is_window();
      if(reset_i)
        $display("BSG_WARN: bsg_dpi_vanilla_core_profiler called while tile is in reset");

      // Originally, this was : 
      //     return (clk_i & edgepol_l & ~reset_i);
      //
      // However, in delay based simulation environments (i.e. VCS)
      // where # is supported, it is possible to call this method at
      // strange times.
      return (~reset_i);
   endfunction

   // Instruction class queries that are supported by the
   // get_instr_count method
   typedef enum int {
        e_instr_float = 0
        ,e_instr_int = 1
        ,e_instr_all = 2
    } dpi_instr_type_e;

   // Return the number of instructions executed for a particular
   // class of instructions. The supported classes of instructions are
   // indicated in dpi_instr_type_e.
   function void bsg_dpi_vanilla_core_profiler_get_instr_count(input dpi_instr_type_e itype, output int count);
      if(init_l === 0) begin
         $fatal(1, "BSG ERROR (%M): get_instr_count() called before init()");
      end

      if(reset_i === 1) begin
         $fatal(1, "BSG ERROR (%M): get_instr_count() called while reset_i === 1");
      end

      /* See comment in is_window, above. Keeping for posterity.
      if(clk_i === 0) begin
         $fatal(1, "BSG ERROR (%M): get_instr_count() must be called when clk_i == 1");
      end

      if(edgepol_l === 0) begin
         $fatal(1, "BSG ERROR (%M): get_instr_count() must be called after the positive edge of clk_i has been evaluated");
      end
       */
      case (itype)
        e_instr_float: begin
           // Return the total number of floating point operations
           // performed to this point.
           count = stat_r.fadd + stat_r.fsub + stat_r.fmul + stat_r.fdiv +
                   stat_r.fsgnj + stat_r.fsgnjn + stat_r.fsgnjx +
                   stat_r.fmin + stat_r.fmax +
                   stat_r.fcvt_s_w + stat_r.fcvt_s_wu +
                   stat_r.fcvt_w_s + stat_r.fcvt_wu_s +
                   stat_r.fmv_w_x + stat_r.fmv_x_w +
                   2 * stat_r.fmadd + // Fused multiply-add counts as two instructions in FLOP statistics
                   stat_r.fmsub + stat_r.fnmsub + stat_r.fnmadd +
                   stat_r.feq + stat_r.flt + stat_r.fle +
                   stat_r.fclass +
                   stat_r.fsqrt;
        end
        e_instr_int: begin
           // Return the total number of integer operations performed
           // to this point
           count = stat_r.sll + stat_r.slli + stat_r.srl + stat_r.srli + stat_r.sra + stat_r.srai +
                   stat_r.add + stat_r.addi + stat_r.sub +
                   stat_r.lui + stat_r.auipc +
                   stat_r.xor_ + stat_r.xori +
                   stat_r.or_ + stat_r.ori +
                   stat_r.and_ + stat_r.andi +
                   stat_r.slt + stat_r.slti + stat_r.sltu + stat_r.sltiu +
                   stat_r.div + stat_r.divu + stat_r.rem + stat_r.remu + stat_r.mul;
        end
        e_instr_all: begin
           // Return the total number of instructions executed to this
           // point. "all" != "float" + "integer", since neither
           // "float" nor "integer" includes overhead and control
           // instructions like jumps and branches.
           count = stat_r.instr;
        end

        default:
          $fatal(1, "BSG ERROR (%M%t): Unrecongnized instruction count type: %d", $time, itype);
      endcase

      return;
   endfunction

endmodule

`BSG_ABSTRACT_MODULE(vanilla_core_profiler)

