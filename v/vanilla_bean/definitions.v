`ifndef _definitions_v_
`define _definitions_v_

`include "parameters.v"

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
typedef enum logic [1:0] {
    IDLE = 2'b00,
    RUN  = 2'b01,
    ERR  = 2'b11
} state_e;

// Network operation enum
typedef enum logic [1:0]
{
    NULL  = 2'b00, // Nothing
    INSTR = 2'b01, // Instruction for instruction memory
    REG   = 2'b10, // Value for a register
    PC    = 2'b11  // Change PC
} net_op_e;

// RV32 Instruction structure
// Ideally represents a R-type instruction; these fields if
// present in other types of instructions, appear at same positions
typedef struct packed {
  logic [RV32_funct7_width_gp-1:0]   funct7;
  logic [RV32_reg_addr_width_gp-1:0] rs2;
  logic [RV32_reg_addr_width_gp-1:0] rs1;
  logic [RV32_funct3_width_gp-1:0]   funct3;
  logic [RV32_reg_addr_width_gp-1:0] rd;
  logic [RV32_opcode_width_gp-1:0]   op;
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
    net_op_e     net_op;      // 21..20 // Operation of the network packet
                                        // for v_cores
    logic [3:0]  mask;        // 19..16 // byte mask for received network
                                        // data
    logic [1:0]  reserved;    // 15..14 // reserved bits, later we may steal
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

// Data memory input structure
typedef struct packed
{
    logic        valid;
    logic        wen;
    logic        swap_aq;
    logic        swap_rl;
    logic [3:0]  mask;
    logic [31:0] addr;
    logic [31:0] write_data;
    logic        yumi;    // in response to data memory
} mem_in_s;

// Data memory output structure
typedef struct packed
{
    logic        valid;
    logic [31:0] read_data;
    logic        yumi;      // in response to core
} mem_out_s;

// Debug signal structures
typedef struct packed
{
    logic [15:0]                    PC_r;           // Program counter
    instruction_s                   instruction_i;
    logic [1:0]                     state_r;        // Core state
    logic                           squashed;
} debug_s;

// Decode control signals structures
typedef struct packed
{
    logic op_writes_rf;     // Op writes to the register file
    logic is_load_op;       // Op loads data from memory
    logic is_store_op;      // Op stores data to memory
    logic is_mem_op;        // Op modifies data memory
    logic is_byte_op;       // Op is byte load/store
    logic is_hex_op;        // Op is hex load/store
    logic is_load_unsigned; // Op is unsigned load
    logic is_branch_op;     // Op is a branch operation
    logic is_jump_op;       // Op is a jump operation
    logic op_reads_rf1;     // OP reads from first port of register file
    logic op_reads_rf2;     // OP reads from first port of register file
    logic op_is_auipc;

    //for M extension;
    logic is_md_instr;    // indicates is md insruciton

    //for FENCE instruction
    logic is_fence_op;
    logic is_fence_i_op;
    //for load reservation and load reservation acquire
    logic op_is_load_reservation;
    logic op_is_lr_acq          ;
    //for atomic swap
    logic op_is_swap_aq         ;
    logic op_is_swap_rl         ;
} decode_s;

// Instruction decode stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;     // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pc_jump_addr; // Jump taget PC
    instruction_s                      instruction;  // Instruction being executed
    decode_s                           decode;       // Decode signals

} id_signals_s;

// Execute stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;     // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pc_jump_addr; // Jump taget PC
    instruction_s                      instruction;  // Instruction being executed
    decode_s                           decode;       // Decode signals
    logic [RV32_reg_data_width_gp-1:0] rs1_val;      // RF output data from RS1 address
    logic [RV32_reg_data_width_gp-1:0] rs2_val;      // RF output data from RS2 address

    logic [RV32_reg_data_width_gp-1:0] mem_addr_op2; // the second operands to compute
                                                     // memory address

    logic                              rs1_in_mem;   // pre-computed forwarding signal
    logic                              rs1_in_wb ;   // pre-computed forwarding signal
    logic                              rs2_in_mem;   // pre-computed forwarding signal
    logic                              rs2_in_wb ;   // pre-computed forwarding signal
} exe_signals_s;

// Memory stage signals
typedef struct packed
{
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;    // Destination address
    decode_s                           decode;     // Decode signals
    logic [RV32_reg_data_width_gp-1:0] alu_result; // ALU ouptut data
    logic [RV32_reg_data_width_gp-1:0] mem_addr_send; //the address sent to memory
} mem_signals_s;

// RF write back stage signals
typedef struct packed
{
    logic                              op_writes_rf; // Op writes to the register file
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;      // Register file write address
    logic [RV32_reg_data_width_gp-1:0] rf_data;      // Register file write data
} wb_signals_s;

`endif
