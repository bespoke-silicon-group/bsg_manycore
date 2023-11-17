
`include "bsg_vanilla_defines.svh"

module vanilla_core_trace
  import bsg_vanilla_pkg::*;
  #(parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)
    , parameter `BSG_INV_PARAM(icache_tag_width_p)
    , parameter `BSG_INV_PARAM(icache_entries_p)
    , parameter `BSG_INV_PARAM(data_width_p)
    , parameter `BSG_INV_PARAM(dmem_size_p)

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
    , localparam reg_addr_width_lp=RV32_reg_addr_width_gp

  )
  (
    input clk_i
    , input reset_i

    , input stall_all
    , input stall_remote_ld_wb
    , input stall_ifetch_wait
    , input stall_remote_flw_wb

    , input exe_signals_s exe_r

    , input [pc_width_lp-1:0] pc_n

    , input lsu_dmem_v_lo
    , input lsu_dmem_w_lo
    , input [dmem_addr_width_lp-1:0] lsu_dmem_addr_lo
    , input [data_width_p-1:0] lsu_dmem_data_lo
    , input [data_width_p-1:0] local_load_packed_data

    , input remote_req_s remote_req_o
    , input remote_req_v_o

    , input int_rf_wen
    , input [reg_addr_width_lp-1:0] int_rf_waddr
    , input [data_width_p-1:0] int_rf_wdata
  
    , input float_rf_wen
    , input [reg_addr_width_lp-1:0] float_rf_waddr
    , input [fpu_recoded_data_width_gp-1:0] float_rf_wdata

    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );

  //                      //
  //  DEBUG INTERFACE     //
  //                      //

  typedef struct packed
  {
    logic [RV32_reg_data_width_gp-1:0] pc;
    logic [RV32_instr_width_gp-1:0] instr;
    logic branch_or_jump;
    logic [RV32_instr_width_gp-1:0] btarget;
    logic is_local_load;
    logic is_local_store;
    logic [dmem_addr_width_lp-1:0] local_dmem_addr;
    logic [RV32_reg_data_width_gp-1:0] local_store_data;
    logic is_remote_load;
    logic is_remote_store;
    logic [RV32_reg_data_width_gp-1:0] remote_addr;
    logic [RV32_reg_data_width_gp-1:0] remote_store_data;
  } exe_debug_s;


  typedef struct packed
  {
    logic [RV32_reg_data_width_gp-1:0] pc;
    logic [RV32_instr_width_gp-1:0] instr;
    logic branch_or_jump;
    logic [RV32_instr_width_gp-1:0] btarget;
    logic is_local_load;
    logic is_local_store;
    logic [dmem_addr_width_lp-1:0] local_dmem_addr;
    logic [RV32_reg_data_width_gp-1:0] local_store_data;
    logic is_remote_load;
    logic is_remote_store;
    logic [RV32_reg_data_width_gp-1:0] remote_addr;
    logic [RV32_reg_data_width_gp-1:0] remote_store_data;
  } mem_debug_s;

  typedef struct packed
  {
    logic [RV32_reg_data_width_gp-1:0] pc;
    logic [RV32_instr_width_gp-1:0] instr;
    logic branch_or_jump;
    logic [RV32_instr_width_gp-1:0] btarget;
    logic is_local_load;
    logic is_local_store;
    logic [dmem_addr_width_lp-1:0] local_dmem_addr;
    logic [RV32_reg_data_width_gp-1:0] local_load_data;
    logic [RV32_reg_data_width_gp-1:0] local_store_data;
    logic is_remote_load;
    logic is_remote_store;
    logic [RV32_reg_data_width_gp-1:0] remote_addr;
    logic [RV32_reg_data_width_gp-1:0] remote_store_data;
  } wb_debug_s;

  exe_debug_s exe_debug;
  mem_debug_s mem_debug;
  wb_debug_s wb_debug;

  // EXE
  assign exe_debug.pc = exe_r.pc_plus4 - 'd4;
  assign exe_debug.instr = exe_r.instruction;
  assign exe_debug.branch_or_jump = exe_r.decode.is_branch_op | exe_r.decode.is_jal_op | exe_r.decode.is_jalr_op;
  assign exe_debug.btarget = {{(32-2-pc_width_lp){1'b0}}, pc_n, 2'b00};

  assign exe_debug.is_local_load = lsu_dmem_v_lo & ~lsu_dmem_w_lo;
  assign exe_debug.is_local_store = lsu_dmem_v_lo & lsu_dmem_w_lo;
  assign exe_debug.local_dmem_addr = lsu_dmem_addr_lo;
  assign exe_debug.local_store_data = lsu_dmem_data_lo;
  
  assign exe_debug.is_remote_load = remote_req_v_o & ~remote_req_o.write_not_read & ~remote_req_o.load_info.icache_fetch;
  assign exe_debug.is_remote_store = remote_req_v_o & remote_req_o.write_not_read;
  assign exe_debug.remote_addr = remote_req_o.addr;
  assign exe_debug.remote_store_data = remote_req_o.data;


  // MEM DEBUG
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mem_debug <= '0;
      wb_debug <= '0;
    end
    else begin
      if (~stall_all) begin
        mem_debug <= '{
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

        wb_debug <= '{
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

  // un-recode FP RF write data
  logic [data_width_p-1:0] float_rf_wdata_unrecoded;
  recFNToFN #(
    .expWidth(fpu_recoded_exp_width_gp)
    ,.sigWidth(fpu_recoded_sig_width_gp)
  ) fn0 (
    .in(float_rf_wdata)
    ,.out(float_rf_wdata_unrecoded)
  );

  // TRACER LOGIC
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
    fd = $fopen("vanilla.log","w");
    $fwrite(fd, "");
    $fclose(fd);
  end

  always @(negedge clk_i) begin
        stamp = "";
        pc_instr = "";
        fp_pc_instr = "";
        stall_reason = "";
        int_rf_write = "";
        float_rf_write = "";
        btarget = "";
        dmem_access = "";
        remote_access = "";

        if (reset_i === 1'b0) begin
          fd = $fopen("vanilla.log", "a");

          // STAMP
          stamp = $sformatf("%08t %2d %2d", $time, global_x_i, global_y_i);

          // PC_INSTR
          pc_instr = (wb_debug.pc == 32'hfffffffc)
            ? "BUBBLE           "
            : $sformatf("%08x %08x", wb_debug.pc, wb_debug.instr);

          // FP PC INSTR
          fp_pc_instr = ((wb_debug.pc == 32'hfffffffc) | ~float_rf_wen)
            ? "FP_BUBBLE        "
            : $sformatf("%08x %08x", wb_debug.pc, wb_debug.instr);

          // STALL_REASON
          if (stall_ifetch_wait)
            stall_reason = "STALL=IFETCH";
          else if (stall_remote_ld_wb)
            stall_reason = "STALL=LOADWB";
          else if (stall_remote_flw_wb)
            stall_reason = "STALL=FLW_WB";
          else
            stall_reason = "            ";


          // INT RF WRITE
          int_rf_write = int_rf_wen
            ? $sformatf("x%02d=%08x",int_rf_waddr, int_rf_wdata)
            : {(3+1+8){" "}};

          // FP RF WRITE
          float_rf_write = float_rf_wen
            ? $sformatf("f%02d=%08x", float_rf_waddr, float_rf_wdata_unrecoded)
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

        end // if (~reset_i & (trace_en_i == 1))
  end // always @ (negedge clk_i)
   
 


endmodule

`BSG_ABSTRACT_MODULE(vanilla_core_trace)

