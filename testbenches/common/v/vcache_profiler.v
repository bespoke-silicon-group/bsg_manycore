/**
 *    vcache_profiler.v
 *    
 */


module vcache_profiler
  import bsg_cache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"

    // this string is matched against the name of the instance, and decides whether to print csv header or not.
    , parameter header_print_p="y[3].x[0]"

    , parameter dma_pkt_width_lp=`bsg_cache_dma_pkt_width(addr_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input v_o
    , input yumi_i
    , input miss_v
    , input bsg_cache_decode_s decode_v_r

    , input [dma_pkt_width_lp-1:0] dma_pkt_o
    , input dma_pkt_v_o
    , input dma_pkt_yumi_i

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i
  );

  // task to print a line of operation trace
  task print_operation_trace(integer fd, string vcache_name, string op);
    $fwrite(fd, "%0t,%0s,%0s\n", global_ctr_i, vcache_name, op);
  endtask


  `declare_bsg_cache_dma_pkt_s(addr_width_p);
  bsg_cache_dma_pkt_s dma_pkt;
  assign dma_pkt = dma_pkt_o;


  // event signals
  //

  wire inc_ld = v_o & yumi_i & decode_v_r.ld_op;
  wire inc_st = v_o & yumi_i & decode_v_r.st_op;
  wire inc_ld_miss = v_o & yumi_i & decode_v_r.ld_op & miss_v;
  wire inc_st_miss = v_o & yumi_i & decode_v_r.st_op & miss_v;
  wire inc_dma_read_req = dma_pkt_v_o & dma_pkt_yumi_i & ~dma_pkt.write_not_read;
  wire inc_dma_write_req = dma_pkt_v_o & dma_pkt_yumi_i & dma_pkt.write_not_read;


  // stats counting
  //
  typedef struct packed {
    integer ld_count;
    integer st_count;
    integer ld_miss_count;
    integer st_miss_count;
    integer dma_read_req;
    integer dma_write_req;
  } vcache_stat_s;

  vcache_stat_s stat_r;

  always_ff @ (posedge clk_i) begin

    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      if (inc_ld) stat_r.ld_count++;
      if (inc_st) stat_r.st_count++;
      if (inc_ld_miss) stat_r.ld_miss_count++;
      if (inc_st_miss) stat_r.st_miss_count++;
      if (inc_dma_read_req) stat_r.dma_read_req++;
      if (inc_dma_write_req) stat_r.dma_write_req++;
    end

  end


  // file logging
  //
  localparam logfile_lp = "vcache_stats.csv";
  localparam tracefile_lp = "vcache_operation_trace.csv";

  string my_name;
  integer log_fd, trace_fd;

  initial begin

    my_name = $sformatf("%m");
    if (str_match(my_name, header_print_p)) begin
      log_fd = $fopen(logfile_lp, "w");
      $fwrite(log_fd, "instance,global_ctr,tag,ld,st,ld_miss,st_miss,dma_read_req,dma_write_req\n");
      $fclose(log_fd);

      trace_fd = $fopen(tracefile_lp, "w");
      $fwrite(trace_fd, "instance,global_ctr,op\n");
      $fclose(trace_fd);
    end



    forever begin
      @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin

          $display("[BSG_INFO][VCACHE_PROFILER] %s t=%0t printing stats.", my_name, $time);

          log_fd = $fopen(logfile_lp, "a");
          $fwrite(log_fd, "%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
            my_name, global_ctr_i, print_stat_tag_i,
            stat_r.ld_count, stat_r.st_count,
            stat_r.ld_miss_count, stat_r.st_miss_count,
            stat_r.dma_read_req, stat_r.dma_write_req 
          );   
          $fclose(log_fd);
        end


        if (~reset_i) begin
          trace_fd = $fopen(tracefile_lp, "a");
          if (miss_v) begin
            if (inc_ld_miss)
              print_operation_trace(trace_fd, my_name, "miss_ld");
            else if (inc_st_miss)
              print_operation_trace(trace_fd, my_name, "miss_st");
          end 
        
          else begin
            if (inc_ld)
              print_operation_trace(trace_fd, my_name, "ld");
            else if (inc_st)
              print_operation_trace(trace_fd, my_name, "st");
            else
              print_operation_trace(trace_fd, my_name, "idle");
          end

          $fclose(trace_fd);
        end

      end
    end
  end


  // string match helper
  //
  function str_match(string s1, s2);

    int len1, len2;
    len1 = s1.len();
    len2 = s2.len();

    if (len2 > len1)
      return 0;

    for (int i = 0; i < len1-len2+1; i++)
      if (s1.substr(i,i+len2-1) == s2)
        return 1;
  
  endfunction

endmodule
