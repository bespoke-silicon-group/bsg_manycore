/**
 *    router_profiler.v
 *
 */

  // attach this to bsg_mesh_router


  // output format:
  //    {timestamp},{global_ctr},{x},{y},{XY_order_p},{output_dir},{idle},{utilized},{stalled},{arbitrated}

`include "bsg_manycore_defines.vh"

module router_profiler
  import bsg_noc_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(dims_p)
    , `BSG_INV_PARAM(XY_order_p)
    , `BSG_INV_PARAM(ruche_factor_X_p)
    
    , `BSG_INV_PARAM(origin_x_cord_p)
    , `BSG_INV_PARAM(origin_y_cord_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , parameter enable_periodic_p=0
    , parameter tracefile_p = "router_stat.csv"
    , parameter periodfile_p = "router_periodic_stat.csv"
    , parameter period_p = 250
    , localparam dirs_lp = 1+(2*dims_p)
  )
  (
    input clk_i
    , input reset_i
  

    , input [dirs_lp-1:0][dirs_lp-1:0] req_t
    , input [dirs_lp-1:0][dirs_lp-1:0] yumi_lo

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input print_stat_v_i
    , input [31:0] print_stat_tag_i
    , input [31:0] global_ctr_i
  );

  localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p);
  localparam y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p);
  wire [x_subcord_width_lp-1:0] sub_x = my_x_i[x_subcord_width_lp-1:0];
  wire [y_subcord_width_lp-1:0] sub_y = my_y_i[y_subcord_width_lp-1:0];


  // per output
  typedef struct packed {
    integer idle;
    integer utilized;
    integer stalled;
    integer arbitrated;
  } router_stat_s;


  router_stat_s [dirs_lp-1:0] stat_r;
  

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      stat_r <= '0;
    end
    else begin
      // count only bisection links;
      // local links:
      if (sub_x == (num_tiles_x_p/2)) begin
        stat_r[W].idle        <= stat_r[W].idle + ($countones(req_t[W]) == 0);
        stat_r[W].utilized    <= stat_r[W].utilized + ((req_t[W] & yumi_lo[W]) != '0);
        stat_r[W].stalled     <= stat_r[W].stalled + (($countones(req_t[W]) > 0) & (yumi_lo[W] == '0));
        stat_r[W].arbitrated  <= stat_r[W].arbitrated + (($countones(req_t[W]) > 1) & (yumi_lo[W] != '0));
      end
      if (sub_x == (num_tiles_x_p/2)-1) begin
        stat_r[E].idle        <= stat_r[E].idle + ($countones(req_t[E]) == 0);
        stat_r[E].utilized    <= stat_r[E].utilized + ((req_t[E] & yumi_lo[E]) != '0);
        stat_r[E].stalled     <= stat_r[E].stalled + (($countones(req_t[E]) > 0) & (yumi_lo[E] == '0));
        stat_r[E].arbitrated  <= stat_r[E].arbitrated + (($countones(req_t[E]) > 1) & (yumi_lo[E] != '0));
      end
      // ruche links;
      for (integer rf = 0; rf < ruche_factor_X_p; rf++) begin
        if (sub_x == (num_tiles_x_p/2)+rf) begin
          stat_r[RW].idle        <= stat_r[RW].idle + ($countones(req_t[RW]) == 0);
          stat_r[RW].utilized    <= stat_r[RW].utilized + ((req_t[RW] & yumi_lo[RW]) != '0);
          stat_r[RW].stalled     <= stat_r[RW].stalled + (($countones(req_t[RW]) > 0) & (yumi_lo[RW] == '0));
          stat_r[RW].arbitrated  <= stat_r[RW].arbitrated + (($countones(req_t[RW]) > 1) & (yumi_lo[RW] != '0));
        end
        if (sub_x == (num_tiles_x_p/2)-1-rf) begin
          stat_r[RE].idle        <= stat_r[RE].idle + ($countones(req_t[RE]) == 0);
          stat_r[RE].utilized    <= stat_r[RE].utilized + ((req_t[RE] & yumi_lo[RE]) != '0);
          stat_r[RE].stalled     <= stat_r[RE].stalled + (($countones(req_t[RE]) > 0) & (yumi_lo[RE] == '0));
          stat_r[RE].arbitrated  <= stat_r[RE].arbitrated + (($countones(req_t[RE]) > 1) & (yumi_lo[RE] != '0));
        end
      end
      /*
      for (integer i = 0; i < dirs_lp; i++) begin
        stat_r[i].idle        <= stat_r[i].idle + ($countones(req_t[i]) == 0);
        stat_r[i].utilized    <= stat_r[i].utilized + ((req_t[i] & yumi_lo[i]) != '0);
        stat_r[i].stalled     <= stat_r[i].stalled + (($countones(req_t[i]) > 0) & (yumi_lo[i] == '0));
        stat_r[i].arbitrated  <= stat_r[i].arbitrated + (($countones(req_t[i]) > 1) & (yumi_lo[i] != '0));
      end     
      */
    end
  end





  // logging
  integer fd;

  initial begin
    fd = $fopen(tracefile_p, "w");
    $fwrite(fd,"");
    $fclose(fd);
    fd = $fopen(periodfile_p, "w");
    $fwrite(fd,"");
    $fclose(fd);
  end

  // print header of csv
  always @ (negedge reset_i) begin

    if ((my_x_i == x_cord_width_p'(origin_x_cord_p))
      & (my_y_i == y_cord_width_p'(origin_y_cord_p))
      & (XY_order_p == 1)) begin

      fd = $fopen(tracefile_p, "a");
      $fwrite(fd,"global_ctr,x,y,XY_order,output_dir,idle,utilized,stalled\n");
      $fclose(fd);
      
      fd = $fopen(periodfile_p, "a");
      $fwrite(fd,"global_ctr,x,y,XY_order,output_dir,idle,utilized,stalled\n");
      $fclose(fd);
    end


  end


  // task to print periodic stat;
  task print_stat(integer fd, integer dir);
    $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n", 
      global_ctr_i, my_x_i, my_y_i, XY_order_p, dir,
      stat_r[dir].idle,
      stat_r[dir].utilized,
      stat_r[dir].stalled
    );
  endtask


  // when there is print_stat_v_i signal received, it dumps the stats.
  always @ (posedge clk_i) begin
    if (~reset_i & print_stat_v_i) begin
      fd = $fopen(tracefile_p, "a");
      // local links:
      if (sub_x == (num_tiles_x_p/2)) begin
        print_stat(fd, W);
      end
      if (sub_x == (num_tiles_x_p/2)-1) begin
        print_stat(fd, E);
      end
      // ruche links;
      for (integer rf = 0; rf < ruche_factor_X_p; rf++) begin
        if (sub_x == (num_tiles_x_p/2)+rf) begin
          print_stat(fd, RW);
        end
        if (sub_x == (num_tiles_x_p/2)-1-rf) begin
          print_stat(fd, RE);
        end
      end
      /*
      for (integer i = 0; i < dirs_lp; i++) begin
        $fwrite(fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n", 
          $time, global_ctr_i, my_x_i, my_y_i, XY_order_p, i,
          stat_r[i].idle,
          stat_r[i].utilized,
          stat_r[i].stalled,
          stat_r[i].arbitrated
        );
      end
      */
      $fclose(fd); 
    end
  end


  // period stat;
  logic kernel_start_received_r;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      kernel_start_received_r <= 1'b0;
    end
    else begin
      if (print_stat_v_i && (print_stat_tag_i[31:30] == 2'b10)) begin
        kernel_start_received_r <= 1'b1;
      end
    end
  end


  // print only bisection links
  always @ (posedge clk_i) begin
    if ((reset_i === 1'b0) && enable_periodic_p  && kernel_start_received_r && ((global_ctr_i % period_p) == 0)
        && (my_x_i >= origin_x_cord_p) && (my_x_i < (origin_x_cord_p+num_tiles_x_p))
        && (my_y_i >= origin_y_cord_p) && (my_y_i < (origin_y_cord_p+num_tiles_y_p))) begin
      fd = $fopen(periodfile_p, "a");
      // ver bisection
      if (my_y_i == (origin_y_cord_p+(num_tiles_y_p/2))) begin
        print_stat(fd, N);
      end
      if (my_y_i == (origin_y_cord_p+(num_tiles_y_p/2)-1)) begin
        print_stat(fd, S);
      end
      // hor bisection
      if (my_x_i == (origin_x_cord_p+(num_tiles_x_p/2))) begin
        print_stat(fd, W);
      end
      if (my_x_i == (origin_x_cord_p+(num_tiles_x_p/2)-1)) begin
        print_stat(fd, E);
      end
      // ruche X
      if (dims_p == 3) begin
        for (integer rf = 0; rf < ruche_factor_X_p; rf++) begin
          if (my_x_i == (origin_x_cord_p+(num_tiles_x_p/2)+rf)) begin
            print_stat(fd, RW);
          end
          if (my_x_i == (origin_x_cord_p+(num_tiles_x_p/2)-1-rf)) begin
            print_stat(fd, RE);
          end
        end
      end
      // tile-cache boundary
      if (my_y_i == origin_y_cord_p) begin
        print_stat(fd, N);
      end
      if (my_y_i == origin_y_cord_p+num_tiles_y_p-1) begin
        print_stat(fd, S);
      end
      $fclose(fd); 
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(router_profiler)
