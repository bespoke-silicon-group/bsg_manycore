/**
 *    definitions.vh
 *
 */

`ifndef DEFINITIONS_VH
`define DEFINITIONS_VH

`include "parameters.vh"

/**
 *  This file defines the structs and macros
 *  used through out the vanilla core.
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
  logic [RV32_opcode_width_gp-1:0]   op;
} instruction_s;

`define declare_icache_format_s(tag_width_p) \
  typedef struct packed { \
    logic lower_cout; \
    logic lower_sign; \
    logic [tag_width_p-1:0] tag; \
    instruction_s instr; \
  } icache_format_s;

`define icache_format_width(tag_width_p) \
   (1+1+tag_width_p+$bits(instruction_s))


typedef struct packed {
  logic        icache_fetch;
  logic        is_unsigned_op;
  logic        is_byte_op;
  logic        is_hex_op;
  logic [1:0]  part_sel;
  logic [4:0]  reg_id;
  logic        is_float_wb;
} load_info_s;


typedef union packed {
  logic [31:0] write_data; // stores send store data
  struct packed {          // loads send reg_id to be loaded
    logic [19:0] rsvd;
    load_info_s load_info;
  } read_info; 
} mem_payload_u;

// Data memory input structure
typedef struct packed
{
    logic          wen;
    logic          swap_aq;
    logic          swap_rl;
    logic [3:0]    mask;
    logic [31:0]   addr;
    mem_payload_u  payload;
} mem_in_s;

// Data memory output structure
typedef struct packed
{
    logic        buf_full;
    logic [31:0] read_data;
    load_info_s  load_info;
} mem_out_s;


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
    logic op_reads_rf2;     // OP reads from second port of register file
    logic op_is_auipc;

    //for M extension;
    logic is_md_instr;      // indicates is md insruciton

    //for FENCE instruction
    logic is_fence_op;
    logic is_fence_i_op;

    //for load reservation and load reservation acquire
    logic op_is_load_reservation;
    logic op_is_lr_acq;

    //for atomic swap
    logic op_is_swap_aq;
    logic op_is_swap_rl;

    //for F extension
    logic op_reads_fp_rf1;  // reads rf1 of FP regfile
    logic op_reads_fp_rf2;  // reads rf1 of FP regfile
    logic is_fp_wb;         // writes back to FP regfile
    logic is_fp_instr;      // goes into FP pipeline
    logic is_signed_int;  // f2i, i2f with signed?

} decode_s;

// Instruction decode stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;          // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pred_or_jump_addr; // Jump target PC
    instruction_s                      instruction;       // Instruction being executed
    decode_s                           decode;            // Decode signals
    logic                              icache_miss;
} id_signals_s;

// Execute stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;          // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pred_or_jump_addr; // Jump target PC
    instruction_s                      instruction;       // Instruction being executed
    decode_s                           decode;            // Decode signals
    logic [RV32_reg_data_width_gp-1:0] rs1_val;           // RF output data from RS1 address
    logic [RV32_reg_data_width_gp-1:0] rs2_val;           // RF output data from RS2 address

    logic [RV32_reg_data_width_gp-1:0] mem_addr_op2;      // the second operands to compute
                                                          // memory address

    logic                              rs1_in_mem;        // pre-computed forwarding signal
    logic                              rs1_in_wb ;        // pre-computed forwarding signal
    logic                              rs2_in_mem;        // pre-computed forwarding signal
    logic                              rs2_in_wb ;        // pre-computed forwarding signal
    logic                              icache_miss;
} exe_signals_s;

// Memory stage signals
typedef struct packed
{
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;       // Destination address
    decode_s                           decode;        // Decode signals
    logic [RV32_reg_data_width_gp-1:0] exe_result;    // Execution result
    logic [RV32_reg_data_width_gp-1:0] mem_addr_send; //the address sent to memory
    logic                              remote_load;
    logic                              icache_miss;
} mem_signals_s;

// RF write back stage signals
typedef struct packed
{
    logic                              op_writes_rf; // Op writes to the register file
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;      // Register file write address
    logic [RV32_reg_data_width_gp-1:0] rf_data;      // Register file write data
    logic                              icache_miss;
    logic [RV32_reg_data_width_gp-1:0] icache_miss_pc;
} wb_signals_s;

`endif
