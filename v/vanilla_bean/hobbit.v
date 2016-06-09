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
                //output ring_packet_s              net_packet_o,
            
                input  mem_out_s                  from_mem_i,
                output mem_in_s                   to_mem_o,
            
                //input                             gate_way_full_i,
                //output logic [mask_length_gp-1:0] barrier_o,
                //output logic                      exception_o,
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
//logic         net_id_match_valid, net_pc_write_cmd,  net_imem_write_cmd,
//              net_reg_write_cmd,  net_bar_write_cmd, net_pc_write_cmd_idle,
//              net_reg_is_const,   exec_net_packet,   net_sent;
logic         net_id_match_valid, net_pc_write_cmd,  net_imem_write_cmd,
              net_reg_write_cmd, net_pc_write_cmd_idle,
              exec_net_packet;

// Barrier logic
//logic [mask_length_gp-1:0] barrier_n, barrier_r;
//logic [mask_length_gp-1:0] barrier_mask_n, barrier_mask_r;

// Stall and exception logic
//logic stall, stall_non_mem, stall_mem, exception_n;
logic stall, stall_non_mem, stall_mem;

// Program counter logic
//logic [imem_addr_width_p-1:0] pc_n, pc_r, pc_plus1, pc_jump_addr, pc_long_jump_addr;
logic [RV32_reg_data_width_gp-1:0] pc_n, pc_r, pc_plus4, pc_jump_addr, pc_long_jump_addr;
logic                              pc_wen, pc_wen_r, imem_cen;

// Instruction memory logic
logic [imem_addr_width_p-1:0] imem_addr;
instruction_s                 imem_out, instruction, instruction_r;
//logic [operand_size_gp-1:0]   operand;

// Constant register file logic
//logic [31:0]               crf_out, crf_wd, const_reg_val, const_reg_val_r;
//logic [rs_imm_size_gp-1:0] crf_addr, net_const_rf_addr, instr_const_rf_addr;
//logic                      crf_wen, crf_cen;

// Register file logic
//logic [31:0]           rf_rs_out, rf_rd_out, rf_wd;
//logic [rd_size_gp-1:0] rf_wa;
//logic                  rf_wen, rf_cen;
logic [RV32_reg_data_width_gp-1:0] rf_rs1_out, rf_rs2_out, rf_wd;
logic [RV32_reg_addr_width_gp-1:0] rf_wa;
logic                              rf_wen, rf_cen;

// ALU logic
//logic [31:0] rs_to_alu, rd_to_alu, alu_result;
logic [RV32_reg_data_width_gp-1:0] rs1_to_alu, rs2_to_alu, alu_result;
logic                              jump_now;

// Stores
logic [RV32_reg_data_width_gp-1:0] store_data;
logic [3:0]                        mask;

// Sign extended of rs_imm field
//logic [31:0] sign_extended_rs_imm;

// Sign extended immediate
logic [RV32_instr_width_gp-1:0] sign_extended_imm;

// Forwarding signals
//logic   rs_in_mem, rs_in_wb, rd_in_mem, rd_in_wb;
logic   rs1_in_mem, rs1_in_wb, rs2_in_mem, rs2_in_wb;

// Data memory handshake logic
logic valid_to_mem_c, yumi_to_mem_c;

// Decoded control signals logic
decode_s decode;

// State machine logic
state_e state_n, state_r;

// Value forwarding logic
//logic        rs_is_forward, rd_is_forward;
//logic [31:0] rs_forward_val, rd_forward_val;
logic                              rs1_is_forward, rs2_is_forward;
logic [RV32_reg_data_width_gp-1:0] rs1_forward_val, rs2_forward_val;

//logic [31:0]  rf_data, rs_to_exe, rd_to_exe;
logic [RV32_reg_data_width_gp-1:0] rf_data, loaded_byte, loaded_hex, rs1_to_exe, rs2_to_exe;

