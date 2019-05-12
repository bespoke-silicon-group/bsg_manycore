/**
 *
 *  hobbit_tracer.v
 *
 *  This module traces signals inside The Hobbit.
 *
 *
 *  += DEVELOPER GUIDE =+
 *
 *  It creates a log file for each active tile, where x,y is the coordinate of hobbit.
 *  ex) hobbit_1_2.log
 *
 *  Each line is a comma-separated-value (csv) so that it is easy to parse.
 *  Each column should have an "id" and "value", and an equal sign in between.
 *  e.g.) exe.rs1=3
 *
 *  The first column is always the timestamp.
 *  e.g.) T=143400
 *
 *  An example trace looks like this.
 *  e.g.) T=215580, id.op_reads_rf1=0, id.op_reads_rf2=0, id.op_is_auipc=0
 *
 *  If the value is in hexadecimal format, you must append "0x", to
 *  distinguish from binary or base-10 integer.
 *
 *  Each line should be of reasonable length.
 *
 *  If a line starts with "#", then this line is a comment, and should be
 *  ignored by a parser. The comment cannot start in the middle of a line.
 *
 *  Each timestep should have a line separator for readability.
 *
 *  No other exceptions allowed!!!
 *
 */

`include "definitions.vh"
`include "parameters.vh"

