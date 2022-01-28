/**
 *  bsg_vanilla_pkg.v
 *  
 *  This file defines the structs and macros
 *  used throughout the vanilla core.
 *
 */


package bsg_vanilla_pkg;

import bsg_manycore_pkg::*;

// vanilla_core global parameters
localparam RV32_reg_data_width_gp = 32;
localparam RV32_instr_width_gp    = 32;
localparam RV32_reg_els_gp        = 32;
localparam RV32_reg_addr_width_gp = 5;
localparam RV32_opcode_width_gp   = 7;
localparam RV32_funct3_width_gp   = 3;
localparam RV32_funct7_width_gp   = 7;
localparam RV32_Iimm_width_gp     = 12;
localparam RV32_Simm_width_gp     = 12;
localparam RV32_Bimm_width_gp     = 12;
localparam RV32_Uimm_width_gp     = 20;
localparam RV32_Jimm_width_gp     = 20;

localparam fpu_recoded_exp_width_gp    = 8;
localparam fpu_recoded_sig_width_gp    = 24;
localparam fpu_recoded_data_width_gp   = (1+fpu_recoded_exp_width_gp+fpu_recoded_sig_width_gp);

// Maximum EPA width for vanilla core (word addr)
localparam epa_word_addr_width_gp=16;


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

// remote request from vanilla core
//
typedef enum logic [1:0] {
  e_vanilla_amoswap
  , e_vanilla_amoor
  , e_vanilla_amoadd
} bsg_vanilla_amo_type_e;

typedef struct packed
{
  logic write_not_read;
  logic is_amo_op;
  bsg_vanilla_amo_type_e amo_type;
  logic [3:0] mask;
  bsg_manycore_load_info_s load_info;
  logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;
  logic [31:0] data;
  logic [31:0] addr;
} remote_req_s;

// remote load response from network
//
typedef struct packed
{
  logic float_wb;
  logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;
  logic is_unsigned_op;
  logic is_byte_op;
  logic is_hex_op;
  logic [1:0] part_sel;
  logic [31:0] data;
} remote_load_resp_s;


// Decode control signals structures
typedef enum logic [1:0] {
  eDIV
  ,eDIVU
  ,eREM
  ,eREMU
} idiv_op_e;


typedef struct packed {
  // int regfile
  logic read_rs1;
  logic read_rs2;
  logic write_rd;

  // Load & Store
  logic is_load_op;       // Op loads data from memory
  logic is_store_op;      // Op stores data to memory
  logic is_byte_op;       // Op is byte load/store
  logic is_hex_op;        // Op is hex load/store
  logic is_load_unsigned; // Op is unsigned load

  // Branch & Jump
  logic is_branch_op;
  logic is_jal_op;
  logic is_jalr_op;

  // MUL DIV
  logic is_imul_op;
  logic is_idiv_op;
  idiv_op_e idiv_op;

  // FENCE
  logic is_fence_op;
  logic is_barsend_op;
  logic is_barrecv_op;

  // Load Reserve
  logic is_lr_aq_op;
  logic is_lr_op;

  // Atomic
  logic is_amo_op;
  logic is_amo_aq;
  logic is_amo_rl;
  bsg_vanilla_amo_type_e amo_type;

  // FPU
  logic is_fp_op;           // goes into FP_EXE
  logic read_frs1;          // reads rs1 of FP regfile
  logic read_frs2;          // reads rs2 of FP regfile
  logic read_frs3;          // reads rs3 of FP regfile
  logic write_frd;    // writes back to FP regfile

  // CSR
  logic is_csr_op;

  // MRET
  logic is_mret_op;

  // This signal is for debugging only.
  // It shouldn't be used to synthesize any actual circuits.
  logic unsupported;
  
} decode_s;


typedef enum logic [3:0] {
  eFADD
  ,eFSUB
  ,eFMUL
  ,eFSGNJ
  ,eFSGNJN
  ,eFSGNJX
  ,eFMIN
  ,eFMAX
  ,eFCVT_S_W
  ,eFCVT_S_WU
  ,eFMV_W_X
  ,eFMADD
  ,eFMSUB
  ,eFNMSUB
  ,eFNMADD
} fpu_float_op_e;