// Branch and jump predictions
// logic [imem_addr_width_p-1:0] jalr_prediction_n, jalr_prediction_r, 
//                               jalr_prediction_rr;
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
//assign net_bar_write_cmd     = exec_net_packet  & (net_packet_r.header.net_op == BAR);
assign net_pc_write_cmd_idle = net_pc_write_cmd & (state_r == IDLE);
// assign net_reg_is_const      = (|net_packet_r.header.addr[rs_imm_size_gp-1:rd_size_gp]);

/*
// Determining the output network packet
always_comb
begin
    if (net_id_match_valid) begin
        if ((exe.decode.is_netw_op) & (~gate_way_full_i) 
            & (state_r == RUN) & (~stall_mem)) begin
            net_sent = 1'b1;
            net_packet_o = '{
                //header : rs_to_alu,
                //data   : rd_to_alu,
                header : rs1_to_alu,
                data   : rs2_to_alu,
                valid  : 1'b1
            };
        end else begin
            net_sent = 1'b0;
            net_packet_o = '{
                header : net_packet_r.header,
                data   : net_packet_r.data,
                valid  : 1'b0
            };
        end
    end else if (~net_packet_r.valid & exe.decode.is_netw_op 
                & (~gate_way_full_i) & (state_r == RUN) & (~stall_mem)) begin
        net_sent = 1'b1;
        net_packet_o = '{
            //header : rs_to_alu,
            //data   : rd_to_alu,
            header : rs1_to_alu,
            data   : rs2_to_alu,
            valid  : 1'b1
        };
    end else begin
        net_sent = 1'b0;
        net_packet_o = net_packet_r;
    end
end
*/
/*
//+----------------------------------------------
//|
//|         BARRIER LOGIC SIGNALS
//|
//+----------------------------------------------

// Barrier final result, in the barrier mask, 1 means not mask and 0 means mask
assign barrier_o = barrier_mask_r & barrier_r;

// barrier_mask_n, which stores the mask for barrier signal
always_comb
begin
    if (net_bar_write_cmd & (state_r != ERR))
        barrier_mask_n = net_packet_r.data[mask_length_gp-1:0];
    else
        barrier_mask_n = barrier_mask_r;
end

// barrier_n signal, which contains the barrier value it can be set
// by PC write network command if in IDLE or by an an BAR instruction
// that is committing
always_comb
begin
    if (net_pc_write_cmd_idle)
        barrier_n = net_packet_r.data[mask_length_gp-1:0];
    else if (exe.decode.is_bar_op & (~stall))
        barrier_n = alu_result[mask_length_gp-1:0];
    else
        barrier_n = barrier_r;
end
*/
//+----------------------------------------------
//|
//|     STALL AND EXCEPTION LOGIC SIGNALS
//|
//+----------------------------------------------

// rf structural hazard and imem structural hazard (can't load next instruction)
//assign stall_non_mem = (net_imem_write_cmd)
//                     | (net_reg_write_cmd & (~net_reg_is_const) & wb.op_writes_rf)
//                     | (net_reg_write_cmd & net_reg_is_const & decode.op_reads_crf)  
//                     | (exe.decode.is_netw_op & (~net_sent))
//                     | (state_r != RUN);
assign stall_non_mem = (net_imem_write_cmd)
                     | (net_reg_write_cmd & wb.op_writes_rf)
                     | (net_reg_write_cmd)  
                     //| (exe.decode.is_netw_op & (~net_sent))
                     | (state_r != RUN);

// stall due to data memory access
assign stall_mem = (exe.decode.is_mem_op & (~from_mem_i.yumi))
                 //| (mem.decode.is_mem_op & (~from_mem_i.valid));
                   | (mem.decode.is_load_op & (~from_mem_i.valid));

// Stall if LD/ST still active; or in non-RUN state
assign stall = (stall_non_mem | stall_mem); 
/*
// exception_n signal, which indicates an exception
// We cannot determine next state as ERR in WORK state, since the instruction
// must be completed, WORK state means start of any operation and in memory
// instructions which could take some cycles, it could mean wait for the
// response of the memory to aknowledge the command. So we signal that we recieved
// a wrong package, but do not stop the execution. Afterwards the exception_r
// register is used to avoid extra fetch after this instruction.
always_comb
begin
    if ((state_r == ERR) | (net_pc_write_cmd & (state_r != IDLE)))
        exception_n = 1'b1;
    else
        exception_n = exception_o;
end
*/

