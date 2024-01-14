`ifndef BSG_MANYCORE_INSTRUCTION_DEFINES_SVH
`define BSG_MANYCORE_INSTRUCTION_DEFINES_SVH

/**
 *  bsg_manycore_instructions_defines.svh
 *  
 *  This file defines the macros
 *  used throughout the vanilla core. (Outside the decoder)
 *
 */

`include "bsg_defines.sv"

`define declare_icache_format_s(tag_width_mp, block_size_in_words_mp) \
  typedef struct packed { \
    logic [block_size_in_words_mp-1:0] lower_cout; \
    logic [block_size_in_words_mp-1:0] lower_sign; \
    logic [tag_width_mp-1:0] tag; \
    instruction_s [block_size_in_words_mp-1:0] instr; \
  } icache_format_s

`define icache_format_width(tag_width_mp, block_size_in_words_mp) \
   ((2*block_size_in_words_mp)+tag_width_mp+(block_size_in_words_mp*$bits(instruction_s)))

// FPU recoded Constants
`define FPU_RECODED_ONE   33'h080000000
`define FPU_RECODED_ZERO  33'h0
`define FPU_RECODED_CANONICAL_NAN 33'h0e0400000

`define REMOTE_INTERRUPT_JUMP_ADDR  0   // remote interrupt jump addr (word addr)
`define TRACE_INTERRUPT_JUMP_ADDR   1   // trace interrupt jump addr (word addr)

// 32M Instruction Encodings
`define MD_MUL_FUN3       3'b000
`define MD_MULH_FUN3      3'b001
`define MD_MULHSU_FUN3    3'b010
`define MD_MULHU_FUN3     3'b011
`define MD_DIV_FUN3       3'b100
`define MD_DIVU_FUN3      3'b101
`define MD_REM_FUN3       3'b110
`define MD_REMU_FUN3      3'b111

// Generic Many Core Opcodes
`define MANYCORE_LOAD     7'b1111100
`define MANYCORE_STORE    7'b1011100

`define MANYCORE_BRANCH   7'b001110?

`define MANYCORE_JALR_OP    7'b0011000
`define MANYCORE_MISC_MEM   7'b1110000
`define MANYCORE_AMO_OP     7'b1010000
`define MANYCORE_JAL_OP     7'b0010000
`define MANYCORE_OP_IMM     7'b1101100
`define MANYCORE_OP         7'b1001100
`define MANYCORE_SYSTEM     7'b0001100
`define MANYCORE_AUIPC_OP   7'b1101000
`define MANYCORE_LUI_OP     7'b1001000