typedef enum logic [2:0] {
  eFEQ
  ,eFLE
  ,eFLT
  ,eFCVT_W_S
  ,eFCVT_WU_S
  ,eFCLASS
  ,eFMV_X_W
} fpu_int_op_e;

typedef struct packed {
  logic is_fpu_float_op;
  logic is_fpu_int_op;
  logic is_fdiv_op;
  logic is_fsqrt_op;
  fpu_float_op_e fpu_float_op;
  fpu_int_op_e   fpu_int_op;
} fp_decode_s;

// FPU ROUNDING MODE
typedef enum logic [2:0] {
  eRNE = 3'b000,    // Round to Nearest, ties to Even
  eRTZ = 3'b001,    // Round towards Zero
  eRDN = 3'b010,    // Round Down (towards -oo)
  eRUP = 3'b011,    // Round Up (towards +oo)
  eRMM = 3'b100,    // Round to Nearest, ties to Max magnitude
  eDYN = 3'b111    // dynamic rounding mode
} frm_e;


// FPU EXCEPTION FLAGS
typedef struct packed {
  logic invalid;
  logic div_zero;
  logic overflow;
  logic underflow;
  logic inexact;
} fflags_s;


// FPU FCSR
typedef struct packed {
  frm_e frm;
  fflags_s fflag;
} fcsr_s;


// Instruction decode stage signals
typedef struct packed
{
    logic [RV32_reg_data_width_gp-1:0] pc_plus4;          // PC + 4
    logic [RV32_reg_data_width_gp-1:0] pred_or_jump_addr; // Jump target PC
    instruction_s                      instruction;       // Instruction being executed
    decode_s                           decode;            // Decode signals
    fp_decode_s                        fp_decode;
    logic                              icache_miss;
    logic                              valid;             // valid instruction in ID
    logic                              branch_predicted_taken;
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
                                                          // CSR instructions use this register for loading CSR vals
    logic [RV32_Iimm_width_gp-1:0]     mem_addr_op2;      // the second operands to compute
                                                          // memory address
    logic                              icache_miss;
    logic                              valid;             // valid instruction in EXE
    logic                              branch_predicted_taken;
} exe_signals_s;


// Memory stage signals
typedef struct packed {
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;
    logic write_rd;
    logic write_frd;
    logic is_byte_op;
    logic is_hex_op;
    logic is_load_unsigned;
    logic local_load;
    logic [1:0] byte_sel;
    logic icache_miss;
} mem_ctrl_signals_s;

typedef struct packed {
    logic [RV32_reg_data_width_gp-1:0] exe_result;
} mem_data_signals_s;

// RF write back stage signals
typedef struct packed {
    logic                              write_rd;
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;
    logic                              icache_miss;
    logic clear_sb;
} wb_ctrl_signals_s;

typedef struct packed {
    logic [RV32_reg_data_width_gp-1:0] rf_data;
} wb_data_signals_s;

// FP Execute stage signals
typedef struct packed {
  logic [RV32_reg_addr_width_gp-1:0] rd;
  fp_decode_s fp_decode;
  frm_e rm;
} fp_exe_ctrl_signals_s;

typedef struct packed {
  logic [fpu_recoded_data_width_gp-1:0] rs1_val;
  logic [fpu_recoded_data_width_gp-1:0] rs2_val;
  logic [fpu_recoded_data_width_gp-1:0] rs3_val;
} fp_exe_data_signals_s;

// FLW write back stage signals
typedef struct packed {
    logic valid;
    logic [RV32_reg_addr_width_gp-1:0] rd_addr;
} flw_wb_ctrl_signals_s;

typedef struct packed {
    logic [RV32_reg_data_width_gp-1:0] rf_data;
} flw_wb_data_signals_s;


// MACHINE CSR structs, constants
// mstatus
typedef struct packed {
  logic mpie;   //  machine previous interrupt enabler (using bit-7)
  logic mie;    //  machine interrupt enable (using bit-3)
} csr_mstatus_s;

// machine interrupt pending/enable vector
typedef struct packed {
  logic trace;  // bit-17
  logic remote; // bit-16
} csr_interrupt_vector_s;

endpackage