//+----------------------------------------------
//|
//|        EXTERNAL MODULE CONNECTIONS
//|
//+----------------------------------------------

// RISC-V edit: support for byte and hex stores
always_comb
begin
  if (exe.decode.is_byte_op)
    begin
      store_data = (32'(rs2_to_alu[7:0])) << ((5'(alu_result[1:0])) << 3);
      mask       = (4'b0001 << alu_result[1:0]);
    end
  else if(exe.decode.is_hex_op)
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
    //write_data    : rs_to_alu,
    write_data    : store_data,
    valid         : valid_to_mem_c,
    wen           : exe.decode.is_store_op,
    //byte_not_word : exe.decode.is_byte_op,
    mask          : mask,
    yumi          : yumi_to_mem_c,
    addr          : alu_result
};

// DEBUG Struct
//assign debug_o = {pc_r, instruction, state_r, barrier_mask_r, barrier_r};
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
        $display("  ID: pc+4:%x instr:{%x_%x_%x_%x_%x_%x} j_addr:%x wrf:%b ld:%b uld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b"
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
                 ,id.decode.is_uload_op 
                 ,id.decode.is_store_op 
                 ,id.decode.is_mem_op   
                 ,id.decode.is_byte_op  
                 ,id.decode.is_hex_op   
                 ,id.decode.is_branch_op
                 ,id.decode.is_jump_op  
                 ,id.decode.op_reads_rf1
                 ,id.decode.op_reads_rf2
                 ,id.decode.op_is_auipc
                );
        $display(" EXE: pc+4:%x instr:{%x_%x_%x_%x_%x_%x} j_addr:%x wrf:%b ld:%b uld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b rs1:%0x rs2:%0x"
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
                 ,exe.decode.is_uload_op  
                 ,exe.decode.is_store_op  
                 ,exe.decode.is_mem_op    
                 ,exe.decode.is_byte_op   
                 ,exe.decode.is_hex_op    
                 ,exe.decode.is_branch_op 
                 ,exe.decode.is_jump_op   
                 ,exe.decode.op_reads_rf1 
                 ,exe.decode.op_reads_rf2 
                 ,exe.decode.op_is_auipc
                 ,exe.rs1_val
                 ,exe.rs2_val
                );
        $display(" MEM: pc+4:%x rd_addr:%x wrf:%b ld:%b uld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b alu:%x"
                 ,mem.pc_plus4
                 ,mem.rd_addr
                 ,mem.decode.op_writes_rf 
                 ,mem.decode.is_load_op   
                 ,mem.decode.is_uload_op  
                 ,mem.decode.is_store_op  
                 ,mem.decode.is_mem_op    
                 ,mem.decode.is_byte_op   
                 ,mem.decode.is_hex_op    
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
        $display("MISC: stall:%b stall_mem:%b stall_non_mem:%b valid_to_mem_c:%b alu_result:%x st_data:%x mask:%b jump_now:%b flush:%b"
                 ,stall
                 ,stall_mem      
                 ,stall_non_mem
                 ,valid_to_mem_c
                 ,alu_result
                 ,store_data
                 ,mask
                 ,jump_now
                 ,flush
                );
      end

  end

//+----------------------------------------------
//|
//|     BRANCH AND JUMP PREDICTION SIGNALS
//|
//+----------------------------------------------

// Under predicted flag (meaning that we predicted not taken when taken)
//assign branch_under_predict = 
//        (~exe.instruction.rs_imm[rs_imm_size_gp-1]) & jump_now;
assign branch_under_predict = 
        (~exe.instruction[RV32_instr_width_gp-1]) & jump_now;

// Over predicted flag (meaning that we predicted taken when not taken)
//assign branch_over_predict = 
//        exe.instruction.rs_imm[rs_imm_size_gp-1] & (~jump_now);
assign branch_over_predict = 
        exe.instruction[RV32_instr_width_gp-1] & (~jump_now);

// Flag if a branch misptediction occured
assign branch_mispredict = exe.decode.is_branch_op 
                           & (branch_under_predict | branch_over_predict);

// JALR mispredict (or just a JALR instruction in the single cycle because it
// follows the same logic as a JALR mispredict)
//assign jalr_mispredict = (exe.instruction ==? `kJALR) 
//                         & (rs_to_alu != jalr_prediction_rr);
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
//assign pc_plus1 = pc_r + 1'b1;
assign pc_plus4 = pc_r + 3'b100;

//localparam long_jump_width_lp = `BSG_MIN(imem_addr_width_p,operand_size_gp);

// Next PC if there is a branch taken
//assign pc_jump_addr      = $signed(pc_r) + $signed(instruction.rs_imm); 
//assign pc_long_jump_addr = $signed(pc_r) + 
//                           $signed(operand[long_jump_width_lp-1:0]);
assign pc_jump_addr      = $signed(pc_r) + $signed(`RV32_signext_Bimm(instruction)); 
assign pc_long_jump_addr = $signed(pc_r) + $signed(`RV32_signext_Jimm(instruction));

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
        //pc_n = net_packet_r.header.addr[imem_addr_width_p-1:0];
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
        //pc_n = rs_to_alu[imem_addr_width_p-1:0];
        pc_n = alu_result;

    // Predict taken branch
    //else if (decode.is_branch_op & instruction.rs_imm[rs_imm_size_gp-1])
    else if (decode.is_branch_op & instruction[RV32_instr_width_gp-1])
        pc_n = pc_jump_addr;

    // Predict jump to previous linked location
    //else if (instruction ==? `kJALR)
    else if (instruction ==? `RV32_JALR)
        pc_n = jalr_prediction_n;

    // if the instruction is long branch, there is no prediction 
    //else if (instruction ==? `kBL)
    else if (instruction ==? `RV32_JAL)
        pc_n = pc_long_jump_addr;

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

// Instantiate the instruction memory
/*
mem_1rw #(.addr_width_p(imem_addr_width_p),
          .num_entries_p(2**imem_addr_width_p),
          .num_bits_p(instruction_size_gp)
         ) imem_0
(
    .clk(clk),
    .addr_i(imem_addr),
    .wen_i(net_imem_write_cmd),
    .cen_i(imem_cen),
    //.wd_i(net_packet_r.data[instruction_size_gp-1:0]),
    .wd_i(net_packet_r.data[`RV32_instr_width_gp-1:0]),
    .rd_o(imem_out)
);
*/

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
      //.wd_i(net_packet_r.data[instruction_size_gp-1:0]),
      .wd_i(net_packet_r.data[i*8+:8]),
      .rd_o(imem_out[i*8+:8])
  );

