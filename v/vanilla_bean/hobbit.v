`include "parameters.v"
`include "definitions.v"
//`include "bsg_defines.v"

/**
 *  Vanilla-Bean Core
 *
 *  5 stage pipeline implementation of the vanilla core ISA.
 */
module hobbit #(parameter imem_addr_width_p = -1, 
                          gw_ID_p           = -1, 
                          ring_ID_p         = -1,
                          x_cord_width_p    = -1,
                          y_cord_width_p    = -1,
                          debug_p           = 0)
               (
                input                             clk,
                input                             reset,
            
                input  ring_packet_s              net_packet_i,
            
                input  mem_out_s                  from_mem_i,
                output mem_in_s                   to_mem_o,
                input  logic                      reservation_i,
                output logic                      reserve_1_o,
            
                input  [x_cord_width_p-1:0]       my_x_i,
                input  [y_cord_width_p-1:0]       my_y_i,
                output debug_s                    debug_o
               );

// Pipeline stage logic structures
id_signals_s  id;
exe_signals_s exe;
mem_signals_s mem;
wb_signals_s  wb;

// Network signals logic
ring_packet_s net_packet_r;
logic         net_id_match_valid, net_pc_write_cmd,  net_imem_write_cmd,
              net_reg_write_cmd, net_pc_write_cmd_idle,
              exec_net_packet;

// Stall and exception logic
logic stall, stall_non_mem, stall_mem, stall_lrw;

// Program counter logic
logic [RV32_reg_data_width_gp-1:0] pc_n, pc_r, pc_plus4, pc_jump_addr, pc_long_jump_addr;
logic                              pc_wen, pc_wen_r, imem_cen;

// Instruction memory logic
logic [imem_addr_width_p-1:0] imem_addr;
instruction_s                 imem_out, instruction, instruction_r;

// Register file logic
logic [RV32_reg_data_width_gp-1:0] rf_rs1_out, rf_rs2_out, rf_wd;
logic [RV32_reg_addr_width_gp-1:0] rf_wa;
logic                              rf_wen, rf_cen;

// MUL/DIV signals 
logic        instr_is_md, stall_md, md_valid, md_rs1_signed, md_rs2_signed;
logic [1:0]  md_op, md_out_sel;
logic        md_ready, md_resp_valid;
logic [31:0] md_result;

// ALU logic
logic [RV32_reg_data_width_gp-1:0] rs1_to_alu, rs2_to_alu, basic_comp_result, alu_result;
logic                              jump_now;

// Stores
logic [RV32_reg_data_width_gp-1:0] store_data;
logic [3:0]                        mask;

// Sign extended immediate
logic [RV32_instr_width_gp-1:0] sign_extended_imm;

// Forwarding signals
logic   rs1_in_mem, rs1_in_wb, rs2_in_mem, rs2_in_wb;

// Data memory handshake logic
logic valid_to_mem_c, yumi_to_mem_c;

// Decoded control signals logic
decode_s decode;

// State machine logic
state_e state_n, state_r;

// Value forwarding logic
logic                              rs1_is_forward, rs2_is_forward;
logic [RV32_reg_data_width_gp-1:0] rs1_forward_val, rs2_forward_val;

//logic [31:0]  rf_data, rs_to_exe, rd_to_exe;
logic [RV32_reg_data_width_gp-1:0] rf_data, loaded_byte, loaded_hex, rs1_to_exe, rs2_to_exe;

// Branch and jump predictions
logic [RV32_reg_data_width_gp-1:0] jalr_prediction_n, jalr_prediction_r, 
                                   jalr_prediction_rr;
logic                              jalr_mispredict, branch_under_predict, 
                                   branch_over_predict, branch_mispredict;
logic                              flush;

//+----------------------------------------------
//|
//|         NETWORK PACKET SIGNALS
//|
//+----------------------------------------------

