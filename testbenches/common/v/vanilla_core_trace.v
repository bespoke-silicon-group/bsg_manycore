/**
 *  vanilla_core_trace.v
 *
 */


module vanilla_core_trace
  import bsg_vanilla_pkg::*;
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter data_width_p="inv"
    , parameter dmem_size_p="inv"

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    , localparam reg_addr_width_lp=RV32_reg_addr_width_gp
    //, localparam bsg_data_end_lp = `_bsg_data_end_addr
  )
  (
    input clk_i
    , input reset_i

    , input trace_en_i

    , input stall
    , input stall_fp
    //, input stall_depend
    , input stall_ifetch_wait
    , input stall_icache_store
    , input stall_lr_aq
    , input stall_fence
    , input stall_md
    , input stall_force_wb
    , input stall_remote_req
    , input stall_local_flw

    //, input flush
    
    , input id_signals_s id_r
    , input exe_signals_s exe_r

    , input [pc_width_lp-1:0] pc_n

    , input int_rf_wen
    , input [reg_addr_width_lp-1:0] int_rf_waddr
    , input [data_width_p-1:0] int_rf_wdata

    , input fp_exe_valid
  
    , input float_rf_wen
    , input [reg_addr_width_lp-1:0] float_rf_waddr
    , input [data_width_p-1:0] float_rf_wdata

    , input lsu_dmem_v_lo
    , input lsu_dmem_w_lo
    , input [dmem_addr_width_lp-1:0] lsu_dmem_addr_lo
    , input [data_width_p-1:0] lsu_dmem_data_lo
    , input [data_width_p-1:0] local_load_packed_data
  
    , input remote_req_s remote_req_o
    , input remote_req_v_o
    //, input remote_req_yumi_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  exe_debug_s exe_debug;
  mem_debug_s mem_debug;
  wb_debug_s wb_debug;

  assign exe_debug.pc = exe_r.pc_plus4 - 'd4;
  assign exe_debug.instr = exe_r.instruction;
  assign exe_debug.branch_or_jump = exe_r.decode.is_branch_op
    | exe_r.decode.is_jal_op | exe_r.decode.is_jalr_op;
  assign exe_debug.btarget = {{(32-2-pc_width_lp){1'b0}}, pc_n, 2'b00};

  assign exe_debug.is_local_load = lsu_dmem_v_lo & ~lsu_dmem_w_lo;
  assign exe_debug.is_local_store = lsu_dmem_v_lo & lsu_dmem_w_lo;
  assign exe_debug.local_dmem_addr = lsu_dmem_addr_lo;
  assign exe_debug.local_store_data = lsu_dmem_data_lo;

  assign exe_debug.is_remote_load = remote_req_v_o & ~remote_req_o.write_not_read & ~remote_req_o.load_info.icache_fetch;
  assign exe_debug.is_remote_store = remote_req_v_o & remote_req_o.write_not_read;
  assign exe_debug.remote_addr = remote_req_o.addr;
  assign exe_debug.remote_store_data = remote_req_o.data;


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mem_debug <= '0;
      wb_debug <= '0;
    end
    else begin
      if (~stall) begin

        mem_debug <= {
          pc: exe_debug.pc,
          instr: exe_debug.instr,
          branch_or_jump: exe_debug.branch_or_jump,
          btarget: exe_debug.btarget,

          is_local_load: exe_debug.is_local_load,
          is_local_store: exe_debug.is_local_store,
          local_dmem_addr: exe_debug.local_dmem_addr,
          local_store_data: exe_debug.local_store_data,

          is_remote_load: exe_debug.is_remote_load,
          is_remote_store: exe_debug.is_remote_store,
          remote_addr: exe_debug.remote_addr,
          remote_store_data: exe_debug.remote_store_data
        };
  
        wb_debug <= {
          pc: mem_debug.pc,
          instr: mem_debug.instr,
          branch_or_jump: mem_debug.branch_or_jump,
          btarget: mem_debug.btarget,

          is_local_load: mem_debug.is_local_load,
          is_local_store: mem_debug.is_local_store,
          local_dmem_addr: mem_debug.local_dmem_addr,
          local_store_data: mem_debug.local_store_data,
          local_load_data: local_load_packed_data,

          is_remote_load: mem_debug.is_remote_load,
          is_remote_store: mem_debug.is_remote_store,
          remote_addr: mem_debug.remote_addr,
          remote_store_data: mem_debug.remote_store_data
        };

      end
    end
  end


  // FP pipeline track
  //
  fp_debug_s fp_exe_debug, fpu1_r, fpu2_r, fpu3_r, fp_wb_debug;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      fp_exe_debug <= '0;
      fpu1_r <= '0;
      fpu2_r <= '0;
      fpu3_r <= '0;
      fp_wb_debug <= '0;
    end
    else begin
      if (~stall_fp) begin
        fp_exe_debug.pc <= id_r.pc_plus4 - 'd4;
        fp_exe_debug.instr <= id_r.instruction;
        fp_exe_debug.valid <= fp_exe_valid;
      end

      if (~stall_fp) begin
        fpu1_r <= fp_exe_debug;
        fpu2_r <= fpu1_r;
        fpu3_r <= fpu2_r;
        fp_wb_debug <= fpu3_r;
      end

    end

  end  


  // TRACER LOGIC
  //
  integer fd;
  string stamp;
  string pc_instr;
  string fp_pc_instr;
  string stall_reason;
  string int_rf_write;
  string float_rf_write;
  string btarget;
  string dmem_access;
  string remote_access;

  initial begin
    fd = $fopen("vanilla.log", "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin

      @(negedge clk_i) begin
        stamp = "";
        pc_instr = "";
        fp_pc_instr = "";
        stall_reason = "";
        int_rf_write = "";
        float_rf_write = "";
        btarget = "";
        dmem_access = "";
        remote_access = "";

        if (~reset_i & (trace_en_i == 1)) begin
     //   if ((my_x_i == 0) & (my_y_i == 1)) begin // comment this out for global logging
          fd = $fopen("vanilla.log", "a");

          // STAMP
          stamp = $sformatf("%08t %2d %2d", $time, my_x_i, my_y_i);

          // PC INSTR
          pc_instr = wb_debug.pc == 32'hfffffffc
            ? "BUBBLE           "
            : $sformatf("%08x %08x", wb_debug.pc, wb_debug.instr);

          // FP PC INSTR
          fp_pc_instr = fp_wb_debug.valid
            ? $sformatf("%08x %08x", fp_wb_debug.pc, fp_wb_debug.instr)
            : "FP_BUBBLE        ";

          // STALL REASON
          if (stall_ifetch_wait)
            stall_reason = "STALL=IFETCH";
          else if (stall_icache_store)
            stall_reason = "STALL=ISTORE";
          else if (stall_lr_aq)
            stall_reason = "STALL=LR_AQ ";
          else if (stall_fence)
            stall_reason = "STALL=FENCE ";
          else if (stall_md)
            stall_reason = "STALL=MULDIV";
          else if (stall_force_wb)
            stall_reason = "STALL=LOADWB";
          else if (stall_remote_req)
            stall_reason = "STALL=MEMREQ";
          else if (stall_local_flw)
            stall_reason = "STALL=FLW   ";
          else
            stall_reason = "            ";

          // INT RF WRITE
          int_rf_write = int_rf_wen
            ? $sformatf("x%02d=%08x",int_rf_waddr, int_rf_wdata)
            : {(3+1+8){" "}};

          // FP RF WRITE
          float_rf_write = float_rf_wen
            ? $sformatf("f%02d=%08x", float_rf_waddr, float_rf_wdata)
            : {(3+1+8){" "}};

          // BTARGET
          btarget = wb_debug.branch_or_jump
            ? $sformatf("bt=%08x", wb_debug.btarget)
            : {(3+8){" "}};

          // DMEM ACCESS
          if (wb_debug.is_local_load)
            dmem_access = $sformatf("LL[%3x]=%08x",
              wb_debug.local_dmem_addr, wb_debug.local_load_data);
          else if (wb_debug.is_local_store)
            dmem_access = $sformatf("LS[%3x]=%08x",
              wb_debug.local_dmem_addr, wb_debug.local_store_data);
          else
            dmem_access = {(2+5+1+8){" "}};

          // REMOTE ACCESS
          if (wb_debug.is_remote_load)
            remote_access = $sformatf("RL[%8x]=        ", wb_debug.remote_addr);
          else if (wb_debug.is_remote_store)
            remote_access = $sformatf("RS[%8x]=%8x", wb_debug.remote_addr, wb_debug.remote_store_data);
          else
            remote_access = "";
            

          $fwrite(fd, "%s | %s %s %s | %s %s | %s %s | %s\n",
            stamp,

            pc_instr,
            int_rf_write,
            stall_reason,

            fp_pc_instr,
            float_rf_write,

            btarget,
            dmem_access,

            remote_access
          );
   
 
          $fclose(fd);

   //     end // comment this out for global logging
        end
      end
    end


  end


  /*
  
  // SP (x2) overflow checking.
  //
  always_ff @ (negedge clk_i) begin
    if (int_rf_wen & (int_rf_waddr == 2) & int_rf_wdata < bsg_data_end_lp) begin
      $display("[ERROR][VCORE] SP underflow. t=%0t data_end=%x, sp=%x",
        $time, bsg_data_end_lp, int_rf_wdata);
    end
  end

  */

endmodule