// Since imem has one cycle delay and we send next cycle's address, pc_n,
// if the PC is not written, the instruction must not change.
assign instruction = (pc_wen_r) ? imem_out : instruction_r;
//assign operand     = {{instruction.rd}, {instruction.rs_imm}};

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

/*
//+----------------------------------------------
//|
//|      CONSTANT REGISTER FILE SIGNALS
//|
//+----------------------------------------------

// Network address adjusted to make it 0 based in the constant register file
assign net_const_rf_addr = 
        {net_packet_r.header.addr[rs_imm_size_gp-1:rd_size_gp] - 1'b1,
         net_packet_r.header.addr[rd_size_gp-1:0]};

// Instruction rs address adjusted to make it 0 based in the constant register file
assign instr_const_rf_addr = 
        {instruction.rs_imm[rs_imm_size_gp-1:rd_size_gp] - 1'b1, 
         instruction.rs_imm[rd_size_gp-1:0]};

// The address to the constant register file is used for both reads
// writes to the register file. Therefore, we must check for a network
// packet to determine the address.
assign crf_addr = net_reg_write_cmd ? net_const_rf_addr : instr_const_rf_addr;

// The constant register file is only written by the network. Also, we
// must check to make sure the network command is not for the GP regfile
assign crf_wen = (net_reg_write_cmd & net_reg_is_const);

// Constant register file chip enable signal
assign crf_cen = (~stall & decode.op_reads_crf) 
               | (net_reg_write_cmd & net_reg_is_const);

// Instantiate the constant register file
mem_1rw #(.addr_width_p($clog2(const_file_size_gp))
         ,.num_entries_p(const_file_size_gp)
         ,.num_bits_p(32)
         ) const_rf_0
(
    .clk(clk),
    .addr_i(crf_addr[$clog2(const_file_size_gp)-1:0]),
    .wen_i(crf_wen),
    .cen_i(crf_cen),
    .wd_i(net_packet_r.data),
    .rd_o(crf_out)
);

// Because the constant register file is synchronous when the pipeline is turned on,
// we must not update the constant register value if the PC has not been changed.
assign const_reg_val = (!pc_wen_r ? const_reg_val_r : crf_out);
*/

