/**
 *
 *  cl_decode.v
 *
 *  instruction decoder.
 *
 *  This module defines a decode unit that looks at the instruction
 *  and sets a bunch of control signals that describe the use of the
 *  instruction.
 *
 *
 */


module cl_decode
import bsg_vanilla_pkg::*;
import bsg_manycore_pkg::*;
(
  input instruction_s instruction_i
  , output decode_s decode_o
  , output fp_float_decode_s fp_float_decode_o
  , output fp_int_decode_s fp_int_decode_o
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

// Is byte Op -- byte ld/st operation
assign decode_o.is_byte_op =
  ((instruction_i.op == `RV32_LOAD) & (instruction_i.funct3 ==? 3'b?00)) |
  ((instruction_i.op == `RV32_STORE) & (instruction_i.funct3 == 3'b000));

// Is hex Op -- hex ld/st operation (half)
assign decode_o.is_hex_op =
  ((instruction_i.op == `RV32_LOAD) & (instruction_i.funct3 ==? 3'b?01)) |
  ((instruction_i.op == `RV32_STORE) & (instruction_i.funct3 == 3'b001));

// Is Load Op -- data memory load operation
assign decode_o.is_load_op = 
  (instruction_i.op == `RV32_LOAD) |
  (instruction_i.op == `RV32_LOAD_FP);

// Is load unsigned
assign decode_o.is_load_unsigned =
  (instruction_i.op == `RV32_LOAD) &
  (instruction_i.funct3 ==? 3'b10?);


// Is Store Op -- data memory store operation
assign decode_o.is_store_op =
  (instruction_i.op == `RV32_STORE) |
  (instruction_i.op == `RV32_STORE_FP);
  

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
assign decode_o.is_jal_op = instruction_i.op == `RV32_JAL_OP;
assign decode_o.is_jalr_op = instruction_i.op == `RV32_JALR_OP;


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
        `RV32_AMO: // if it's not LR
            decode_o.op_reads_rf2 = (instruction_i.funct7 ==? 7'b00001??)
                                  | (instruction_i.funct7 ==? 7'b01000??);
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
assign decode_o.is_md_op  = (instruction_i.op == `RV32_OP)
                             & (instruction_i.funct7 == 7'b0000001);

//memory order related instructions.

assign decode_o.op_is_lr = (instruction_i ==? `RV32_LR_W)
  & ~instruction_i[26]
  & ~instruction_i[25];

assign decode_o.op_is_lr_aq = (instruction_i ==? `RV32_LR_W)
  & instruction_i[26]
  & ~instruction_i[25];

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

always_comb begin
  if ((instruction_i.op == `RV32_AMO) & (instruction_i.funct3 == 3'b010)) begin
    casez (instruction_i.funct7)
      // amoswap
      7'b00001??: begin
        decode_o.is_amo_op = 1'b1;
        decode_o.amo_type = e_amo_swap;
      end
      // amoor
      7'b01000??: begin
        decode_o.is_amo_op = 1'b1;
        decode_o.amo_type = e_amo_or;
      end
      default: begin
        decode_o.is_amo_op = 1'b0;
        decode_o.amo_type = e_amo_swap;
      end
    endcase
  end
  else begin
    decode_o.is_amo_op = 1'b0;
    decode_o.amo_type = e_amo_swap;
  end
end

assign decode_o.is_amo_aq = instruction_i[26];
assign decode_o.is_amo_rl = instruction_i[25];


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
      decode_o.op_writes_fp_rf = 1'b1;
      decode_o.is_fp_float_op = 1'b1;
      decode_o.is_fp_int_op = 1'b0;
    end

    // compare
    `RV32_FEQ_S, `RV32_FLT_S, `RV32_FLE_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b1;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b1;
    end

    // classify
    `RV32_FCLASS_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b1;
    end
 
    // i2f (signed int)
    `RV32_FCVT_S_W: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b1;
      decode_o.is_fp_float_op = 1'b1;
      decode_o.is_fp_int_op = 1'b0;
    end

    // i2f (unsigned int)
    `RV32_FCVT_S_WU: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b1;
      decode_o.is_fp_float_op = 1'b1;
      decode_o.is_fp_int_op = 1'b0;
    end
   
    // f2i (signed int)
    `RV32_FCVT_W_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b1;
    end

    // f2i (unsigned int)
    `RV32_FCVT_WU_S: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b1;
    end

    // FMV (fp -> int)
    `RV32_FMV_X_W: begin
      decode_o.op_reads_fp_rf1 = 1'b1;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b1;
    end

    // FMV (int -> fp)
    `RV32_FMV_W_X: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b1;
      decode_o.is_fp_float_op = 1'b1;
      decode_o.is_fp_int_op = 1'b0;
    end

    // Float load
    `RV32_FLW_S: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b1;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b0;
    end

    // Float store
    `RV32_FSW_S: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b1;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b0;
    end

    default: begin
      decode_o.op_reads_fp_rf1 = 1'b0;
      decode_o.op_reads_fp_rf2 = 1'b0;
      decode_o.op_writes_fp_rf = 1'b0;
      decode_o.is_fp_float_op = 1'b0;
      decode_o.is_fp_int_op = 1'b0;
    end

  endcase
end

// fp_decode_s
assign fp_float_decode_o.fadd_op        = instruction_i ==? `RV32_FADD_S;
assign fp_float_decode_o.fsub_op        = instruction_i ==? `RV32_FSUB_S;
assign fp_float_decode_o.fmul_op        = instruction_i ==? `RV32_FMUL_S;
assign fp_float_decode_o.fsgnj_op       = instruction_i ==? `RV32_FSGNJ_S;
assign fp_float_decode_o.fsgnjn_op      = instruction_i ==? `RV32_FSGNJN_S;
assign fp_float_decode_o.fsgnjx_op      = instruction_i ==? `RV32_FSGNJX_S;
assign fp_float_decode_o.fmin_op        = instruction_i ==? `RV32_FMIN_S;
assign fp_float_decode_o.fmax_op        = instruction_i ==? `RV32_FMAX_S;
assign fp_float_decode_o.fcvt_s_w_op    = instruction_i ==? `RV32_FCVT_S_W;
assign fp_float_decode_o.fcvt_s_wu_op   = instruction_i ==? `RV32_FCVT_S_WU;
assign fp_float_decode_o.fmv_w_x_op     = instruction_i ==? `RV32_FMV_W_X;

assign fp_int_decode_o.feq_op         = instruction_i ==? `RV32_FEQ_S;
assign fp_int_decode_o.fle_op         = instruction_i ==? `RV32_FLE_S;
assign fp_int_decode_o.flt_op         = instruction_i ==? `RV32_FLT_S;
assign fp_int_decode_o.fcvt_w_s_op    = instruction_i ==? `RV32_FCVT_W_S;
assign fp_int_decode_o.fcvt_wu_s_op   = instruction_i ==? `RV32_FCVT_WU_S;
assign fp_int_decode_o.fclass_op      = instruction_i ==? `RV32_FCLASS_S;
assign fp_int_decode_o.fmv_x_w_op     = instruction_i ==? `RV32_FMV_X_W;

endmodule
