/**
 *  vanilla_core_profiler.v
 *
 */

`include "definitions.vh"
`include "parameters.vh"

module vanilla_core_profiler
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter data_width_p="inv"
  )
  (
    input clk_i
    , input reset_i

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

    , input flush
    , input id_signals_s id_r
    , input branch_mispredict
    , input jalr_mispredict

    , input remote_req_s remote_req_o 
    , input remote_req_v_o
    , input remote_req_yumi_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input [31:0] global_ctr_i
  );


  // event signals
  //
  logic instr_committed;
  logic fadd_committed;
  logic fmul_committed;
  logic ld_committed;
  logic st_committed;
  logic branch_committed;
  logic branch_mispredicted;

  assign instr_committed = (~stall & ~stall_depend & ~flush)
    & (id_r.instruction != '0)
    & ~id_r.icache_miss;

  assign fadd_committed = instr_committed & id_r.decode.is_fp_float_op & id_r.fp_float_decode.fadd_op;
  assign fmul_committed = instr_committed & id_r.decode.is_fp_float_op & id_r.fp_float_decode.fmul_op;
  assign ld_committed = instr_committed & id_r.decode.is_load_op;
  assign st_committed = instr_committed & id_r.decode.is_store_op;

  assign branch_committed = instr_committed
    & (id_r.decode.is_branch_op | (id_r.instruction.op == `RV32_JALR_OP)); 
  assign branch_mispredicted = (branch_mispredict | jalr_mispredict) & ~(stall | stall_depend | stall_fp);

  //  profiling counters
  //
  integer num_cycle_r;
  integer num_instr_r;
  integer num_fadd_r;
  integer num_fmul_r;
  integer num_ld_r;
  integer num_st_r;

  integer num_branch_r;
  integer num_mispredict_r;

  integer stall_fp_r;
  integer stall_depend_r;
  integer stall_ifetch_wait_r;
  integer stall_lr_aq_r;
  integer stall_fence_r;
  integer stall_md_r;
  integer stall_force_wb_r;
  integer stall_remote_req_r;
  integer stall_local_flw_r;
  
  logic inc_stall_depend;
  logic inc_stall_fp;
  logic inc_stall_force_wb;

  assign inc_stall_depend = stall_depend & ~(stall | stall_fp);
  assign inc_stall_fp = stall_fp & ~(stall | stall_depend);
  assign inc_stall_force_wb = stall_force_wb
    & ~(stall_ifetch_wait | stall_icache_store | stall_lr_aq
        | stall_fence | stall_md | stall_remote_req | stall_local_flw);

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      num_cycle_r <= '0;
      num_instr_r <= '0;
      num_fadd_r <= '0;
      num_fmul_r <= '0;
      num_ld_r <= '0;
      num_st_r <= '0;
      num_branch_r <= '0;
      num_mispredict_r <= '0;

      stall_fp_r <= '0;
      stall_depend_r <= '0;
      stall_ifetch_wait_r <= '0;
      stall_lr_aq_r <= '0;
      stall_fence_r <= '0;
      stall_md_r <= '0;
      stall_force_wb_r <= '0;
      stall_remote_req_r <= '0;
      stall_local_flw_r <= '0;
    end
    else begin
      num_cycle_r <= num_cycle_r + 1;
      
      if (instr_committed) num_instr_r <= num_instr_r + 1;
      if (fadd_committed) num_fadd_r <= num_fadd_r + 1;
      if (fmul_committed) num_fmul_r <= num_fmul_r + 1;
      if (ld_committed) num_ld_r <= num_ld_r + 1;
      if (st_committed) num_st_r <= num_st_r + 1;
      if (branch_committed) num_branch_r <= num_branch_r + 1;
      if (branch_mispredicted) num_mispredict_r <= num_mispredict_r + 1;
      
      if (inc_stall_fp) stall_fp_r <= stall_fp_r + 1;
      if (inc_stall_depend) stall_depend_r <= stall_depend_r + 1;
      if (stall_ifetch_wait) stall_ifetch_wait_r <= stall_ifetch_wait_r + 1;
      if (stall_lr_aq) stall_lr_aq_r <= stall_lr_aq_r + 1;
      if (stall_fence) stall_fence_r <= stall_fence_r + 1;
      if (stall_md) stall_md_r <= stall_md_r + 1;
      if (stall_force_wb) stall_force_wb_r <= stall_force_wb_r + 1;
      if (stall_remote_req) stall_remote_req_r <= stall_remote_req_r + 1;
      if (stall_local_flw) stall_local_flw_r <= stall_local_flw_r + 1;
      
    end
  end 



  // print signaling
  //
  logic print_stat_exe;
  logic print_stat_mem_r;
  logic print_stat_wb_r;  
  logic [data_width_p-1:0] print_stat_tag_exe;
  logic [data_width_p-1:0] print_stat_tag_mem_r;
  logic [data_width_p-1:0] print_stat_tag_wb_r;
  logic print_now;
  
  assign print_stat_exe = remote_req_v_o & remote_req_yumi_i
    & (remote_req_o.addr == `BSG_PRINT_STAT_ADDR);
  assign print_stat_tag_exe = remote_req_o.payload;


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      print_stat_mem_r <= 1'b0;
      print_stat_wb_r <= 1'b0;

      print_stat_tag_mem_r <= '0;
      print_stat_tag_wb_r <= '0;

    end
    else begin
      if (~stall) begin
        print_stat_mem_r <= print_stat_exe;
        print_stat_wb_r <= print_stat_mem_r;

        if (print_stat_exe) begin
          print_stat_tag_mem_r <= print_stat_tag_exe;
        end
  
        if (print_stat_mem_r) begin
          print_stat_tag_wb_r <= print_stat_tag_mem_r;
        end

      end 
    end
  end

  assign print_now = print_stat_wb_r & ~stall;


  // file logging
  //
  localparam logfile_lp = "vanilla_stats.log";

  integer fd;
  string stamp;

  initial begin

    fd = $fopen(logfile_lp, "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin
        stamp = "";

        if (print_now) begin
          $display("[BSG_INFO][PROFILER] t=%0t x,y=%02d,%02d printing stats.",
            $time, my_x_i, my_y_i
          );

          fd = $fopen(logfile_lp, "a");
          stamp = $sformatf("x=%02d,y=%02d,global_ctr=%0d,tag=%0d",
            my_x_i, my_y_i, global_ctr_i, print_stat_tag_wb_r);

          $fwrite(fd, "%s,num_cycle=%0d,num_instr=%0d,num_fadd=%0d,num_fmul=%0d\n",
            stamp, num_cycle_r, num_instr_r, num_fadd_r, num_fmul_r);

          $fwrite(fd, "%s,num_ld=%0d,num_st=%0d,num_branch=%0d,num_mispredict=%0d\n",
            stamp, num_ld_r, num_st_r, num_branch_r, num_mispredict_r);

          $fwrite(fd, "%s,st_fp=%0d,st_depend=%0d,st_ifetch=%0d,st_lr=%0d,st_fence=%0d,st_md=%0d,st_force_wb=%0d,st_remote_req=%0d,st_flw=%0d\n",
            stamp, stall_fp_r, stall_depend_r, stall_ifetch_wait_r, stall_lr_aq_r, stall_fence_r,
            stall_md_r, stall_force_wb_r, stall_remote_req_r, stall_local_flw_r
          );
      
          $fwrite(fd, "\n");

          $fclose(fd);          

        end
      end
    end
  end



endmodule