//+----------------------------------------------
//|
//|           REGISTER FILE SIGNALS
//|
//+----------------------------------------------

// Register write could be from network or the controller
//assign rf_wen = (net_reg_write_cmd & (~net_reg_is_const)) 
//              | (wb.op_writes_rf & (~stall));
assign rf_wen = (net_reg_write_cmd) | (wb.op_writes_rf & (~stall));

// Selection between network 0and address included in the instruction which is 
// exeuted Address for Reg. File is shorter than address of Ins. memory in network 
// data Since network can write into immediate registers, the address is wider
// but for the destination register in an instruction the extra bits must be zero
//assign rf_wa = (net_reg_write_cmd ? net_packet_r.header.addr[rd_size_gp-1:0] 
//                                  : wb.rd_addr);
assign rf_wa = (net_reg_write_cmd ? net_packet_r.header.addr[RV32_reg_addr_width_gp-1:0] 
                                  : wb.rd_addr);

// Choose if the data is from the netword of the write-back stage
assign rf_wd = (net_reg_write_cmd ? net_packet_r.data : wb.rf_data);

// Register file chip enable signal
//assign rf_cen = (~stall) | (net_reg_write_cmd & (~net_reg_is_const));
assign rf_cen = (~stall) | (net_reg_write_cmd);

// Instantiate the general purpose register file
//reg_file #(.addr_width_p($bits(instruction.rd))) rf_0
reg_file #(.addr_width_p(RV32_reg_addr_width_gp)) rf_0
(
    .clk(clk),
    //.rs_addr_i(id.instruction.rs_imm[rd_size_gp-1:0]),
    //.rd_addr_i(id.instruction.rd),
    .rs_addr_i(id.instruction.rs1),
    .rd_addr_i(id.instruction.rs2),
    .wen_i(rf_wen),
    .cen_i(rf_cen),
    .write_addr_i(rf_wa),
    .write_data_i(rf_wd),
    //.rs_val_o(rf_rs_out),
    //.rd_val_o(rf_rd_out)
    .rs_val_o(rf_rs1_out),
    .rd_val_o(rf_rs2_out)
);

//+----------------------------------------------
//|
//|                ALU SIGNALS
//|
//+----------------------------------------------

// RS register forwarding
//assign  rs_in_mem       = mem.decode.op_writes_rf 
//                          & (exe.instruction.rs_imm == mem.rd_addr);
//assign  rs_in_wb        = wb.op_writes_rf & (exe.instruction.rs_imm  == wb.rd_addr);
//assign  rs_forward_val  = rs_in_mem ? rf_data : (rs_in_wb ? wb.rf_data : 32'd0);
//assign  rs_is_forward   = (rs_in_mem | rs_in_wb);
assign  rs1_in_mem       = mem.decode.op_writes_rf 
                           & (exe.instruction.rs1 == mem.rd_addr)
                           & (|exe.instruction.rs1);
