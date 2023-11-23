`ifndef BSG_RISCV_DEFINES_VH
`define BSG_RISCV_DEFINES_VH

/**
 *  bsg_riscv_defines.vh
 *  
 *  This file defines the macros
 *  used for riscv operations throughout the vanilla core.
 *
 */

`include "bsg_vanilla_defines.vh"

`define RV32_MSTATUS_MIE_BIT_IDX  3
`define RV32_MSTATUS_MPIE_BIT_IDX 7

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

`define RV32_Bimm_12inject1(instr,value) {``value``[12], ``value``[10:5], ``instr``[24:12],\
                                          ``value``[4:1],``value``[11],``instr``[6:0]}
`define RV32_Jimm_20inject1(instr,value) {``value``[20], ``value``[10:1], ``value``[11],``value``[19:12], ``instr``[11:0]}

// Both JAL and BRANCH use 2-byte address, we need to pad 1'b0 at MSB to get
// the real byte address
`define RV32_Bimm_13extract(instr) {``instr``[31], ``instr``[7], ``instr``[30:25], ``instr``[11:8], 1'b0}
`define RV32_Jimm_21extract(instr) {``instr``[31], ``instr``[19:12],``instr``[20],``instr``[30:21], 1'b0}

`define RV32_Iimm_12extract(instr) {``instr``[31:20]}
`define RV32_Simm_12extract(instr) {``instr[31:25],``instr``[11:7]}

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
`define RV32_FENCE_OP   {4'b????,4'b????,4'b????,5'b00000,`RV32_FENCE_FUN3,5'b00000,`RV32_MISC_MEM}
`define RV32_FENCE_FM     4'b0000
`define RV32_BARSEND_FM   4'b0001
`define RV32_BARRECV_FM   4'b0010

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
`define RV32_CSR_BARCFG_ADDR       12'hfc1
`define RV32_CSR_BAR_PI_ADDR       12'hfc2
`define RV32_CSR_BAR_PO_ADDR       12'hfc3

// mret
// used for returning from the interrupt
`define RV32_MRET     {7'b0011000, 5'b00010, 5'b00000, 3'b000, 5'b00000, `RV32_SYSTEM}

// RV32M Instruction Encodings
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

`endif

