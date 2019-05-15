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

    , input [1:0] xbar_port_v_in
    , input [1:0] xbar_port_we_in
    , input [1:0][mem_width_lp-1:0] xbar_port_addr_in
    , input [1:0][31:0] xbar_port_data_in
    , input [1:0][3:0] xbar_port_mask_in
    , input [1:0] xbar_port_yumi_out
    
    , input [31:0] load_returning_data
    , input [31:0] core_mem_rdata

    , input [x_cord_width_p-1:0] in_src_x_cord_lo
    , input [y_cord_width_p-1:0] in_src_y_cord_lo

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

  // remote store tracking
  //
  logic remote_stored; 
  logic [31:0] remote_store_data;
  logic [31:0] remote_store_addr;
  string remote_store_type;

  always_comb begin
    remote_stored = xbar_port_v_in[0] & xbar_port_we_in[0] & xbar_port_yumi_out[0];
    remote_store_addr[31:2] = {{(32-mem_width_lp){1'b0}}, xbar_port_addr_in[0]};

    case (xbar_port_mask_in[0]) 
      4'b0001: begin
        remote_store_type = "RSB";
        remote_store_addr[1:0] = 2'b00;
        remote_store_data = {24'b0, xbar_port_data_in[0][7:0]};
      end
      4'b0010: begin
        remote_store_type = "RSB";
        remote_store_addr[1:0] = 2'b01;
        remote_store_data = {24'b0, xbar_port_data_in[0][15:8]};
      end
      4'b0100: begin
        remote_store_type = "RSB";
        remote_store_addr[1:0] = 2'b10;
        remote_store_data = {24'b0, xbar_port_data_in[0][23:16]};
      end
      4'b1000: begin
        remote_store_type = "RSB";
        remote_store_addr[1:0] = 2'b11;
        remote_store_data = {24'b0, xbar_port_data_in[0][31:24]};
      end
      4'b0011: begin
        remote_store_type = "RSH";
        remote_store_addr[1:0] = 2'b00;
        remote_store_data = {16'b0, xbar_port_data_in[0][15:0]};
      end
      4'b1100: begin
        remote_store_type = "RSH";
        remote_store_addr[1:0] = 2'b10;
        remote_store_data = {16'b0, xbar_port_data_in[0][31:16]};
      end
      4'b1111: begin
        remote_store_type = "RSW";
        remote_store_addr[1:0] = 2'b00;
        remote_store_data = xbar_port_data_in[0];
      end
      default: begin
        remote_store_addr[1:0] = 2'b00;
        remote_store_data = '0;
      end
    endcase 
  end

  // remote load tracking
  //
  logic remote_loaded;
  logic remote_loaded_r;
  logic [x_cord_width_p-1:0] remote_load_x_r;
  logic [y_cord_width_p-1:0] remote_load_y_r;
  logic [31:0] remote_load_addr_r;
  logic [31:0] remote_load_data;

  always_comb begin
    remote_loaded = xbar_port_v_in[0] & ~xbar_port_we_in[0] & xbar_port_yumi_out[0];
    remote_load_data = load_returning_data;
  end

  always_ff @ (posedge clk_i) begin
    remote_loaded_r <= remote_loaded;
    remote_load_x_r <= in_src_x_cord_lo;
    remote_load_y_r <= in_src_y_cord_lo;
    remote_load_addr_r <= {{(32-2-mem_width_lp){1'b0}}, xbar_port_addr_in[0], 2'b00};
  end

  // local store tracking
  //
  logic local_stored;
  logic [31:0] local_store_addr;
  logic [31:0] local_store_data;
  string local_store_type;
  
  always_comb begin
    local_stored = xbar_port_v_in[1] & xbar_port_we_in[1] & xbar_port_yumi_out[1];
    local_store_addr[31:2] = {{(31-2-mem_width_lp){1'b0}}, xbar_port_addr_in[1]};
    case (xbar_port_mask_in[1])
      4'b0001: begin
        local_store_type = "LSB";
        local_store_addr[1:0] = 2'b00;
        local_store_data = {24'b0, xbar_port_data_in[1][7:0]};
      end
      4'b0010: begin
        local_store_type = "LSB";
        local_store_addr[1:0] = 2'b01;
        local_store_data = {24'b0, xbar_port_data_in[1][15:8]};
      end
      4'b0100: begin
        local_store_type = "LSB";
        local_store_addr[1:0] = 2'b10;
        local_store_data = {24'b0, xbar_port_data_in[1][23:16]};
      end
      4'b1000: begin
        local_store_type = "LSB";
        local_store_addr[1:0] = 2'b11;
        local_store_data = {24'b0, xbar_port_data_in[1][31:24]};
      end
      4'b0011: begin
        local_store_type = "LSH";
        local_store_addr[1:0] = 2'b00;
        local_store_data = {16'b0, xbar_port_data_in[1][31:24]};
      end
      4'b1100: begin
        local_store_type = "LSH";
        local_store_addr[1:0] = 2'b10;
        local_store_data = {16'b0, xbar_port_data_in[1][31:24]};
      end
      4'b1111: begin
        local_store_type = "LSW";
        local_store_addr[1:0] = 2'b00;
        local_store_data = xbar_port_data_in[1];
      end
      default: begin

      end
    endcase
  end

  // local load tracking
  //
  logic local_loaded;
  logic local_loaded_r;
  logic [31:0] local_load_addr_r;
  logic [31:0] local_load_data;

  always_comb begin
    local_loaded = xbar_port_v_in[1] & ~xbar_port_we_in[1] & xbar_port_yumi_out[1];
    local_load_data = core_mem_rdata;
  end

  always_ff @ (posedge clk_i) begin
    local_loaded_r <= local_loaded;
    local_load_addr_r <= {{(32-2-mem_width_lp){1'b0}}, xbar_port_addr_in[1], 2'b00};
  end
  
  

  // trace logger
  //
  integer fd;
  integer emit_trace;
  string stamp;
  string rf_write_pc_instr;
  string rf_write_trace;
  string dmem_store_pc_instr;
  string dmem_store_trace;
  string dmem_load_pc_instr;
  string dmem_load_trace;

  initial begin

    fd = $fopen("vanilla.log", "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin
        fd = $fopen("vanilla.log", "a");
        emit_trace = 0;
        stamp = $sformatf("%08t %2d %2d", $time, my_x_i, my_y_i);

        // regfile write
        //
        if (h_rf_wen) begin
          emit_trace = 1;

          if (h_stall & h_pending_load_arrived) begin
            // 1. remote load direct write to rf (Rx)
            rf_write_pc_instr = $sformatf("%08x %08x", remote_load_pc_r[h_rf_wa], remote_load_instr_r[h_rf_wa]);
            rf_write_trace = $sformatf("Rx[%2d]=%08x", h_rf_wa, h_rf_wd);
          end
          else if (wb_is_remote_load_r) begin
            // 2. remote load wb (Rx)
            rf_write_pc_instr = $sformatf("%08x %08x", h_wb_pc_r, h_wb_instr_r);
            rf_write_trace = $sformatf("Rx[%2d]=%08x", h_rf_wa, h_rf_wd);
          end
          else begin
            // 3. other types of wb (Lx)
            rf_write_pc_instr = $sformatf("%08x %08x", h_wb_pc_r, h_wb_instr_r);
            rf_write_trace = $sformatf("Lx[%2d]=%08x", h_rf_wa, h_rf_wd);
          end
        end
        else begin
          rf_write_pc_instr = {(8+1+8){" "}};
          rf_write_trace = {(2+1+2+1+1+8){" "}};
        end
  
        // dmem store
        //
        if (remote_stored) begin
          emit_trace = 1;
          dmem_store_pc_instr = {(8+1+8){" "}};
          dmem_store_trace= $sformatf("%s[%08x]=%08x (%2d,%2d)", remote_store_type,
            remote_store_addr, remote_store_data,
            in_src_x_cord_lo, in_src_y_cord_lo
          );
        end
        else if (local_stored) begin
          emit_trace = 1;
          dmem_store_pc_instr = $sformatf("%08x %08x", h_exe_pc, h_exe_instr);
          dmem_store_trace = $sformatf("%s[%08x]=%08x        ", local_store_type,
            local_store_addr, local_store_data 
          );
        end
        else begin
          dmem_store_pc_instr = {(8+1+8){" "}};
          dmem_store_trace = {(3+1+8+1+1+8+8){" "}};
        end

        // dmem load
        //
        if (remote_loaded_r) begin
          emit_trace = 1;
          dmem_load_pc_instr = {(8+1+8){" "}};
          dmem_load_trace = $sformatf("RL [%08x]=%08x        ",
            remote_load_addr_r, remote_load_data
          );
        end
        else if (local_loaded_r) begin
          emit_trace = 1;
          dmem_load_pc_instr = $sformatf("%08x %08x", h_mem_pc_r, h_mem_instr_r);
          dmem_load_trace = $sformatf("LL [%08x]=%08x        ",
            local_load_addr_r, local_load_data 
          );
        end
        else begin
          dmem_load_pc_instr = {(8+1+8){" "}};
          dmem_load_trace = {(3+1+8+1+1+8+8){" "}};
        end
        

        if (emit_trace) begin
          $fwrite(fd, "%s | %s %s | %s %s | %s %s |\n",
            stamp,
            rf_write_pc_instr,
            rf_write_trace,
            dmem_store_pc_instr,
            dmem_store_trace,
            dmem_load_pc_instr,
            dmem_load_trace
          );
        end

        $fclose(fd);

      end
    end


  end 



endmodule
