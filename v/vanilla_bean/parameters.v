`ifndef _parameters_v_
`define _parameters_v_

//`timescale 1ns / 1ns

// RV32 Opcodes
`define RV32_LOAD     7'b0000011
`define RV32_STORE    7'b0100011
`define RV32_MADD     7'b1000011
`define RV32_BRANCH   7'b1100011
`define RV32_LOAD_FP  7'b0000111
`define RV32_STORE_FP 7'b0100111 
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
`define RV32_OP_FP    7'b1010011
`define RV32_SYSTEM   7'b1110011
`define RV32_AUIPC_OP 7'b0010111
`define RV32_LUI_OP   7'b0110111
//                    7'b1010111 is reserved
//                    7'b1110111 is reserved
//                    7'b0011011 is RV64-specific
//                    7'b0111011 is RV64-specific
`define RV32_CUSTOM_2 7'b1011011
`define RV32_CUSTOM_3 7'b1111011

// Some useful RV32 instruction macros
`define RV32_Rtype(op, funct3, funct7) {``funct7``, {5{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``op``}
`define RV32_Itype(op, funct3)         {           {12{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``op``} 
`define RV32_Stype(op, funct3)         { {7{1'b?}}, {5{1'b?}}, {5{1'b?}}, ``funct3``, {5{1'b?}}, ``op``}
`define RV32_Utype(op)                 {                                  {20{1'b?}}, {5{1'b?}}, ``op``}

// RV32IM Instruction encodings
`define RV32_LUI       `RV32_Utype(`RV32_LUI_OP)
`define RV32_AUIPC     `RV32_Utype(`RV32_AUIPC_OP)
`define RV32_JAL       `RV32_Utype(`RV32_JAL_OP)
`define RV32_JALR      `RV32_Itype(`RV32_JALR_OP, 3'b000)
`define RV32_BEQ       `RV32_Stype(`RV32_BRANCH , 3'b000)
`define RV32_BNE       `RV32_Stype(`RV32_BRANCH , 3'b001)
`define RV32_BLT       `RV32_Stype(`RV32_BRANCH , 3'b100)
`define RV32_BGE       `RV32_Stype(`RV32_BRANCH , 3'b101)
`define RV32_BLTU      `RV32_Stype(`RV32_BRANCH , 3'b110)
`define RV32_BGEU      `RV32_Stype(`RV32_BRANCH , 3'b111)
`define RV32_LB        `RV32_Itype(`RV32_LOAD   , 3'b000)
`define RV32_LH        `RV32_Itype(`RV32_LOAD   , 3'b001)
`define RV32_LW        `RV32_Itype(`RV32_LOAD   , 3'b010)
`define RV32_LBU       `RV32_Itype(`RV32_LOAD   , 3'b100)
`define RV32_LHU       `RV32_Itype(`RV32_LOAD   , 3'b101)
`define RV32_SB        `RV32_Stype(`RV32_STORE  , 3'b000)
`define RV32_SH        `RV32_Stype(`RV32_STORE  , 3'b001)
`define RV32_SW        `RV32_Stype(`RV32_STORE  , 3'b010)
`define RV32_ADDI      `RV32_Itype(`RV32_OP_IMM , 3'b000)
`define RV32_SLTI      `RV32_Itype(`RV32_OP_IMM , 3'b010)
`define RV32_SLTIU     `RV32_Itype(`RV32_OP_IMM , 3'b011)
`define RV32_XORI      `RV32_Itype(`RV32_OP_IMM , 3'b100)
`define RV32_ORI       `RV32_Itype(`RV32_OP_IMM , 3'b110)
`define RV32_ANDI      `RV32_Itype(`RV32_OP_IMM , 3'b111)
`define RV32_SLLI      `RV32_Rtype(`RV32_OP_IMM , 3'b001, 7'b0000000)
`define RV32_SRLI      `RV32_Rtype(`RV32_OP_IMM , 3'b101, 7'b0000000)
`define RV32_SRAI      `RV32_Rtype(`RV32_OP_IMM , 3'b101, 7'b0100000)
`define RV32_ADD       `RV32_Rtype(`RV32_OP     , 3'b000, 7'b0000000)
`define RV32_SUB       `RV32_Rtype(`RV32_OP     , 3'b000, 7'b0100000)
`define RV32_SLL       `RV32_Rtype(`RV32_OP     , 3'b001, 7'b0000000)
`define RV32_SLT       `RV32_Rtype(`RV32_OP     , 3'b010, 7'b0000000)
`define RV32_SLTU      `RV32_Rtype(`RV32_OP     , 3'b011, 7'b0000000)
`define RV32_XOR       `RV32_Rtype(`RV32_OP     , 3'b100, 7'b0000000)
`define RV32_SRL       `RV32_Rtype(`RV32_OP     , 3'b101, 7'b0000000)
`define RV32_SRA       `RV32_Rtype(`RV32_OP     , 3'b101, 7'b0100000)
`define RV32_OR        `RV32_Rtype(`RV32_OP     , 3'b110, 7'b0000000)
`define RV32_AND       `RV32_Rtype(`RV32_OP     , 3'b111, 7'b0000000)
`define RV32_MUL       `RV32_Rtype(`RV32_OP     , 3'b000, 7'b0000001) 
`define RV32_MULH      `RV32_Rtype(`RV32_OP     , 3'b001, 7'b0000001) 
`define RV32_MULHSU    `RV32_Rtype(`RV32_OP     , 3'b010, 7'b0000001) 
`define RV32_MULHU     `RV32_Rtype(`RV32_OP     , 3'b011, 7'b0000001) 
`define RV32_DIV       `RV32_Rtype(`RV32_OP     , 3'b100, 7'b0000001) 
`define RV32_DIVU      `RV32_Rtype(`RV32_OP     , 3'b101, 7'b0000001) 
`define RV32_REM       `RV32_Rtype(`RV32_OP     , 3'b110, 7'b0000001) 
`define RV32_REMU      `RV32_Rtype(`RV32_OP     , 3'b111, 7'b0000001) 
`define RV32_LR_W      `RV32_Rtype(`RV32_AMO    , 3'b010, 7'b00010??)

// RV32 Immediate sign extension macros
`define RV32_signext_Iimm(instr) {{21{``instr``[31]}}, ``instr``[30:20]}
`define RV32_signext_Simm(instr) {{21{``instr``[31]}}, ``instr[30:25], ``instr``[11:7]}
`define RV32_signext_Bimm(instr) {{20{``instr``[31]}}, ``instr``[7], ``instr``[30:25], ``instr``[11:8], {1'b0}}
`define RV32_signext_Uimm(instr) {``instr``[31:12], {12{1'b0}}}
`define RV32_signext_Jimm(instr) {{12{``instr``[31]}}, ``instr``[19:12], ``instr``[20], ``instr``[30:21], {1'b0}} 

parameter RV32_instr_width_gp    = 32;
parameter RV32_reg_data_width_gp = 32;
parameter RV32_reg_addr_width_gp = 5;
parameter RV32_shamt_width_gp    = 5;
parameter RV32_opcode_width_gp   = 7;
parameter RV32_funct3_width_gp   = 3;
parameter RV32_funct7_width_gp   = 7;
parameter RV32_Iimm_width_gp     = 12;
parameter RV32_Simm_width_gp     = 12;
parameter RV32_Bimm_width_gp     = 12;
parameter RV32_Uimm_width_gp     = 20;
parameter RV32_Jimm_width_gp     = 20;

/*
// Instruction mapping
`define kADDU       16'b00000_?????_?????? // 00
`define kSUBU       16'b00001_?????_?????? // 01
`define kSLLV       16'b00010_?????_?????? // 02
`define kSRAV       16'b00011_?????_?????? // 03
`define kSRLV       16'b00100_?????_?????? // 04
`define kAND        16'b00101_?????_?????? // 05
`define kOR         16'b00110_?????_?????? // 06
`define kNOR        16'b00111_?????_?????? // 07
`define kSLT        16'b01000_?????_?????? // 08
`define kSLTU       16'b01001_?????_?????? // 09
`define kMOV        16'b01010_?????_?????? // 0A
                                           // 0B
`define kWAIT       16'b01100_000??_?????? // 0C_1
`define kBAR        16'b01100_100??_?????? // 0C_2
`define kBARWAIT    16'b01100_010??_?????? // 0C_3
`define kNETW       16'b01101_?????_?????? // 0D
                                           // 0E
                                           // 0F
`define kBEQZ       16'b10000_?????_?????? // 10
`define kBNEQZ      16'b10001_?????_?????? // 11
`define kBGTZ       16'b10010_?????_?????? // 12
`define kBLTZ       16'b10011_?????_?????? // 13
                                           // 14
                                           // 15
`define kBL         16'b10110_?????_?????? // 16
`define kJALR       16'b10111_?????_?????? // 17
`define kLW         16'b11000_?????_?????? // 18
`define kLBU        16'b11001_?????_?????? // 19
`define kSW         16'b11010_?????_?????? // 1A
`define kSB         16'b11011_?????_?????? // 1B
`define kLG         16'b11100_?????_?????? // 1C
`define kMOVI       16'b11101_?????_?????? // 1D
`define kADDI       16'b11110_?????_?????? // 1E
                                           // 1F

// Instruction encoding sizing
parameter opcode_size_gp      = 5;
parameter rd_size_gp          = 5;
parameter rs_imm_size_gp      = 6;
parameter operand_size_gp     = rd_size_gp + rs_imm_size_gp;
parameter instruction_size_gp = (rd_size_gp + rs_imm_size_gp + opcode_size_gp);
*/

// Memory sizing (address widths)
//parameter const_file_size_gp     = (2**rs_imm_size_gp - 2**rd_size_gp);
parameter imem_addr_width_gp     = 14;
parameter data_mem_addr_width_gp = 13;

// Length of barrier output, which is equal to its mask size 
parameter mask_length_gp = 3;
`endif
