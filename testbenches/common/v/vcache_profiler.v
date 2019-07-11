/**
 *    vcache_profiler.v
 *    
 */


module vcache_profiler
(
  input clk_i
  , input reset_i

  , input v_o
  , input yumi_i
  , input miss_v
  , input ld_op_v_r
  , input st_op_v_r
);


  // event signals
  //
  logic inc_ld;
  logic inc_st;
  logic inc_ld_miss;
  logic inc_st_miss;

  assign inc_ld = v_o & yumi_i & ld_op_v_r;
  assign inc_st = v_o & yumi_i & st_op_v_r;
  assign inc_ld_miss = v_o & yumi_i & ld_op_v_r & miss_v;
  assign inc_st_miss = v_o & yumi_i & st_op_v_r & miss_v;


  // stats counting
  //
  integer ld_count_r;
  integer st_count_r;
  integer ld_miss_count_r;
  integer st_miss_count_r;

  always_ff @ (negedge clk_i) begin

    if (reset_i) begin
      ld_count_r <= '0;
      st_count_r <= '0;
      ld_miss_count_r <= '0;
      st_miss_count_r <= '0;
    end
    else begin
      if (inc_ld) ld_count_r <= ld_count_r + 1;
      if (inc_st) st_count_r <= st_count_r + 1;
      if (inc_ld_miss) ld_miss_count_r <= ld_miss_count_r + 1;
      if (inc_st_miss) st_miss_count_r <= st_miss_count_r + 1;
    end

  end


  // file logging
  //
  localparam logfile_lp = "vcache_stats.log";

  string my_name;
  integer fd;

  initial begin
    fd = $fopen(logfile_lp, "w");
    $fwrite(fd, "");
    $fclose(fd);
  end

  final begin
    my_name = $sformatf("%m");
    fd = $fopen(logfile_lp, "a");
    $fwrite(fd, "%s,ld=%0d,st=%0d,ld_miss=%0d,st_miss=%0d\n",
      my_name, ld_count_r, st_count_r, ld_miss_count_r, st_miss_count_r);   
    $fclose(fd);
  end


endmodule
