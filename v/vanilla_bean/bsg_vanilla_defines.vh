`ifndef BSG_VANILLA_DEFINES_VH
`define BSG_VANILLA_DEFINES_VH

/**
 *  bsg_vanilla_defines.vh
 *  
 *  This file defines the macros
 *  used throughout the vanilla core.
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

`define VANILLA_MSTATUS_MIE_BIT_IDX  3
`define VANILLA_MSTATUS_MPIE_BIT_IDX 7

// Vanilla Core Opcodes
`define VANILLA_LOAD     7'b0000011
`define VANILLA_STORE    7'b0100011

`define VANILLA_BRANCH   7'b110001?

`define VANILLA_JALR_OP    7'b1100111
`define VANILLA_MISC_MEM   7'b0001111
`define VANILLA_AMO_OP     7'b0101111
`define VANILLA_JAL_OP     7'b1101111
`define VANILLA_OP_IMM     7'b0010011
`define VANILLA_OP         7'b0110011
`define VANILLA_SYSTEM     7'b1110011
`define VANILLA_AUIPC_OP   7'b0010111
`define VANILLA_LUI_OP     7'b0110111

// Some useful Vanilla instruction macros
`define Vanilla_Rtype(op, funct3, funct7) {``funct7``, {5{1'b?}},  {5{1'b?}},``funct3``, {5{1'b?}},``op``}
`define Vanilla_Itype(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define Vanilla_Stype(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define Vanilla_Utype(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// Vanilla Immediate sign extension macros
`define Vanilla_signext_Iimm(instr) {{21{``instr``[31]}},``instr``[30:20]}
`define Vanilla_signext_Simm(instr) {{21{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define Vanilla_signext_Bimm(instr) {{20{``instr``[31]}},``instr``[7],``instr``[30:25],``instr``[11:8], {1'b0}}
`define Vanilla_signext_Uimm(instr) {``instr``[31:12], {12{1'b0}}}
`define Vanilla_signext_Jimm(instr) {{12{``instr``[31]}},``instr``[19:12],``instr``[20],``instr``[30:21], {1'b0}}

`define Vanilla_Bimm_12inject1(instr,value) {``value``[12], ``value``[10:5], ``instr``[24:12],\
                                          ``value``[4:1],``value``[11],``instr``[6:0]}
`define Vanilla_Jimm_20inject1(instr,value) {``value``[20], ``value``[10:1], ``value``[11],``value``[19:12], ``instr``[11:0]}

// Both JAL and BRANCH use 2-byte address, we need to pad 1'b0 at MSB to get
// the real byte address
`define Vanilla_Bimm_13extract(instr) {``instr``[31], ``instr``[7], ``instr``[30:25], ``instr``[11:8], 1'b0}
`define Vanilla_Jimm_21extract(instr) {``instr``[31], ``instr``[19:12],``instr``[20],``instr``[30:21], 1'b0}

`define Vanilla_Iimm_12extract(instr) {``instr``[31:20]}
`define Vanilla_Simm_12extract(instr) {``instr[31:25],``instr``[11:7]}

// Vanilla Instruction encodings
// We have to delete the white space in macro definition,
// otherwise Design Compiler would issue warings.
`define VANILLA_LUI    `Vanilla_Utype(`VANILLA_LUI_OP)
`define VANILLA_AUIPC  `Vanilla_Utype(`VANILLA_AUIPC_OP)
`define VANILLA_JAL    `Vanilla_Utype(`VANILLA_JAL_OP)
`define VANILLA_JALR   `Vanilla_Itype(`VANILLA_JALR_OP, 3'b000)
`define VANILLA_BEQ    `Vanilla_Stype(`VANILLA_BRANCH, 3'b000)
`define VANILLA_BNE    `Vanilla_Stype(`VANILLA_BRANCH, 3'b001)
`define VANILLA_BLT    `Vanilla_Stype(`VANILLA_BRANCH, 3'b100)
`define VANILLA_BGE    `Vanilla_Stype(`VANILLA_BRANCH, 3'b101)
`define VANILLA_BLTU   `Vanilla_Stype(`VANILLA_BRANCH, 3'b110)
`define VANILLA_BGEU   `Vanilla_Stype(`VANILLA_BRANCH, 3'b111)
`define VANILLA_LB     `Vanilla_Itype(`VANILLA_LOAD, 3'b000)
`define VANILLA_LH     `Vanilla_Itype(`VANILLA_LOAD, 3'b001)
`define VANILLA_LW     `Vanilla_Itype(`VANILLA_LOAD, 3'b010)
`define VANILLA_LBU    `Vanilla_Itype(`VANILLA_LOAD, 3'b100)
`define VANILLA_LHU    `Vanilla_Itype(`VANILLA_LOAD, 3'b101)
`define VANILLA_SB     `Vanilla_Stype(`VANILLA_STORE, 3'b000)
`define VANILLA_SH     `Vanilla_Stype(`VANILLA_STORE, 3'b001)
`define VANILLA_SW     `Vanilla_Stype(`VANILLA_STORE, 3'b010)
`define VANILLA_ADDI   `Vanilla_Itype(`VANILLA_OP_IMM,3'b000)
`define VANILLA_SLTI   `Vanilla_Itype(`VANILLA_OP_IMM, 3'b010)
`define VANILLA_SLTIU  `Vanilla_Itype(`VANILLA_OP_IMM, 3'b011)
`define VANILLA_XORI   `Vanilla_Itype(`VANILLA_OP_IMM, 3'b100)
`define VANILLA_ORI    `Vanilla_Itype(`VANILLA_OP_IMM, 3'b110)
`define VANILLA_ANDI   `Vanilla_Itype(`VANILLA_OP_IMM, 3'b111)
`define VANILLA_SLLI   `Vanilla_Rtype(`VANILLA_OP_IMM, 3'b001, 7'b0000000)
`define VANILLA_SRLI   `Vanilla_Rtype(`VANILLA_OP_IMM, 3'b101, 7'b0000000)
`define VANILLA_SRAI   `Vanilla_Rtype(`VANILLA_OP_IMM, 3'b101, 7'b0100000)
`define VANILLA_ADD    `Vanilla_Rtype(`VANILLA_OP,3'b000,7'b0000000)
`define VANILLA_SUB    `Vanilla_Rtype(`VANILLA_OP, 3'b000, 7'b0100000)
`define VANILLA_SLL    `Vanilla_Rtype(`VANILLA_OP, 3'b001, 7'b0000000)
`define VANILLA_SLT    `Vanilla_Rtype(`VANILLA_OP, 3'b010, 7'b0000000)
`define VANILLA_SLTU   `Vanilla_Rtype(`VANILLA_OP, 3'b011, 7'b0000000)
`define VANILLA_XOR    `Vanilla_Rtype(`VANILLA_OP, 3'b100, 7'b0000000)
`define VANILLA_SRL    `Vanilla_Rtype(`VANILLA_OP, 3'b101, 7'b0000000)
`define VANILLA_SRA    `Vanilla_Rtype(`VANILLA_OP, 3'b101, 7'b0100000)
`define VANILLA_OR     `Vanilla_Rtype(`VANILLA_OP, 3'b110, 7'b0000000)
`define VANILLA_AND    `Vanilla_Rtype(`VANILLA_OP, 3'b111, 7'b0000000)

// CSR encoding
`define VANILLA_CSRRW_FUN3  3'b001
`define VANILLA_CSRRS_FUN3  3'b010
`define VANILLA_CSRRC_FUN3  3'b011
`define VANILLA_CSRRWI_FUN3 3'b101
`define VANILLA_CSRRSI_FUN3 3'b110
`define VANILLA_CSRRCI_FUN3 3'b111

`define VANILLA_CSRRW   `Vanilla_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRW_FUN3)
`define VANILLA_CSRRS   `Vanilla_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRS_FUN3)
`define VANILLA_CSRRC   `Vanilla_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRC_FUN3)
`define VANILLA_CSRRWI  `Vanilla_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRWI_FUN3)
`define VANILLA_CSRRSI  `Vanilla_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRSI_FUN3)
`define VANILLA_CSRRCI  `Vanilla_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRCI_FUN3)

// fcsr CSR addr
`define VANILLA_CSR_FFLAGS_ADDR  12'h001
`define VANILLA_CSR_FRM_ADDR     12'h002
`define VANILLA_CSR_FCSR_ADDR    12'h003
// machine CSR addr
`define VANILLA_CSR_MSTATUS_ADDR   12'h300
`define VANILLA_CSR_MTVEC_ADDR     12'h305
`define VANILLA_CSR_MIE_ADDR       12'h304
`define VANILLA_CSR_MIP_ADDR       12'h344
`define VANILLA_CSR_MEPC_ADDR      12'h341
`define VANILLA_CSR_CFG_POD_ADDR   12'h360

// machine custom CSR addr
`define VANILLA_CSR_CREDIT_LIMIT_ADDR 12'hfc0
`define VANILLA_CSR_BARCFG_ADDR       12'hfc1
`define VANILLA_CSR_BAR_PI_ADDR       12'hfc2
`define VANILLA_CSR_BAR_PO_ADDR       12'hfc3

`endif

