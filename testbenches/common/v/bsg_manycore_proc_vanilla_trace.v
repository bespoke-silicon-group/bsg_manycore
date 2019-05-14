/**
 *  bsg_manycore_proc_vanilla_trace
 *  
 *  trace format:
 *
 */


module bsg_manycore_proc_vanilla_trace
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter data_width_p="inv"
    , parameter dmem_size_p="inv"

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam mem_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
  )
  (
    input clk_i
    , input reset_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i 
  );


  // hobbit signals (h_)
  //
  wire h_freeze = bsg_manycore_proc_vanilla.hobbit0.freeze_i;
  wire h_stall = bsg_manycore_proc_vanilla.hobbit0.stall;
  wire h_rf_wen = bsg_manycore_proc_vanilla.hobbit0.rf_wen;
  wire [4:0] h_rf_wa = bsg_manycore_proc_vanilla.hobbit0.rf_wa;
  wire [31:0] h_rf_wd = bsg_manycore_proc_vanilla.hobbit0.rf_wd; 

  wire [31:0] h_exe_pc = (bsg_manycore_proc_vanilla.hobbit0.exe.pc_plus4 - 'd4) | 32'h80000000;
  wire [31:0] h_exe_instr = bsg_manycore_proc_vanilla.hobbit0.exe.instruction;
  wire h_pending_load_arrived = bsg_manycore_proc_vanilla.hobbit0.pending_load_arrived;
  wire h_to_mem_v_o = bsg_manycore_proc_vanilla.hobbit0.to_mem_v_o;
  wire h_to_mem_yumi_i = bsg_manycore_proc_vanilla.hobbit0.to_mem_yumi_i;
  wire h_remote_load_in_exe = bsg_manycore_proc_vanilla.hobbit0.remote_load_in_exe;
  wire h_insert_load_in_exe = bsg_manycore_proc_vanilla.hobbit0.insert_load_in_exe;
  wire [4:0] h_exe_rd = bsg_manycore_proc_vanilla.hobbit0.exe.instruction.rd;
  wire [4:0] h_exe_rd_addr = bsg_manycore_proc_vanilla.hobbit0.exe_rd_addr;


  wire remote_load_sent = h_to_mem_v_o & h_to_mem_yumi_i & h_remote_load_in_exe;

  logic [31:0] h_mem_pc_r;
  logic [31:0] h_mem_instr_r;
  logic mem_is_remote_load_r;

  logic [31:0] h_wb_pc_r;
  logic [31:0] h_wb_instr_r;
  logic wb_is_remote_load_r;

  logic [31:0][31:0] remote_load_pc_r;
  logic [31:0][31:0] remote_load_instr_r;
  

  // remote load tracking
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      remote_load_pc_r <= '0;
      remote_load_instr_r <= '0;
    end
    else begin
      if (remote_load_sent) begin
        remote_load_pc_r[h_exe_rd] <= h_exe_pc;
        remote_load_instr_r[h_exe_rd] <= h_exe_instr;
      end
    end
  end


  // delay pipeline logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i | h_freeze) begin
      h_mem_pc_r <= '0;
      h_mem_instr_r <= '0;
      h_wb_pc_r <= '0;
      h_wb_instr_r <= '0;
    end
    else begin
      if (~h_stall) begin

        h_mem_pc_r <= h_insert_load_in_exe
          ? remote_load_pc_r[h_exe_rd_addr]
          : h_exe_pc;
        h_mem_instr_r <= h_insert_load_in_exe
          ? remote_load_pc_r[h_exe_rd_addr]
          : h_exe_instr;
        mem_is_remote_load_r <= h_insert_load_in_exe;
      
        h_wb_pc_r <= h_mem_pc_r;
        h_wb_instr_r <= h_mem_instr_r;
        wb_is_remote_load_r <= mem_is_remote_load_r;

      end
    end
  end


 

  // trace logger
  //
  integer fd;

  initial begin

    fd = $fopen("vanilla.log", "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin
        // we only trace when tile is unfrozen.
        if (~h_freeze) begin
        
          fd = $fopen("vanilla.log", "a");
   
          $fwrite(fd, "%08t ", $time); // timestamp
          $fwrite(fd, "%2d %2d ", my_x_i, my_y_i); // x,y
          
          // regfile write
          if (h_rf_wen) begin

            if (h_stall & h_pending_load_arrived) begin
              // 1. remote load direct write to rf (Rx)
              $fwrite(fd, "%08x %08x ", remote_load_pc_r[h_rf_wa], remote_load_instr_r[h_rf_wa]);
              $fwrite(fd, "Rx[%2d]=%08x", h_rf_wa, h_rf_wd);

            end
            else if (wb_is_remote_load_r) begin
              // 2. remote load wb (Rx)
              $fwrite(fd, "%08x %08x ", h_wb_pc_r, h_wb_instr_r);
              $fwrite(fd, "Rx[%2d]=%08x", h_rf_wa, h_rf_wd);

            end
            else begin
              // 3. other types of wb (Lx)
              $fwrite(fd, "%08x %08x ", h_wb_pc_r, h_wb_instr_r);
              $fwrite(fd, "Lx[%2d]=%08x", h_rf_wa, h_rf_wd);
            end
          end
          else begin
            // print nothing
            $fwrite(fd, {(8+1+8+1+2+4+1+8){" "}});
          end



          $fwrite(fd, "\n");
          $fclose(fd);
      
        end
      end
    end


  end 



endmodule
