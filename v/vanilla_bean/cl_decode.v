`include "parameters.v"
`include "definitions.v"

/**
 *  This module defines a decode unit that looks at the instruction
 *  and sets a bunch of control signals that descibe the use of the
 *  instruction.
 */
module cl_decode
(
    input  instruction_s instruction_i,
    output decode_s      decode_o
);

logic reads_crf;

// Op Writes RF -- register file write operation
always_comb
    unique casez (instruction_i)
        `RV32_LUI,  `RV32_AUIPC, `RV32_JAL,   `RV32_JALR,
        `RV32_LB,   `RV32_LH,    `RV32_LW,    `RV32_LBU,  `RV32_LHU,
        `RV32_ADDI, `RV32_SLTI,  `RV32_SLTIU, `RV32_XORI, `RV32_ORI, 
        `RV32_ANDI, `RV32_SLLI,  `RV32_SRLI,  `RV32_SRAI, `RV32_ADD,
        `RV32_SUB,  `RV32_SLL,   `RV32_SLT,   `RV32_SLTU, `RV32_XOR,
        `RV32_SRL,  `RV32_SRA,   `RV32_OR,    `RV32_AND,  `RV32_MUL,
        `RV32_MULH, `RV32_MULHSU,`RV32_MULHU, `RV32_DIV,  `RV32_DIVU,
        `RV32_REM,  `RV32_REMU,  `RV32_LR_W:
            decode_o.op_writes_rf = 1'b1;
        default:
            decode_o.op_writes_rf = 1'b0;
    endcase

// Is Mem Op -- data memory operation
always_comb
    unique casez (instruction_i)
        `RV32_LB,   `RV32_LH,    `RV32_LW,    `RV32_LBU,  `RV32_LHU,
        `RV32_SB,   `RV32_SH,    `RV32_SW, `RV32_LR_W:
            decode_o.is_mem_op = 1'b1;
        default:
            decode_o.is_mem_op = 1'b0;
    endcase

// Is Load Op -- data memory load operation
always_comb
    unique casez (instruction_i)
        `RV32_LB,   `RV32_LH,    `RV32_LW,    `RV32_LBU,  `RV32_LHU,
        `RV32_LR_W:
            decode_o.is_load_op = 1'b1;
        default:
            decode_o.is_load_op = 1'b0;
    endcase

// Is Store Op -- data memory store operation
always_comb
    unique casez (instruction_i)
        `RV32_SB,   `RV32_SH,    `RV32_SW:
            decode_o.is_store_op = 1'b1;
        default:
            decode_o.is_store_op = 1'b0;
  endcase

// Is Branch Op -- pc branching operation
// `kBL is actually like jump since there is
// no condition for it
always_comb
    unique casez (instruction_i)
        `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE, `RV32_BLTU,`RV32_BGEU:
            decode_o.is_branch_op = 1'b1;
        default:
            decode_o.is_branch_op = 1'b0;
    endcase

// Is Jump Op -- pc jumping operation
always_comb
    unique casez (instruction_i)
        `RV32_JAL, `RV32_JALR:
            decode_o.is_jump_op = 1'b1;
        default:
            decode_o.is_jump_op = 1'b0;
    endcase

// declares if OP reads from first port of register file
always_comb
    unique casez (instruction_i)
        `RV32_JALR, 
        `RV32_BEQ,  `RV32_BNE,  `RV32_BLT,    `RV32_BGE, `RV32_BLTU, `RV32_BGEU,   
        `RV32_LB,   `RV32_LH,   `RV32_LW,    `RV32_LBU,  `RV32_LHU,   
        `RV32_SB,   `RV32_SH,   `RV32_SW,
        `RV32_ADDI, `RV32_SLTI, `RV32_SLTIU, `RV32_XORI, `RV32_ORI,   `RV32_ANDI, 
        `RV32_SLLI, `RV32_SRLI, `RV32_SRAI, 
        `RV32_ADD,  `RV32_SUB,  `RV32_SLL,    `RV32_SLT, `RV32_SLTU, `RV32_XOR,   
        `RV32_SRL,  `RV32_SRA,  `RV32_OR,    `RV32_AND,   
        `RV32_MUL,  `RV32_MULH, `RV32_MULHSU, `RV32_MULHU, 
        `RV32_DIV,  `RV32_DIVU, `RV32_REM,  `RV32_REMU:
            decode_o.op_reads_rf1 = 1'b1;
        default:
            decode_o.op_reads_rf1 = 1'b0;
    endcase
    
// declares if Op reads from second port of register file
always_comb
    unique casez (instruction_i)
        `RV32_BEQ,  `RV32_BNE,  `RV32_BLT, `RV32_BGE, `RV32_BLTU, `RV32_BGEU,   
        `RV32_SB,   `RV32_SH,   `RV32_SW,
        `RV32_ADD,  `RV32_SUB,  `RV32_SLL,    `RV32_SLT, `RV32_SLTU, `RV32_XOR,   
        `RV32_SRL,  `RV32_SRA,  `RV32_OR,    `RV32_AND,   
        `RV32_MUL,  `RV32_MULH, `RV32_MULHSU, `RV32_MULHU, 
        `RV32_DIV,  `RV32_DIVU, `RV32_REM,  `RV32_REMU:
            decode_o.op_reads_rf2 = 1'b1;
        default:
            decode_o.op_reads_rf2 = 1'b0;
    endcase

// RISC-V edit: declares if Op is AUIPC
always_comb
  unique casez (instruction_i[6:0])
    `RV32_AUIPC_OP:
      decode_o.op_is_auipc = 1'b1;
    default:
      decode_o.op_is_auipc = 1'b0;
  endcase

endmodule
