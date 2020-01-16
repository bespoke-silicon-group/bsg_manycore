/**
 *    vcache_non_blocking_profiler.v
 *
 */


module vcache_non_blocking_profiler
  import bsg_cache_non_blocking_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter id_width_p="inv"
    , parameter block_size_in_words_p="inv"

    , parameter data_mem_pkt_width_lp =
      `bsg_cache_non_blocking_data_mem_pkt_width(ways_p,sets_p,block_size_in_words_p,data_width_p)
    , parameter miss_fifo_entry_width_lp = 
      `bsg_cache_non_blocking_miss_fifo_entry_width(id_width_p,addr_width_p,data_width_p)
    , parameter dma_pkt_width_lp = 
      `bsg_cache_non_blocking_dma_pkt_width(addr_width_p)

    //, parameter lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
    //, parameter lg_block_size_in_words_lp = `BSG_SAFE_CLOG2(block_size_in_words_p)
    //, parameter byte_sel_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    //, parameter tag_width_lp = (addr_width_p-lg_sets_lp-lg_block_size_in_words_lp-byte_sel_width_lp)
    //, parameter mhu_dff_width_lp =
    //  `bsg_cache_non_blocking_mhu_dff_width(id_width_p,addr_width_p,tag_width_lp,ways_p)
  ) 
  (
    input clk_i
    , input reset_i

    , input [data_mem_pkt_width_lp-1:0] tl_data_mem_pkt_lo
    , input tl_data_mem_pkt_v_lo
    , input tl_data_mem_pkt_ready_li

    , input mhu_idle
  
    , input [data_mem_pkt_width_lp-1:0] mhu_data_mem_pkt_lo
    , input mhu_data_mem_pkt_v_lo
    , input mhu_data_mem_pkt_yumi_li

    , input [miss_fifo_entry_width_lp-1:0] miss_fifo_data_li
    , input miss_fifo_v_li
    , input miss_fifo_ready_lo

    , input [dma_pkt_width_lp-1:0] dma_pkt_o
    , input dma_pkt_v_o
    , input dma_pkt_yumi_i

    , input dma_cmd_v_lo
    , input replacement_dirty // connect to mhu0.replacement_dirty
    , input replacement_valid // connect to mhu0.replacement_valid
    //, input [mhu_dff_width_lp-1:0] mhu_dff_r // connect to mhu0.mhu_dff_r

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i
  );


  //  cast structs
  //
  `declare_bsg_cache_non_blocking_data_mem_pkt_s(ways_p,sets_p,block_size_in_words_p,data_width_p);
  `declare_bsg_cache_non_blocking_miss_fifo_entry_s(id_width_p,addr_width_p,data_width_p);
  `declare_bsg_cache_non_blocking_dma_pkt_s(addr_width_p);

  bsg_cache_non_blocking_data_mem_pkt_s tl_data_mem_pkt;
  bsg_cache_non_blocking_data_mem_pkt_s mhu_data_mem_pkt;
  assign tl_data_mem_pkt = tl_data_mem_pkt_lo;
  assign mhu_data_mem_pkt = mhu_data_mem_pkt_lo;
  
  bsg_cache_non_blocking_miss_fifo_entry_s miss_fifo_data;
  assign miss_fifo_data = miss_fifo_data_li;

  bsg_cache_non_blocking_dma_pkt_s dma_pkt;
  assign dma_pkt = dma_pkt_o;

  //`declare_bsg_cache_non_blocking_miss_fifo_entry_width(id_width_p,addr_width_p,data_width_p);
  //bsg_cache_non_blocking_mhu_dff_s mhu_dff;
  //assign mhu_dff = mhu_dff_r;


  //  Profiling Events
  //
  //  - ld_hit (tl_stage)     : total # of load hits.
  //  - st_hit (tl_stage)     : total # of store hit.
  //  - ld_hit_under_miss     : # of load hits during cache miss (subset of load_hit)
  //  - st_hit_under_miss     : # of store hits during cache miss (subset of store_hit)
  //  - ld_miss               : # of loads that went into miss fifo.
  //  - st_miss               : # of stores that went into miss fifo.
  //  - ld_mhu (mhu)          : # of loads processed by MHU.
  //  - st_mhu (mhu)          : # of stores processed by MHU.
  //  - DMA_read_req          : # of DMA read requests
  //  - DMA_write_req         : # of DMA write requests
  wire ld_hit_inc = ~tl_data_mem_pkt.write_not_read & tl_data_mem_pkt_v_lo & tl_data_mem_pkt_ready_li;
  wire st_hit_inc = tl_data_mem_pkt.write_not_read & tl_data_mem_pkt_v_lo & tl_data_mem_pkt_ready_li;

  wire ld_hit_under_miss_inc = ld_hit_inc & ~mhu_idle;
  wire st_hit_under_miss_inc = st_hit_inc & ~mhu_idle;

  wire ld_miss_inc = ~miss_fifo_data.write_not_read & miss_fifo_v_li & miss_fifo_ready_lo;
  wire st_miss_inc = miss_fifo_data.write_not_read & miss_fifo_v_li & miss_fifo_ready_lo;

  wire ld_mhu_inc = ~mhu_data_mem_pkt.write_not_read & mhu_data_mem_pkt_v_lo & mhu_data_mem_pkt_yumi_li;
  wire st_mhu_inc = mhu_data_mem_pkt.write_not_read & mhu_data_mem_pkt_v_lo & mhu_data_mem_pkt_yumi_li;

  wire dma_read_req_inc = ~dma_pkt.write_not_read & dma_pkt_v_o & dma_pkt_yumi_i;
  wire dma_write_req_inc = dma_pkt.write_not_read & dma_pkt_v_o & dma_pkt_yumi_i;

  // replacement stat
  //
  wire replace_invalid_inc = dma_cmd_v_lo & ~replacement_valid;
  wire replace_valid_inc = dma_cmd_v_lo & replacement_valid & ~replacement_dirty;
  wire replace_dirty_inc = dma_cmd_v_lo & replacement_valid & replacement_dirty;
  

  // stat struct
  //
  typedef struct packed {
    integer ld_hit;
    integer st_hit;
    integer ld_hit_under_miss;
    integer st_hit_under_miss;
    integer ld_miss;
    integer st_miss;
    integer ld_mhu;
    integer st_mhu;
    integer dma_read_req;
    integer dma_write_req;

    integer replace_invalid;
    integer replace_valid;
    integer replace_dirty;
  } vcache_non_blocking_stat_s;

  vcache_non_blocking_stat_s stat_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      if (ld_hit_inc) stat_r.ld_hit++;
      if (st_hit_inc) stat_r.st_hit++;
      if (ld_hit_under_miss_inc) stat_r.ld_hit_under_miss++;
      if (st_hit_under_miss_inc) stat_r.st_hit_under_miss++;
      if (ld_miss_inc) stat_r.ld_miss++;
      if (st_miss_inc) stat_r.st_miss++;
      if (ld_mhu_inc) stat_r.ld_mhu++;
      if (st_mhu_inc) stat_r.st_mhu++;
      if (dma_read_req_inc) stat_r.dma_read_req++;
      if (dma_write_req_inc) stat_r.dma_write_req++;

      if (replace_invalid_inc) stat_r.replace_invalid++;
      if (replace_valid_inc) stat_r.replace_valid++;
      if (replace_dirty_inc) stat_r.replace_dirty++;
    end
  end
   
  
  // file logging
  //
  localparam logfile_lp = "vcache_non_blocking_stats.log";

  string my_name;
  integer fd; 

  initial begin
 
    my_name = $sformatf("%m");
    if (str_match(my_name, "vcache[0]")) begin
      fd = $fopen(logfile_lp, "w");
      $fwrite(fd, "instance,global_ctr,tag,ld_hit,st_hit,ld_hit_under_miss,st_hit_under_miss,ld_miss,st_miss,ld_mhu,st_mhu,dma_read_req,dma_write_req,");
      $fwrite(fd, "replace_invalid,replace_valid,replace_dirty\n");
      $fclose(fd);
    end
  
    forever begin
      @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin

          $display("[BSG_INFO][VCACHE_PROFILER] %s t=%0t printing stats.", my_name, $time);

          fd = $fopen(logfile_lp, "a");
          $fwrite(fd, "%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            my_name, global_ctr_i, print_stat_tag_i,
            stat_r.ld_hit, stat_r.st_hit,
            stat_r.ld_hit_under_miss, stat_r.st_hit_under_miss,
            stat_r.ld_miss, stat_r.st_miss,
            stat_r.ld_mhu, stat_r.st_mhu,
            stat_r.dma_read_req, stat_r.dma_write_req
          );   
          $fwrite(fd, "%0d,%0d,%0d\n",
            stat_r.replace_invalid,
            stat_r.replace_valid,
            stat_r.replace_dirty
          );   
          $fclose(fd);
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
