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
    unique casez (instruction_i.op)
        `RV32_LUI_OP, `RV32_AUIPC_OP, `RV32_JAL_OP, `RV32_JALR_OP,
        `RV32_LOAD,   `RV32_OP,       `RV32_OP_IMM, `RV32_AMO: 
            decode_o.op_writes_rf = 1'b1;
        default:
            decode_o.op_writes_rf = 1'b0;
    endcase

// Is Mem Op -- data memory operation
always_comb
    unique casez (instruction_i.op)
        `RV32_LOAD, `RV32_STORE:
            decode_o.is_mem_op = 1'b1;
        default:
            decode_o.is_mem_op = 1'b0;
    endcase

// Is byte Op -- byte ld/st operation
always_comb
    unique casez (instruction_i.funct3[1:0])
        2'b00:
            decode_o.is_byte_op = decode_o.is_mem_op;
        default:
            decode_o.is_byte_op = 1'b0;
    endcase

// Is hex Op -- hex ld/st operation
always_comb
    unique casez (instruction_i.funct3[1:0])
        2'b01:
            decode_o.is_hex_op = decode_o.is_mem_op;
        default:
            decode_o.is_hex_op = 1'b0;
    endcase

// Is Load Op -- data memory load operation
always_comb
    unique casez (instruction_i.op)
        `RV32_LOAD:
            decode_o.is_load_op = 1'b1;
        default:
            decode_o.is_load_op = 1'b0;
    endcase

// Is load unsigned
assign decode_o.is_load_unsigned = (instruction_i.funct3[2]) ? decode_o.is_load_op : 1'b0;

// Is Store Op -- data memory store operation
always_comb
    unique casez (instruction_i.op)
        `RV32_STORE:
            decode_o.is_store_op = 1'b1;
        default:
            decode_o.is_store_op = 1'b0;
  endcase

// Is Branch Op -- pc branching operation
// `kBL is actually like jump since there is
// no condition for it
always_comb
    unique casez (instruction_i.op)
        `RV32_BRANCH:
            decode_o.is_branch_op = 1'b1;
        default:
            decode_o.is_branch_op = 1'b0;
    endcase

// Is Jump Op -- pc jumping operation
always_comb
    unique casez (instruction_i.op)
        `RV32_JAL_OP, `RV32_JALR_OP:
            decode_o.is_jump_op = 1'b1;
        default:
            decode_o.is_jump_op = 1'b0;
    endcase

// declares if OP reads from first port of register file
always_comb
    unique casez (instruction_i.op)
        `RV32_JALR_OP, `RV32_BRANCH, `RV32_LOAD, `RV32_STORE,
        `RV32_OP,      `RV32_OP_IMM, `RV32_AMO:
            decode_o.op_reads_rf1 = 1'b1;
        default:
            decode_o.op_reads_rf1 = 1'b0;
    endcase
    
// declares if Op reads from second port of register file
always_comb
    unique casez (instruction_i.op)
        `RV32_BRANCH, `RV32_STORE, `RV32_OP, `RV32_AMO:
            decode_o.op_reads_rf2 = 1'b1;
        default:
            decode_o.op_reads_rf2 = 1'b0;
    endcase

// RISC-V edit: declares if Op is AUIPC
always_comb
  unique casez (instruction_i.op)
    `RV32_AUIPC_OP:
      decode_o.op_is_auipc = 1'b1;
    default:
      decode_o.op_is_auipc = 1'b0;
  endcase

endmodule