// Detect a valid packet for this core (vaild and IDs match)
assign net_id_match_valid = (net_packet_r.header.ring_ID == ring_ID_p)
                       // & (net_packet_r.header.gw_ID == gw_ID_p)
                          & (~net_packet_r.header.external)
                          & (net_packet_r.valid);

// Detect if this network packet should be executed by this core. Two cases:
//  1) IDs match and not a broadcast (if ID matches a broadcast, this core sent it)
//  2) ID doesn't match but the packet is a broadcast
assign exec_net_packet    = (net_id_match_valid & ~net_packet_r.header.bc)
                            | ((~net_id_match_valid) & net_packet_r.header.bc & 
                            net_packet_r.valid & (~net_packet_r.header.external));

// Network command control signals
assign net_pc_write_cmd      = exec_net_packet  & (net_packet_r.header.net_op == PC);
assign net_imem_write_cmd    = exec_net_packet  & (net_packet_r.header.net_op == INSTR);
assign net_reg_write_cmd     = exec_net_packet  & (net_packet_r.header.net_op == REG);
assign net_pc_write_cmd_idle = net_pc_write_cmd & (state_r == IDLE);

//+----------------------------------------------
//|
//|     STALL AND EXCEPTION LOGIC SIGNALS
//|
//+----------------------------------------------

assign stall_non_mem = (net_imem_write_cmd)
                     | (net_reg_write_cmd & wb.op_writes_rf)
                     | (net_reg_write_cmd)  
                     | (state_r != RUN)
                     | stall_md;

// stall due to data memory access
assign stall_mem = (exe.decode.is_mem_op & (~from_mem_i.yumi))
                   | (mem.decode.is_load_op & (~from_mem_i.valid))
                   | stall_lrw;

// Stall if LD/ST still active; or in non-RUN state
assign stall = (stall_non_mem | stall_mem); 

//+----------------------------------------------
//|
//|        EXTERNAL MODULE CONNECTIONS
//|
//+----------------------------------------------

