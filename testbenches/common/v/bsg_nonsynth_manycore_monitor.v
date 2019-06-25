/**
 *  bsg_nonsynth_manycore_monitor.v
 *
 */

`include "bsg_manycore_packet.vh"

module bsg_nonsynth_manycore_monitor
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter data_mask_width_lp=(data_width_p>>3)
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
    , output logic yumi_o

    , output logic [data_width_p-1:0] data_o
    , output logic v_o
  );

  int status;
  int max_cycle;
  initial begin
    status = $value$plusargs("max_cycle=%d", max_cycle);
    if (max_cycle == 0) begin
      max_cycle = 1000000; // default
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

  // handshaking
  //
  assign yumi_o = v_i;
  assign data_o = '0;

  always_ff @ (posedge clk_i) begin
    if (reset_i)
      v_o <= 1'b0;
    else
      v_o <= v_i & yumi_o;
  end


  // monitoring logic
  //
  logic [15:0] epa_addr;
  assign epa_addr = {addr_i[13:0], 2'b00};


  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin

      if (cycle_count > max_cycle) begin
        $display("[INFO][MONITOR] TIMEOUT reached max_cycle = %d", max_cycle);
        $finish;
      end

      if (v_i & we_i) begin
        if (epa_addr == 16'hEAD0) begin
          $display("[INFO][MONITOR] RECEIVED FINISH PACKET from tile y,x=%2d,%2d, data=%x, time=%0t",
            src_y_cord_i, src_x_cord_i, data_i, $time);
          $finish;
        end
        else if (epa_addr == 16'hEAD4) begin
          $display("[INFO][MONITOR] RECEIVED TIME PACKET from tile y,x=%2d,%2d, data=%x, time=%0t",
            src_y_cord_i, src_x_cord_i, data_i, $time);
        end
        else if (epa_addr == 16'hEAD8) begin
          $display("[INFO][MONITOR] RECEIVED FAIL PACKET from tile y,x=%2d,%2d, data=%x, time=%0t",
            src_y_cord_i, src_x_cord_i, data_i, $time);
          $finish;
        end
        else if (epa_addr == 16'hEADC) begin
          for (integer i = 0; i < 4; i++) begin
            if (mask_i[i]) begin
              $write("%c", data_i[i*8+:8]);
            end
          end
        end
        else begin
          $display("[INFO][MONITOR] RECEIVED IO PACKET from tile y,x=%2d,%2d, data=%x, addr=%x, time=%0t",
            src_y_cord_i, src_x_cord_i, data_i, addr_i, $time);
        end
      end
      else if (v_i & ~we_i) begin
        $display("[INFO][MONITOR] RECEIVED IO PACKET from tile y,x=%2d,%2d, time=%0t",
          src_y_cord_i, src_x_cord_i, $time);
      end
    end
  end



endmodule