assign  rs1_in_wb        = wb.op_writes_rf 
                           & (exe.instruction.rs1  == wb.rd_addr)
                           & (|exe.instruction.rs1);
assign  rs1_forward_val  = rs1_in_mem ? rf_data : (rs1_in_wb ? wb.rf_data : 32'd0);
assign  rs1_is_forward   = (rs1_in_mem | rs1_in_wb);

// RD register forwarding
//assign  rd_in_mem       = mem.decode.op_writes_rf 
//                          & (exe.instruction.rd == mem.rd_addr);
//assign  rd_in_wb        = wb.op_writes_rf & (exe.instruction.rd  == wb.rd_addr);
//assign  rd_forward_val  = rd_in_mem ? rf_data : (rd_in_wb ? wb.rf_data : 32'd0);
//assign  rd_is_forward   = (rd_in_mem | rd_in_wb);
assign  rs2_in_mem       = mem.decode.op_writes_rf 
                           & (exe.instruction.rs2 == mem.rd_addr)
                           & (|exe.instruction.rs2);
assign  rs2_in_wb        = wb.op_writes_rf 
                           & (exe.instruction.rs2  == wb.rd_addr)
                           & (|exe.instruction.rs2);
assign  rs2_forward_val  = rs2_in_mem ? rf_data : (rs2_in_wb ? wb.rf_data : 32'd0);
assign  rs2_is_forward   = (rs2_in_mem | rs2_in_wb);

// Determine the rs value going into the alu. This is either the rs value 
// from the ID stage, or a value found forward in the pipeline. If the
// instruction is ADDI, then the RS val is substituted with the sign 
// extended value of rs_imm value of instruction
//assign sign_extended_imm =
//              {{(32-rs_imm_size_gp){exe.instruction.rs_imm[rs_imm_size_gp-1]}}
//               ,exe.instruction.rs_imm};

//assign rs_to_alu = (exe.instruction ==? `kADDI) ? sign_extended_rs_imm : 
//                   ((rs_is_forward) ? rs_forward_val : exe.rs_val);

// Determine the rd value going into the alu. This is either the rd value 
// from the ID stage, or a value found forward in the pipeline. If the 
// instruction is LG, then the RD val is substituted with the LG offest
// which is the long_immediate value
//assign rd_to_alu =  (exe.instruction ==? `kLG)   ? {exe.long_imm,2'b00} : 
//                   ((exe.instruction ==? `kMOVI) ? {exe.long_imm} : 
//                   ((rd_is_forward) ? rd_forward_val : exe.rd_val));

// RISC-V edit: Immediate values handled in alu
assign rs1_to_alu = ((rs1_is_forward) ? rs1_forward_val : exe.rs1_val);
assign rs2_to_alu = ((rs2_is_forward) ? rs2_forward_val : exe.rs2_val);

// Instantiate the ALU
alu alu_0
(
    .rs1_i(rs1_to_alu),
    .rs2_i(rs2_to_alu),
    .op_i(exe.instruction),
    .result_o(alu_result),
    .jump_now_o(jump_now)
);

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
    //.exception_i(exception_o),
    .net_pc_write_cmd_idle_i(net_pc_write_cmd_idle),
    .stall_i(stall),
    .state_o(state_n)
);

//+----------------------------------------------
//|
//|        DATA MEMORY HANDSHAKE SIGNALS
//|
//+----------------------------------------------

assign valid_to_mem_c = exe.decode.is_mem_op & (~stall_non_mem);
assign yumi_to_mem_c  = mem.decode.is_mem_op & from_mem_i.valid & (~stall_non_mem);

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
        //barrier_mask_r     <= {(mask_length_gp){1'b0}};
        //barrier_r          <= {(mask_length_gp){1'b0}};
        state_r            <= IDLE;
        instruction_r      <= '0;
        //const_reg_val_r    <= '0;
        pc_wen_r           <= '0;
        //exception_o        <= '0;
        jalr_prediction_r  <= '0;
        jalr_prediction_rr <= '0;
        net_packet_r       <= '0;
    end else begin
        if (pc_wen)
            pc_r           <= pc_n;
        //barrier_mask_r     <= barrier_mask_n;
        //barrier_r          <= barrier_n;
        state_r            <= state_n;
        instruction_r      <= instruction;
        //const_reg_val_r    <= const_reg_val;
        pc_wen_r           <= pc_wen;
        //exception_o        <= exception_n;
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

/*
// Instruction structures
instruction_s instr_to_id, lg_movi_instr;

// The LG instruction uses the RS and RD field to specify an offset,
// once the offset is extracted, we insert a 'fake' lg instruction into
// the pipeline with the implicit registers R1 and R0.
// The MOVI instruction uses the RS and RD field to specify an immediate 
// value, once the target is extracted, we insert a 'fake' movi instruction
// into the pipeline with the implicit register R1 (and R0 for simplicity).
assign lg_movi_instr = '{
    opcode  : instruction[instruction_size_gp-1:operand_size_gp], // LG or MOVI
    rd      : {{(rd_size_gp-1){1'b0}}, {1'b1}},                   // R1
    rs_imm  : {(rs_imm_size_gp){1'b0}}                            // R0
};

// Choose which instruction to pass to the decode stage
assign instr_to_id = ((instruction ==? `kLG)|(instruction ==? `kMOVI)) 
                      ? lg_movi_instr : instruction;
*/

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle | (flush & (~stall)))
        id <= '0;
    else if (~stall)
        id <= '{
            pc_plus4     : pc_plus4,
            pc_jump_addr : pc_jump_addr,
            //long_imm     : operand,
            //instruction  : instr_to_id,
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
    // RS is in the constant register file. Only RS can be found in
    // the constant register file, and if the register is in the
    // constant register file, then there is no forwarding
    //if (id.decode.op_reads_crf)
    //  rs_to_exe = const_reg_val;

    // RS pre-forward found in the write back stage. A pre-forward is
    // a bypass of the write back signal in the ID stage, where the
    // normal forward occurs in the EXE stage right before the ALU
    //else if ((id.instruction.rs_imm == wb.rd_addr) & wb.op_writes_rf)
    if (|id.instruction.rs1 // RISC-V: no bypass for reg 0
        & (id.instruction.rs1 == wb.rd_addr) 
        & wb.op_writes_rf
       )
        //rs_to_exe = wb.rf_data;
        rs1_to_exe = wb.rf_data;

    // RS in general purpose register file
    else
        //rs_to_exe = rf_rs_out;
        rs1_to_exe = rf_rs1_out;
