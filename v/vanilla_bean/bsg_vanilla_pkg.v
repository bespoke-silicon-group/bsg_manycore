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
localparam epa_word_addr_width_gp = 16; // max EPA width on vanilla core. (word addr)


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
  } icache_format_s;

`define icache_format_width(tag_width_mp) \
   (1+1+tag_width_mp+$bits(instruction_s))


// remote request from vanilla core
//
typedef struct packed
{
  logic write_not_read;
  logic is_amo_op;
  bsg_manycore_amo_type_e amo_type;
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


typedef struct packed
{
    logic op_writes_rf;     // Op writes to the register file

    logic is_load_op;       // Op loads data from memory
    logic is_store_op;      // Op stores data to memory
    logic is_byte_op;       // Op is byte load/store
    logic is_hex_op;        // Op is hex load/store
    logic is_load_unsigned; // Op is unsigned load

    logic is_branch_op;     // Op is a branch operation
    logic is_jal_op;        // jal
    logic is_jalr_op;       // jalr

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
    logic is_amo_op;
    logic is_amo_aq;
    logic is_amo_rl;
    bsg_manycore_amo_type_e amo_type;
    

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



//                            //
//    RISCV                   //
//    Instruction Decoding    //
//                            //
//                            //




// RV32 Opcodes
`define RV32_LOAD     7'b0000011
`define RV32_STORE    7'b0100011
`define RV32_MADD     7'b1000011

// we have branch instructions ignore the low bit so that we can place the prediction bit there
// RISC-V by default has the low bits set to 11 in the icache, so we can use those creatively
// note this relies on all code using ==? and casez.

`define RV32_BRANCH   7'b110001?

`define RV32_MSUB     7'b1000111
`define RV32_JALR_OP  7'b1100111
`define RV32_CUSTOM_0 7'b0001011
`define RV32_CUSTOM_1 7'b0101011
`define RV32_NMSUB    7'b1001011
//                    7'b1101011 is reserved
`define RV32_MISC_MEM 7'b0001111
`define RV32_AMO      7'b0101111
`define RV32_NMADD    7'b1001111
`define RV32_JAL_OP   7'b1101111
`define RV32_OP_IMM   7'b0010011
`define RV32_OP       7'b0110011
`define RV32_SYSTEM   7'b1110011
`define RV32_AUIPC_OP 7'b0010111
`define RV32_LUI_OP   7'b0110111
//                    7'b1010111 is reserved
//                    7'b1110111 is reserved
//                    7'b0011011 is RV64-specific
//                    7'b0111011 is RV64-specific
`define RV32_CUSTOM_2 7'b1011011
`define RV32_CUSTOM_3 7'b1111011

`define RV32_CSRRW_FUN3 3'b001
`define RV32_CSRRS_FUN3 3'b010
`define RV32_CSRRC_FUN3 3'b011

`define RV32_CSRRWI_FUN3 3'b101
`define RV32_CSRRSI_FUN3 3'b110
`define RV32_CSRRCI_FUN3 3'b111

//MUL_DIV defines
`define MD_MUL_FUN3       3'b000
`define MD_MULH_FUN3      3'b001
`define MD_MULHSU_FUN3    3'b010
`define MD_MULHU_FUN3     3'b011
`define MD_DIV_FUN3       3'b100
`define MD_DIVU_FUN3      3'b101
`define MD_REM_FUN3       3'b110
`define MD_REMU_FUN3      3'b111

//FENCE defines
`define RV32_FENCE_FUN3   3'b000
`define RV32_FENCE_I_FUN3 3'b001


// Some useful RV32 instruction macros
`define RV32_Rtype(op, funct3, funct7) {``funct7``, {5{1'b?}},  {5{1'b?}},``funct3``, {5{1'b?}},``op``}
`define RV32_Itype(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV32_Stype(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define RV32_Utype(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// RV32IM Instruction encodings
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
`define RV32_MUL       `RV32_Rtype(`RV32_OP, `MD_MUL_FUN3   , 7'b0000001)
`define RV32_MULH      `RV32_Rtype(`RV32_OP, `MD_MULH_FUN3  , 7'b0000001)
`define RV32_MULHSU    `RV32_Rtype(`RV32_OP, `MD_MULHSU_FUN3, 7'b0000001)
`define RV32_MULHU     `RV32_Rtype(`RV32_OP, `MD_MULHU_FUN3 , 7'b0000001)
`define RV32_DIV       `RV32_Rtype(`RV32_OP, `MD_DIV_FUN3   , 7'b0000001)
`define RV32_DIVU      `RV32_Rtype(`RV32_OP, `MD_DIVU_FUN3  , 7'b0000001)
`define RV32_REM       `RV32_Rtype(`RV32_OP, `MD_REM_FUN3   , 7'b0000001)
`define RV32_REMU      `RV32_Rtype(`RV32_OP, `MD_REMU_FUN3  , 7'b0000001)
`define RV32_LR_W      `RV32_Rtype(`RV32_AMO, 3'b010, 7'b00010??)


`define RV32_CSRRW      `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRW_FUN3)
`define RV32_CSRRS      `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRS_FUN3)
`define RV32_CSRRC      `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRC_FUN3)

`define RV32_CSRRWI     `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRWI_FUN3)
`define RV32_CSRRSI     `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRSI_FUN3)
`define RV32_CSRRCI     `RV32_Itype(`RV32_SYSTEM, `RV32_CSRRCI_FUN3)

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


//                      //
//  DEBUG INTERFACE     //
//                      //

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
  logic is_remote_load;
  logic is_remote_store;
  logic [RV32_reg_data_width_gp-1:0] remote_addr;
  logic [RV32_reg_data_width_gp-1:0] remote_store_data;
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
  logic is_remote_load;
  logic is_remote_store;
  logic [RV32_reg_data_width_gp-1:0] remote_addr;
  logic [RV32_reg_data_width_gp-1:0] remote_store_data;
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
  logic is_remote_load;
  logic is_remote_store;
  logic [RV32_reg_data_width_gp-1:0] remote_addr;
  logic [RV32_reg_data_width_gp-1:0] remote_store_data;
} wb_debug_s;


typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic valid;
} fp_debug_s;

endpackage