// RISC-V edit: support for byte and hex stores
always_comb
begin
  if (~|exe.instruction.funct3[1:0]) // byte op
    begin
      store_data = (32'(rs2_to_alu[7:0])) << ((5'(alu_result[1:0])) << 3);
      mask       = (4'b0001 << alu_result[1:0]);
    end
  else if(exe.instruction.funct3[1:0] == 2'b01) // hex op
    begin
      store_data = (32'(rs2_to_alu[15:0])) << ((5'(alu_result[1:0])) << 3);
      mask       = (4'b0011 << alu_result[1:0]);
    end
  else
    begin
      store_data = rs2_to_alu;
      mask       = 4'b1111;
    end
end

// Data_mem
assign to_mem_o = '{
    write_data    : store_data,
    valid         : valid_to_mem_c,
    wen           : exe.decode.is_store_op,
    mask          : mask,
    yumi          : yumi_to_mem_c,
    addr          : alu_result
};

// DEBUG Struct
assign debug_o = {pc_r, instruction, state_r};

if(debug_p)
  always_ff @(negedge clk)
  begin
    if ((~|my_x_i & ~|my_y_i) & state_r==RUN)
      begin
        $display("\n%0dns (%d,%d):", $time, my_x_i, my_y_i);
        $display("  IF: pc  :%x instr:{%x_%x_%x_%x_%x_%x} state:%b net_pkt:{%x_%x_%x}"
                 ,pc_r
                 ,instruction.funct7
                 ,instruction.rs2
                 ,instruction.rs1
                 ,instruction.funct3
                 ,instruction.rd
                 ,instruction.opcode
                 ,state_r
                 ,net_packet_r.valid
                 ,net_packet_r.header.addr
                 ,net_packet_r.data
                );
        $display("  ID: pc+4:%x instr:{%x_%x_%x_%x_%x_%x} j_addr:%x wrf:%b ld:%b st:%b mem:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b"
                 ,id.pc_plus4
                 ,id.instruction.funct7
                 ,id.instruction.rs2
                 ,id.instruction.rs1
                 ,id.instruction.funct3
                 ,id.instruction.rd
                 ,id.instruction.opcode
                 ,id.pc_jump_addr
                 ,id.decode.op_writes_rf
                 ,id.decode.is_load_op  
                 ,id.decode.is_store_op 
                 ,id.decode.is_mem_op   
                 ,id.decode.is_branch_op
                 ,id.decode.is_jump_op  
                 ,id.decode.op_reads_rf1
                 ,id.decode.op_reads_rf2
                 ,id.decode.op_is_auipc
                );
        $display(" EXE: pc+4:%x instr:{%x_%x_%x_%x_%x_%x} j_addr:%x wrf:%b ld:%b st:%b mem:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b rs1:%0x rs2:%0x"
                 ,exe.pc_plus4
                 ,exe.instruction.funct7
                 ,exe.instruction.rs2
                 ,exe.instruction.rs1
                 ,exe.instruction.funct3
                 ,exe.instruction.rd
                 ,exe.instruction.opcode
                 ,exe.pc_jump_addr
                 ,exe.decode.op_writes_rf 
                 ,exe.decode.is_load_op   
                 ,exe.decode.is_store_op  
                 ,exe.decode.is_mem_op    
                 ,exe.decode.is_branch_op 
                 ,exe.decode.is_jump_op   
                 ,exe.decode.op_reads_rf1 
                 ,exe.decode.op_reads_rf2 
                 ,exe.decode.op_is_auipc
                 ,exe.rs1_val
                 ,exe.rs2_val
                );
        $display(" MEM: pc+4:%x rd_addr:%x wrf:%b ld:%b st:%b mem:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b alu:%x"
                 ,mem.pc_plus4
                 ,mem.rd_addr
                 ,mem.decode.op_writes_rf 
                 ,mem.decode.is_load_op   
                 ,mem.decode.is_store_op  
                 ,mem.decode.is_mem_op    
                 ,mem.decode.is_branch_op 
                 ,mem.decode.is_jump_op   
                 ,mem.decode.op_reads_rf1 
                 ,mem.decode.op_reads_rf2 
                 ,mem.decode.op_is_auipc
                 ,mem.alu_result
                );
        $display("  WB: wrf:%b rd_addr:%x, rf_data:%x"
                 ,wb.op_writes_rf 
                 ,wb.rd_addr      
                 ,wb.rf_data      
                );
        $display("MISC: stall:%b stall_mem:%b stall_non_mem:%b stall_lrw:%b reservation:%b valid_to_mem:%b alu_result:%x st_data:%x mask:%b jump_now:%b flush:%b"
                 ,stall
                 ,stall_mem      
                 ,stall_non_mem
                 ,stall_lrw
                 ,reservation_i
                 ,valid_to_mem_c
                 ,alu_result
                 ,store_data
                 ,mask
                 ,jump_now
                 ,flush
                );
        $display("  MD: stall_md:%b md_vlaid:%b md_op:%b md_out_sel:%b md_resp_valid:%b md_result:%x"
                 ,stall_md
                 ,md_valid
                 ,md_op
                 ,md_out_sel
                 ,md_resp_valid
                 ,md_result
                );
      end

  end

//+----------------------------------------------
//|
//|     BRANCH AND JUMP PREDICTION SIGNALS
//|
//+----------------------------------------------

// Under predicted flag (meaning that we predicted not taken when taken)
assign branch_under_predict = 
        (~exe.instruction[RV32_instr_width_gp-1]) & jump_now;

// Over predicted flag (meaning that we predicted taken when not taken)
assign branch_over_predict = 
        exe.instruction[RV32_instr_width_gp-1] & (~jump_now);

// Flag if a branch misptediction occured
assign branch_mispredict = exe.decode.is_branch_op 
                           & (branch_under_predict | branch_over_predict);

// JALR mispredict (or just a JALR instruction in the single cycle because it
// follows the same logic as a JALR mispredict)
assign jalr_mispredict = (exe.instruction[6:0] ==? `RV32_JALR_OP) 
                         & (alu_result != jalr_prediction_rr);

// Flush the control signals in the execute and instr decode stages if there
// is a misprediciton and (only for the pipelined version of the core)
assign flush = (branch_mispredict | jalr_mispredict);

//+----------------------------------------------
//|
//|          PROGRAM COUNTER SIGNALS
//|
//+----------------------------------------------

// PC write enable. This stops the CPU updating the PC
assign pc_wen = net_pc_write_cmd_idle | (~stall);

// Next PC under normal circumstances
assign pc_plus4 = pc_r + 3'b100;

assign pc_jump_addr      = $signed(pc_r) 
                           + (decode.is_branch_op 
                              ? $signed(`RV32_signext_Bimm(instruction))
                              : $signed(`RV32_signext_Jimm(instruction))
                             );

// Determine what the next PC should be
always_comb
begin
    // Update the JALR prediction register
    if (exe.decode.is_jump_op)
        jalr_prediction_n = exe.pc_plus4;
    else
        jalr_prediction_n = jalr_prediction_r;

    // Network setting PC (highest priority)
    if (net_pc_write_cmd_idle)
        pc_n = RV32_reg_data_width_gp'(net_packet_r.header.addr[imem_addr_width_p-1:0]);

    // Fixing a branch misprediction (or single cycle branch will
    // follow a branch under prediction logic)
    else if (branch_mispredict)
        if (branch_under_predict)
            pc_n = exe.pc_jump_addr;
        else
            pc_n = exe.pc_plus4;

    // Fixing a JALR misprediction (or a signal cycle JALR instruction)
    else if (jalr_mispredict)
        pc_n = alu_result;

    // Predict taken branch or instrcution is a long jump
    else if ((decode.is_branch_op & instruction[RV32_instr_width_gp-1]) | (instruction[6:0] == `RV32_JAL_OP))
        pc_n = pc_jump_addr;

    // Predict jump to previous linked location
    else if (decode.is_jump_op) // equivalent to (instruction ==? `RV32_JALR)
        pc_n = jalr_prediction_n;

    // Standard operation or predict not taken branch
    else
        pc_n = pc_plus4;
