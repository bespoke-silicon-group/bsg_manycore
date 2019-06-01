/**
 *  vanilla_core_trace.v
 *
 */

`include "definitions.vh"

module vanilla_core_trace
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter data_width_p="inv"
    , parameter dmem_size_p="inv"

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    , localparam bsg_data_end_lp = `_bsg_data_end_addr
  )
  (
    input clk_i
    , input reset_i

    , input stall
    , input exe_signals_s exe_r
    , input mem_signals_s mem_r
    , input wb_signals_s wb_r

    , input dmem_v_li
    , input dmem_w_li
    , input [dmem_addr_width_lp-1:0] dmem_addr_li
    , input [data_width_p-1:0] dmem_data_li
    , input [data_width_p-1:0] dmem_data_lo

    , input int_rf_wen
    , input [4:0] int_rf_waddr
    , input [data_width_p-1:0] int_rf_wdata

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i 
  );

  exe_signals_s exe_rr, exe_rrr;
  mem_signals_s mem_rr;
  logic [data_width_p-1:0] exe_pc_r;
  logic [data_width_p-1:0] exe_pc_rr;
  logic dmem_read_r;
  logic [dmem_addr_width_lp-1:0] dmem_addr_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      exe_rr <= '0;
      exe_rrr <= '0;
      mem_rr <= '0;
      exe_pc_r <= '0;
      exe_pc_rr <= '0;
      dmem_read_r <= '0;
      dmem_addr_r <= '0;
    end
    else begin
      if (~stall) begin
        exe_rr <= exe_r;
        exe_rrr <= exe_rr;
        mem_rr <= mem_r;
        exe_pc_r <= (exe_r.pc_plus4 - 'd4) | 32'h80000000;
        exe_pc_rr <= exe_pc_r;
        dmem_read_r <= dmem_v_li & ~dmem_w_li;
        dmem_addr_r <= dmem_addr_li;
      end
    end
  end


  integer fd;
  string stamp;
  string pc_instr;
  string rf_write;
  string dmem_read;
  string dmem_write;

  initial begin
    fd = $fopen("vanilla.log", "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin
        stamp = "";
        pc_instr = "";
        rf_write = "";
        dmem_read = "";
        dmem_write = "";

        if (my_x_i == 1'b0 & my_y_i == 2'b01 & ~reset_i) begin //

        fd = $fopen("vanilla.log", "a");
   
        // stamp
        stamp = $sformatf("t=%08t x=%2d y=%2d: ", $time, my_x_i, my_y_i);
    
        // pc_instr
        pc_instr = $sformatf("pc=%08x instr=%08x", exe_pc_rr, exe_rrr.instruction);
 
        // rf_write
        if (int_rf_wen)
          rf_write = $sformatf("x%2d=%08x", int_rf_waddr, int_rf_wdata);
        else
          rf_write = {(4+8){" "}};

        // dmem_read
        if (dmem_read_r)
          dmem_read = $sformatf("M[%03x]==%08x", dmem_addr_r, dmem_data_lo);
        else
          dmem_read = {(8+8){" "}};
        // dmem_write
        if (dmem_v_li & dmem_w_li) 
          dmem_write = $sformatf("M[%03x]:=%08x", dmem_addr_li, dmem_data_li);
        else
          dmem_write = {(8+8){" "}};

        $fwrite(fd, "%s %s %s %s %s\n", 
          stamp,
          pc_instr,
          rf_write,
          dmem_read,
          dmem_write
        );

        $fclose(fd);

        end //

      end
    end

  end 


  // synopsys translate_off
  
  // SP (x2) overflow checking.
  always_ff @ (negedge clk_i) begin
    if (int_rf_wen & (int_rf_waddr == 2) & int_rf_wdata < bsg_data_end_lp) begin
      $display("[ERROR][VCORE] SP underflow. t=%0t data_end=%x, sp=%x",
        $time, bsg_data_end_lp, int_rf_wdata);
    end
  end
 

  // synopsys translate_on

endmodule
