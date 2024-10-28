`include "bsg_manycore_defines.svh"

module torus_router_profiler
  import bsg_noc_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(dims_p)
    , `BSG_INV_PARAM(XY_order_p)
    
    , `BSG_INV_PARAM(origin_x_cord_p)
    , `BSG_INV_PARAM(origin_y_cord_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , parameter tracefile_p = "router_stat.csv"
    , parameter period_p = 250
    , parameter num_vc_p=2
    , localparam vc_dirs_lp = 1+(2*dims_p*num_vc_p)
  )
  (
    input clk_i
    , input reset_i

    , input [vc_dirs_lp-1:0] alloc_link_v_lo
    //, input [vc_dirs_lp-1:0] alloc_link_ready_li

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input print_stat_v_i
    , input [31:0] print_stat_tag_i
    , input [31:0] global_ctr_i
  );



  // per output
  typedef struct packed {
    integer utilized;
  } router_stat_s;


  router_stat_s [S:W] stat_r;

  
  // initialize file;
  integer fd;

  initial begin
    fd = $fopen(tracefile_p, "w");
    $fwrite(fd,"");
    $fclose(fd);
  end


  // write header;
  always @ (negedge reset_i) begin

    if ((my_x_i == x_cord_width_p'(origin_x_cord_p))
      & (my_y_i == y_cord_width_p'(origin_y_cord_p))
      & (XY_order_p == 1)) begin

      fd = $fopen(tracefile_p, "a");
      $fwrite(fd,"global_ctr,x,y,XY_order,output_dir,utilized\n");
      $fclose(fd);
    end

  end

  // count stats;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      if (XY_order_p) begin
        for (integer i = W; i <= S; i++) begin
          stat_r[i].utilized   <= stat_r[i].utilized + (|alloc_link_v_lo[1+(i*2)+:2]);
        end
      end
    end
  end



  // print stat;
  always @ (posedge clk_i) begin
    if (~reset_i & print_stat_v_i & XY_order_p) begin
      fd = $fopen(tracefile_p, "a");
      for (integer i = W; i <= S; i++) begin
        $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d\n", 
          global_ctr_i, my_x_i, my_y_i, XY_order_p, i,
          stat_r[i].utilized
        );
      end
      $fclose(fd); 
    end
  end


endmodule
