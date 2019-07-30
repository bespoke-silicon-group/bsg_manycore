/**
 *    infinite_mem_profiler.v
 *
 */

module infinite_mem_profiler
  #(parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
  )
  (
    input clk_i
    , input reset_i

    , input in_v_lo
    , input in_we_lo

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  logic inc_ld;
  logic inc_st;
  
  assign inc_ld = in_v_lo & ~in_we_lo;
  assign inc_st = in_v_lo & in_we_lo;


  integer ld_count_r;
  integer st_count_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      ld_count_r <= '0;
      st_count_r <= '0;
    end
    else begin
      if (inc_ld) ld_count_r++;
      if (inc_st) st_count_r++;
    end
  end

  // file logging
  //
  localparam logfile_lp = "infinite_mem_stats.log";

  integer fd;

  initial begin
  
    #1; // we need to wait for one time unit so that my_x_i becomes a known value.

    if (my_x_i == '0) begin
      fd = $fopen(logfile_lp, "w");
      $fwrite(fd, "x,y,global_ctr,tag,ld,st\n");
      $fclose(fd);
    end

    forever begin
      @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin
          fd = $fopen(logfile_lp, "a");
          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d\n",
            my_x_i, my_y_i, global_ctr_i, print_stat_tag_i, ld_count_r, st_count_r);   
          $fclose(fd);
        end
      end
    end
  end


endmodule