end

//+----------------------------------------------
//|
//|         INSTRUCTION MEMORY SIGNALS
//|
//+----------------------------------------------

// Selection between network and core for instruction address
assign imem_addr = (net_imem_write_cmd) ? 
                    net_packet_r.header.addr[2+:imem_addr_width_p] 
                  : pc_n[2+:imem_addr_width_p];

// Instruction memory chip enable signal
assign imem_cen = (~stall) | (net_imem_write_cmd | net_pc_write_cmd_idle);

// RISC-V edit: reserved bits in network packet header
//              used as mask input
genvar i;
for(i=0; i<4; i=i+1)
  mem_1rw #(.addr_width_p(imem_addr_width_p),
            .num_entries_p(2**imem_addr_width_p),
            //.num_bits_p(instruction_size_gp)
            .num_bits_p(8)
           ) imem_0
  (
      .clk(clk),
      .addr_i(imem_addr),
      .wen_i(net_imem_write_cmd & net_packet_r.header.reserved[i]),
      .cen_i(imem_cen),
      .wd_i(net_packet_r.data[i*8+:8]),
      .rd_o(imem_out[i*8+:8])
  );

// Since imem has one cycle delay and we send next cycle's address, pc_n,
// if the PC is not written, the instruction must not change.
assign instruction = (pc_wen_r) ? imem_out : instruction_r;

//+----------------------------------------------
//|
//|         DECODE CONTROL SIGNALS
//|
//+----------------------------------------------

// Instantiate the instruction decoder
cl_decode cl_decode_0
(
    .instruction_i(instruction),
    .decode_o(decode)
);

//+----------------------------------------------
//|
//|           REGISTER FILE SIGNALS
//|
//+----------------------------------------------

// Register write could be from network or the controller
assign rf_wen = (net_reg_write_cmd) | (wb.op_writes_rf & (~stall));

