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


// load info
//
typedef struct packed {
  logic        float_wb;
  logic        icache_fetch;
  logic        is_unsigned_op;
  logic        is_byte_op;
  logic        is_hex_op;
  logic [1:0]  part_sel;
  logic [4:0]  reg_id;
} load_info_s;

`define load_info_width (5+2+5)

typedef union packed {
  logic [31:0] write_data;
  struct packed {
    logic [19:0] reserved;
    load_info_s load_info;
  } read_info; 
} payload_u;

// remote request from vanilla core
//
typedef struct packed
{
  logic          write_not_read;
  logic          swap_aq;
  logic          swap_rl;
  logic [3:0]    mask;
  logic [31:0]   addr;
  payload_u      payload;
} remote_req_s;

// remote load response from network
//
typedef struct packed
{
  logic float_wb;
  logic [4:0] reg_id;
  logic is_unsigned_op;
  logic is_byte_op;
  logic is_hex_op;
  logic [1:0] part_sel;
  logic [31:0] data;
} remote_load_resp_s;


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
    logic is_md_op;      // indicates is md insruciton

    //for FENCE instruction
    logic is_fence_op;
    logic is_fence_i_op;

    //for load reservation and load reservation acquire
    logic op_is_lr_aq;
    logic op_is_lr;

    //for atomic swap
    logic op_is_swap_aq;
    logic op_is_swap_rl;

    //for F extension
    logic op_reads_fp_rf1;  // reads rf1 of FP regfile
    logic op_reads_fp_rf2;  // reads rf1 of FP regfile
    logic op_writes_fp_rf;      // writes back to FP regfile
    logic is_fp_float_op;    // goes into FP float pipeline
    logic is_fp_int_op;      // goes into FP int pipeline

} decode_s;

typedef struct packed {

  logic fadd_op;
  logic fsub_op;
  logic fmul_op;
  logic fsgnj_op;
  logic fsgnjn_op;
  logic fsgnjx_op;
  logic fmin_op;
  logic fmax_op;
  logic fcvt_s_w_op;
  logic fcvt_s_wu_op;
  logic fmv_w_x_op;

} fp_float_decode_s;

typedef struct packed {

  logic feq_op;
  logic fle_op;
  logic flt_op;
  logic fcvt_w_s_op;
  logic fcvt_wu_s_op;
  logic fclass_op;
  logic fmv_x_w_op;

} fp_int_decode_s;

// Instruction decode stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;          // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pred_or_jump_addr; // Jump target PC
    instruction_s                      instruction;       // Instruction being executed
    decode_s                           decode;            // Decode signals
    logic                              icache_miss;
    fp_int_decode_s                    fp_int_decode;
    fp_float_decode_s                  fp_float_decode; 
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
    fp_int_decode_s                    fp_int_decode;
} exe_signals_s;


// Memory stage signals
typedef struct packed
{
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;       // Destination address
    logic [RV32_reg_data_width_gp-1:0] exe_result;    // Execution result
    logic [RV32_reg_data_width_gp-1:0] mem_addr_sent; //the address sent to memory
    logic op_writes_rf;
    logic op_writes_fp_rf;
    logic is_byte_op;
    logic is_hex_op;
    logic is_load_unsigned;
    logic local_load;
    logic icache_miss;
    
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

// FP Execute stage signals
typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] rs1_val;
  logic [RV32_reg_data_width_gp-1:0] rs2_val;
  logic [RV32_reg_addr_width_gp-1:0] rd;
  fp_float_decode_s fp_float_decode;
  logic valid;
} fp_exe_signals_s;

// FP writeback stage signals
typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] wb_data;
  logic [RV32_reg_addr_width_gp-1:0] rd;
  logic valid;
} fp_wb_signals_s;



// DEBUG INTERFACE

typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic branch_or_jump;
  logic [RV32_instr_width_gp-1:0] btarget;
  logic is_local_load;
  logic is_local_store;
  logic [9:0] local_dmem_addr; // hard-coded for now...
  logic [RV32_reg_data_width_gp-1:0] local_store_data;
} exe_debug_s;

typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic branch_or_jump;
  logic [RV32_instr_width_gp-1:0] btarget;
  logic is_local_load;
  logic is_local_store;
  logic [9:0] local_dmem_addr;
  logic [RV32_reg_data_width_gp-1:0] local_store_data;
} mem_debug_s;

typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic branch_or_jump;
  logic [RV32_instr_width_gp-1:0] btarget;
  logic is_local_load;
  logic is_local_store;
  logic [9:0] local_dmem_addr;
  logic [RV32_reg_data_width_gp-1:0] local_load_data;
  logic [RV32_reg_data_width_gp-1:0] local_store_data;
} wb_debug_s;


typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic valid;
} fp_debug_s;


`endif
