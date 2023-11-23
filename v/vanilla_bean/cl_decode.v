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

`include "bsg_vanilla_defines.vh"
`include "bsg_riscv_defines.vh"

module cl_decode
import bsg_vanilla_pkg::*;
import bsg_manycore_pkg::*;
(
  input instruction_s instruction_i
  , output decode_s decode_o
  , output fp_decode_s fp_decode_o
);


// Op Writes RF -- register file write operation
always_comb begin
  if (instruction_i.rd == 0) begin
    decode_o.write_rd = 1'b0; // reg 0 is always 0
  end
  else begin
    unique casez (instruction_i.op)
      `RV32_LUI_OP, `RV32_AUIPC_OP,
      `RV32_JAL_OP, `RV32_JALR_OP,
      `RV32_LOAD, `RV32_OP,
      `RV32_OP_IMM, `RV32_AMO_OP: begin
        decode_o.write_rd = 1'b1;
      end
      `RV32_OP_FP: begin
        decode_o.write_rd = 
          (instruction_i.funct7 == `RV32_FCMP_S_FUN7) // FEQ, FLT, FLE
          | ((instruction_i.funct7 == `RV32_FCLASS_S_FUN7) & (instruction_i.rs2 == 5'b00000)) // FCLASS, FMV.X.W
          | ((instruction_i.funct7 == `RV32_FCVT_S_F2I_FUN7)); // FCVT.W.S, FCVT.WU.S
      end
      `RV32_SYSTEM: begin
        decode_o.write_rd = 1'b1; // CSRRW, CSRRS
      end
      default: begin
        decode_o.write_rd = 1'b0;
      end
    endcase
  end
end

// declares if OP reads from first port of register file
always_comb begin
  unique casez (instruction_i.op)
    `RV32_JALR_OP, `RV32_BRANCH,
    `RV32_LOAD, `RV32_STORE,
    `RV32_OP, `RV32_OP_IMM,
    `RV32_AMO_OP: begin
      decode_o.read_rs1 = 1'b1;
    end
   `RV32_OP_FP: begin
     decode_o.read_rs1 = 
       (instruction_i.funct7 == `RV32_FCVT_S_I2F_FUN7) // FCVT.S.W, FCVT.S.WU
       | (instruction_i.funct7 == `RV32_FMV_W_X_FUN7); // FMV.W.X
    end
    `RV32_LOAD_FP, `RV32_STORE_FP: begin // FLW, FSW
      decode_o.read_rs1 = 1'b1;
     end
    `RV32_SYSTEM: begin
      case (instruction_i.funct3)
        `RV32_CSRRW_FUN3, `RV32_CSRRS_FUN3, `RV32_CSRRC_FUN3: begin
          decode_o.read_rs1 = 1'b1;
        end
        default: begin
          decode_o.read_rs1 = 1'b0;
        end
      endcase
    end
    default: begin
      decode_o.read_rs1 = 1'b0;
    end
  endcase
end

// declares if Op reads from second port of register file
always_comb begin
  unique casez (instruction_i.op)
    `RV32_BRANCH, `RV32_STORE, `RV32_OP: begin
      decode_o.read_rs2 = 1'b1;
    end
    `RV32_AMO_OP: begin
      // According the ISA, LR instruction don't read rs2
      decode_o.read_rs2 = (instruction_i.funct7 ==? 7'b00001??)   // amoswap
                            | (instruction_i.funct7 ==? 7'b01000??)  // amoor
                            | (instruction_i.funct7 ==? 7'b00000??); // amoadd
    end
    default: begin
      decode_o.read_rs2 = 1'b0;
    end
  endcase
end

// Load & Store
wire is_rv32_load = (instruction_i.op == `RV32_LOAD);
wire is_rv32_store = (instruction_i.op == `RV32_STORE);
assign decode_o.is_load_op = is_rv32_load | (instruction_i.op == `RV32_LOAD_FP);
assign decode_o.is_store_op = is_rv32_store | (instruction_i.op == `RV32_STORE_FP);

assign decode_o.is_byte_op =
  (is_rv32_load & (instruction_i.funct3 ==? 3'b?00)) |
  (is_rv32_store & (instruction_i.funct3 == 3'b000));
assign decode_o.is_hex_op =
  (is_rv32_load & (instruction_i.funct3 ==? 3'b?01)) |
  (is_rv32_store & (instruction_i.funct3 == 3'b001));
assign decode_o.is_load_unsigned =
  is_rv32_load & (instruction_i.funct3 ==? 3'b10?);

// Branch & Jump
assign decode_o.is_branch_op = instruction_i.op ==? `RV32_BRANCH;
assign decode_o.is_jal_op = instruction_i.op == `RV32_JAL_OP;
assign decode_o.is_jalr_op = instruction_i.op == `RV32_JALR_OP;

// MEMORY FENCE
always_comb begin
  decode_o.is_fence_op = 1'b0;
  decode_o.is_barsend_op = 1'b0;
  decode_o.is_barrecv_op = 1'b0;
  if (instruction_i ==? `RV32_FENCE_OP) begin
    // fence FM
    unique casez (instruction_i[31:28])
      `RV32_FENCE_FM: decode_o.is_fence_op = 1'b1;
      `RV32_BARSEND_FM: decode_o.is_barsend_op = 1'b1;
      `RV32_BARRECV_FM: decode_o.is_barrecv_op = 1'b1;
      default: begin
        decode_o.is_fence_op = 1'b0;
        decode_o.is_barsend_op = 1'b0;
        decode_o.is_barrecv_op = 1'b0;
      end
    endcase
  end
end

// CSR
always_comb begin
  if (instruction_i.op == `RV32_SYSTEM) begin
    case (instruction_i.funct3)
      `RV32_CSRRW_FUN3,
      `RV32_CSRRS_FUN3,
      `RV32_CSRRC_FUN3,
      `RV32_CSRRWI_FUN3,
      `RV32_CSRRSI_FUN3,
      `RV32_CSRRCI_FUN3: begin
        decode_o.is_csr_op = 1'b1;
      end
      default: begin
        decode_o.is_csr_op = 1'b0;
      end
    endcase
  end
  else begin
    decode_o.is_csr_op = 1'b0;
  end
end

// MRET
assign decode_o.is_mret_op = (instruction_i == `RV32_MRET);


//+----------------------------------------------
//|
//|     RISC-V edit: "M" STANDARD EXTENSION
//|
//+----------------------------------------------

assign decode_o.is_imul_op = (instruction_i ==? `RV32_MUL);

always_comb begin
  unique casez (instruction_i)
    `RV32_DIV: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eDIV;
    end    
    `RV32_DIVU: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eDIVU;
    end    
    `RV32_REM: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eREM;
    end    
    `RV32_REMU: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eREMU;
    end
    default: begin
      decode_o.is_idiv_op = 1'b0;
      decode_o.idiv_op = eDIV;
    end
  endcase
end


//+----------------------------------------------
//|
//|     RISC-V edit: "A" STANDARD EXTENSION
//|
//+----------------------------------------------

// LOAD RESERVATION
assign decode_o.is_lr_op = (instruction_i ==? `RV32_LR_W);
assign decode_o.is_lr_aq_op = (instruction_i ==? `RV32_LR_W_AQ);

// ATOMICS
always_comb begin
  unique casez (instruction_i)
    `RV32_AMOSWAP_W: begin
      decode_o.is_amo_op = 1'b1;
      decode_o.amo_type = e_vanilla_amoswap;
    end    
    `RV32_AMOOR_W: begin
      decode_o.is_amo_op = 1'b1;
      decode_o.amo_type = e_vanilla_amoor;
    end
    `RV32_AMOADD_W: begin
      decode_o.is_amo_op = 1'b1;
      decode_o.amo_type = e_vanilla_amoadd;
    end
    default: begin
      decode_o.is_amo_op = 1'b0;
      decode_o.amo_type = e_vanilla_amoswap;
    end
  endcase
end

assign decode_o.is_amo_aq = instruction_i[26];
assign decode_o.is_amo_rl = instruction_i[25];


//+----------------------------------------------
//|
//|     RISC-V edit: "F" STANDARD EXTENSION
//|
//+----------------------------------------------

always_comb begin
  decode_o.read_frs1 = 1'b0;
  decode_o.read_frs2 = 1'b0;
  decode_o.read_frs3 = 1'b0;
  decode_o.write_frd = 1'b0;
  decode_o.is_fp_op = 1'b0;
  unique casez (instruction_i)
    // Rtype float instr
    `RV32_FADD_S,  `RV32_FSUB_S,   `RV32_FMUL_S,
    `RV32_FSGNJ_S, `RV32_FSGNJN_S, `RV32_FSGNJX_S,
    `RV32_FMIN_S,  `RV32_FMAX_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // compare
    `RV32_FEQ_S, `RV32_FLT_S, `RV32_FLE_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // classify
    `RV32_FCLASS_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // i2f (signed int)
    `RV32_FCVT_S_W, `RV32_FCVT_S_WU: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // f2i
    `RV32_FCVT_W_S, `RV32_FCVT_WU_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // FMV (fp -> int)
    `RV32_FMV_X_W: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // FMV (int -> fp)
    `RV32_FMV_W_X: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // Float load
    `RV32_FLW_S: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b0;
    end
    // Float store
    `RV32_FSW_S: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b0;
    end
    // FMA
    `RV32_FMADD_S, `RV32_FMSUB_S, `RV32_FNMSUB_S, `RV32_FNMADD_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b1;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // FDIV, SQRT
    `RV32_FDIV_S, `RV32_FSQRT_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    default: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b0;
    end
  endcase
end


// fp_decode_s
always_comb begin
  fp_decode_o.is_fpu_float_op = 1'b0;
  fp_decode_o.is_fpu_int_op = 1'b0;
  fp_decode_o.is_fdiv_op = 1'b0;
  fp_decode_o.is_fsqrt_op = 1'b0;
  fp_decode_o.fpu_float_op = eFADD;
  fp_decode_o.fpu_int_op = eFEQ;

  unique casez (instruction_i)
    `RV32_FADD_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFADD;
    end
    `RV32_FSUB_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSUB;
    end
    `RV32_FMUL_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMUL;
    end
    `RV32_FSGNJ_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSGNJ;
    end
    `RV32_FSGNJN_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSGNJN;
    end
    `RV32_FSGNJX_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSGNJX;
    end
    `RV32_FMIN_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMIN;
    end
    `RV32_FMAX_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMAX;
    end
    // i2f signed
    `RV32_FCVT_S_W: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFCVT_S_W;
    end
    // i2f unsigned
    `RV32_FCVT_S_WU: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFCVT_S_WU;
    end
    // move i->f
    `RV32_FMV_W_X: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMV_W_X;
    end
    `RV32_FMADD_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMADD;
    end
    `RV32_FMSUB_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMSUB;
    end
    `RV32_FNMSUB_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFNMSUB;
    end
    `RV32_FNMADD_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFNMADD;
    end
    `RV32_FDIV_S: begin
      fp_decode_o.is_fdiv_op = 1'b1;
    end
    `RV32_FSQRT_S: begin
      fp_decode_o.is_fsqrt_op = 1'b1;
    end
    `RV32_FEQ_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFEQ;
    end
    `RV32_FLE_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFLE;
    end
    `RV32_FLT_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFLT;
    end
    // f2i signed
    `RV32_FCVT_W_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFCVT_W_S;
    end
    // f2i unsigned
    `RV32_FCVT_WU_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFCVT_WU_S;
    end
    `RV32_FCLASS_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFCLASS;
    end
    // move f->i
    `RV32_FMV_X_W: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFMV_X_W;
    end
    default: begin
      fp_decode_o.is_fpu_float_op = 1'b0;
      fp_decode_o.is_fpu_int_op = 1'b0;
      fp_decode_o.is_fdiv_op = 1'b0;
      fp_decode_o.is_fsqrt_op = 1'b0;
      fp_decode_o.fpu_float_op = eFADD;
      fp_decode_o.fpu_int_op = eFEQ;
    end
  endcase
end

// Unsupported ops:
// mulh, mulhsu, mulhu
always_comb begin
  unique casez (instruction_i)
    `RV32_MULH, `RV32_MULHSU, `RV32_MULHU: begin
      decode_o.unsupported = 1'b1;
    end
    default: begin
      decode_o.unsupported = 1'b0;
    end
  endcase
end

endmodule