// Selection between network 0and address included in the instruction which is 
// exeuted Address for Reg. File is shorter than address of Ins. memory in network 
// data Since network can write into immediate registers, the address is wider
// but for the destination register in an instruction the extra bits must be zero
assign rf_wa = (net_reg_write_cmd ? net_packet_r.header.addr[RV32_reg_addr_width_gp-1:0] 
                                  : wb.rd_addr);

// Choose if the data is from the netword of the write-back stage
assign rf_wd = (net_reg_write_cmd ? net_packet_r.data : wb.rf_data);

// Register file chip enable signal
assign rf_cen = (~stall) | (net_reg_write_cmd);

// Instantiate the general purpose register file
reg_file #(.addr_width_p(RV32_reg_addr_width_gp)) rf_0
(
    .clk(clk),
    .rs_addr_i(id.instruction.rs1),
    .rd_addr_i(id.instruction.rs2),
    .wen_i(rf_wen),
    .cen_i(rf_cen),
    .write_addr_i(rf_wa),
    .write_data_i(rf_wd),
    .rs_val_o(rf_rs1_out),
    .rd_val_o(rf_rs2_out)
);

//+----------------------------------------------
//|
//|     RISC-V edit: "M" STANDARAD EXTENSION 
//|
//+----------------------------------------------
assign instr_is_md = (exe.instruction.opcode == `RV32_OP)
                      & (exe.instruction.funct7 == 7'b0000001);
assign md_valid    = instr_is_md & md_ready;
assign stall_md    = instr_is_md & ~md_resp_valid;

always_comb
begin
  md_op          = 2'bxx;
  md_out_sel     = 2'bxx;
  md_rs1_signed  = 1'b1;
  md_rs2_signed  = 1'b1;

  unique casez (exe.instruction.funct3)
    3'b000: // MUL
      begin
        md_op      = 2'b00;
        md_out_sel = 2'b00;
      end

    3'b001: // MULH
      begin
        md_op      = 2'b00;
        md_out_sel = 2'b01;
      end

    3'b010: // MULHSU
      begin
        md_op         = 2'b00;
        md_out_sel    = 2'b01;
        md_rs2_signed = 1'b0;
      end

    3'b011: // MULHU
      begin
        md_op         = 2'b00;
        md_out_sel    = 2'b01;
        md_rs1_signed = 1'b0;
        md_rs2_signed = 1'b0;
      end

    3'b100: // DIV
      begin
        md_op      = 2'b01;
        md_out_sel = 2'b00;
      end

    3'b101: // DIVU
      begin
        md_op         = 2'b01;
        md_out_sel    = 2'b00;
        md_rs1_signed = 1'b0;
        md_rs2_signed = 1'b0;
      end

    3'b110: // REM
      begin
        md_op      = 2'b10;
        md_out_sel = 2'b10;
      end
    
    3'b111: // REMU
      begin
        md_op         = 2'b10;
        md_out_sel    = 2'b10;
        md_rs1_signed = 1'b0;
        md_rs2_signed = 1'b0;
      end
  endcase
end

vscale_mul_div md_0
  ( .clk             (clk)
   ,.reset           (reset)
   ,.req_valid       (md_valid)
   ,.req_ready       (md_ready)
   ,.req_in_1_signed (md_rs1_signed)
   ,.req_in_2_signed (md_rs2_signed)
   ,.req_op          (md_op)
   ,.req_out_sel     (md_out_sel)
   ,.req_in_1        (rs1_to_alu)
   ,.req_in_2        (rs2_to_alu)
   ,.resp_valid      (md_resp_valid)
   ,.resp_result     (md_result)
  );

//+----------------------------------------------
//|
//|                ALU SIGNALS
//|
//+----------------------------------------------

// RS register forwarding
assign  rs1_in_mem       = mem.decode.op_writes_rf 
                           & (exe.instruction.rs1 == mem.rd_addr)
                           & (|exe.instruction.rs1);
assign  rs1_in_wb        = wb.op_writes_rf 
                           & (exe.instruction.rs1  == wb.rd_addr)
                           & (|exe.instruction.rs1);
assign  rs1_forward_val  = rs1_in_mem ? rf_data : wb.rf_data;
assign  rs1_is_forward   = (rs1_in_mem | rs1_in_wb);

// RD register forwarding
assign  rs2_in_mem       = mem.decode.op_writes_rf 
                           & (exe.instruction.rs2 == mem.rd_addr)
                           & (|exe.instruction.rs2);
assign  rs2_in_wb        = wb.op_writes_rf 
                           & (exe.instruction.rs2  == wb.rd_addr)
                           & (|exe.instruction.rs2);
assign  rs2_forward_val  = rs2_in_mem ? rf_data : wb.rf_data;
assign  rs2_is_forward   = (rs2_in_mem | rs2_in_wb);

// RISC-V edit: Immediate values handled in alu
assign rs1_to_alu = ((rs1_is_forward) ? rs1_forward_val : exe.rs1_val);
assign rs2_to_alu = ((rs2_is_forward) ? rs2_forward_val : exe.rs2_val);

// Instantiate the ALU
alu alu_0
(
    .rs1_i(rs1_to_alu),
    .rs2_i(rs2_to_alu),
    .op_i(exe.instruction),
    .result_o(basic_comp_result),
    .jump_now_o(jump_now)
);

assign alu_result = instr_is_md ? md_result : basic_comp_result;

//+----------------------------------------------
//|
//|            STATE MACHINE SIGNALS
//|
//+----------------------------------------------

// Instantiate the state machine
cl_state_machine state_machine
(
    .instruction_i(exe.instruction),
    .state_i(state_r),
    .net_pc_write_cmd_idle_i(net_pc_write_cmd_idle),
    .stall_i(stall),
    .state_o(state_n)
);

//+----------------------------------------------
//|
//|        DATA MEMORY HANDSHAKE SIGNALS
//|
//+----------------------------------------------

assign valid_to_mem_c = exe.decode.is_mem_op & (~stall_non_mem) & (~stall_lrw);
assign yumi_to_mem_c  = mem.decode.is_mem_op & from_mem_i.valid & (~stall_non_mem);

// RISC-V edit: add reservation
always_comb
begin
  reserve_1_o = 1'b0;
  stall_lrw   = 1'b0;

  if(exe.instruction ==? `RV32_LR_W)
    begin
      reserve_1_o = ~exe.instruction[26];
      // stall until reseervation is cleared
      stall_lrw   = exe.instruction[26] & reservation_i;
    end
