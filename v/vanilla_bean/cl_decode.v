`include "parameters.v"
`include "definitions.v"

/**
 *  This module defines a decode unit that looks at the instruction
 *  and sets a bunch of control signals that describe the use of the
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

`ifdef bsg_FPU
        `RV32_LOAD_FP, `RV32_STORE_FP:
            //we have to handle the FLD/FSD
            decode_o.is_mem_op = (instruction_i.funct3 == `RV32_FLS_FUN3)
                               | (instruction_i.funct3 == `RV32_FDLS_FUN3);
`endif
        `RV32_LOAD, `RV32_STORE, `RV32_AMO:
            decode_o.is_mem_op = 1'b1;
        default:
            decode_o.is_mem_op = 1'b0;
    endcase

// Is byte Op -- byte ld/st operation
always_comb
    unique casez (instruction_i.funct3)
        3'b000, 3'b100: //LB, LBU,SB:
            decode_o.is_byte_op = decode_o.is_mem_op;
        default:
            decode_o.is_byte_op = 1'b0;
    endcase

// Is hex Op -- hex ld/st operation
always_comb
    unique casez (instruction_i.funct3)
        3'b001, 3'b101: //LH, LHU, SH
            decode_o.is_hex_op = decode_o.is_mem_op;
        default:
            decode_o.is_hex_op = 1'b0;
    endcase

// Is Load Op -- data memory load operation
always_comb
    unique casez (instruction_i.op)
`ifdef bsg_FPU
        `RV32_LOAD_FP:
            //We have to handle the FLD/FSD instruction.
            decode_o.is_load_op= (instruction_i.funct3 == `RV32_FLS_FUN3)
                               | (instruction_i.funct3 == `RV32_FDLS_FUN3);
`endif
        //currently we only supports lr, swap.aq, swap.rl AMO. further extensions should
        //decode more details
        `RV32_LOAD, `RV32_AMO:
            decode_o.is_load_op = 1'b1;
        default:
            decode_o.is_load_op = 1'b0;
    endcase

// Is load unsigned
assign decode_o.is_load_unsigned = (instruction_i.funct3[2]) ? decode_o.is_load_op : 1'b0;

// Is Store Op -- data memory store operation
always_comb
    unique casez (instruction_i.op)
`ifdef bsg_FPU
        `RV32_STORE_FP:
            //we have to handle the FLD/FSD
            decode_o.is_store_op= (instruction_i.funct3 == `RV32_FLS_FUN3)
                               |  (instruction_i.funct3 == `RV32_FDLS_FUN3);
`endif
        `RV32_STORE:
            decode_o.is_store_op = 1'b1;
        `RV32_AMO: // amoswap.aq and amoswap.rl
            decode_o.is_store_op =( instruction_i.funct7 == `RV32_AMOSWAP_AQ_FUN7)
                                 |( instruction_i.funct7 == `RV32_AMOSWAP_RL_FUN7);
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

`ifdef  bsg_FPU
        `RV32_SYSTEM:
            decode_o.op_reads_rf1 = ~instruction_i.funct3[2];
        `RV32_LOAD_FP, `RV32_STORE_FP:
            decode_o.op_reads_rf1 = 1'b1;
        `RV32_OP_FP:
            unique casez( instruction_i.funct7 )
                `RV32_FMV_S_X_FUN7:
                    decode_o.op_reads_rf1 = 1'b1;
                default:
                    decode_o.op_reads_rf1 = 1'b0;
            endcase
`endif
        default:
            decode_o.op_reads_rf1 = 1'b0;
    endcase

// declares if Op reads from second port of register file
// According the ISA, LR instruction don't read rs2
always_comb
    unique casez (instruction_i.op)
        `RV32_BRANCH, `RV32_STORE, `RV32_OP :
            decode_o.op_reads_rf2 = 1'b1;
        `RV32_AMO: //swap reads rs2
            decode_o.op_reads_rf2 = ( instruction_i.funct7 == `RV32_AMOSWAP_AQ_FUN7)
                                   |( instruction_i.funct7 == `RV32_AMOSWAP_RL_FUN7);

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

//+----------------------------------------------
//|
//|     RISC-V edit: "M" STANDARD EXTENSION
//|
//+----------------------------------------------
assign decode_o.is_md_instr  = (instruction_i.op == `RV32_OP)
                             & (instruction_i.funct7 == 7'b0000001);

//memory order related instructions.
assign decode_o.op_is_load_reservation = instruction_i ==? `RV32_LR_W;
assign decode_o.op_is_lr_acq           = decode_o.op_is_load_reservation
                                       & instruction_i[26] ;



assign decode_o.is_fence_op  =  ( instruction_i.op       == `RV32_MISC_MEM  )
                              &&( instruction_i.funct3   == `RV32_FENCE_FUN3)
                              &&( instruction_i.rs1      == 5'b0            )
                              &&( instruction_i.rd       == 5'b0            )
                              &&( instruction_i[31:28]   == 4'b0            );

assign decode_o.is_fence_i_op = ( instruction_i.op       == `RV32_MISC_MEM    )
                              &&( instruction_i.funct3   == `RV32_FENCE_I_FUN3)
                              &&( instruction_i.rs1      == 5'b0              )
                              &&( instruction_i.rd       == 5'b0              )
                              &&( instruction_i[31:20]   == 12'b0             );

assign decode_o.op_is_swap_aq = ( instruction_i.op       == `RV32_AMO         )
                              &&( instruction_i.funct3   == 3'b010            )
                              &&( instruction_i.funct7   == `RV32_AMOSWAP_AQ_FUN7   );

assign decode_o.op_is_swap_rl = ( instruction_i.op       == `RV32_AMO         )
                              &&( instruction_i.funct3   == 3'b010            )
                              &&( instruction_i.funct7   == `RV32_AMOSWAP_RL_FUN7   );
endmodule
