/**
 *    vcache_profiler.v
 *    
 */


module vcache_profiler
  import bsg_cache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter ways_p="inv"

    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter dma_pkt_width_lp=`bsg_cache_dma_pkt_width(addr_width_p)
    , parameter stat_info_width_lp=`bsg_cache_stat_info_width(ways_p)
  )
  (
    input clk_i
    , input reset_i

    , input v_o
    , input yumi_i
    , input miss_v
    , input bsg_cache_pkt_decode_s decode_v_r

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
  );

  `declare_bsg_cache_dma_pkt_s(addr_width_p);
  bsg_cache_dma_pkt_s dma_pkt;
  assign dma_pkt = dma_pkt_o;

  `declare_bsg_cache_stat_info_s(ways_p);
  bsg_cache_stat_info_s stat_info;
  assign stat_info = stat_mem_data_lo;

  // event signals
  //
  wire inc_ld = v_o & yumi_i & decode_v_r.ld_op;
  wire inc_st = v_o & yumi_i & decode_v_r.st_op;
  wire inc_ld_miss = v_o & yumi_i & decode_v_r.ld_op & miss_v;
  wire inc_st_miss = v_o & yumi_i & decode_v_r.st_op & miss_v;
  wire inc_dma_read_req = dma_pkt_v_o & dma_pkt_yumi_i & ~dma_pkt.write_not_read;
  wire inc_dma_write_req = dma_pkt_v_o & dma_pkt_yumi_i & dma_pkt.write_not_read;

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
    integer st_count;
    integer ld_miss_count;
    integer st_miss_count;
    integer dma_read_req;
    integer dma_write_req;
    integer replace_invalid;
    integer replace_valid;
    integer replace_dirty;
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
      if (inc_replace_invalid) stat_r.replace_invalid++;
      if (inc_replace_valid) stat_r.replace_valid++;
      if (inc_replace_dirty) stat_r.replace_dirty++;
    end

  end


  // file logging
  //
  localparam logfile_lp = "vcache_stats.log";

  string my_name;
  integer fd;

  initial begin

    my_name = $sformatf("%m");
    if (str_match(my_name, "vcache[0]")) begin
      fd = $fopen(logfile_lp, "w");
      $fwrite(fd, "instance,global_ctr,tag,ld,st,ld_miss,st_miss,dma_read_req,dma_write_req,");
      $fwrite(fd, "replace_invalid,replace_valid,replace_dirty\n");
      $fclose(fd);
    end

    forever begin
      @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin

          $display("[BSG_INFO][VCACHE_PROFILER] %s t=%0t printing stats.", my_name, $time);

          fd = $fopen(logfile_lp, "a");
          $fwrite(fd, "%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,",
            my_name, global_ctr_i, print_stat_tag_i,
            stat_r.ld_count, stat_r.st_count,
            stat_r.ld_miss_count, stat_r.st_miss_count,
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