end

//+----------------------------------------------
//|
//|        SEQUENTIAL LOGIC SIGNALS
//|
//+----------------------------------------------

// All sequental logic signals are set in this statement. The
// active high reset signal is what causes all signals to be
// reset to zero.
always_ff @ (posedge clk)
begin
    if (reset) begin
        pc_r               <= '0;
        state_r            <= IDLE;
        instruction_r      <= '0;
        pc_wen_r           <= '0;
        jalr_prediction_r  <= '0;
        jalr_prediction_rr <= '0;
        net_packet_r       <= '0;
    end else begin
        if (pc_wen)
            pc_r           <= pc_n;
        state_r            <= state_n;
        instruction_r      <= instruction;
        pc_wen_r           <= pc_wen;
        jalr_prediction_r  <= jalr_prediction_n;
        jalr_prediction_rr <= jalr_prediction_r;
        net_packet_r       <= net_packet_i;
    end
end

//+----------------------------------------------
//|
//|     INSTR FETCH TO INSTR DECODE SHIFT
//|
//+----------------------------------------------

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle | (flush & (~stall)))
        id <= '0;
    else if (~stall)
        id <= '{
            pc_plus4     : pc_plus4,
            pc_jump_addr : pc_jump_addr,
            instruction  : instruction,
            decode       : decode
        };
end

//+----------------------------------------------
//|
//|        INSTR DECODE TO EXECUTE SHIFT
//|
//+----------------------------------------------

