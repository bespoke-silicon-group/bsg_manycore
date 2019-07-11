/**
 *  vanilla_core_profiler.v
 *
 */

`include "definitions.vh"

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
    , input flush
    , input id_signals_s id_r

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

  assign instr_committed = (~stall & ~stall_depend & ~flush)
    & (id_r.instruction != '0)
    & ~id_r.icache_miss;



  //  profiling counters
  //
  integer total_cycle_r;
  integer num_instr_committed_r;


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      total_cycle_r <= '0;
      num_instr_committed_r <= '0;
    end
    else begin
      total_cycle_r <= total_cycle_r + 1;
      if (instr_committed) num_instr_committed_r <= num_instr_committed_r + 1;
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
  localparam logfile_lp = "vcore_profile.log";

  integer fd;

  initial begin

    fd = $fopen(logfile_lp, "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin

        if (print_now) begin

          fd = $fopen(logfile_lp, "a");

          $fwrite(fd,
            "x=%02d,y=%02d,global_ctr=%0d,tag=%0d,total_cycle=%0d,num_instr_committed=%0d\n",
            my_x_i, my_y_i,
            global_ctr_i, print_stat_tag_wb_r,
            total_cycle_r,
            num_instr_committed_r
          );

          $fclose(fd);          

        end
      end
    end
  end



endmodule
