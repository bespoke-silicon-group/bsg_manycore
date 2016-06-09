`ifndef _definitions_v_
`define _definitions_v_

`include "parameters.v"
//`timescale 1 ns / 1 ns

/**
 *  This file defines the structs and macros
 *  used through out the vanilla core.
 */

`define EqualsEqualsQuestion(out,left,right)\
  always_comb\
    unique casez(left)\
      right:   out = 1'b1;\
      default: out = 1'b0;\
    endcase

//---- Controller states ----//
// WORK state means start of any operation or wait for the 
// response of memory in acknowledge of the command
// MEM_WAIT state means the memory acknowledged the command, 
// but it did not send the valid signal and core is waiting for it
typedef enum logic [1:0] {
    IDLE = 2'b00,
    RUN  = 2'b01,    
    ERR  = 2'b11
} state_e;

// Network operation enum
typedef enum logic [2:0]
{
    NULL  = 3'b000, // Nothing
    INSTR = 3'b001, // Instruction for instruction memory
    REG   = 3'b010, // Value for a register
    PC    = 3'b011, // Change PC
    BAR   = 3'b100  // Barrier mask
}
net_op_e;

/*
// Instruction structure
typedef struct packed
{
    logic [opcode_size_gp-1:0] opcode; // Operator code
    logic [rd_size_gp-1:0]     rd;     // Destination register
    logic [rs_imm_size_gp-1:0] rs_imm; // Source register or immediate value
}
instruction_s;
*/

// RV32 Instruction structure
// Ideally represents a R-type instruction; these fields if
// present in other types of instructions, appear at same positions
typedef struct packed {
  logic [RV32_funct7_width_gp-1:0]   funct7;
  logic [RV32_reg_addr_width_gp-1:0] rs2;
  logic [RV32_reg_addr_width_gp-1:0] rs1;
  logic [RV32_funct3_width_gp-1:0]   funct3;
  logic [RV32_reg_addr_width_gp-1:0] rd;
  logic [RV32_opcode_width_gp-1:0]   opcode;
} instruction_s;


// Ring packet header
typedef struct packed
{
    logic        bc;          // 31     // Broadcast flag
    logic        external;    // 30     // External flag, meaning the packet
                                        // is for a device outside the ring      
    logic [2:0]  gw_ID;       // 29..27 // Gate Way ID of the receiver or 
                                        // sender in case of a broadcast pakcet 
    logic [4:0]  ring_ID;     // 26..22 // Ring ID of the receiver or sender
                                        // in case of a broadcast packet
    net_op_e     net_op;      // 21..19 // Operation of the network packet 
                                        // for v_cores
    logic [4:0]  reserved;    // 18..14 // reserved bits, later we may steal 
                                        // more bits for net_op 
    logic [13:0] addr;        // 13..0  // the addr field which could be largened
                                        // using reserved field
} v_core_header_s;

// Ring packet
typedef struct packed{
    logic           valid;
    v_core_header_s header;  // 63..32
    logic [31:0]    data;    // 31..0
} ring_packet_s;

// Mesh network packet
typedef struct packed
{
    logic           valid; 
    logic           credit;
    v_core_header_s data; 
}
mesh_packet_s;

/*
// Data memory input structure
typedef struct packed
{
    logic        valid;         
    logic        wen;           
    logic        byte_not_word; 
    logic [31:0] addr;          
    logic [31:0] write_data;   
    logic           yumi;    // in response to data memory
}
mem_in_s;
*/
// Data memory input structure
typedef struct packed
{
    logic        valid;         
    logic        wen;           
    logic [3:0]  mask;
    logic [31:0] addr;          
    logic [31:0] write_data;   
    logic           yumi;    // in response to data memory
}
mem_in_s;

// Data memory output structure
typedef struct packed
{
    logic        valid;     
    logic [31:0] read_data; 
    logic        yumi;      // in response to core
}
mem_out_s;

// Debug signal structures
typedef struct packed
{
    logic [imem_addr_width_gp-1:0]  PC_r_f;           // Program counter
    logic [RV32_instr_width_gp-1:0] instruction_i_f;  // Instruction
    logic [1:0]                     state_r_f;        // Core state
    //logic [mask_length_gp-1:0]      barrier_mask_r_f; // Barrier mask
    //logic [mask_length_gp-1:0]      barrier_r_f;      // Barrier
}
debug_s;

/*
// Decode control signals structures
typedef struct packed
{
    logic op_writes_rf; // Op writes to the register file
    logic is_load_op;   // Op loads data from memory
    logic is_store_op;  // Op stores data to memory
    logic is_mem_op;    // Op modifies data memory
    logic is_byte_op;   // Op specifies byte sized data
    logic is_branch_op; // Op is a branch operation
    logic is_jump_op;   // Op is a jump operation
    logic is_bar_op;    // Op is a barrier operation
    logic is_netw_op;   // Op is a network operation
    logic op_reads_crf; // Op reads from constant register file
    logic op_reads_rf1; // OP reads from first port of register file
    logic op_reads_rf2; // OP reads from first port of register file
}
decode_s;
*/
// Decode control signals structures
typedef struct packed
{
    logic op_writes_rf; // Op writes to the register file
    logic is_load_op;   // Op loads data from memory
    logic is_uload_op;  // Op loads unsigned byte or hex values
    logic is_store_op;  // Op stores data to memory
    logic is_mem_op;    // Op modifies data memory
    logic is_byte_op;   // Op specifies byte sized data
    logic is_hex_op;    // Op specifies hex sized data
    logic is_branch_op; // Op is a branch operation
    logic is_jump_op;   // Op is a jump operation
    logic op_reads_rf1; // OP reads from first port of register file
    logic op_reads_rf2; // OP reads from first port of register file
    logic op_is_auipc;
}
decode_s;

/*
// Instruction decode stage signals
typedef struct packed
{
    logic [imem_addr_width_gp-1:0] pc_plus1;     // PC + 1
    logic [imem_addr_width_gp-1:0] pc_jump_addr; // Jump taget PC
    logic [operand_size_gp-1:0]    long_imm;     // Load global offset
    instruction_s                  instruction;  // Instruction being executed
    decode_s                       decode;       // Decode signals
}
id_signals_s;
*/
// Instruction decode stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;     // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pc_jump_addr; // Jump taget PC
    instruction_s                      instruction;  // Instruction being executed
    decode_s                           decode;       // Decode signals
}
id_signals_s;

/*
// Execute stage signals
typedef struct packed
{
    logic [imem_addr_width_gp-1:0] pc_plus1;     // PC + 1
    logic [imem_addr_width_gp-1:0] pc_jump_addr; // Jump taget PC
    logic [operand_size_gp-1:0]    long_imm;     // Load global offset
    instruction_s                  instruction;  // Instruction being executed
    decode_s                       decode;       // Decode signals
    logic [31:0]                   rs_val;       // RF output data from RS address
    logic [31:0]                   rd_val;       // RF output data from RD address
}
exe_signals_s;
*/
// Execute stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;     // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pc_jump_addr; // Jump taget PC
    instruction_s                      instruction;  // Instruction being executed
    decode_s                           decode;       // Decode signals
    logic [RV32_reg_data_width_gp-1:0] rs1_val;      // RF output data from RS1 address
    logic [RV32_reg_data_width_gp-1:0] rs2_val;      // RF output data from RS2 address
}
exe_signals_s;

/*
// Memory stage signals
typedef struct packed
{
    logic [imem_addr_width_gp-1:0] pc_plus1;   // PC + 1
    logic [rd_size_gp-1:0]         rd_addr;    // Destination address
    decode_s                       decode;     // Decode signals
    logic [31:0]                   alu_result; // ALU ouptut data
}
mem_signals_s;
*/
// Memory stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;   // PC + 4
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;    // Destination address
    decode_s                           decode;     // Decode signals
    logic [RV32_reg_data_width_gp-1:0] alu_result; // ALU ouptut data
}
mem_signals_s;

/*
// RF write back stage signals
typedef struct packed
{
    logic                  op_writes_rf; // Op writes to the register file
    logic [rd_size_gp-1:0] rd_addr;      // Register file write address
    logic [31:0]           rf_data;      // Register file write data
}
wb_signals_s;
*/
// RF write back stage signals
typedef struct packed
{
    logic                              op_writes_rf; // Op writes to the register file
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;      // Register file write address
    logic [RV32_reg_data_width_gp-1:0] rf_data;      // Register file write data
}
wb_signals_s;

`endif
