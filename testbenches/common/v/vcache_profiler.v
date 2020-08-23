/**
 *    vcache_profiler.v
 *    
 */


module vcache_profiler
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"

    // this string is matched against the name of the instance, and decides whether to print csv header or not.
    , parameter header_print_p="y[3].x[0]"
    , parameter data_mask_width_lp=(data_width_p>>3)
  )
  (
    input clk_i
    , input reset_i

    , input v_o
    , input yumi_i
    , input miss_v


    , input ld_op_v_r        // load
    , input st_op_v_r        // store
    , input word_op_v_r      // size of load op = word
    , input half_op_v_r      // size of load op = half
    , input byte_op_v_r      // size of load op = byte
    , input mask_op_v_r      // store mask determining size of store operation
    , input sigext_op_v_r    // sign extend
    , input tagst_op_v_r     // tag store                
    , input tagfl_op_v_r     // tag flush
    , input taglv_op_v_r     // tag load valid
    , input tagla_op_v_r     // tag load address
    , input afl_op_v_r       // address flush                                        
    , input aflinv_op_v_r    // address flush invalidate
    , input ainv_op_v_r      // address invalidate


    , input [data_mask_width_lp-1:0] mask_v_r

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i

    , input trace_en_i // from toplevel testbench
  );

  // task to print a line of operation trace
  task print_operation_trace(integer fd, string vcache_name, string op);
    $fwrite(fd, "%0d,%0s,%0s\n", global_ctr_i, vcache_name, op);
  endtask


  // event signals
  //
  wire inc_miss     = miss_v;

  // Manycore performs all types of stores operations using the SM, therefore
  // mask_op should be hight while evaluating the store signals, but not for
  // load signals 
  wire inc_ld       = v_o & yumi_i & ld_op_v_r;
  wire inc_ld_lw    = v_o & yumi_i & ld_op_v_r & ~mask_op_v_r & word_op_v_r &  sigext_op_v_r;  // load word
  wire inc_ld_lwu   = v_o & yumi_i & ld_op_v_r & ~mask_op_v_r & word_op_v_r & ~sigext_op_v_r; // load word unsigned
  wire inc_ld_lh    = v_o & yumi_i & ld_op_v_r & ~mask_op_v_r & half_op_v_r &  sigext_op_v_r;  // load half
  wire inc_ld_lhu   = v_o & yumi_i & ld_op_v_r & ~mask_op_v_r & half_op_v_r & ~sigext_op_v_r; // load half unsigned
  wire inc_ld_lb    = v_o & yumi_i & ld_op_v_r & ~mask_op_v_r & byte_op_v_r &  sigext_op_v_r;  // load byte
  wire inc_ld_lbu   = v_o & yumi_i & ld_op_v_r & ~mask_op_v_r & byte_op_v_r & ~sigext_op_v_r; // load byte unsigned

  // All store operations from bsg_manycore are performed with the store mask op
  wire inc_st       = v_o & yumi_i & st_op_v_r;
  wire inc_sm_sw    = v_o & yumi_i & st_op_v_r & mask_op_v_r & ($countones(mask_v_r) == 4); // store word
  wire inc_sm_sh    = v_o & yumi_i & st_op_v_r & mask_op_v_r & ($countones(mask_v_r) == 2); // store half
  wire inc_sm_sb    = v_o & yumi_i & st_op_v_r & mask_op_v_r & ($countones(mask_v_r) == 1); // store byte

  wire inc_tagst    = v_o & yumi_i & tagst_op_v_r;   // tag store                
  wire inc_tagfl    = v_o & yumi_i & tagfl_op_v_r;   // tag flush
  wire inc_taglv    = v_o & yumi_i & taglv_op_v_r;   // tag load valid
  wire inc_tagla    = v_o & yumi_i & tagla_op_v_r;   // tag load address
  wire inc_afl      = v_o & yumi_i & afl_op_v_r;     // address flush                                        
  wire inc_aflinv   = v_o & yumi_i & aflinv_op_v_r;  // address flush invalidate
  wire inc_ainv     = v_o & yumi_i & ainv_op_v_r;    // address invalidate

  wire inc_miss_ld  = v_o & yumi_i & ld_op_v_r & miss_v; // miss on load
  wire inc_miss_st  = v_o & yumi_i & st_op_v_r & miss_v; // miss on store

  wire inc_idle     = ~(v_o & yumi_i) & ~(miss_v);

  // stats counting
  //
  typedef struct packed {
    integer ld_count;
    integer ld_lw_count;
    integer ld_lwu_count;
    integer ld_lh_count;
    integer ld_lhu_count;
    integer ld_lb_count;
    integer ld_lbu_count;

    integer st_count;
    integer sm_sw_count;
    integer sm_sh_count;
    integer sm_sb_count;

    integer tagst_count;   
    integer tagfl_count;   
    integer taglv_count;   
    integer tagla_count;   
    integer afl_count;     
    integer aflinv_count;  
    integer ainv_count;    

    integer miss_ld_count;
    integer miss_st_count;

    integer miss_count;   // Number of cycles miss handler is active
    integer idle_count;   // Number of cycles vcache is idle

  } vcache_stat_s;

  vcache_stat_s stat_r;

  always_ff @ (posedge clk_i) begin

    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      if (inc_ld)            stat_r.ld_count++;
      if (inc_ld_lw)         stat_r.ld_lw_count++;
      if (inc_ld_lwu)        stat_r.ld_lwu_count++;
      if (inc_ld_lh)         stat_r.ld_lh_count++;
      if (inc_ld_lhu)        stat_r.ld_lhu_count++;
      if (inc_ld_lb)         stat_r.ld_lb_count++;
      if (inc_ld_lbu)        stat_r.ld_lbu_count++;

      if (inc_st)            stat_r.st_count++; 
      if (inc_sm_sw)         stat_r.sm_sw_count++;
      if (inc_sm_sh)         stat_r.sm_sh_count++;
      if (inc_sm_sb)         stat_r.sm_sb_count++;

      if (inc_tagst)         stat_r.tagst_count++;   
      if (inc_tagfl)         stat_r.tagfl_count++;   
      if (inc_taglv)         stat_r.taglv_count++;   
      if (inc_tagla)         stat_r.tagla_count++;   
      if (inc_afl)           stat_r.afl_count++;     
      if (inc_aflinv)        stat_r.aflinv_count++;  
      if (inc_ainv)          stat_r.ainv_count++;    

      if (inc_miss_ld)       stat_r.miss_ld_count++;
      if (inc_miss_st)       stat_r.miss_st_count++;

      if (inc_miss)          stat_r.miss_count++;
      if (inc_idle)          stat_r.idle_count++;
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
      $fwrite(log_fd, "time,vcache,global_ctr,tag,");
      $fwrite(log_fd, "instr_ld,instr_ld_lw,instr_ld_lwu,");
      $fwrite(log_fd, "instr_ld_lh,instr_ld_lhu,instr_ld_lb,instr_ld_lbu,");
      $fwrite(log_fd, "instr_st,instr_sm_sw,instr_sm_sh,instr_sm_sb,");
      $fwrite(log_fd, "instr_tagst,instr_tagfl,instr_taglv,instr_tagla,");
      $fwrite(log_fd, "instr_afl,instr_aflinv,instr_ainv,");
      $fwrite(log_fd, "miss_ld,miss_st,stall_miss,stall_idle\n");
      $fclose(log_fd);

      //if (trace_en_i) begin
        trace_fd = $fopen(tracefile_lp, "w");
        $fwrite(trace_fd, "cycle,vcache,operation\n");
        $fclose(trace_fd);
      //end
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

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat_r.ld_count,
            stat_r.ld_lw_count,
            stat_r.ld_lwu_count,
            stat_r.ld_lh_count,
            stat_r.ld_lhu_count,
            stat_r.ld_lb_count,
            stat_r.ld_lbu_count, 
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,",
            stat_r.st_count,
            stat_r.sm_sw_count,
            stat_r.sm_sh_count,
            stat_r.sm_sb_count,
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,",
            stat_r.tagst_count,
            stat_r.tagfl_count,
            stat_r.taglv_count,
            stat_r.tagla_count,
          );

          $fwrite(log_fd, "%0d,%0d,%0d,",
            stat_r.afl_count,
            stat_r.aflinv_count,
            stat_r.ainv_count,
           );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d\n",
            stat_r.miss_ld_count,
            stat_r.miss_st_count,
            stat_r.miss_count,
            stat_r.idle_count
          );

          $fclose(log_fd);
        end



        if (~reset_i & trace_en_i) begin
          trace_fd = $fopen(tracefile_lp, "a");

          // If miss handler has finished the dma request and result is ready
          // for a missed request
          if (inc_miss_ld)
            print_operation_trace(trace_fd, my_name, "miss_ld");
          else if (inc_miss_st)
            print_operation_trace(trace_fd, my_name, "miss_st");


          // If miss handler is still busy on a request
          else if (miss_v) begin
            print_operation_trace(trace_fd, my_name, "miss");
          end 

        
          // If response is ready for a hit request
          else begin

            if (inc_ld) begin
              if (inc_ld_lw)
                print_operation_trace(trace_fd, my_name, "ld_lw");
              else if (inc_ld_lwu)
                print_operation_trace(trace_fd, my_name, "ld_lwu");
              else if (inc_ld_lh)
                print_operation_trace(trace_fd, my_name, "ld_lh");
              else if (inc_ld_lhu)
                print_operation_trace(trace_fd, my_name, "ld_lhu");
              else if (inc_ld_lb) 
                print_operation_trace(trace_fd, my_name, "ld_lb");
              else if (inc_ld_lbu)
                print_operation_trace(trace_fd, my_name, "ld_lbu");
              else
                print_operation_trace(trace_fd, my_name, "ld");
            end


            else if (inc_st) begin
              if (inc_sm_sw)
                print_operation_trace(trace_fd, my_name, "sm_sw");  
              else if (inc_sm_sh)
                print_operation_trace(trace_fd, my_name, "sm_sh");  
              else if (inc_sm_sb)
                print_operation_trace(trace_fd, my_name, "sm_sb");  
              else
                print_operation_trace(trace_fd, my_name, "st");
            end


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