// Some useful ManyCore instruction macros
`define MANYCORE_Rtype(op, funct3, funct7) {``funct7``, {5{1'b?}},  {5{1'b?}},``funct3``, {5{1'b?}},``op``}
`define MANYCORE_Itype(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define MANYCORE_Stype(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define MANYCORE_Utype(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// ManyCore Immediate sign extension macros
`define MANYCORE_signext_Iimm(instr) {{21{``instr``[31]}},``instr``[30:20]}
`define MANYCORE_signext_Simm(instr) {{21{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define MANYCORE_signext_Bimm(instr) {{20{``instr``[31]}},``instr``[7],``instr``[30:25],``instr``[11:8], {1'b0}}
`define MANYCORE_signext_Uimm(instr) {``instr``[31:12], {12{1'b0}}}
`define MANYCORE_signext_Jimm(instr) {{12{``instr``[31]}},``instr``[19:12],``instr``[20],``instr``[30:21], {1'b0}}

`define MANYCORE_Bimm_12inject1(instr,value) {``value``[12], ``value``[10:5], ``instr``[24:12],\
                                          ``value``[4:1],``value``[11],``instr``[6:0]}
`define MANYCORE_Jimm_20inject1(instr,value) {``value``[20], ``value``[10:1], ``value``[11],``value``[19:12], ``instr``[11:0]}

// Both JAL and BRANCH use 2-byte address, we need to pad 1'b0 at MSB to get
// the real byte address
`define MANYCORE_Bimm_13extract(instr) {``instr``[31], ``instr``[7], ``instr``[30:25], ``instr``[11:8], 1'b0}
`define MANYCORE_Jimm_21extract(instr) {``instr``[31], ``instr``[19:12],``instr``[20],``instr``[30:21], 1'b0}

`define MANYCORE_Iimm_12extract(instr) {``instr``[31:20]}
`define MANYCORE_Simm_12extract(instr) {``instr[31:25],``instr``[11:7]}

// Manycore Instruction encodings
// We have to delete the white space in macro definition,
// otherwise Design Compiler would issue warings.
`define MANYCORE_LUI    `MANYCORE_Utype(`MANYCORE_LUI_OP)
`define MANYCORE_AUIPC  `MANYCORE_Utype(`MANYCORE_AUIPC_OP)
`define MANYCORE_JAL    `MANYCORE_Utype(`MANYCORE_JAL_OP)
`define MANYCORE_JALR   `MANYCORE_Itype(`MANYCORE_JALR_OP, 3'b000)
`define MANYCORE_BEQ    `MANYCORE_Stype(`MANYCORE_BRANCH, 3'b000)
`define MANYCORE_BNE    `MANYCORE_Stype(`MANYCORE_BRANCH, 3'b001)
`define MANYCORE_BLT    `MANYCORE_Stype(`MANYCORE_BRANCH, 3'b100)
`define MANYCORE_BGE    `MANYCORE_Stype(`MANYCORE_BRANCH, 3'b101)
`define MANYCORE_BLTU   `MANYCORE_Stype(`MANYCORE_BRANCH, 3'b110)
`define MANYCORE_BGEU   `MANYCORE_Stype(`MANYCORE_BRANCH, 3'b111)
`define MANYCORE_LB     `MANYCORE_Itype(`MANYCORE_LOAD, 3'b000)
`define MANYCORE_LH     `MANYCORE_Itype(`MANYCORE_LOAD, 3'b001)
`define MANYCORE_LW     `MANYCORE_Itype(`MANYCORE_LOAD, 3'b010)
`define MANYCORE_LBU    `MANYCORE_Itype(`MANYCORE_LOAD, 3'b100)
`define MANYCORE_LHU    `MANYCORE_Itype(`MANYCORE_LOAD, 3'b101)
`define MANYCORE_SB     `MANYCORE_Stype(`MANYCORE_STORE, 3'b000)
`define MANYCORE_SH     `MANYCORE_Stype(`MANYCORE_STORE, 3'b001)
`define MANYCORE_SW     `MANYCORE_Stype(`MANYCORE_STORE, 3'b010)
`define MANYCORE_ADDI   `MANYCORE_Itype(`MANYCORE_OP_IMM,3'b000)
`define MANYCORE_SLTI   `MANYCORE_Itype(`MANYCORE_OP_IMM, 3'b010)
`define MANYCORE_SLTIU  `MANYCORE_Itype(`MANYCORE_OP_IMM, 3'b011)
`define MANYCORE_XORI   `MANYCORE_Itype(`MANYCORE_OP_IMM, 3'b100)
`define MANYCORE_ORI    `MANYCORE_Itype(`MANYCORE_OP_IMM, 3'b110)
`define MANYCORE_ANDI   `MANYCORE_Itype(`MANYCORE_OP_IMM, 3'b111)
`define MANYCORE_SLLI   `MANYCORE_Rtype(`MANYCORE_OP_IMM, 3'b001, 7'b0000000)
`define MANYCORE_SRLI   `MANYCORE_Rtype(`MANYCORE_OP_IMM, 3'b101, 7'b0000000)
`define MANYCORE_SRAI   `MANYCORE_Rtype(`MANYCORE_OP_IMM, 3'b101, 7'b0100000)
`define MANYCORE_ADD    `MANYCORE_Rtype(`MANYCORE_OP,3'b000,7'b0000000)
`define MANYCORE_SUB    `MANYCORE_Rtype(`MANYCORE_OP, 3'b000, 7'b0100000)
`define MANYCORE_SLL    `MANYCORE_Rtype(`MANYCORE_OP, 3'b001, 7'b0000000)
`define MANYCORE_SLT    `MANYCORE_Rtype(`MANYCORE_OP, 3'b010, 7'b0000000)
`define MANYCORE_SLTU   `MANYCORE_Rtype(`MANYCORE_OP, 3'b011, 7'b0000000)
`define MANYCORE_XOR    `MANYCORE_Rtype(`MANYCORE_OP, 3'b100, 7'b0000000)
`define MANYCORE_SRL    `MANYCORE_Rtype(`MANYCORE_OP, 3'b101, 7'b0000000)
`define MANYCORE_SRA    `MANYCORE_Rtype(`MANYCORE_OP, 3'b101, 7'b0100000)
`define MANYCORE_OR     `MANYCORE_Rtype(`MANYCORE_OP, 3'b110, 7'b0000000)
`define MANYCORE_AND    `MANYCORE_Rtype(`MANYCORE_OP, 3'b111, 7'b0000000)

// CSR encoding
`define MANYCORE_CSRRW_FUN3  3'b001
`define MANYCORE_CSRRS_FUN3  3'b010
`define MANYCORE_CSRRC_FUN3  3'b011
`define MANYCORE_CSRRWI_FUN3 3'b101
`define MANYCORE_CSRRSI_FUN3 3'b110
`define MANYCORE_CSRRCI_FUN3 3'b111

`define MANYCORE_CSRRW   `MANYCORE_Itype(`MANYCORE_SYSTEM, `MANYCORE_CSRRW_FUN3)
`define MANYCORE_CSRRS   `MANYCORE_Itype(`MANYCORE_SYSTEM, `MANYCORE_CSRRS_FUN3)
`define MANYCORE_CSRRC   `MANYCORE_Itype(`MANYCORE_SYSTEM, `MANYCORE_CSRRC_FUN3)
`define MANYCORE_CSRRWI  `MANYCORE_Itype(`MANYCORE_SYSTEM, `MANYCORE_CSRRWI_FUN3)
`define MANYCORE_CSRRSI  `MANYCORE_Itype(`MANYCORE_SYSTEM, `MANYCORE_CSRRSI_FUN3)
`define MANYCORE_CSRRCI  `MANYCORE_Itype(`MANYCORE_SYSTEM, `MANYCORE_CSRRCI_FUN3)

// fcsr CSR addr
`define MANYCORE_CSR_FFLAGS_ADDR  12'h001
`define MANYCORE_CSR_FRM_ADDR     12'h002
`define MANYCORE_CSR_FCSR_ADDR    12'h003
// machine CSR addr
`define MANYCORE_CSR_CFG_POD_ADDR   12'h360

// machine custom CSR addr
`define MANYCORE_CSR_CREDIT_LIMIT_ADDR 12'hfc0
`define MANYCORE_CSR_BARCFG_ADDR       12'hfc1
`define MANYCORE_CSR_BAR_PI_ADDR       12'hfc2
`define MANYCORE_CSR_BAR_PO_ADDR       12'hfc3

`endif

