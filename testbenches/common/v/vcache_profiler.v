/**
 *    vcache_profiler.v
 *    
 */

`include "bsg_defines.v"
`include "bsg_cache.vh"
`include "profiler.vh"

module vcache_profiler
  import bsg_cache_pkg::*;
  #(parameter `BSG_INV_PARAM(data_width_p)
    , parameter `BSG_INV_PARAM(addr_width_p)
    , parameter `BSG_INV_PARAM(ways_p)
    , parameter `BSG_INV_PARAM(block_size_in_words_p)

    // this string is matched against the name of the instance, and decides whether to print csv header or not.
    , parameter header_print_p="y[3].x[0]"

    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter dma_pkt_width_lp=`bsg_cache_dma_pkt_width(addr_width_p, block_size_in_words_p)
    , parameter stat_info_width_lp=`bsg_cache_stat_info_width(ways_p)
    // periodic stat;
    , parameter period_p = 250
  )
  (
    input clk_i
    , input reset_i

    , input v_o
    , input yumi_i
    , input miss_v
    , input bsg_cache_decode_s decode_v_r
    , input [data_mask_width_lp-1:0] mask_v_r

    , input [dma_pkt_width_lp-1:0] dma_pkt_o
    , input dma_pkt_v_o
    , input dma_pkt_yumi_i

    , input [lg_ways_lp-1:0] chosen_way_n // connect to miss.chosen_way_n
    , input [ways_p-1:0] valid_v_r
    , input [stat_info_width_lp-1:0] stat_mem_data_lo
    , input bsg_cache_dma_cmd_e dma_cmd_lo
    , input dma_done_li

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i

    , input trace_en_i // from toplevel testbench
  );

  `DEFINE_PROFILER(bsg_vcache_profiler
                   ,"vcache_operation_trace.csv"
                   ,"cycle,vcache,operation\n"
                   )

  // task to print a line of operation trace
  task print_operation_trace(string vcache_name, string op);
    $fwrite(bsg_vcache_profiler_trace_fd(), "%0d,%0s,%0s\n", global_ctr_i, vcache_name, op);
  endtask


  `declare_bsg_cache_dma_pkt_s(addr_width_p, block_size_in_words_p);
  bsg_cache_dma_pkt_s dma_pkt;
  assign dma_pkt = dma_pkt_o;

  `declare_bsg_cache_stat_info_s(ways_p);
  bsg_cache_stat_info_s stat_info;
  assign stat_info = stat_mem_data_lo;


  // event signals
  //
  wire inc_miss     = miss_v & ~v_o;

  // Manycore performs all types of stores operations using the SM, therefore
  // mask_op should be hight while evaluating the store signals, but not for
  // load signals 
  wire inc_ld       = v_o & yumi_i & decode_v_r.ld_op;
  wire inc_ld_ld    = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b11 & decode_v_r.sigext_op;  // load double (reserved for 64-bit)
  wire inc_ld_ldu   = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b11 & ~decode_v_r.sigext_op; // load double unsigned (reserved for 64-bit) 
  wire inc_ld_lw    = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b10 & decode_v_r.sigext_op;  // load word
  wire inc_ld_lwu   = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b10 & ~decode_v_r.sigext_op; // load word unsigned
  wire inc_ld_lh    = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b01 & decode_v_r.sigext_op;  // load half
  wire inc_ld_lhu   = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b01 & ~decode_v_r.sigext_op; // load half unsigned
  wire inc_ld_lb    = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b00 & decode_v_r.sigext_op;  // load byte
  wire inc_ld_lbu   = inc_ld & ~decode_v_r.mask_op & decode_v_r.data_size_op == 2'b00 & ~decode_v_r.sigext_op; // load byte unsigned

  // All store operations from bsg_manycore are performed with the store mask op
  wire inc_st       = v_o & yumi_i & decode_v_r.st_op;
  wire inc_sm_sd    = inc_st & decode_v_r.mask_op & ($countones(mask_v_r) == 8); // store double (reserved for 64-bit)
  wire inc_sm_sw    = inc_st & decode_v_r.mask_op & ($countones(mask_v_r) == 4); // store word
  wire inc_sm_sh    = inc_st & decode_v_r.mask_op & ($countones(mask_v_r) == 2); // store half
  wire inc_sm_sb    = inc_st & decode_v_r.mask_op & ($countones(mask_v_r) == 1); // store byte

  wire inc_tagst    = v_o & yumi_i & decode_v_r.tagst_op;   // tag store                
  wire inc_tagfl    = v_o & yumi_i & decode_v_r.tagfl_op;   // tag flush
  wire inc_taglv    = v_o & yumi_i & decode_v_r.taglv_op;   // tag load valid
  wire inc_tagla    = v_o & yumi_i & decode_v_r.tagla_op;   // tag load address
  wire inc_afl      = v_o & yumi_i & decode_v_r.afl_op;     // address flush                                        
  wire inc_aflinv   = v_o & yumi_i & decode_v_r.aflinv_op;  // address flush invalidate
  wire inc_ainv     = v_o & yumi_i & decode_v_r.ainv_op;    // address invalidate
  wire inc_alock    = v_o & yumi_i & decode_v_r.alock_op;   // address lock                              
  wire inc_aunlock  = v_o & yumi_i & decode_v_r.aunlock_op; // address unlock
  wire inc_atomic   = v_o & yumi_i & decode_v_r.atomic_op;  // atomic
  wire inc_amoswap  = inc_atomic & (decode_v_r.amo_subop == e_cache_amo_swap); // atomic swap
  wire inc_amoor    = inc_atomic & (decode_v_r.amo_subop == e_cache_amo_or);   // atomic or
  wire inc_amoadd   = inc_atomic & (decode_v_r.amo_subop == e_cache_amo_add);   // atomic add

  wire inc_miss_ld  = v_o & yumi_i & decode_v_r.ld_op & miss_v; // miss on load
  wire inc_miss_st  = v_o & yumi_i & decode_v_r.st_op & miss_v; // miss on store
  wire inc_miss_amo = v_o & yumi_i & decode_v_r.atomic_op & miss_v; // miss on atomic

  wire inc_dma_read_req = dma_pkt_v_o & dma_pkt_yumi_i & ~dma_pkt.write_not_read; // DMA read request
  wire inc_dma_write_req = dma_pkt_v_o & dma_pkt_yumi_i & dma_pkt.write_not_read; // DMA write request

  wire inc_stall_rsp = v_o & ~yumi_i;
  wire inc_idle     = ~v_o & ~miss_v; // Simplified From: ~(v_o & yumi_i) & ~(inc_miss) & ~(inc_stall_rsp);

  // replacement stats
  // 1) replace invalid
  // 2) replace valid
  // 3) replace valid+dirty
  wire replacing = (dma_cmd_lo == e_dma_send_fill_addr) & dma_done_li;
  wire inc_replace_invalid = replacing & ~valid_v_r[chosen_way_n];
  wire inc_replace_valid = replacing & valid_v_r[chosen_way_n] & ~stat_info.dirty[chosen_way_n]; 
  wire inc_replace_dirty = replacing & valid_v_r[chosen_way_n] & stat_info.dirty[chosen_way_n];
 

  // stats counting
  //
  typedef struct packed {
    integer ld_count;
    integer ld_ld_count;
    integer ld_ldu_count;
    integer ld_lw_count;
    integer ld_lwu_count;
    integer ld_lh_count;
    integer ld_lhu_count;
    integer ld_lb_count;
    integer ld_lbu_count;

    integer st_count;
    integer sm_sd_count;
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
    integer alock_count;   
    integer aunlock_count; 
    integer atomic_count;  
    integer amoswap_count; 
    integer amoor_count;   
    integer amoadd_count;

    integer miss_ld_count;
    integer miss_st_count;
    integer miss_amo_count;

    integer miss_count;   // Number of cycles miss handler is active
    integer idle_count;   // Number of cycles vcache is idle
    integer stall_rsp_count;   // Number of cycles vcache is stalled trying to inject a response into the network

    integer dma_read_req;
    integer dma_write_req;
    integer replace_invalid;
    integer replace_valid;
    integer replace_dirty;
  } vcache_stat_s;

  vcache_stat_s stat_r;

  always_ff @ (posedge clk_i) begin

    if (reset_i) begin
      stat_r = '0;
    end
    else begin

      if (inc_ld)            stat_r.ld_count++;
      if (inc_ld_ld)         stat_r.ld_ld_count++;
      if (inc_ld_ldu)        stat_r.ld_ldu_count++;
      if (inc_ld_lw)         stat_r.ld_lw_count++;
      if (inc_ld_lwu)        stat_r.ld_lwu_count++;
      if (inc_ld_lh)         stat_r.ld_lh_count++;
      if (inc_ld_lhu)        stat_r.ld_lhu_count++;
      if (inc_ld_lb)         stat_r.ld_lb_count++;
      if (inc_ld_lbu)        stat_r.ld_lbu_count++;

      if (inc_st)            stat_r.st_count++; 
      if (inc_sm_sd)         stat_r.sm_sd_count++;
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
      if (inc_alock)         stat_r.alock_count++;   
      if (inc_aunlock)       stat_r.aunlock_count++; 
      if (inc_atomic)        stat_r.atomic_count++;  
      if (inc_amoswap)       stat_r.amoswap_count++; 
      if (inc_amoor)         stat_r.amoor_count++;   
      if (inc_amoadd)         stat_r.amoadd_count++;

      if (inc_miss_ld)       stat_r.miss_ld_count++;
      if (inc_miss_st)       stat_r.miss_st_count++;
      if (inc_miss_amo)      stat_r.miss_amo_count++;

      if (inc_miss)          stat_r.miss_count++;
      if (inc_idle)          stat_r.idle_count++;
      if (inc_stall_rsp)     stat_r.stall_rsp_count++;
       
      if (inc_dma_read_req)  stat_r.dma_read_req++;
      if (inc_dma_write_req) stat_r.dma_write_req++;
      if (inc_replace_invalid) stat_r.replace_invalid++;
      if (inc_replace_valid) stat_r.replace_valid++;
      if (inc_replace_dirty) stat_r.replace_dirty++;
    end

  end


  // file logging
  //
  localparam logfile_lp = "vcache_stats.csv";
  localparam tracefile_lp = "vcache_operation_trace.csv";
  localparam periodicfile_lp = "vcache_periodic_stats.csv";

  string my_name;
  integer log_fd, trace_fd, periodic_fd;

  initial begin

    my_name = $sformatf("%m");
    if (str_match(my_name, header_print_p)) begin
      log_fd = $fopen(logfile_lp, "w");
      $fwrite(log_fd, "time,vcache,global_ctr,tag,");
      $fwrite(log_fd, "instr_ld,instr_ld_ld,instr_ld_ldu,instr_ld_lw,instr_ld_lwu,");
      $fwrite(log_fd, "instr_ld_lh,instr_ld_lhu,instr_ld_lb,instr_ld_lbu,");
      $fwrite(log_fd, "instr_st,instr_sm_sd,instr_sm_sw,instr_sm_sh,instr_sm_sb,");
      $fwrite(log_fd, "instr_tagst,instr_tagfl,instr_taglv,instr_tagla,");
      $fwrite(log_fd, "instr_afl,instr_aflinv,instr_ainv,instr_alock,instr_aunlock,");
      $fwrite(log_fd, "instr_atomic,instr_amoswap,instr_amoor,instr_amoadd,");
      $fwrite(log_fd, "miss_ld,miss_st,miss_amo,stall_miss,stall_idle,stall_rsp,dma_read_req,dma_write_req,");
      $fwrite(log_fd, "replace_invalid,replace_valid,replace_dirty\n");
      $fclose(log_fd);

      trace_fd = $fopen(tracefile_lp, "w");
      $fwrite(trace_fd, "cycle,vcache,operation\n");
      $fclose(trace_fd);

      periodic_fd = $fopen(periodicfile_lp, "w");
      $fwrite(periodic_fd, "global_ctr,load,store,atomic,miss,stall_rsp,idle\n");
      $fclose(periodic_fd);
    end
  end




    always @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin


          log_fd = $fopen(logfile_lp, "a");
          $fwrite(log_fd, "%0d,%s,%0d,%0d,",
            $time,
            my_name,
            global_ctr_i,
            print_stat_tag_i
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat_r.ld_count,
            stat_r.ld_ld_count,
            stat_r.ld_ldu_count,
            stat_r.ld_lw_count,
            stat_r.ld_lwu_count,
            stat_r.ld_lh_count,
            stat_r.ld_lhu_count,
            stat_r.ld_lb_count,
            stat_r.ld_lbu_count, 
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,",
            stat_r.st_count,
            stat_r.sm_sd_count,
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

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,",
            stat_r.afl_count,
            stat_r.aflinv_count,
            stat_r.ainv_count,
            stat_r.alock_count,
            stat_r.aunlock_count,
           );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,",
            stat_r.atomic_count,
            stat_r.amoswap_count,
            stat_r.amoor_count,
            stat_r.amoadd_count,
          );

          $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            stat_r.miss_ld_count,
            stat_r.miss_st_count,
            stat_r.miss_amo_count,
            stat_r.miss_count,
            stat_r.idle_count,
            stat_r.stall_rsp_count,
            stat_r.dma_read_req,
            stat_r.dma_write_req
          );

          $fwrite(log_fd, "%0d,%0d,%0d\n",
            stat_r.replace_invalid,
            stat_r.replace_valid,
            stat_r.replace_dirty
          );   

          $fclose(log_fd);
        end



        if (~reset_i & trace_en_i) begin
          // If miss handler has finished the dma request and result is ready
          // for a missed request
          if (inc_miss_ld)
            print_operation_trace(my_name, "miss_ld");
          else if (inc_miss_st)
            print_operation_trace(my_name, "miss_st");


          // If miss handler is still busy on a request
          else if (miss_v) begin
            print_operation_trace(my_name, "miss");
          end 

        
          // If response is ready for a hit request
          else begin

            if (inc_ld) begin
              if (inc_ld_ld) 
                print_operation_trace(my_name, "ld_ld");
              else if (inc_ld_ldu)
                print_operation_trace(my_name, "ld_ldu");
              else if (inc_ld_lw)
                print_operation_trace(my_name, "ld_lw");
              else if (inc_ld_lwu)
                print_operation_trace(my_name, "ld_lwu");
              else if (inc_ld_lh)
                print_operation_trace(my_name, "ld_lh");
              else if (inc_ld_lhu)
                print_operation_trace(my_name, "ld_lhu");
              else if (inc_ld_lb) 
                print_operation_trace(my_name, "ld_lb");
              else if (inc_ld_lbu)
                print_operation_trace(my_name, "ld_lbu");
              else
                print_operation_trace(my_name, "ld");
            end


            else if (inc_st) begin
              if (inc_sm_sd)
                print_operation_trace(my_name, "sm_sd");
              else if (inc_sm_sw)
                print_operation_trace(my_name, "sm_sw");
              else if (inc_sm_sh)
                print_operation_trace(my_name, "sm_sh");
              else if (inc_sm_sb)
                print_operation_trace(my_name, "sm_sb");
              else
                print_operation_trace(my_name, "st");
            end


            else if (inc_stall_rsp)
              print_operation_trace(my_name, "stall_rsp");

            else if (inc_tagst)
              print_operation_trace(my_name, "tagst");
            else if (inc_tagfl)
              print_operation_trace(my_name, "tagfl");
            else if (inc_taglv)
              print_operation_trace(my_name, "taglv");
            else if (inc_tagla)
              print_operation_trace(my_name, "tagla");
            else if (inc_afl)
              print_operation_trace(my_name, "afl");
            else if (inc_aflinv)
              print_operation_trace(my_name, "aflinv");
            else if (inc_ainv)
              print_operation_trace(my_name, "ainv");
            else if (inc_alock)
              print_operation_trace(my_name, "alock");
            else if (inc_aunlock)
              print_operation_trace(my_name, "aunlock");
            else if (inc_atomic)
              print_operation_trace(my_name, "atomic");
            else if (inc_amoswap)
              print_operation_trace(my_name, "amoswap");
            else if (inc_amoor)
              print_operation_trace(my_name, "amoor");
            else if (inc_amoadd)
              print_operation_trace(my_name, "amoadd");
            else
              print_operation_trace(my_name, "idle");
          end

        end // if (~reset_i & trace_en_i)
    end // always @ (negedge clk_i)


  // periodic stat
  logic kernel_start_received_r;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      kernel_start_received_r <= 1'b0;
    end
    else begin
      if (print_stat_v_i && (print_stat_tag_i[data_width_p-1-:2] == 2'b10)) begin
        kernel_start_received_r <= 1'b1;
      end
    end
  end

  always @ (negedge clk_i) begin
    if (kernel_start_received_r && ((global_ctr_i % period_p) == 0)) begin
      periodic_fd = $fopen(periodicfile_lp, "a");
      $fwrite(log_fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
        global_ctr_i,
        stat_r.ld_count,
        stat_r.st_count,
        stat_r.atomic_count,
        stat_r.miss_count,
        stat_r.stall_rsp_count,
        stat_r.idle_count
      );
      $fclose(periodic_fd);
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

`BSG_ABSTRACT_MODULE(vcache_profiler)

