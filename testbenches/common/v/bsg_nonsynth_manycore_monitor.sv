/**
 *  bsg_nonsynth_manycore_monitor.v
 *
 */

`include "bsg_manycore_defines.svh"

module bsg_nonsynth_manycore_monitor
 
  // Import address parameters
  import bsg_manycore_pkg::*;
  import bsg_manycore_addr_pkg::*;

  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)
    , parameter `BSG_INV_PARAM(addr_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)

    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter mem_els_p=2**18
    , parameter mem_addr_width_lp=`BSG_SAFE_CLOG2(mem_els_p)

    , parameter `BSG_INV_PARAM(saif_toggle_scope_p)
  
    , parameter uptime_p = 1
  )
  (
    input clk_i
    , input  reset_i

    , input v_i
    , input [data_width_p-1:0] data_i
    , input [data_mask_width_lp-1:0] mask_i
    , input [addr_width_p-1:0] addr_i
    , input we_i
    , input [x_cord_width_p-1:0] src_x_cord_i
    , input [y_cord_width_p-1:0] src_y_cord_i
    , input bsg_manycore_load_info_s load_info_i
    , output logic yumi_o

    , output logic [data_width_p-1:0] data_o
    , output logic v_o


    , output logic print_stat_v_o
    , output logic [data_width_p-1:0] print_stat_tag_o
  );

  longint max_cycle;
  int num_finish;   // Number of finish packets needs to be received to end the simulation.
                    // By default, number of pods running the SPMD program. Each pod sends one finish packet.
                    // However, you can set a different number, depending on the nature of the spmd program.
                    // For example, you can require a finish packet from each tile in 4x4 tile-group spmd program.
                    // In  that case, you would set num_finish to 16. this helps with not requiring barrier to synchronize task completion of all tiles.
  initial begin
    void'($value$plusargs("max_cycle=%d", max_cycle));
    void'($value$plusargs("num_finish=%d", num_finish));
    if (max_cycle == 0) begin
      max_cycle = 1000000; // default
    end
  end


  // get uptime from proc uptime.
  function string get_uptime();
    string uptime;
    if (uptime_p) begin
      int fd;
      fd = $fopen("/proc/uptime", "r");
      void'($fscanf(fd, "%s", uptime));
      $fclose(fd);
    end
    return uptime;
  endfunction


  // keep track of number of finish packets received.
  integer finish_count;
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      if (finish_count == num_finish) begin
        $display("[INFO][MONITOR] RECEIVED BSG_FINISH PACKET from all pods, time=%0t", $time);
        $finish;
      end
    end
  end

  // cycle counter
  //
  logic [39:0] cycle_count;

  bsg_cycle_counter #(
    .width_p(40)
    ,.init_val_p(0)
  ) cc (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.ctr_r_o(cycle_count)
  );

  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      if (cycle_count > max_cycle) begin
        $display("[INFO][MONITOR] BSG_TIMEOUT reached max_cycle = %d", max_cycle);
        $finish;
      end
    end
  end

  // off-chip memory that tiles can access.
  //
  logic mem_v_li;
  logic mem_w_li;
  logic [data_width_p-1:0] mem_data_li;
  logic [data_width_p-1:0] mem_data_lo;
  logic [data_mask_width_lp-1:0] mem_mask_li;
  logic [mem_addr_width_lp-1:0] mem_addr_li;
  
  bsg_mem_1rw_sync_mask_write_byte #(
    .data_width_p(data_width_p)
    ,.els_p(mem_els_p) // 1MB in total
  ) host_dram (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.v_i(mem_v_li)
    ,.w_i(mem_w_li)  
    ,.addr_i(mem_addr_li)
    ,.data_i(mem_data_li)
    ,.write_mask_i(mem_mask_li)
    ,.data_o(mem_data_lo)
  );

  assign mem_addr_li = addr_i[0+:mem_addr_width_lp];
  assign mem_data_li = data_i;
  assign mem_mask_li = mask_i;


  logic send_mem_data_r, send_mem_data_n;
  logic send_zero_data_r, send_zero_data_n;

  always_comb begin

    send_mem_data_n = 1'b0;
    send_zero_data_n = 1'b0;
    mem_v_li = 1'b0;
    mem_w_li = 1'b0;
    yumi_o = 1'b0;

    if (addr_i[addr_width_p-1]) begin
      send_zero_data_n = v_i & we_i;
      send_mem_data_n = v_i & ~we_i;
      mem_v_li = v_i;
      mem_w_li = we_i;
      yumi_o = v_i;
    end
    else begin
      send_zero_data_n = v_i;
      yumi_o = v_i;
    end
  end


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      send_mem_data_r <= 1'b0;
      send_zero_data_r <= 1'b0;
    end
    else begin
      send_mem_data_r <= send_mem_data_n;
      send_zero_data_r <= send_zero_data_n;
    end
  end



  assign v_o = send_mem_data_r | send_zero_data_r;
  assign data_o = send_mem_data_r
    ? mem_data_lo
    : '0;


  // monitoring logic
  //
  wire [15:0] epa_addr = {addr_i[13:0], 2'b00};
  integer out_fd;



  always_ff @ (negedge clk_i) begin
    if (reset_i) begin
      finish_count <= 0;
    end
    else begin
      if (v_i & we_i) begin
        if (~addr_i[addr_width_p-1]) begin
          if (epa_addr == bsg_finish_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED a finish packet from tile y,x=%2d,%2d, data=%x, sim_time=%0t, wall_time=%s",
              src_y_cord_i, src_x_cord_i, data_i, $time, get_uptime());
            finish_count <= finish_count + 1;
          end
          else if (epa_addr == bsg_time_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED TIME BSG_PACKET from tile y,x=%2d,%2d, data=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, $time);
          end
          else if (epa_addr == bsg_heartbeat_init_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED HEARTBEAT START from tile y,x=%2d,%2d, data=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, $time);
          end
          else if (epa_addr == bsg_heartbeat_iter_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED HEARTBEAT ITER from tile y,x=%2d,%2d, data=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, $time);
          end
          else if (epa_addr == bsg_heartbeat_end_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED HEARTBEAT END from tile y,x=%2d,%2d, data=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, $time);
          end
          else if (epa_addr == bsg_fail_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED BSG_FAIL PACKET from tile y,x=%2d,%2d, data=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, $time);
            $finish;
          end
          else if (epa_addr == bsg_stdout_epa_gp || epa_addr == bsg_stderr_epa_gp) begin
            out_fd = (epa_addr == bsg_stdout_epa_gp) 
                       ? 32'h8000_0001  // 0xEADC => stdout
                       : 32'h8000_0002; // 0xEEE0 => stderr

            for (integer i = 0; i < 4; i++) begin
              if (mask_i[i]) begin
                $fwrite(out_fd, "%c", data_i[i*8+:8]);
              end
            end
          end
          else if (epa_addr == bsg_branch_trace_epa_gp) begin
            // Branch and JALR trace
            $fwrite('h8000_0002, "BSG_BRANCH_TRACE t=%0t x=%0d y=%0d target=%x\n"
                      , $time, src_x_cord_i, src_y_cord_i, data_i
                   );
          end
          else if (epa_addr == bsg_print_stat_epa_gp) begin
            $display("[INFO][MONITOR] RECEIVED PRINT_STAT PACKET from tile y,x=%2d,%2d, data=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, $time);      
          end
`ifdef SAIF
          else if (epa_addr == bsg_saif_start_addr_gp) begin
            $display("[SAIF] saif on.  %m. t = %t", $time);
            $set_gate_level_monitoring("rtl_on", "sv");
            $set_toggle_region(saif_toggle_scope_p);
            $toggle_start();
          end
          else if (epa_addr == bsg_saif_end_addr_gp) begin
            $display("[SAIF] saif off. %m. t = %t", $time);
            $toggle_stop();
            $toggle_report("vanilla.saif", 1.0e-12, saif_toggle_scope_p);
          end
`endif
          else begin
            $display("[INFO][MONITOR] RECEIVED BSG_IO PACKET from tile y,x=%2d,%2d, data=%x, addr=%x, time=%0t",
              src_y_cord_i, src_x_cord_i, data_i, addr_i, $time);
          end
          
        end
      end
      else if (v_i & ~we_i) begin
        if (~addr_i[addr_width_p-1]) begin
          $display("[INFO][MONITOR] RECEIVED BSG_IO PACKET from tile y,x=%2d,%2d, time=%0t",
            src_y_cord_i, src_x_cord_i, $time);
        end
      end
    end
  end

  // print stat trigger
  //
  assign print_stat_v_o = v_i & (epa_addr == bsg_print_stat_epa_gp);
  assign print_stat_tag_o = data_i;

endmodule

`BSG_ABSTRACT_MODULE(bsg_nonsynth_manycore_monitor)

