`include "bsg_manycore_defines.vh"
`include "bsg_vanilla_defines.vh"

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
    chandle vanilla_core_pc_hist_set_instance_name
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
    ,e_stall
    ,e_unknown
  } pc_state_e;

  // initialize dpi module
  chandle pc_hist_vptr;
  initial
    begin
      pc_hist_vptr = vanilla_core_pc_hist_new();
      // define states
      vanilla_core_pc_hist_register_operation
        (pc_hist_vptr
         ,e_instr
         ,"instr"
         );
      vanilla_core_pc_hist_register_operation
        (pc_hist_vptr
         ,e_fp_instr
         ,"fp_instr"
         );
      vanilla_core_pc_hist_register_operation
        (pc_hist_vptr
         ,e_stall
         ,"stall"
         );
      vanilla_core_pc_hist_register_operation
        (pc_hist_vptr
         ,e_unknown
         ,"unknown"
         );
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
     );
  
  
  // event signals
  wire instr_inc = ~(stall_all) * (exe_r.instruction != '0) & ~exe_r.icache_miss;
  wire fp_instr_inc = (fp_exe_ctrl_r.fp_decode.is_fpu_float_op
                       | fp_exe_ctrl_r.fp_decode.is_fpu_int_op
                       | fp_exe_ctrl_r.fp_decode.is_fdiv_op
                       | fp_exe_ctrl_r.fp_decode.is_fsqrt_op)
       & ~stall_all;

  always @(negedge clk_i) begin
    if (~reset_i) begin
      if (instr_inc) begin
        vanilla_core_pc_hist_increment
          (pc_hist_vptr
           ,exe_pc
           ,e_instr
           );
      end
      else if (fp_instr_inc) begin
        vanilla_core_pc_hist_increment
          (pc_hist_vptr
           ,fp_exe_pc_r
           ,e_fp_instr
           );
      end
      else if (exe_bubble_type !== e_exe_no_bubble) begin
        vanilla_core_pc_hist_increment
          (pc_hist_vptr
           ,exe_bubble_pc
           ,e_stall
           );
      end
      else if (stall_all) begin
        vanilla_core_pc_hist_increment
          (pc_hist_vptr
           ,exe_pc
           ,e_stall
           );
      end
    end
  end

endmodule

