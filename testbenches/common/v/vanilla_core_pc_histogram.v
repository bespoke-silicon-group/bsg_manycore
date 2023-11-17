`include "bsg_manycore_defines.svh"
`include "bsg_vanilla_defines.svh"

module vanilla_core_pc_histogram
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  import bsg_manycore_profile_pkg::*;
  import vanilla_exe_bubble_classifier_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    ,parameter `BSG_INV_PARAM(y_cord_width_p)
    ,parameter `BSG_INV_PARAM(data_width_p)
    ,parameter `BSG_INV_PARAM(icache_tag_width_p)
    ,parameter `BSG_INV_PARAM(icache_entries_p)
    ,parameter `BSG_INV_PARAM(origin_x_cord_p)
    ,parameter `BSG_INV_PARAM(origin_y_cord_p)
    ,parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    ,parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    ,parameter reg_els_lp=RV32_reg_els_gp
    ,parameter reg_addr_width_lp=RV32_reg_addr_width_gp
    )
  (
   input clk_i
   , input reset_i

   , input [pc_width_lp-1:0] pc_r
   , input [pc_width_lp-1:0] pc_n

   , input [data_width_p-1:0] if_pc
   , input [data_width_p-1:0] id_pc
   , input [data_width_p-1:0] exe_pc
   , input instruction_s instruction
   , input decode_s decode

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

   , input stall_icache_store
   , input stall_remote_ld_wb
   , input stall_ifetch_wait
   , input stall_remote_flw_wb

   , input branch_mispredict
   , input jalr_mispredict

   , input [data_width_p-1:0] rs1_val_to_exe
   , input [RV32_Iimm_width_gp-1:0] mem_addr_op2

   , input int_sb_clear
   , input float_sb_clear
   , input [reg_addr_width_lp-1:0] int_sb_clear_id
   , input [reg_addr_width_lp-1:0] float_sb_clear_id

   , input id_signals_s id_r
   , input exe_signals_s exe_r
   , input fp_exe_ctrl_signals_s fp_exe_ctrl_r

   , input [x_cord_width_p-1:0] global_x_i
   , input [y_cord_width_p-1:0] global_y_i
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

  /////////
  // DPI //
  /////////
  import "DPI-C" context function
    chandle vanilla_core_pc_hist_new();
  import "DPI-C" context function
    void vanilla_core_pc_hist_set_instance_name
      (chandle pc_hist_vptr
       ,int x
       ,int y
       );
  import "DPI-C" context function
    void vanilla_core_pc_hist_increment
      (chandle pc_hist_vptr
       ,int pc
       ,int operation
       );
  import "DPI-C" context function
    void vanilla_core_pc_hist_register_operation
      (chandle pc_hist_vptr
       ,int operation
       ,string operation_name
       );
  import "DPI-C" context function
    void vanilla_core_pc_hist_del(chandle pc_hist_vptr);

  typedef enum bit [31:0] {
    e_instr
    ,e_fp_instr
    ,e_icache_miss
    ,e_stall_icache_store
    ,e_stall_remote_ld_wb
    ,e_stall_remote_flw_wb
    ,e_stall_ifetch_wait
    ,e_branch_miss
    ,e_jalr_miss
    ,e_icache_miss_bubble
    ,e_stall_depend_dram
    ,e_stall_depend_seq_dram
    ,e_stall_depend_dram_amo
    ,e_stall_depend_global
    ,e_stall_depend_group
    ,e_stall_depend_fdiv
    ,e_stall_depend_idiv
    ,e_stall_depend_local_load
    ,e_stall_depend_imul
    ,e_stall_amo_aq
    ,e_stall_amo_rl
    ,e_stall_bypass
    ,e_stall_lr_aq
    ,e_stall_fence
    ,e_stall_remote_req
    ,e_stall_remote_credit
    ,e_stall_fdiv_busy
    ,e_stall_idiv_busy
    ,e_stall_fcsr
    ,e_stall_barrier
    ,e_unknown
  } pc_state_e;

  // initialize dpi module
  chandle pc_hist_vptr;
  initial
    begin
      pc_hist_vptr = vanilla_core_pc_hist_new();
      // define states
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_instr, "instr");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_fp_instr, "fp_instr");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_icache_miss, "icache_miss");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_icache_store, "stall_icache_store");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_remote_ld_wb, "stall_remote_ld_wb");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_remote_flw_wb, "stall_remote_flw_wb");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_ifetch_wait, "stall_ifetch_wait");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_branch_miss, "branch_miss");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_jalr_miss, "jalr_miss");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_icache_miss_bubble, "icache_miss_bubble");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_dram, "stall_depend_dram");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_seq_dram, "stall_depend_seq_dram");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_dram_amo, "stall_depend_dram_amo");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_global, "stall_depend_global");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_group, "stall_depend_group");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_fdiv, "stall_depend_fdiv");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_idiv, "stall_depend_idiv");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_local_load, "stall_depend_local_load");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_depend_imul, "stall_depend_imul");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_amo_aq, "stall_amo_aq");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_amo_rl, "stall_amo_rl");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_bypass, "stall_bypass");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_lr_aq, "stall_lr_aq");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_fence, "stall_fence");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_remote_req, "stall_remote_req");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_remote_credit, "stall_remote_credit");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_fdiv_busy, "stall_fdiv_busy");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_idiv_busy, "stall_idiv_busy");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_fcsr, "stall_fcsr");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_stall_barrier, "stall_barrier");
      vanilla_core_pc_hist_register_operation(pc_hist_vptr, e_unknown, "unknown");
    end

  // cleanup dpi module
  final
    begin
      vanilla_core_pc_hist_del(pc_hist_vptr);
    end

  always @(negedge reset_i) begin
    vanilla_core_pc_hist_set_instance_name
      (pc_hist_vptr
       , global_x_i
       , global_y_i
       );
  end

  exe_bubble_type_e exe_bubble_type;
  logic [pc_width_lp-1:0] exe_bubble_pc;

  vanilla_exe_bubble_classifier
    #(.pc_width_p(pc_width_lp)
      ,.data_width_p(data_width_p)
      )
  stall_class
    (.*
     ,.exe_bubble_pc_o(exe_bubble_pc)
     ,.exe_bubble_type_o(exe_bubble_type)
     ,.is_exe_seq_lw_o()
     ,.is_exe_seq_flw_o()
     );

  // MEM stage pc tracker
  logic [data_width_p-1:0] mem_pc_r;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mem_pc_r <= '0;
    end
    else begin
      if (~stall_all & (exe_bubble_type == e_exe_no_bubble)) begin
        mem_pc_r <= exe_pc;
      end
    end
  end

  // event signals
  wire instr_inc = ~(stall_all) & (exe_r.instruction != '0) & ~exe_r.icache_miss;
  wire fp_instr_inc = (fp_exe_ctrl_r.fp_decode.is_fpu_float_op
                       | fp_exe_ctrl_r.fp_decode.is_fpu_int_op
                       | fp_exe_ctrl_r.fp_decode.is_fdiv_op
                       | fp_exe_ctrl_r.fp_decode.is_fsqrt_op)
       & ~stall_all;

  always @(negedge clk_i) begin
    if (~reset_i) begin
      if (instr_inc) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr, exe_pc, e_instr);
      end
      else if (fp_instr_inc) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr, fp_exe_pc_r, e_fp_instr);
      end
      else if ( exe_r.icache_miss) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_pc,  e_icache_miss);
      end
      // TODO: we should report a more informative PC than exe_pc for
      // icache_store, remote_lw_wb, and remote_flw_wb
      else if ( stall_all & stall_icache_store) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_pc,  e_stall_icache_store);
      end
      else if ( stall_all & stall_remote_ld_wb) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_pc,  e_stall_remote_ld_wb);
      end
      else if ( stall_all & stall_remote_flw_wb) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_pc,  e_stall_remote_flw_wb);
      end
      else if ( stall_all & stall_ifetch_wait) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  mem_pc_r,  e_stall_ifetch_wait);
      end
      // stalls that originate in id stage or exe stage
      else if ( exe_bubble_type == e_exe_bubble_branch_miss) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_branch_miss);
      end
      else if ( exe_bubble_type == e_exe_bubble_jalr_miss) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_jalr_miss);
      end
      else if ( exe_bubble_type == e_exe_bubble_icache_miss) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_icache_miss_bubble);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_dram) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_dram);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_seq_dram) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_seq_dram);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_dram_amo) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_dram_amo);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_global) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_global);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_group) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_group);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_fdiv) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_fdiv);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_idiv) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_idiv);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_local_load) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_local_load);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_depend_imul) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_depend_imul);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_amo_aq) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_amo_aq);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_amo_rl) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_amo_rl);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_bypass) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_bypass);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_lr_aq) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_lr_aq);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_fence) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_fence);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_remote_req) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_remote_req);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_remote_credit) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_remote_credit);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_fdiv_busy) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_fdiv_busy);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_idiv_busy) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_idiv_busy);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_fcsr) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_fcsr);
      end
      else if ( exe_bubble_type == e_exe_bubble_stall_barrier) begin
        vanilla_core_pc_hist_increment(pc_hist_vptr,  exe_bubble_pc,  e_stall_barrier);
      end
      else begin
        vanilla_core_pc_hist_increment(pc_hist_vptr, exe_pc, e_unknown);
      end
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(vanilla_core_pc_histogram)
