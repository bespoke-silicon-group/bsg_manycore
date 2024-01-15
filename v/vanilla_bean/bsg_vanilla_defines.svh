`ifndef BSG_RISCV_DEFINES_SVH
`define BSG_RISCV_DEFINES_SVH

/**
 *  bsg_vanilla_defines.svh
 *  
 *  This file defines the macros
 *  used for Vanilla ISA operations throughout the vanilla core.
 *
 */

`include "bsg_manycore_instruction_defines.svh"

// Vanilla Opcodes
`define VANILLA_LOAD     `MANYCORE_LOAD
`define VANILLA_STORE    `MANYCORE_STORE

// we have branch instructions ignore the low bit so that we can place the prediction bit there.
// RISC-V by default has the low bits set to 11 in the icache, so we can use those creatively.
// note this relies on all code using ==? and casez.
`define VANILLA_BRANCH     `MANYCORE_BRANCH

`define VANILLA_JALR_OP    `MANYCORE_JALR_OP
`define VANILLA_MISC_MEM   `MANYCORE_MISC_MEM
`define VANILLA_AMO_OP     `MANYCORE_AMO_OP
`define VANILLA_JAL_OP     `MANYCORE_JAL_OP
`define VANILLA_OP_IMM     `MANYCORE_OP_IMM
`define VANILLA_OP         `MANYCORE_OP
`define VANILLA_SYSTEM     `MANYCORE_SYSTEM
`define VANILLA_AUIPC_OP   `MANYCORE_AUIPC_OP
`define VANILLA_LUI_OP     `MANYCORE_LUI_OP


// Some useful Vanilla instruction macros
`define VANILLA_Rtype(op, funct3, funct7) {``funct7``, {5{1'b?}},  {5{1'b?}},``funct3``, {5{1'b?}},``op``}
`define VANILLA_Itype(op, funct3)         {{12{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define VANILLA_Stype(op, funct3)         {{7{1'b?}},{5{1'b?}},{5{1'b?}},``funct3``,{5{1'b?}},``op``}
`define VANILLA_Utype(op)                 {{20{1'b?}},{5{1'b?}},``op``}

// Vanilla Immediate sign extension macros
`define VANILLA_signext_Iimm(instr) {{21{``instr``[31]}},``instr``[30:20]}
`define VANILLA_signext_Simm(instr) {{21{``instr``[31]}},``instr[30:25],``instr``[11:7]}
`define VANILLA_signext_Bimm(instr) {{20{``instr``[31]}},``instr``[7],``instr``[30:25],``instr``[11:8], {1'b0}}
`define VANILLA_signext_Uimm(instr) {``instr``[31:12], {12{1'b0}}}
`define VANILLA_signext_Jimm(instr) {{12{``instr``[31]}},``instr``[19:12],``instr``[20],``instr``[30:21], {1'b0}}

`define VANILLA_Bimm_12inject1(instr,value) {``value``[12], ``value``[10:5], ``instr``[24:12],\
                                          ``value``[4:1],``value``[11],``instr``[6:0]}
`define VANILLA_Jimm_20inject1(instr,value) {``value``[20], ``value``[10:1], ``value``[11],``value``[19:12], ``instr``[11:0]}

// Both JAL and BRANCH use 2-byte address, we need to pad 1'b0 at MSB to get
// the real byte address
`define VANILLA_Bimm_13extract(instr) {``instr``[31], ``instr``[7], ``instr``[30:25], ``instr``[11:8], 1'b0}
`define VANILLA_Jimm_21extract(instr) {``instr``[31], ``instr``[19:12],``instr``[20],``instr``[30:21], 1'b0}

`define VANILLA_Iimm_12extract(instr) {``instr``[31:20]}
`define VANILLA_Simm_12extract(instr) {``instr[31:25],``instr``[11:7]}

// VanillaI Instruction encodings
// We have to delete the white space in macro definition,
// otherwise Design Compiler would issue warings.
`define VANILLA_LUI       `MANYCORE_LUI
`define VANILLA_AUIPC     `MANYCORE_AUIPC
`define VANILLA_JAL       `MANYCORE_JAL
`define VANILLA_JALR      `MANYCORE_JALR
`define VANILLA_BEQ       `MANYCORE_BEQ
`define VANILLA_BNE       `MANYCORE_BNE
`define VANILLA_BLT       `MANYCORE_BLT
`define VANILLA_BGE       `MANYCORE_BGE
`define VANILLA_BLTU      `MANYCORE_BLTU
`define VANILLA_BGEU      `MANYCORE_BGEU
`define VANILLA_LB        `MANYCORE_LB
`define VANILLA_LH        `MANYCORE_LH
`define VANILLA_LW        `MANYCORE_LW
`define VANILLA_LBU       `MANYCORE_LBU
`define VANILLA_LHU       `MANYCORE_LHU
`define VANILLA_SB        `MANYCORE_SB
`define VANILLA_SH        `MANYCORE_SH
`define VANILLA_SW        `MANYCORE_SW
`define VANILLA_ADDI      `MANYCORE_ADDI
`define VANILLA_SLTI      `MANYCORE_SLTI
`define VANILLA_SLTIU     `MANYCORE_SLTIU
`define VANILLA_XORI      `MANYCORE_XORI
`define VANILLA_ORI       `MANYCORE_ORI
`define VANILLA_ANDI      `MANYCORE_ANDI
`define VANILLA_SLLI      `MANYCORE_SLLI
`define VANILLA_SRLI      `MANYCORE_SRLI
`define VANILLA_SRAI      `MANYCORE_SRAI
`define VANILLA_ADD       `MANYCORE_ADD
`define VANILLA_SUB       `MANYCORE_SUB
`define VANILLA_SLL       `MANYCORE_SLL
`define VANILLA_SLT       `MANYCORE_SLT
`define VANILLA_SLTU      `MANYCORE_SLTU
`define VANILLA_XOR       `MANYCORE_XOR
`define VANILLA_SRL       `MANYCORE_SRL
`define VANILLA_SRA       `MANYCORE_SRA
`define VANILLA_OR        `MANYCORE_OR
`define VANILLA_AND       `MANYCORE_AND

// FENCE defines
`define VANILLA_FENCE_FUN3   3'b000
`define VANILLA_FENCE_OP   {4'b????,4'b????,4'b????,5'b00000,`VANILLA_FENCE_FUN3,5'b00000,`VANILLA_MISC_MEM}
`define VANILLA_FENCE_FM     4'b0000
`define VANILLA_BARSEND_FM   4'b0001
`define VANILLA_BARRECV_FM   4'b0010

//TRIGGER SAIF DUMP defines
`define SAIF_TRIGGER_START {12'b000000000001,5'b00000,3'b000,5'b00000,`VANILLA_OP_IMM}
`define SAIF_TRIGGER_END {12'b000000000010,5'b00000,3'b000,5'b00000,`VANILLA_OP_IMM}

// CSR encoding
`define VANILLA_CSRRW_FUN3  3'b001
`define VANILLA_CSRRS_FUN3  3'b010
`define VANILLA_CSRRC_FUN3  3'b011
`define VANILLA_CSRRWI_FUN3 3'b101
`define VANILLA_CSRRSI_FUN3 3'b110
`define VANILLA_CSRRCI_FUN3 3'b111

`define VANILLA_CSRRW      `VANILLA_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRW_FUN3)
`define VANILLA_CSRRS      `VANILLA_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRS_FUN3)
`define VANILLA_CSRRC      `VANILLA_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRC_FUN3)
`define VANILLA_CSRRWI     `VANILLA_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRWI_FUN3)
`define VANILLA_CSRRSI     `VANILLA_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRSI_FUN3)
`define VANILLA_CSRRCI     `VANILLA_Itype(`VANILLA_SYSTEM, `VANILLA_CSRRCI_FUN3)

// fcsr CSR addr
`define VANILLA_CSR_FFLAGS_ADDR  12'h001
`define VANILLA_CSR_FRM_ADDR     12'h002  
`define VANILLA_CSR_FCSR_ADDR    12'h003
// machine CSR addr
`define VANILLA_CSR_CFG_POD_ADDR   12'h360				    

// machine custom CSR addr
`define VANILLA_CSR_CREDIT_LIMIT_ADDR 12'hfc0
`define VANILLA_CSR_BARCFG_ADDR       12'hfc1
`define VANILLA_CSR_BAR_PI_ADDR       12'hfc2
`define VANILLA_CSR_BAR_PO_ADDR       12'hfc3

// mret
// used for returning from the interrupt
`define VANILLA_MRET     {7'b0011000, 5'b00010, 5'b00000, 3'b000, 5'b00000, `VANILLA_SYSTEM}

// VANILLA M Instruction Encodings
`define VANILLA_MUL       `VANILLA_Rtype(`VANILLA_OP, `MD_MUL_FUN3   , 7'b0000001)
`define VANILLA_MULH      `VANILLA_Rtype(`VANILLA_OP, `MD_MULH_FUN3  , 7'b0000001)
`define VANILLA_MULHSU    `VANILLA_Rtype(`VANILLA_OP, `MD_MULHSU_FUN3, 7'b0000001)
`define VANILLA_MULHU     `VANILLA_Rtype(`VANILLA_OP, `MD_MULHU_FUN3 , 7'b0000001)
`define VANILLA_DIV       `VANILLA_Rtype(`VANILLA_OP, `MD_DIV_FUN3   , 7'b0000001)
`define VANILLA_DIVU      `VANILLA_Rtype(`VANILLA_OP, `MD_DIVU_FUN3  , 7'b0000001)
`define VANILLA_REM       `VANILLA_Rtype(`VANILLA_OP, `MD_REM_FUN3   , 7'b0000001)
`define VANILLA_REMU      `VANILLA_Rtype(`VANILLA_OP, `MD_REMU_FUN3  , 7'b0000001)

// VANILLA A Instruction Encodings
`define VANILLA_LR_W       {5'b00010,2'b00,5'b00000,5'b?????,3'b010,5'b?????,`VANILLA_AMO_OP}
`define VANILLA_LR_W_AQ    {5'b00010,2'b10,5'b00000,5'b?????,3'b010,5'b?????,`VANILLA_AMO_OP}
`define VANILLA_AMOSWAP_W  {5'b00001,2'b??,5'b?????,5'b?????,3'b010,5'b?????,`VANILLA_AMO_OP}
`define VANILLA_AMOOR_W    {5'b01000,2'b??,5'b?????,5'b?????,3'b010,5'b?????,`VANILLA_AMO_OP}
`define VANILLA_AMOADD_W   {5'b00000,2'b??,5'b?????,5'b?????,3'b010,5'b?????,`VANILLA_AMO_OP}

// VANILLA F Instruction Encodings
`define VANILLA_OP_FP            7'b0101100
`define VANILLA_LOAD_FP          7'b1111000
`define VANILLA_STORE_FP         7'b1011000

`define VANILLA_FCMP_S_FUN7      7'b1010000
`define VANILLA_FCLASS_S_FUN7    7'b1110000
`define VANILLA_FCVT_S_F2I_FUN7  7'b1100000
`define VANILLA_FCVT_S_I2F_FUN7  7'b1101000
`define VANILLA_FMV_W_X_FUN7     7'b1111000
`define VANILLA_FMV_X_W_FUN7     7'b1110000

`define VANILLA_FADD_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b???, 7'b0000000)
`define VANILLA_FSUB_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b???, 7'b0000100)
`define VANILLA_FMUL_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b???, 7'b0001000)

`define VANILLA_FSGNJ_S  `VANILLA_Rtype(`VANILLA_OP_FP, 3'b000, 7'b0010000)
`define VANILLA_FSGNJN_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b001, 7'b0010000)
`define VANILLA_FSGNJX_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b010, 7'b0010000)

`define VANILLA_FMIN_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b000, 7'b0010100)
`define VANILLA_FMAX_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b001, 7'b0010100)

`define VANILLA_FEQ_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b010, `VANILLA_FCMP_S_FUN7)
`define VANILLA_FLT_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b001, `VANILLA_FCMP_S_FUN7)
`define VANILLA_FLE_S `VANILLA_Rtype(`VANILLA_OP_FP, 3'b000, `VANILLA_FCMP_S_FUN7)

`define VANILLA_FCLASS_S {`VANILLA_FCLASS_S_FUN7, 5'b00000, 5'b?????, 3'b001, 5'b?????, `VANILLA_OP_FP}

// i2f
`define VANILLA_FCVT_S_W  {`VANILLA_FCVT_S_I2F_FUN7, 5'b00000, 5'b?????, 3'b???, 5'b?????, `VANILLA_OP_FP}
`define VANILLA_FCVT_S_WU {`VANILLA_FCVT_S_I2F_FUN7, 5'b00001, 5'b?????, 3'b???, 5'b?????, `VANILLA_OP_FP}

// f2i
`define VANILLA_FCVT_W_S  {`VANILLA_FCVT_S_F2I_FUN7, 5'b00000, 5'b?????, 3'b???, 5'b?????, `VANILLA_OP_FP}
`define VANILLA_FCVT_WU_S {`VANILLA_FCVT_S_F2I_FUN7, 5'b00001, 5'b?????, 3'b???, 5'b?????, `VANILLA_OP_FP}

// move (i->f) 
`define VANILLA_FMV_W_X {`VANILLA_FMV_W_X_FUN7, 5'b0000, 5'b?????, 3'b000, 5'b?????, `VANILLA_OP_FP}

// move (f->i)
`define VANILLA_FMV_X_W {`VANILLA_FMV_X_W_FUN7, 5'b0000, 5'b?????, 3'b000, 5'b?????, `VANILLA_OP_FP}

`define VANILLA_FLW_S `VANILLA_Itype(`VANILLA_LOAD_FP, 3'b010)
`define VANILLA_FSW_S `VANILLA_Stype(`VANILLA_STORE_FP, 3'b010)

`define VANILLA_FMADD_S   {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b0111100}
`define VANILLA_FMSUB_S   {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b0111000}
`define VANILLA_FNMSUB_S  {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b0110100}
`define VANILLA_FNMADD_S  {5'b?????, 2'b00, 5'b?????, 5'b?????, 3'b???, 5'b?????, 7'b0110000}

`define VANILLA_FDIV_S   `VANILLA_Rtype(`VANILLA_OP_FP, 3'b???, 7'b0001100)
`define VANILLA_FSQRT_S  {7'b0101100, 5'b00000, 5'b?????, 3'b???, 5'b?????, 7'b0101100}

`endif
