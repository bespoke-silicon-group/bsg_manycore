/**
 *    infinite_mem_profiler.v
 *
 */

`include "bsg_manycore_defines.svh"

module infinite_mem_profiler
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter string logfile_p="infinite_mem_stats.log"
    , parameter manycore_packet_width_lp=
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input packet_v_lo
    , input [manycore_packet_width_lp-1:0] packet_lo
    , input packet_yumi_li

    , input [31:0] global_ctr_i
    , input print_stat_v_i
    , input [data_width_p-1:0] print_stat_tag_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_packet_s packet_cast;
  assign packet_cast = packet_lo;

  wire inc = packet_v_lo & packet_yumi_li; 
  wire inc_ld = inc & (packet_cast.op_v2 == e_remote_load);
  wire inc_st = inc & (packet_cast.op_v2 == e_remote_store);
  wire inc_amoswap = inc & (packet_cast.op_v2 == e_remote_amoswap);
  wire inc_amoor = inc & (packet_cast.op_v2 == e_remote_amoor);
  
  integer ld_count_r;
  integer st_count_r;
  integer amoswap_count_r;
  integer amoor_count_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      ld_count_r = '0;
      st_count_r = '0;
      amoswap_count_r = 0;
      amoor_count_r = 0;
    end
    else begin
      if (inc_ld) ld_count_r++;
      if (inc_st) st_count_r++;
      if (inc_amoswap) amoswap_count_r++;
      if (inc_amoor) amoor_count_r++;
    end
  end

  // file logging
  //

  integer fd;
  string header;
   initial begin
      fd = $fopen(logfile_p, "w");
      $fwrite(fd,"");
   end

  always @(negedge reset_i) begin
     if (my_x_i == '0) begin
      fd = $fopen(logfile_p, "a");
      $fwrite(fd, "x,y,global_ctr,tag,ld,st,amoswap,amoor\n");
      $fclose(fd);
    end
  end

   always @(negedge clk_i) begin
        if (~reset_i & print_stat_v_i) begin
          fd = $fopen(logfile_p, "a");
          $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
            my_x_i, my_y_i, global_ctr_i, print_stat_tag_i, ld_count_r, st_count_r,
            amoswap_count_r,amoor_count_r);   
          $fclose(fd);
        end
   end
   


endmodule
