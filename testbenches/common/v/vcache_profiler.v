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

    , input trace_en_i // from toplevel testbench
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

  wire inc_miss     = miss_v;
  wire inc_ld       = v_o & yumi_i & decode_v_r.ld_op;
  wire inc_st       = v_o & yumi_i & decode_v_r.st_op;
  wire inc_mask     = v_o & yumi_i & decode_v_r.mask_op;
  wire inc_sigext   = v_o & yumi_i & decode_v_r.sigext_op;
  wire inc_tagst    = v_o & yumi_i & decode_v_r.tagst_op;
  wire inc_tagfl    = v_o & yumi_i & decode_v_r.tagfl_op;
  wire inc_taglv    = v_o & yumi_i & decode_v_r.taglv_op;
  wire inc_tagla    = v_o & yumi_i & decode_v_r.tagla_op;
  wire inc_afl      = v_o & yumi_i & decode_v_r.afl_op;
  wire inc_aflinv   = v_o & yumi_i & decode_v_r.aflinv_op;
  wire inc_ainv     = v_o & yumi_i & decode_v_r.ainv_op;
  wire inc_alock    = v_o & yumi_i & decode_v_r.alock_op;
  wire inc_aunlock  = v_o & yumi_i & decode_v_r.aunlock_op;
  wire inc_tag_read = v_o & yumi_i & decode_v_r.tag_read_op;
  wire inc_atomic   = v_o & yumi_i & decode_v_r.atomic_op;
  wire inc_amoswap  = v_o & yumi_i & decode_v_r.amoswap_op;
  wire inc_amoor    = v_o & yumi_i & decode_v_r.amoor_op;

  wire inc_ld_miss  = v_o & yumi_i & decode_v_r.ld_op & miss_v;
  wire inc_st_miss  = v_o & yumi_i & decode_v_r.st_op & miss_v;

  wire inc_dma_read_req = dma_pkt_v_o & dma_pkt_yumi_i & ~dma_pkt.write_not_read;
  wire inc_dma_write_req = dma_pkt_v_o & dma_pkt_yumi_i & dma_pkt.write_not_read;

  wire inc_idle     = ~(v_o & yumi_i) & ~(miss_v);

  // stats counting
  //
  typedef struct packed {
    integer ld_count;
    integer st_count;
    integer mask_count; 
    integer sigext_count; 
    integer tagst_count;   
    integer tagfl_count;   
    integer taglv_count;   
    integer tagla_count;   
    integer afl_count;     
    integer aflinv_count;  
    integer ainv_count;    
    integer alock_count;   
    integer aunlock_count; 
    integer tag_read_count;
    integer atomic_count;  
    integer amoswap_count; 
    integer amoor_count;   

    integer ld_miss_count;
    integer st_miss_count;

    integer miss_count;   // Number of cycles miss handler is active
    integer idle_count;   // Number of cycles vcache is idle

    integer dma_read_req;
    integer dma_write_req;
  } vcache_stat_s;

  vcache_stat_s stat_r;

  always_ff @ (posedge clk_i) begin

    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      if (inc_ld)            stat_r.ld_count++;
      if (inc_st)            stat_r.st_count++;
      if (inc_mask)          stat_r.mask_count++;      
      if (inc_sigext)        stat_r.sigext_count++; 
      if (inc_tagst)         stat_r.tagst_count++;   
      if (inc_tagfl)         stat_r.tagfl_count++;   
      if (inc_taglv)         stat_r.taglv_count++;   
      if (inc_tagla)         stat_r.tagla_count++;   
      if (inc_afl)           stat_r.afl_count++;     
      if (inc_aflinv)        stat_r.aflinv_count++;  
      if (inc_ainv)          stat_r.ainv_count++;    
      if (inc_alock)         stat_r.alock_count++;   
      if (inc_aunlock)       stat_r.aunlock_count++; 
      if (inc_tag_read)      stat_r.tag_read_count++;
      if (inc_atomic)        stat_r.atomic_count++;  
      if (inc_amoswap)       stat_r.amoswap_count++; 
      if (inc_amoor)         stat_r.amoor_count++;   

      if (inc_ld_miss)       stat_r.ld_miss_count++;
      if (inc_st_miss)       stat_r.st_miss_count++;

      if (inc_miss)          stat_r.miss_count++;
      if (inc_idle)          stat_r.idle_count++;

      if (inc_dma_read_req)  stat_r.dma_read_req++;
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
      $fwrite(log_fd, "time,vcache,global_ctr,tag,instr_ld,instr_st,instr_mask,");
      $fwrite(log_fd, "instr_sigext,instr_tagst,instr_tagfl,instr_taglv,");
      $fwrite(log_fd, "instr_afl,instr_aflinv,instr_ainv,instr_alock,instr_aunlock,");
      $fwrite(log_fd, "instr_tag_read,instr_atomic,instr_amoswap,instr_amoor,");
      $fwrite(log_fd, "miss_ld,miss_st,stall_miss,stall_idle,dma_read_req,dma_write_req\n");
      $fclose(log_fd);

      if (trace_en_i) begin
        trace_fd = $fopen(tracefile_lp, "w");
        $fwrite(trace_fd, "cycle,vcache,operation\n");
        $fclose(trace_fd);
      end
    end



    forever begin
      @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin

          $display("[BSG_INFO][VCACHE_PROFILER] %s t=%0t printing stats.", my_name, $time);

          log_fd = $fopen(logfile_lp, "a");
          $fwrite(log_fd, "%0d,%s,%0d,%0d,",
            $time,
            my_name,
            global_ctr_i,
            print_stat_tag_i
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat_r.ld_count,
            stat_r.st_count,
            stat_r.mask_count,
            stat_r.sigext_count,
            stat_r.tagst_count,
            stat_r.tagfl_count,
            stat_r.taglv_count,
            stat_r.tagla_count
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat_r.afl_count,
            stat_r.aflinv_count,
            stat_r.ainv_count,
            stat_r.alock_count,
            stat_r.aunlock_count,
            stat_r.tag_read_count,
            stat_r.atomic_count,
            stat_r.amoswap_count,
            stat_r.amoor_count
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d\n",
            stat_r.ld_miss_count,
            stat_r.st_miss_count,
            stat_r.miss_count,
            stat_r.idle_count,
            stat_r.dma_read_req,
            stat_r.dma_write_req
          );

          $fclose(log_fd);
        end



        if (~reset_i & trace_en_i) begin
          trace_fd = $fopen(tracefile_lp, "a");

          // If miss handler has finished the dma request and result is ready
          // for a missed request
          if (inc_ld_miss)
            print_operation_trace(trace_fd, my_name, "miss_ld");
          else if (inc_st_miss)
            print_operation_trace(trace_fd, my_name, "miss_st");


          // If miss handler is still busy on a request
          else if (miss_v) begin
            print_operation_trace(trace_fd, my_name, "miss");
          end 

        
          // If response is ready for a hit request
          else begin
            if (inc_ld)
              print_operation_trace(trace_fd, my_name, "ld");
            else if (inc_st)
              print_operation_trace(trace_fd, my_name, "st");
            else if (inc_mask)
              print_operation_trace(trace_fd, my_name, "mask");
            else if (inc_sigext)
              print_operation_trace(trace_fd, my_name, "sigext");
            else if (inc_tagst)
              print_operation_trace(trace_fd, my_name, "tagst");
            else if (inc_tagfl)
              print_operation_trace(trace_fd, my_name, "tagfl");
            else if (inc_taglv)
              print_operation_trace(trace_fd, my_name, "taglv");
            else if (inc_tagla)
              print_operation_trace(trace_fd, my_name, "tagla");
            else if (inc_afl)
              print_operation_trace(trace_fd, my_name, "afl");
            else if (inc_aflinv)
              print_operation_trace(trace_fd, my_name, "aflinv");
            else if (inc_ainv)
              print_operation_trace(trace_fd, my_name, "ainv");
            else if (inc_alock)
              print_operation_trace(trace_fd, my_name, "alock");
            else if (inc_aunlock)
              print_operation_trace(trace_fd, my_name, "aunlock");
            else if (inc_tag_read)
              print_operation_trace(trace_fd, my_name, "tag_read");
            else if (inc_atomic)
              print_operation_trace(trace_fd, my_name, "atomic");
            else if (inc_amoswap)
              print_operation_trace(trace_fd, my_name, "amoswap");
            else if (inc_amoor)
              print_operation_trace(trace_fd, my_name, "amoor");
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
