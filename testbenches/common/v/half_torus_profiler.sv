
  // output format:
  //    {timestamp},{global_ctr},{x},{y},{XY_order_p},{output_dir},{utilized}

`include "bsg_manycore_defines.svh"

module half_torus_profiler
  import bsg_noc_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(XY_order_p)
    , `BSG_INV_PARAM(width_p)    

    , `BSG_INV_PARAM(origin_x_cord_p)
    , `BSG_INV_PARAM(origin_y_cord_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , parameter num_vc_p=2
    , parameter dims_p=2
    , localparam vc_link_width_lp=`bsg_vc_link_sif_width(width_p,num_vc_p)
    , localparam link_width_lp=`bsg_ready_and_link_sif_width(width_p)

    , parameter tracefile_p = "router_stat.csv"
    , parameter periodfile_p = "router_periodic_stat.csv"
    , parameter period_p = 250
    , parameter enable_periodic_p = 0
    , localparam dirs_lp = 1+(2*dims_p)
  )
  (
    input clk_i
    , input reset_i

    , input        [S:N][link_width_lp-1:0] ver_link_i
    , input        [S:N][link_width_lp-1:0] ver_link_o

    , input        [E:W][vc_link_width_lp-1:0] hor_link_i
    , input        [E:W][vc_link_width_lp-1:0] hor_link_o
  

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input print_stat_v_i
    , input [31:0] print_stat_tag_i
    , input [31:0] global_ctr_i
  );


  // Cast links;
  `declare_bsg_vc_link_sif_s(width_p,num_vc_p,bsg_vc_link_sif_s);
  `declare_bsg_ready_and_link_sif_s(width_p,bsg_link_sif_s);
  bsg_vc_link_sif_s [E:W] hor_link_in, hor_link_out;
  bsg_link_sif_s [S:N]    ver_link_in, ver_link_out;
  assign  hor_link_in  = hor_link_i;
  assign  hor_link_out = hor_link_o;
  assign  ver_link_in  = ver_link_i;
  assign  ver_link_out = ver_link_o;


  // per output
  typedef struct packed {
    integer utilized;
  } router_stat_s;


  router_stat_s [S:W] stat_r;
  

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      for (integer i = W; i <= E; i++) begin
        stat_r[i].utilized <= stat_r[i].utilized + (|(hor_link_out[i].v & hor_link_in[i].ready_and_rev));
      end     
      for (integer i = N; i <= S; i++) begin
        stat_r[i].utilized <= stat_r[i].utilized + (ver_link_out[i].v & ver_link_in[i].ready_and_rev);
      end     
    end
  end





  // logging
  integer fd;

  initial begin
    fd = $fopen(tracefile_p, "w");
    $fwrite(fd,"");
    $fclose(fd);
  end

  // print header of csv
  always @ (negedge reset_i) begin
    if ((my_x_i == x_cord_width_p'(origin_x_cord_p))
      & (my_y_i == y_cord_width_p'(origin_y_cord_p))
      & (XY_order_p == 1)) begin

      fd = $fopen(tracefile_p, "a");
      $fwrite(fd,"timestamp,global_ctr,x,y,XY_order,output_dir,utilized\n");
      $fclose(fd);
    end
  end


  // when there is print_stat_v_i signal received, it dumps the stats.
  always @ (posedge clk_i) begin
    if (~reset_i & print_stat_v_i) begin
      fd = $fopen(tracefile_p, "a");
      for (integer i = W; i <= S; i++) begin
        $fwrite(fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d\n", 
          $time, global_ctr_i, my_x_i, my_y_i, XY_order_p, i,
          stat_r[i].utilized,
        );
      end
      $fclose(fd); 
    end
  end




endmodule