end

// Determine what rs2 value should be passed to the exe stage of the pipeine
always_comb
begin
    // RD pre-forward found in the write back stage. A pre-forward is
    // a bypass of the write back signal in the ID stage, where the
    // normal forward occurs in the EXE stage right before the ALU
    //if ((id.instruction.rd == wb.rd_addr) & wb.op_writes_rf)
    if (|id.instruction.rs2 // RISC-V: no bypass for reg 0
        & (id.instruction.rs2 == wb.rd_addr) 
        & wb.op_writes_rf
       )
        //rd_to_exe = wb.rf_data;
        rs2_to_exe = wb.rf_data;

    // RD in general purpose register file
    else
        //rd_to_exe = rf_rd_out;
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
            //long_imm     : id.long_imm,
            instruction  : id.instruction,
            decode       : id.decode,
            //rs_val       : rs_to_exe,
            //rd_val       : rd_to_exe
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
            alu_result : alu_result
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
    
        //rf_data = from_mem_i.read_data;
        if (mem.decode.is_byte_op)
            rf_data = (mem.decode.is_uload_op) 
                       ? 32'(loaded_byte[7:0])
                       : {{24{loaded_byte[7]}}, loaded_byte[7:0]};
        else if(mem.decode.is_hex_op)
            rf_data = (mem.decode.is_uload_op)
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
