/**
 *    parameters.vh
 *
 */



`ifndef PARAMETERS_VH
`define PARAMETERS_VH

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

//SWAP defines
`define RV32_AMOSWAP_AQ_FUN7   7'b0000110
`define RV32_AMOSWAP_RL_FUN7   7'b0000101

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

`define RV32_AMOSWAP_AQ_W `RV32_Rtype(`RV32_AMO, 3'b010, `RV32_AMOSWAP_AQ_FUN7)
`define RV32_AMOSWAP_RL_W `RV32_Rtype(`RV32_AMO, 3'b010, `RV32_AMOSWAP_RL_FUN7)

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

localparam RV32_instr_width_gp    = 32;
localparam RV32_reg_data_width_gp = 32;
localparam RV32_reg_els_gp        = 32;
localparam RV32_reg_addr_width_gp = 5;
localparam RV32_shamt_width_gp    = 5;
localparam RV32_opcode_width_gp   = 7;
localparam RV32_funct3_width_gp   = 3;
localparam RV32_funct7_width_gp   = 7;
localparam RV32_Iimm_width_gp     = 12;
localparam RV32_Simm_width_gp     = 12;
localparam RV32_Bimm_width_gp     = 12;
localparam RV32_Uimm_width_gp     = 20;
localparam RV32_Jimm_width_gp     = 20;

/////////////////////////////////////////////////////
// The MSB indicator of the address in bytes.
`define MC_DMEM_MASK_BITS 12  
`define MC_IS_DMEM_ADDR(addr, addr_width)  (  addr[ `MC_DMEM_MASK_BITS -2]                              \
                                                    & (~ (| addr[  (``addr_width``-1) : `MC_DMEM_MASK_BITS -1 ]) ) \
                                                   )

`define MC_ICACHE_MASK_BITS    24 
`define MC_IS_ICACHE_ADDR(addr, addr_width)  (  addr[ `MC_ICACHE_MASK_BITS -2]                              \
                                                      & (~ (| addr[ (``addr_width``-1) : `MC_ICACHE_MASK_BITS -1 ]) ) \
                                                     )

/////////////////////////////////////////////////////
// The CSR Address
`define         CSR_FREEZE             0
`define         CSR_TGO_X              1
`define         CSR_TGO_Y              2



/////////////////////////////////////////////////////
// The CUDA Print stat parameters
// The cuda print stat tag message incorporates within itself the x,y coordiantes
// and the tile group id of the tile that triggerd the bsg_cuda_print_stat instruction
// <stat_type>   -   <y cord>   -   <x cord>   -   <tile group id>   -   <tag>
localparam RV32_cuda_print_stat_tag_width_gp    = 8;
localparam RV32_cuda_print_stat_tg_id_width_gp  = 10;
localparam RV32_cuda_print_stat_x_width_gp      = 6;
localparam RV32_cuda_print_stat_y_width_gp      = 6;
localparam RV32_cuda_print_stat_type_width_gp   = 2;




`endif