// Determine what rs1 value should be passed to the exe stage of the pipeline
always_comb
begin
    // RS pre-forward found in the write back stage. A pre-forward is
    // a bypass of the write back signal in the ID stage, where the
    // normal forward occurs in the EXE stage right before the ALU
    if (|id.instruction.rs1 // RISC-V: no bypass for reg 0
        & (id.instruction.rs1 == wb.rd_addr) 
        & wb.op_writes_rf
       )
        rs1_to_exe = wb.rf_data;

    // RS in general purpose register file
    else
        rs1_to_exe = rf_rs1_out;
end

// Determine what rs2 value should be passed to the exe stage of the pipeine
always_comb
begin
    // RD pre-forward found in the write back stage. A pre-forward is
    // a bypass of the write back signal in the ID stage, where the
    // normal forward occurs in the EXE stage right before the ALU
    if (|id.instruction.rs2 // RISC-V: no bypass for reg 0
        & (id.instruction.rs2 == wb.rd_addr) 
        & wb.op_writes_rf
       )
        rs2_to_exe = wb.rf_data;

    // RD in general purpose register file
    else
        rs2_to_exe = rf_rs2_out;
end

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle | (flush & (~stall)))
        exe <= '0;
    else if (~stall)
        exe <= '{
            pc_plus4     : id.pc_plus4,
            pc_jump_addr : id.pc_jump_addr,
            instruction  : id.instruction,
            decode       : id.decode,
            rs1_val      : rs1_to_exe,
            rs2_val      : rs2_to_exe
        };
end

//+----------------------------------------------
//|
//|          EXECUTE TO MEMORY SHIFT
//|
//+----------------------------------------------

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle)
        mem <= '0;
    else if (~stall)
        mem <= '{
            pc_plus4   : exe.pc_plus4,
            rd_addr    : exe.instruction.rd,
            decode     : exe.decode,
            alu_result : alu_result,
            ld_width   : exe.instruction.funct3
        };
end

//+----------------------------------------------
//|
//|       MEMORY TO RF WRITE BACK SHIFT
//|
//+----------------------------------------------

// Determine what data to send to the write back stage
// that will end up being writen to the register file
always_comb
begin
    // RISC-V edit: added support for byte and hex loads
    if (mem.decode.op_is_auipc)
        rf_data = mem.pc_plus4 - 3'b100 + mem.alu_result;
    else if (mem.decode.is_jump_op)
        rf_data = mem.pc_plus4;
    else if (mem.decode.is_load_op)
      begin
        unique casez (mem.alu_result[1:0])
          00: loaded_byte = from_mem_i.read_data[0+:8];
          01: loaded_byte = from_mem_i.read_data[8+:8];
          10: loaded_byte = from_mem_i.read_data[16+:8];
          11: loaded_byte = from_mem_i.read_data[24+:8];
          default: loaded_byte = 8'bx;
        endcase

        loaded_hex = (|mem.alu_result[1:0]) 
                      ? from_mem_i.read_data[16+:16]
                      : from_mem_i.read_data[0+:16];
    
        if (~|mem.ld_width[1:0])  // 2'b00 is byte op
            rf_data = (mem.ld_width[2]) 
                       ? 32'(loaded_byte[7:0])
                       : {{24{loaded_byte[7]}}, loaded_byte[7:0]};
        else if(mem.ld_width[1:0] == 2'b01) // 2'b01 is hex op
            rf_data = (mem.ld_width[2])
                       ? 32'(loaded_hex[15:0])
                       : {{24{loaded_hex[15]}}, loaded_hex[15:0]};
        else
            rf_data = from_mem_i.read_data;
      end
    else
        rf_data = mem.alu_result;
end

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle)
        wb <= '0;
    else if (~stall)
        wb <= '{
            op_writes_rf : mem.decode.op_writes_rf,
            rd_addr      : mem.rd_addr,
            rf_data      : rf_data
        };
end

endmodule
