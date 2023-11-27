/**
 *    router_profiler.v
 *
 */

  // attach this to bsg_mesh_router


  // output format:
  //    {timestamp},{global_ctr},{x},{y},{XY_order_p},{output_dir},{idle},{utilized},{stalled},{arbitrated}

module router_profiler
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter dims_p="inv"
    , parameter XY_order_p="inv"
    , parameter dirs_lp = 1+(2*dims_p)
    
    , parameter origin_x_cord_p="inv"
    , parameter origin_y_cord_p="inv"

    , parameter tracefile_p = "router_stat.csv"
  )
  (
    input clk_i
    , input reset_i
  

    , input [dirs_lp-1:0][dirs_lp-1:0] req_t
    , input [dirs_lp-1:0][dirs_lp-1:0] yumi_lo

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input trace_en_i
    , input print_stat_v_i
    , input [31:0] global_ctr_i
  );


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
      for (integer i = 0; i < dirs_lp; i++) begin
        stat_r[i].idle        <= stat_r[i].idle + ($countones(req_t[i]) == 0);
        stat_r[i].utilized    <= stat_r[i].utilized + ((req_t[i] & yumi_lo[i]) != '0);
        stat_r[i].stalled     <= stat_r[i].stalled + (($countones(req_t[i]) > 0) & (yumi_lo[i] == '0));
        stat_r[i].arbitrated  <= stat_r[i].arbitrated + (($countones(req_t[i]) > 1) & (yumi_lo[i] != '0));
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
      $fwrite(fd,"timestamp,global_ctr,x,y,XY_order,output_dir,idle,utilized,stalled,arbitrated\n");
      $fclose(fd);
      
    end


  end


  // when there is print_stat_v_i signal received, it dumps the stats.
  always @ (posedge clk_i) begin
    if (~reset_i & trace_en_i & print_stat_v_i) begin
      fd = $fopen(tracefile_p, "a");
      for (integer i = 0; i < dirs_lp; i++) begin
        $fwrite(fd, "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n", 
          $time, global_ctr_i, my_x_i, my_y_i, XY_order_p, i,
          stat_r[i].idle,
          stat_r[i].utilized,
          stat_r[i].stalled,
          stat_r[i].arbitrated
        );
      end
      $fclose(fd); 
    end
  end




endmodule
