/**
 *  bsg_manycore_proc_vanilla_trace
 *  
 *  trace format:
 *
 */

`include "bsg_manycore_packet.vh"
`include "definitions.vh"

module bsg_manycore_proc_vanilla_trace
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter load_id_width_p="inv"
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

    , input [1:0] xbar_port_v_in
    , input [1:0] xbar_port_we_in
    , input [1:0][data_width_p-1:0] xbar_port_data_in
    , input [1:0][(data_width_p>>3)-1:0] xbar_port_mask_in
    , input [1:0][mem_width_lp-1:0] xbar_port_addr_in
    , input [1:0] xbar_port_yumi_out
    , input [1:0][data_width_p-1:0] xbar_port_data_out
  );

  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p,
    x_cord_width_p, y_cord_width_p, load_id_width_p);

  // hobbit signals (h_)
  //
  wire h_freeze = bsg_manycore_proc_vanilla.hobbit0.freeze_i;
  wire h_stall = bsg_manycore_proc_vanilla.hobbit0.stall;
  wire [31:0] h_exe_pc = (bsg_manycore_proc_vanilla.hobbit0.exe.pc_plus4-4) | 32'h80000000;
  wire [31:0] h_exe_instr = bsg_manycore_proc_vanilla.hobbit0.exe.instruction;
  exe_signals_s h_exe;
  assign h_exe = bsg_manycore_proc_vanilla.hobbit0.exe;

  exe_signals_s h_mem_exe_r;
  exe_signals_s h_wb_exe_r;
  logic [31:0] h_mem_pc_r;
  logic [31:0] h_mem_instr_r;
  logic [31:0] h_wb_pc_r;
  logic [31:0] h_wb_instr_r;

  // delay pipeline logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i | h_freeze) begin
      h_mem_pc_r <= '0;
      h_mem_instr_r <= '0;
      h_wb_pc_r <= '0;
      h_wb_instr_r <= '0;
      h_mem_exe_r <= '0;
      h_wb_exe_r <= '0;
    end
    else begin
      if (~h_stall) begin
        h_mem_pc_r <= h_exe_pc;
        h_mem_instr_r <= h_exe_instr;
        h_wb_pc_r <= h_mem_pc_r;
        h_wb_instr_r <= h_mem_instr_r;
        h_mem_exe_r <= h_exe;
        h_wb_exe_r <= h_mem_exe_r;
      end
    end
  end

  // regfile write tracking
  //
  wire h_rf_wen = bsg_manycore_proc_vanilla.hobbit0.rf_wen;
  wire [4:0] h_rf_wa = bsg_manycore_proc_vanilla.hobbit0.rf_wa;
  wire [31:0] h_rf_wd = bsg_manycore_proc_vanilla.hobbit0.rf_wd;
  
  // stall tracking
  //
  wire h_stall_mem_req = bsg_manycore_proc_vanilla.hobbit0.stall_mem_req;
  wire h_stall_ifetch = bsg_manycore_proc_vanilla.hobbit0.stall_ifetch;
  wire h_stall_fence = bsg_manycore_proc_vanilla.hobbit0.stall_fence;
  wire h_stall_lrw = bsg_manycore_proc_vanilla.hobbit0.stall_lrw;
  wire h_stall_load_wb = bsg_manycore_proc_vanilla.hobbit0.stall_load_wb;
  wire h_stall_iwrite = bsg_manycore_proc_vanilla.hobbit0.stall_iwrite;
  wire h_stall_md = bsg_manycore_proc_vanilla.hobbit0.stall_md;
  wire h_stall_freeze = bsg_manycore_proc_vanilla.hobbit0.freeze_i;

  
  // branch tracking
  //
  wire [31:0] h_pc_n = {{(32-2-pc_width_lp){1'b0}}, bsg_manycore_proc_vanilla.hobbit0.pc_n, 2'b00};
  logic [31:0] h_mem_pc_n_r;
  logic [31:0] h_wb_pc_n_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      h_mem_pc_n_r <= '0;
      h_wb_pc_n_r <= '0;
    end
    else begin
      if (~h_stall) begin
        h_mem_pc_n_r <= h_pc_n;
        h_wb_pc_n_r <= h_mem_pc_n_r;
      end
    end
  end
  
  // IMEM tracking
  //
  wire h_icache_cen = bsg_manycore_proc_vanilla.hobbit0.icache_cen;
  wire h_icache_w_en = bsg_manycore_proc_vanilla.hobbit0.icache_w_en;
  wire [icache_addr_width_lp-1:0] h_icache_w_addr = bsg_manycore_proc_vanilla.hobbit0.icache_w_addr;
  wire [icache_tag_width_p-1:0] h_icache_w_tag = bsg_manycore_proc_vanilla.hobbit0.icache_w_tag;
  wire [31:0] h_icache_w_instr = bsg_manycore_proc_vanilla.hobbit0.icache_w_instr;

  // DMEM tracking
  //
  logic remote_read_r;
  logic [mem_width_lp-1:0] remote_read_addr_r;
  logic [31:0] remote_read_data_r;

  logic local_read_r;
  logic [mem_width_lp-1:0] local_read_addr_r;
  logic [31:0] local_read_data_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      remote_read_r <= 1'b0;
      local_read_r <= 1'b0;
    end
    else begin
      remote_read_r <= xbar_port_v_in[0] & ~xbar_port_we_in[0] & xbar_port_yumi_out[0];
      remote_read_addr_r <= xbar_port_addr_in[0];
      local_read_r <= xbar_port_v_in[1] & ~xbar_port_we_in[1] & xbar_port_yumi_out[1];
      local_read_addr_r <= xbar_port_addr_in[1];
    end
  end

  logic remote_store;
  logic local_store;

  assign remote_store = xbar_port_v_in[0] & xbar_port_we_in[0] & xbar_port_yumi_out[0];
  assign local_store = xbar_port_v_in[1] & xbar_port_we_in[1] & xbar_port_yumi_out[1];
 
  // Network packet
  //
  bsg_manycore_packet_s tile_data_out;

  wire launching_out = bsg_manycore_proc_vanilla.launching_out;
  assign tile_data_out = bsg_manycore_proc_vanilla.data_o_debug;
  

  // trace logger
  //
  //  <time> <X> <Y> <PC> <INSTR> <stall_reason>
  integer fd;
  string stamp;
  string wb_pc_instr;
  string stall_reason;
  string rf_write;
  string btarget;
  string icache_write;
  string dmem_load;
  string dmem_store;
  string network_pkt;

  initial begin
    fd = $fopen("vanilla.log", "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin
        stamp = "";
        wb_pc_instr = "";
        stall_reason = "";
        rf_write = "";
        btarget = "";
        icache_write = "";
        dmem_load = "";
        dmem_store = "";
  
      if ((my_x_i == 1) & (my_y_i == 1)) begin
        fd = $fopen("vanilla.log", "a");

        // STAMP
        stamp = $sformatf("%08t %2d %2d:", $time, my_x_i, my_y_i);

        // PC_INSTR
        wb_pc_instr = h_wb_pc_r == 32'hfffffffc
          ? "BUBBLE           "
          : $sformatf("%08x %08x", h_wb_pc_r, h_wb_instr_r);

        // stall reason
        if (h_stall_mem_req)
          stall_reason = "STALL: MEMREQ";
        else if (h_stall_ifetch)
          stall_reason = "STALL: IFETCH";
        else if (h_stall_fence)
          stall_reason = "STALL: FENCE ";
        else if (h_stall_lrw)
          stall_reason = "STALL: LRW   ";
        else if (h_stall_load_wb)
          stall_reason = "STALL: LOADWB";
        else if (h_stall_ifetch)
          stall_reason = "STALL: MD    ";
        else if (h_stall_ifetch)
          stall_reason = "STALL: FREEZE";
        else
          stall_reason = "             ";
       
        // regfile write
        rf_write = h_rf_wen
          ? $sformatf("r%2d = %08x", h_rf_wa, h_rf_wd) 
          : {3+3+8{" "}};

        // branch target
        if (h_wb_exe_r.decode.is_branch_op | h_wb_exe_r.decode.is_jump_op) begin
          btarget = $sformatf("BT=%08x", h_wb_pc_n_r | 32'h80000000);
        end
        else begin
          btarget = {(3+8){" "}};
        end
    
        // icache write
        if (h_icache_cen & h_icache_w_en) begin
          icache_write = $sformatf("I$[%06x]=%08x",
            {h_icache_w_tag, h_icache_w_addr, 2'b00},
            h_icache_w_instr
          );
        end
        else begin
          icache_write = {(4+6+1+8){" "}}; 
        end

        // dmem load
        if (remote_read_r) begin
          dmem_load = $sformatf("RL[%3x]=%08x", remote_read_addr_r, xbar_port_data_out[0]);
        end
        else if (local_read_r) begin
          dmem_load = $sformatf("LL[%3x]=%08x", local_read_addr_r, xbar_port_data_out[1]);
        end
        else begin
          dmem_load = {(5+3+8){" "}};
        end

        // dmem store
        if (remote_store) begin
          dmem_store = $sformatf("RS[%3x]=%08x (mask=%04b)",
            xbar_port_addr_in[0], xbar_port_data_in[0], xbar_port_mask_in[0]);
        end
        else if (local_store) begin
          dmem_store = $sformatf("LS[%3x]=%08x (mask=%04b)",
            xbar_port_addr_in[1], xbar_port_data_in[1], xbar_port_mask_in[1]);
        end
        else begin
          dmem_store = {28{" "}};
        end

        // network packet
        if (launching_out) begin
          network_pkt = $sformatf("{op=%02b,d=%08x}->t_%02d_%02d[%08x]",
                          tile_data_out.op,
                          tile_data_out.payload,
                          tile_data_out.x_cord,
                          tile_data_out.y_cord,
                          tile_data_out.addr
                        );
        end else begin
          network_pkt = {37{" "}};
        end

        $fwrite(fd, "%s %s %s | %s | %s | %s | %s | %s | %s\n",
          stamp,
          wb_pc_instr,
          stall_reason,
          rf_write,
          btarget,
          icache_write,
          dmem_load,
          dmem_store,
          network_pkt
        );

        $fclose(fd);

      end

      end
    end

  end 



endmodule
