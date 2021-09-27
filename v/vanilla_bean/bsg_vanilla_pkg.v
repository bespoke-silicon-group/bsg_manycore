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

`define declare_icache_format_s(tag_width_mp) \
  typedef struct packed { \
    logic lower_cout; \
    logic lower_sign; \
    logic [tag_width_mp-1:0] tag; \
    instruction_s instr; \
  } icache_format_s

`define icache_format_width(tag_width_mp) \
   (1+1+tag_width_mp+$bits(instruction_s))


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


// FPU recoded Constants
`define FPU_RECODED_ONE   33'h080000000
`define FPU_RECODED_ZERO  33'h0
`define FPU_RECODED_CANONICAL_NAN 33'h0e0400000


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
    logic [RV32_reg_data_width_gp-1:0] mem_addr_op2;      // the second operands to compute
                                                          // memory address
    logic                              icache_miss;
    logic                              valid;             // valid instruction in EXE
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
    logic [RV32_reg_data_width_gp-1:0] mem_addr_sent;
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
    logic [RV32_reg_data_width_gp-1:0] icache_miss_pc;
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
`define RV32_MSTATUS_MIE_BIT_IDX  3
`define RV32_MSTATUS_MPIE_BIT_IDX 7

// machine interrupt pending/enable vector
typedef struct packed {
  logic trace;  // bit-17
  logic remote; // bit-16
} csr_interrupt_vector_s;


`define REMOTE_INTERRUPT_JUMP_ADDR  0   // remote interrupt jump addr (word addr)
`define TRACE_INTERRUPT_JUMP_ADDR   1   // trace interrupt jump addr (word addr)




//                            //
//    RISCV                   //
//    Instruction Decoding    //
//                            //
//                            //


// RV32 Opcodes
`define RV32_LOAD     7'b0000011
`define RV32_STORE    7'b0100011

// we have branch instructions ignore the low bit so that we can place the prediction bit there.
// RISC-V by default has the low bits set to 11 in the icache, so we can use those creatively.
// note this relies on all code using ==? and casez.
`define RV32_BRANCH   7'b110001?