module hobbit_tracer
  #(parameter icache_tag_width_p="inv"
    , parameter icache_addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , localparam pc_width_lp = (icache_tag_width_p+icache_addr_width_p)
  )
  (
    // add your internal or port signals as "input"
    input clk_i
    , input reset_i
    
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  
    , input freeze_down

    , input [pc_width_lp-1:0] pc_r
    , input instruction_s instruction
    , input icache_miss_lo

    , input icache_v_i
    , input [pc_width_lp-1:0] icache_pc_i
    , input [RV32_instr_width_gp-1:0] icache_instr_i

    , input id_signals_s id
    , input exe_signals_s exe
    , input mem_signals_s mem
    , input wb_signals_s wb

    , input dependency
    , input record_load
    
    , input mem_in_s to_mem_o
    , input mem_out_s from_mem_i
    , input reservation_i
    , input reserve_1_o
    , input outstanding_stores_i
    
    , input jump_now
    , input flush
    , input stall
    , input stall_mem
    , input stall_non_mem
    , input stall_lrw
    , input depend_stall
    , input stall_load_wb
    , input stall_md
    , input stall_fence

    , input rf_wen
    , input [RV32_reg_addr_width_gp-1:0] rf_wa
    , input [RV32_reg_data_width_gp-1:0] rf_wd
    , input [RV32_reg_addr_width_gp-1:0] rf_rs1_addr
    , input [RV32_reg_data_width_gp-1:0] rf_rs1_val
    , input [RV32_reg_addr_width_gp-1:0] rf_rs2_addr
    , input [RV32_reg_data_width_gp-1:0] rf_rs2_val

    , input md_valid
    , input md_resp_valid
    , input [RV32_reg_data_width_gp-1:0] md_result

  );

  // tracing
  //
  string filename; 
  integer fd;

  initial begin

    wait(freeze_down);

    filename = $sformatf("hobbit_%0d_%0d.log", my_x_i, my_y_i);
    fd = $fopen(filename, "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
  
      @(negedge clk_i) begin

        fd = $fopen(filename, "a");

        // IF STAGE
        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", pc_r=0x%08x", {{(RV32_instr_width_gp-pc_width_lp-2){1'b0}}, pc_r<<2});
        $fwrite(fd, ", instr=0x%08x", instruction);
        $fwrite(fd, ", if.rd=%0d", instruction.rd);
        $fwrite(fd, ", if.rs1=%0d", instruction.rs1);
        $fwrite(fd, ", if.rs2=%0d", instruction.rs2);
        $fwrite(fd, ", icache_miss_lo=%0d", icache_miss_lo);

        $fwrite(fd, ", icache_v_i=%0d", icache_v_i);
        $fwrite(fd, ", icache_pc_i=0x%08x", icache_pc_i);
        $fwrite(fd, ", icache_instr_i=0x%08x", icache_instr_i);
        $fwrite(fd, "\n");

        // ID STAGE
        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", id.pc=0x%08x", id.pc_plus4-4);
        $fwrite(fd, ", id.instr=0x%08x", id.instruction);
        $fwrite(fd, ", id.rd=%0d", id.instruction.rd);
        $fwrite(fd, ", id.rs1=%0d", id.instruction.rs1);
        $fwrite(fd, ", id.rs2=%0d", id.instruction.rs2);
        $fwrite(fd, ", id.pred_or_jump_addr=0x%08x", id.pred_or_jump_addr);
        $fwrite(fd, ", id.icache_miss=%0d", id.icache_miss);
        $fwrite(fd, ", dependency=%0d", dependency);
        $fwrite(fd, ", record_load=%0d", record_load);
        $fwrite(fd, "\n");

        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", id.op_writes_rf=0x%08x", id.decode.op_writes_rf);
        $fwrite(fd, ", id.load_op=0x%08x", id.decode.is_load_op);
        $fwrite(fd, ", id.store_op=0x%08x", id.decode.is_store_op);
        $fwrite(fd, ", id.mem_op=%0d", id.decode.is_mem_op);
        $fwrite(fd, ", id.byte_op=%0d", id.decode.is_byte_op);
        $fwrite(fd, ", id.hex_op=%0d", id.decode.is_hex_op);
        $fwrite(fd, ", id.branch_op=%0d", id.decode.is_branch_op);
        $fwrite(fd, ", id.jump_op=%0d", id.decode.is_jump_op);
        $fwrite(fd, "\n");
      
        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", id.op_reads_rf1=%0d", id.decode.op_reads_rf1);
        $fwrite(fd, ", id.op_reads_rf2=%0d", id.decode.op_reads_rf2);
        $fwrite(fd, ", id.op_is_auipc=%0d", id.decode.op_is_auipc);
        $fwrite(fd, "\n");
        
        // EXE STAGE
        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", exe.pc=0x%08x", exe.pc_plus4-4);
        $fwrite(fd, ", exe.instr=0x%08x", exe.instruction);
        $fwrite(fd, ", exe.rd=%0d", exe.instruction.rd);
        $fwrite(fd, ", exe.rs1=%0d", exe.instruction.rs1);
        $fwrite(fd, ", exe.rs2=%0d", exe.instruction.rs2);
        $fwrite(fd, ", exe.pred_or_jump_addr=0x%08x", exe.pred_or_jump_addr);
        $fwrite(fd, ", exe.icache_miss=%0d", exe.icache_miss);
        $fwrite(fd, ", exe.rs1_val=%0d", exe.rs1_val);
        $fwrite(fd, ", exe.rs2_val=%0d", exe.rs2_val);
        $fwrite(fd, "\n");

        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", exe.load_op=%0d", exe.decode.is_load_op);
        $fwrite(fd, ", exe.store_op=%0d", exe.decode.is_store_op);
        $fwrite(fd, ", exe.mem_op=%0d", exe.decode.is_mem_op);
        $fwrite(fd, ", exe.byte_op=%0d", exe.decode.is_byte_op);
        $fwrite(fd, ", exe.hex_op=%0d", exe.decode.is_hex_op);
        $fwrite(fd, ", exe.branch_op=%0d", exe.decode.is_branch_op);
        $fwrite(fd, ", exe.jump_op=%0d", exe.decode.is_jump_op);
        $fwrite(fd, ", exe.op_reads_rf1=%0d", exe.decode.op_reads_rf1);
        $fwrite(fd, ", exe.op_reads_rf2=%0d", exe.decode.op_reads_rf2);
        $fwrite(fd, ", exe.op_is_auipc=%0d", exe.decode.op_is_auipc);
        $fwrite(fd, "\n");

        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", reservation_i=%0d", reservation_i);
        $fwrite(fd, ", reserve_1_o=%0d", reserve_1_o);
        $fwrite(fd, ", outstanding_stores_i=%0d", outstanding_stores_i);
        $fwrite(fd, ", jump_now=%0d", jump_now);
        $fwrite(fd, ", flush=%0d", flush);
        $fwrite(fd, "\n");

        $fwrite(fd, "T=%0t", $time); 
        $fwrite(fd, ", to_mem_o.valid=%0d", to_mem_o.valid);
        $fwrite(fd, ", to_mem_o.addr=0x%08x", to_mem_o.addr);
        $fwrite(fd, ", to_mem_o.payload.write_data=0x%08x", to_mem_o.payload.write_data);
        $fwrite(fd, ", to_mem_o.payload.read_info.load_info.reg_id=%0d",
          to_mem_o.payload.read_info.load_info.reg_id);
        $fwrite(fd, ", from_mem_i.yumi=%0d", from_mem_i.yumi);
        $fwrite(fd, "\n");

        // MEM STAGE
        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", mem.rd_addr=%0d", mem.rd_addr);
        $fwrite(fd, ", mem.op_writes_rf=%0d", mem.decode.op_writes_rf);
        $fwrite(fd, ", mem.load_op=%0d", mem.decode.is_load_op);
        $fwrite(fd, ", mem.store_op=%0d", mem.decode.is_store_op);
        $fwrite(fd, ", mem.mem_op=%0d", mem.decode.is_mem_op);
        $fwrite(fd, ", mem.byte_op=%0d", mem.decode.is_byte_op);
        $fwrite(fd, ", mem.hex_op=%0d", mem.decode.is_hex_op);
        $fwrite(fd, ", mem.branch_op=%0d", mem.decode.is_branch_op);
        $fwrite(fd, ", mem.jump_op=%0d", mem.decode.is_jump_op);
        $fwrite(fd, "\n");

        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", mem.op_reads_rf1=%0d", mem.decode.op_reads_rf1);
        $fwrite(fd, ", mem.op_reads_rf2=%0d", mem.decode.op_reads_rf2);
        $fwrite(fd, ", mem.op_is_auipc=%0d", mem.decode.op_is_auipc);
        $fwrite(fd, ", mem.exe_result=0x%08x", mem.exe_result);
        $fwrite(fd, "\n");

        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", from_mem_i.valid=%0d", from_mem_i.valid);
        $fwrite(fd, ", from_mem_i.read_data=0x%08x", from_mem_i.read_data);
        $fwrite(fd, ", from_mem_i.load_info.reg_id=%0d", from_mem_i.load_info.reg_id);
        $fwrite(fd, ", to_mem_o.yumi_i=%0d", to_mem_o.yumi);
        $fwrite(fd, ", mem.icache_miss=%0d", mem.icache_miss);
        $fwrite(fd, "\n");


        // WB STAGE
        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", wb.op_writes_rf=%0d", wb.op_writes_rf);
        $fwrite(fd, ", wb.rd_addr=%0d", wb.rd_addr);
        $fwrite(fd, ", wb.rf_data=0x%08x", wb.rf_data);
        $fwrite(fd, ", wb.icache_miss=%0d", wb.icache_miss);
        $fwrite(fd, ", wb.icache_miss_pc=0x%08x", wb.icache_miss_pc);
        $fwrite(fd, "\n");

        // MISC
        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", stall=%0d", stall);
        $fwrite(fd, ", stall_mem=%0d", stall_mem);
        $fwrite(fd, ", stall_non_mem=%0d", stall_non_mem);
        $fwrite(fd, ", stall_lwr=%0d", stall_lrw);
        $fwrite(fd, ", depend_stall=%0d", depend_stall);
        $fwrite(fd, ", stall_load_wb=%0d", stall_load_wb);
        $fwrite(fd, ", stall_md=%0d", stall_md);
        $fwrite(fd, ", stall_fence=%0d", stall_fence);
        $fwrite(fd, "\n");

        // REGISTER FILE
        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", rf_wen=%0d", rf_wen);
        $fwrite(fd, ", rf_wa=%0d", rf_wa);
        $fwrite(fd, ", rf_wd=0x%08x", rf_wd);
        $fwrite(fd, ", rf_rs1_addr=%0d", rf_rs1_addr);
        $fwrite(fd, ", rf_rs1_val=0x%08x", rf_rs1_val);
        $fwrite(fd, ", rf_rs2_addr=%0d", rf_rs2_addr);
        $fwrite(fd, ", rf_rs2_val=0x%08x", rf_rs2_val);
        $fwrite(fd, "\n");

        // MUL_DIV
        $fwrite(fd, "T=%0t", $time);
        $fwrite(fd, ", md_valid=%0d", md_valid);
        $fwrite(fd, ", md_resp_valid=%0d", md_resp_valid);
        $fwrite(fd, ", md_result=0x%08x", md_result);
        $fwrite(fd, "\n");


        // line separator between each time step
        $fwrite(fd, "\n");
        $fclose(fd);

      end
    end
  end






endmodule
