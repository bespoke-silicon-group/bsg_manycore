`include "parameters.vh"
`include "definitions.vh"

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


// Op Writes RF -- register file write operation
always_comb begin
  if (instruction_i.rd == 0) begin
    decode_o.op_writes_rf = 1'b0; // reg 0 is always 0
  end
  else begin
    unique casez (instruction_i.op)
        `RV32_LUI_OP, `RV32_AUIPC_OP, `RV32_JAL_OP, `RV32_JALR_OP,
        `RV32_LOAD,   `RV32_OP,       `RV32_OP_IMM, `RV32_AMO:
            decode_o.op_writes_rf = 1'b1;

        `RV32_OP_FP: begin
            decode_o.op_writes_rf = 
              (instruction_i.funct7 == `RV32_FCMP_S_FUN7) // FEQ, FLT, FLE
              | ((instruction_i.funct7 == `RV32_FCLASS_S_FUN7) & (instruction_i.rs2 == 5'b00000)) // FCLASS, FMV.X.W
              | ((instruction_i.funct7 == `RV32_FCVT_S_F2I_FUN7)); // FCVT.W.S, FCVT.WU.S
        end

        default:
            decode_o.op_writes_rf = 1'b0;
    endcase
  end
end

// Is Mem Op -- data memory operation
always_comb begin
    unique casez (instruction_i.op)

        `RV32_LOAD, `RV32_STORE, `RV32_AMO:
            decode_o.is_mem_op = 1'b1;
        `RV32_LOAD_FP, `RV32_STORE_FP:
            decode_o.is_mem_op = 1'b1;
        default:
            decode_o.is_mem_op = 1'b0;
    endcase
end

// Is byte Op -- byte ld/st operation
always_comb begin
    unique casez (instruction_i.funct3)
        3'b000, 3'b100: //LB, LBU,SB:
            decode_o.is_byte_op = decode_o.is_mem_op;
        default:
            decode_o.is_byte_op = 1'b0;
    endcase
end

// Is hex Op -- hex ld/st operation
always_comb begin
    unique casez (instruction_i.funct3)
        3'b001, 3'b101: //LH, LHU, SH
            decode_o.is_hex_op = decode_o.is_mem_op;
        default:
            decode_o.is_hex_op = 1'b0;
    endcase
end

// Is Load Op -- data memory load operation
always_comb
    unique casez (instruction_i.op)
        //currently we only supports lr, swap.aq, swap.rl AMO. further extensions should
        //decode more details
        `RV32_LOAD:
            decode_o.is_load_op = 1'b1; 
        `RV32_AMO:
            decode_o.is_load_op =(instruction_i.funct7 != `RV32_AMOSWAP_RL_FUN7);
        `RV32_LOAD_FP: begin // FLW
            decode_o.is_load_op = 1'b1;
        end
        default:
            decode_o.is_load_op = 1'b0;
    endcase

// Is load unsigned
assign decode_o.is_load_unsigned = (instruction_i.funct3[2])
  ? decode_o.is_load_op
  : 1'b0;

//always_comb
//    unique casez (instruction_i.op)
//        `RV32_LOAD:
//          decode_o.is_load_unsigned = instruction_i.funct3[2];
        //`RV32_LOAD_FP: // FLW
        //  decode.is_load_unsigned = 1'b0;
//        default: 
//          decode_o.is_load_unsigned = 1'b0;
//    endcase

// Is Store Op -- data memory store operation
always_comb
    unique casez (instruction_i.op)
        `RV32_STORE:
            decode_o.is_store_op = 1'b1;
        `RV32_AMO: // amoswap.aq and amoswap.rl
            decode_o.is_store_op = (instruction_i.funct7 == `RV32_AMOSWAP_RL_FUN7);
        `RV32_STORE_FP: // FSW
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
        `RV32_OP_FP: begin
            decode_o.op_reads_rf1 = 
              (instruction_i.funct7 == `RV32_FCVT_S_I2F_FUN7) // FCVT.S.W, FCVT.S.WU
              | (instruction_i.funct7 == `RV32_FMV_W_X_FUN7); // FMV.W.X
        end
        `RV32_LOAD_FP, `RV32_STORE_FP: begin // FLW, FSW
            decode_o.op_reads_rf1 = 1'b1;
        end
        default:
            decode_o.op_reads_rf1 = 1'b0;
    endcase

// declares if Op reads from second port of register file
// According the ISA, LR instruction don't read rs2
always_comb
    unique casez (instruction_i.op)
        `RV32_BRANCH, `RV32_STORE, `RV32_OP:
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


//+----------------------------------------------
//|
//|     RISC-V edit: "F" STANDARD EXTENSION
//|
//+----------------------------------------------

always_comb begin

  unique casez (instruction_i)

    // Rtype float instr
    `RV32_FADD_S,  `RV32_FSUB_S,   `RV32_FMUL_S,
    `RV32_FSGNJ_S, `RV32_FSGNJN_S, `RV32_FSGNJX_S,
    `RV32_FMIN_S,  `RV32_FMAX_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b1;
      decode_o.is_fp_wb = 1'b1;
      decode_o.is_fp_instr = 1'b1;
      decode_o.is_signed_int = 1'b0;
    end

    `RV32_FEQ_S, `RV32_FLT_S, `RV32_FLE_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b1;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end

    `RV32_FCLASS_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end
 
    // i2f (signed int)
    `RV32_FCVT_S_W: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b1;
      decode_o.is_fp_instr = 1'b1;
      decode_o.is_signed_int = 1'b1;
    end

    // i2f (unsigned int)
    `RV32_FCVT_S_WU: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b1;
      decode_o.is_fp_instr = 1'b1;
      decode_o.is_signed_int = 1'b0;
    end
   
    // f2i (signed int)
    `RV32_FCVT_W_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b1;
    end

    // f2i (unsigned int)
    `RV32_FCVT_WU_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end

    // FMV (fp -> int)
    `RV32_FMV_X_W: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end

    // FMV (int -> fp)
    `RV32_FMV_W_X: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b1;
      decode_o.is_fp_instr = 1'b1;
      decode_o.is_signed_int = 1'b0;
    end

    // Float load
    `RV32_FLW_S: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b1;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end

    // Float store
    `RV32_FSW_S: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b1;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end

    default: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.is_fp_wb = 1'b0;
      decode_o.is_fp_instr = 1'b0;
      decode_o.is_signed_int = 1'b0;
    end

  endcase

end


endmodule