`define RV32_JALR_OP    7'b1100111
`define RV32_MISC_MEM   7'b0001111
`define RV32_AMO_OP     7'b0101111
`define RV32_JAL_OP     7'b1101111
`define RV32_OP_IMM     7'b0010011
`define RV32_OP         7'b0110011
`define RV32_SYSTEM     7'b1110011
`define RV32_AUIPC_OP   7'b0010111
`define RV32_LUI_OP     7'b0110111


// Some useful RV32 instruction macros
`define RV32_Rtype(op, funct3, funct7) {``funct7``, {5{1'b?}},  {5{1'b?}},``funct3``, {5{1'b?}},``op``}
`define RV32_Itype(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV32_Stype(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV32_Utype(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// RV32 Immediate sign extension macros
`define RV32_signext_Iimm(instr) {{21{``instr``[31]}},``instr``[30:20]}
`define RV32_signext_Simm(instr) {{21{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define RV32_signext_Bimm(instr) {{20{``instr``[31]}},``instr``[7],``instr``[30:25],``instr``[11:8], {1'b0}}
`define RV32_signext_Uimm(instr) {``instr``[31:12], {12{1'b0}}}
`define RV32_signext_Jimm(instr) {{12{``instr``[31]}},``instr``[19:12],``instr``[20],``instr``[30:21], {1'b0}}

// RV32 12bit Immediate injection/extraction, replace the Imm content with specified value
// for injection, input immediate value index starting from 1
// * store the sign bit (bit 31) of branches into bit of the stored instruction for use as prediction bit

`define RV32_Bimm_12inject1(instr,value) {``value``[12], ``value``[10:5], ``instr``[24:12],\
                                          ``value``[4:1],``value``[11],``instr``[6:1],``instr``[31]}
`define RV32_Jimm_20inject1(instr,value) {``value``[20], ``value``[10:1], ``value``[11],``value``[19:12], ``instr``[11:0]}

// Both JAL and BRANCH use 2-byte address, we need to pad 1'b0 at MSB to get
// the real byte address
`define RV32_Bimm_13extract(instr) {``instr``[31], ``instr``[7], ``instr``[30:25], ``instr``[11:8], 1'b0}
`define RV32_Jimm_21extract(instr) {``instr``[31], ``instr``[19:12],``instr``[20],``instr``[30:21], 1'b0}


// RV32I Instruction encodings
// We have to delete the white space in macro definition,
// otherwise Design Compiler would issue warings.
`define RV32_LUI       `RV32_Utype(`RV32_LUI_OP)
`define RV32_AUIPC     `RV32_Utype(`RV32_AUIPC_OP)
`define RV32_JAL       `RV32_Utype(`RV32_JAL_OP)
`define RV32_JALR      `RV32_Itype(`RV32_JALR_OP, 3'b000)
`define RV32_BEQ       `RV32_Stype(`RV32_BRANCH, 3'b000)
`define RV32_BNE       `RV32_Stype(`RV32_BRANCH, 3'b001)
`define RV32_BLT       `RV32_Stype(`RV32_BRANCH, 3'b100)
`define RV32_BGE       `RV32_Stype(`RV32_BRANCH, 3'b101)
`define RV32_BLTU      `RV32_Stype(`RV32_BRANCH, 3'b110)
`define RV32_BGEU      `RV32_Stype(`RV32_BRANCH, 3'b111)
`define RV32_LB        `RV32_Itype(`RV32_LOAD, 3'b000)
`define RV32_LH        `RV32_Itype(`RV32_LOAD, 3'b001)
`define RV32_LW        `RV32_Itype(`RV32_LOAD, 3'b010)
`define RV32_LBU       `RV32_Itype(`RV32_LOAD, 3'b100)
`define RV32_LHU       `RV32_Itype(`RV32_LOAD, 3'b101)
`define RV32_SB        `RV32_Stype(`RV32_STORE, 3'b000)
`define RV32_SH        `RV32_Stype(`RV32_STORE, 3'b001)
`define RV32_SW        `RV32_Stype(`RV32_STORE, 3'b010)
`define RV32_ADDI      `RV32_Itype(`RV32_OP_IMM,3'b000)
`define RV32_SLTI      `RV32_Itype(`RV32_OP_IMM, 3'b010)
`define RV32_SLTIU     `RV32_Itype(`RV32_OP_IMM, 3'b011)
`define RV32_XORI      `RV32_Itype(`RV32_OP_IMM, 3'b100)
`define RV32_ORI       `RV32_Itype(`RV32_OP_IMM, 3'b110)
`define RV32_ANDI      `RV32_Itype(`RV32_OP_IMM, 3'b111)
`define RV32_SLLI      `RV32_Rtype(`RV32_OP_IMM, 3'b001, 7'b0000000)
`define RV32_SRLI      `RV32_Rtype(`RV32_OP_IMM, 3'b101, 7'b0000000)
`define RV32_SRAI      `RV32_Rtype(`RV32_OP_IMM, 3'b101, 7'b0100000)
`define RV32_ADD       `RV32_Rtype(`RV32_OP,3'b000,7'b0000000)
`define RV32_SUB       `RV32_Rtype(`RV32_OP, 3'b000, 7'b0100000)
`define RV32_SLL       `RV32_Rtype(`RV32_OP, 3'b001, 7'b0000000)
`define RV32_SLT       `RV32_Rtype(`RV32_OP, 3'b010, 7'b0000000)
`define RV32_SLTU      `RV32_Rtype(`RV32_OP, 3'b011, 7'b0000000)
`define RV32_XOR       `RV32_Rtype(`RV32_OP, 3'b100, 7'b0000000)
`define RV32_SRL       `RV32_Rtype(`RV32_OP, 3'b101, 7'b0000000)
`define RV32_SRA       `RV32_Rtype(`RV32_OP, 3'b101, 7'b0100000)
`define RV32_OR        `RV32_Rtype(`RV32_OP, 3'b110, 7'b0000000)
`define RV32_AND       `RV32_Rtype(`RV32_OP, 3'b111, 7'b0000000)

// FENCE defines
`define RV32_FENCE_FUN3   3'b000
`define RV32_FENCE   {4'b0000,4'b????,4'b????,5'b00000,`RV32_FENCE_FUN3,5'b00000,`RV32_MISC_MEM}

//TRIGGER SAIF DUMP defines
`define SAIF_TRIGGER_START {12'b000000000001,5'b00000,3'b000,5'b00000,`RV32_OP_IMM}
`define SAIF_TRIGGER_END {12'b000000000010,5'b00000,3'b000,5'b00000,`RV32_OP_IMM}

// CSR encoding
`define RV32_CSRRW_FUN3  3'b001
`define RV32_CSRRS_FUN3  3'b010
`define RV32_CSRRC_FUN3  3'b011
`define RV32_CSRRWI_FUN3 3'b101
`define RV32_CSRRSI_FUN3 3'b110
`define RV32_CSRRCI_FUN3 3'b111

`define RV32_CSRRW      `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRW_FUN3)
`define RV32_CSRRS      `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRS_FUN3)
`define RV32_CSRRC      `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRC_FUN3)
`define RV32_CSRRWI     `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRWI_FUN3)
`define RV32_CSRRSI     `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRSI_FUN3)
`define RV32_CSRRCI     `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRCI_FUN3)

// fcsr CSR addr
`define RV32_CSR_FFLAGS_ADDR  12'h001
`define RV32_CSR_FRM_ADDR     12'h002  
`define RV32_CSR_FCSR_ADDR    12'h003
// machine CSR addr
`define RV32_CSR_MSTATUS_ADDR   12'h300
`define RV32_CSR_MTVEC_ADDR     12'h305
`define RV32_CSR_MIE_ADDR       12'h304
`define RV32_CSR_MIP_ADDR       12'h344
`define RV32_CSR_MEPC_ADDR      12'h341
`define RV32_CSR_CFG_POD_ADDR   12'h360				    

// machine custom CSR addr
`define RV32_CSR_CREDIT_LIMIT_ADDR 12'hfc0

// mret
// used for returning from the interrupt
`define RV32_MRET     {7'b0011000, 5'b00010, 5'b00000, 3'b000, 5'b00000, `RV32_SYSTEM}

// RV32M Instruction Encodings
`define MD_MUL_FUN3       3'b000
`define MD_MULH_FUN3      3'b001
`define MD_MULHSU_FUN3    3'b010
`define MD_MULHU_FUN3     3'b011
`define MD_DIV_FUN3       3'b100
`define MD_DIVU_FUN3      3'b101
`define MD_REM_FUN3       3'b110
`define MD_REMU_FUN3      3'b111
`define RV32_MUL       `RV32_Rtype(`RV32_OP, `MD_MUL_FUN3   , 7'b0000001)
`define RV32_MULH      `RV32_Rtype(`RV32_OP, `MD_MULH_FUN3  , 7'b0000001)
`define RV32_MULHSU    `RV32_Rtype(`RV32_OP, `MD_MULHSU_FUN3, 7'b0000001)
`define RV32_MULHU     `RV32_Rtype(`RV32_OP, `MD_MULHU_FUN3 , 7'b0000001)
`define RV32_DIV       `RV32_Rtype(`RV32_OP, `MD_DIV_FUN3   , 7'b0000001)
`define RV32_DIVU      `RV32_Rtype(`RV32_OP, `MD_DIVU_FUN3  , 7'b0000001)
`define RV32_REM       `RV32_Rtype(`RV32_OP, `MD_REM_FUN3   , 7'b0000001)
`define RV32_REMU      `RV32_Rtype(`RV32_OP, `MD_REMU_FUN3  , 7'b0000001)

// RV32A Instruction Encodings
`define RV32_LR_W       {5'b00010,2'b00,5'b00000,5'b?????,3'b010,5'b?????,`RV32_AMO_OP}
`define RV32_LR_W_AQ    {5'b00010,2'b10,5'b00000,5'b?????,3'b010,5'b?????,`RV32_AMO_OP}
`define RV32_AMOSWAP_W  {5'b00001,2'b??,5'b?????,5'b?????,3'b010,5'b?????,`RV32_AMO_OP}
`define RV32_AMOOR_W    {5'b01000,2'b??,5'b?????,5'b?????,3'b010,5'b?????,`RV32_AMO_OP}
`define RV32_AMOADD_W   {5'b00000,2'b??,5'b?????,5'b?????,3'b010,5'b?????,`RV32_AMO_OP}

// RV32F Instruction Encodings
`define RV32_OP_FP            7'b1010011
`define RV32_LOAD_FP          7'b0000111
`define RV32_STORE_FP         7'b0100111

`define RV32_FCMP_S_FUN7      7'b1010000
`define RV32_FCLASS_S_FUN7    7'b1110000
`define RV32_FCVT_S_F2I_FUN7  7'b1100000
`define RV32_FCVT_S_I2F_FUN7  7'b1101000
`define RV32_FMV_W_X_FUN7     7'b1111000
`define RV32_FMV_X_W_FUN7     7'b1110000

`define RV32_FADD_S `RV32_Rtype(`RV32_OP_FP, 3'b???, 7'b0000000)
`define RV32_FSUB_S `RV32_Rtype(`RV32_OP_FP, 3'b???, 7'b0000100)
`define RV32_FMUL_S `RV32_Rtype(`RV32_OP_FP, 3'b???, 7'b0001000)

`define RV32_FSGNJ_S  `RV32_Rtype(`RV32_OP_FP, 3'b000, 7'b0010000)
`define RV32_FSGNJN_S `RV32_Rtype(`RV32_OP_FP, 3'b001, 7'b0010000)
`define RV32_FSGNJX_S `RV32_Rtype(`RV32_OP_FP, 3'b010, 7'b0010000)

`define RV32_FMIN_S `RV32_Rtype(`RV32_OP_FP, 3'b000, 7'b0010100)
`define RV32_FMAX_S `RV32_Rtype(`RV32_OP_FP, 3'b001, 7'b0010100)

`define RV32_FEQ_S `RV32_Rtype(`RV32_OP_FP, 3'b010, `RV32_FCMP_S_FUN7)
`define RV32_FLT_S `RV32_Rtype(`RV32_OP_FP, 3'b001, `RV32_FCMP_S_FUN7)
`define RV32_FLE_S `RV32_Rtype(`RV32_OP_FP, 3'b000, `RV32_FCMP_S_FUN7)

`define RV32_FCLASS_S {`RV32_FCLASS_S_FUN7, 5'b00000, 5'b?????, 3'b001, 5'b?????, `RV32_OP_FP}

// i2f
`define RV32_FCVT_S_W  {`RV32_FCVT_S_I2F_FUN7, 5'b00000, 5'b?????, 3'b???, 5'b?????, `RV32_OP_FP}
`define RV32_FCVT_S_WU {`RV32_FCVT_S_I2F_FUN7, 5'b00001, 5'b?????, 3'b???, 5'b?????, `RV32_OP_FP}

// f2i
`define RV32_FCVT_W_S  {`RV32_FCVT_S_F2I_FUN7, 5'b00000, 5'b?????, 3'b???, 5'b?????, `RV32_OP_FP}
`define RV32_FCVT_WU_S {`RV32_FCVT_S_F2I_FUN7, 5'b00001, 5'b?????, 3'b???, 5'b?????, `RV32_OP_FP}

// move (i->f) 
`define RV32_FMV_W_X {`RV32_FMV_W_X_FUN7, 5'b0000, 5'b?????, 3'b000, 5'b?????, `RV32_OP_FP}

// move (f->i)
`define RV32_FMV_X_W {`RV32_FMV_X_W_FUN7, 5'b0000, 5'b?????, 3'b000, 5'b?????, `RV32_OP_FP}

`define RV32_FLW_S `RV32_Itype(`RV32_LOAD_FP, 3'b010)
`define RV32_FSW_S `RV32_Stype(`RV32_STORE_FP, 3'b010)

`define RV32_FMADD_S   {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b1000011}
`define RV32_FMSUB_S   {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b1000111}
`define RV32_FNMSUB_S  {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b1001011}
`define RV32_FNMADD_S  {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b1001111}

`define RV32_FDIV_S   `RV32_Rtype(`RV32_OP_FP, 3'b???, 7'b0001100)
`define RV32_FSQRT_S  {7'b0101100, 5'b00000, 5'b?????, 3'b???, 5'b?????, 7'b1010011}


endpackage
