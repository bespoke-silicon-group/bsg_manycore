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
      `VANILLA_LUI_OP, `VANILLA_AUIPC_OP,
      `VANILLA_JAL_OP, `VANILLA_JALR_OP,
      `VANILLA_LOAD, `VANILLA_OP,
      `VANILLA_OP_IMM, `VANILLA_AMO_OP: begin
        decode_o.write_rd = 1'b1;
      end
      `VANILLA_OP_FP: begin
        decode_o.write_rd = 
          (instruction_i.funct7 == `VANILLA_FCMP_S_FUN7) // FEQ, FLT, FLE
          | ((instruction_i.funct7 == `VANILLA_FCLASS_S_FUN7) & (instruction_i.rs2 == 5'b00000)) // FCLASS, FMV.X.W
          | ((instruction_i.funct7 == `VANILLA_FCVT_S_F2I_FUN7)); // FCVT.W.S, FCVT.WU.S
      end
      `VANILLA_SYSTEM: begin
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
    `VANILLA_JALR_OP, `VANILLA_BRANCH,
    `VANILLA_LOAD, `VANILLA_STORE,
    `VANILLA_OP, `VANILLA_OP_IMM,
    `VANILLA_AMO_OP: begin
      decode_o.read_rs1 = 1'b1;
    end
   `VANILLA_OP_FP: begin
     decode_o.read_rs1 = 
       (instruction_i.funct7 == `VANILLA_FCVT_S_I2F_FUN7) // FCVT.S.W, FCVT.S.WU
       | (instruction_i.funct7 == `VANILLA_FMV_W_X_FUN7); // FMV.W.X
    end
    `VANILLA_LOAD_FP, `VANILLA_STORE_FP: begin // FLW, FSW
      decode_o.read_rs1 = 1'b1;
     end
    `VANILLA_SYSTEM: begin
      case (instruction_i.funct3)
        `VANILLA_CSRRW_FUN3, `VANILLA_CSRRS_FUN3, `VANILLA_CSRRC_FUN3: begin
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
    `VANILLA_BRANCH, `VANILLA_STORE, `VANILLA_OP: begin
      decode_o.read_rs2 = 1'b1;
    end
    `VANILLA_AMO_OP: begin
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
wire is_vanilla_load = (instruction_i.op == `VANILLA_LOAD);
wire is_vanilla_store = (instruction_i.op == `VANILLA_STORE);
assign decode_o.is_load_op = is_vanilla_load | (instruction_i.op == `VANILLA_LOAD_FP);
assign decode_o.is_store_op = is_vanilla_store | (instruction_i.op == `VANILLA_STORE_FP);

assign decode_o.is_byte_op =
  (is_vanilla_load & (instruction_i.funct3 ==? 3'b?00)) |
  (is_vanilla_store & (instruction_i.funct3 == 3'b000));
assign decode_o.is_hex_op =
  (is_vanilla_load & (instruction_i.funct3 ==? 3'b?01)) |
  (is_vanilla_store & (instruction_i.funct3 == 3'b001));
assign decode_o.is_load_unsigned =
  is_vanilla_load & (instruction_i.funct3 ==? 3'b10?);

// Branch & Jump
assign decode_o.is_branch_op = instruction_i.op ==? `VANILLA_BRANCH;
assign decode_o.is_jal_op = instruction_i.op == `VANILLA_JAL_OP;
assign decode_o.is_jalr_op = instruction_i.op == `VANILLA_JALR_OP;

// MEMORY FENCE
always_comb begin
  decode_o.is_fence_op = 1'b0;
  decode_o.is_barsend_op = 1'b0;
  decode_o.is_barrecv_op = 1'b0;
  if (instruction_i ==? `VANILLA_FENCE_OP) begin
    // fence FM
    unique casez (instruction_i[31:28])
      `VANILLA_FENCE_FM: decode_o.is_fence_op = 1'b1;
      `VANILLA_BARSEND_FM: decode_o.is_barsend_op = 1'b1;
      `VANILLA_BARRECV_FM: decode_o.is_barrecv_op = 1'b1;
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
  if (instruction_i.op == `VANILLA_SYSTEM) begin
    case (instruction_i.funct3)
      `VANILLA_CSRRW_FUN3,
      `VANILLA_CSRRS_FUN3,
      `VANILLA_CSRRC_FUN3,
      `VANILLA_CSRRWI_FUN3,
      `VANILLA_CSRRSI_FUN3,
      `VANILLA_CSRRCI_FUN3: begin
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
assign decode_o.is_mret_op = (instruction_i == `VANILLA_MRET);


//+----------------------------------------------
//|
//|     RISC-V edit: "M" STANDARD EXTENSION
//|
//+----------------------------------------------

assign decode_o.is_imul_op = (instruction_i ==? `VANILLA_MUL);

always_comb begin
  unique casez (instruction_i)
    `VANILLA_DIV: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eDIV;
    end    
    `VANILLA_DIVU: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eDIVU;
    end    
    `VANILLA_REM: begin
      decode_o.is_idiv_op = 1'b1;
      decode_o.idiv_op = eREM;
    end    
    `VANILLA_REMU: begin
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
assign decode_o.is_lr_op = (instruction_i ==? `VANILLA_LR_W);
assign decode_o.is_lr_aq_op = (instruction_i ==? `VANILLA_LR_W_AQ);

// ATOMICS
always_comb begin
  unique casez (instruction_i)
    `VANILLA_AMOSWAP_W: begin
      decode_o.is_amo_op = 1'b1;
      decode_o.amo_type = e_vanilla_amoswap;
    end    
    `VANILLA_AMOOR_W: begin
      decode_o.is_amo_op = 1'b1;
      decode_o.amo_type = e_vanilla_amoor;
    end
    `VANILLA_AMOADD_W: begin
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
    `VANILLA_FADD_S,  `VANILLA_FSUB_S,   `VANILLA_FMUL_S,
    `VANILLA_FSGNJ_S, `VANILLA_FSGNJN_S, `VANILLA_FSGNJX_S,
    `VANILLA_FMIN_S,  `VANILLA_FMAX_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // compare
    `VANILLA_FEQ_S, `VANILLA_FLT_S, `VANILLA_FLE_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // classify
    `VANILLA_FCLASS_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // i2f (signed int)
    `VANILLA_FCVT_S_W, `VANILLA_FCVT_S_WU: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // f2i
    `VANILLA_FCVT_W_S, `VANILLA_FCVT_WU_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // FMV (fp -> int)
    `VANILLA_FMV_X_W: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b1;
    end
    // FMV (int -> fp)
    `VANILLA_FMV_W_X: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // Float load
    `VANILLA_FLW_S: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b0;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b0;
    end
    // Float store
    `VANILLA_FSW_S: begin
      decode_o.read_frs1 = 1'b0;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b0;
      decode_o.write_frd = 1'b0;
      decode_o.is_fp_op = 1'b0;
    end
    // FMA
    `VANILLA_FMADD_S, `VANILLA_FMSUB_S, `VANILLA_FNMSUB_S, `VANILLA_FNMADD_S: begin
      decode_o.read_frs1 = 1'b1;
      decode_o.read_frs2 = 1'b1;
      decode_o.read_frs3 = 1'b1;
      decode_o.write_frd = 1'b1;
      decode_o.is_fp_op = 1'b1;
    end
    // FDIV, SQRT
    `VANILLA_FDIV_S, `VANILLA_FSQRT_S: begin
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
    `VANILLA_FADD_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFADD;
    end
    `VANILLA_FSUB_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSUB;
    end
    `VANILLA_FMUL_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMUL;
    end
    `VANILLA_FSGNJ_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSGNJ;
    end
    `VANILLA_FSGNJN_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSGNJN;
    end
    `VANILLA_FSGNJX_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFSGNJX;
    end
    `VANILLA_FMIN_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMIN;
    end
    `VANILLA_FMAX_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMAX;
    end
    // i2f signed
    `VANILLA_FCVT_S_W: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFCVT_S_W;
    end
    // i2f unsigned
    `VANILLA_FCVT_S_WU: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFCVT_S_WU;
    end
    // move i->f
    `VANILLA_FMV_W_X: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMV_W_X;
    end
    `VANILLA_FMADD_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMADD;
    end
    `VANILLA_FMSUB_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFMSUB;
    end
    `VANILLA_FNMSUB_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFNMSUB;
    end
    `VANILLA_FNMADD_S: begin
      fp_decode_o.is_fpu_float_op = 1'b1;
      fp_decode_o.fpu_float_op = eFNMADD;
    end
    `VANILLA_FDIV_S: begin
      fp_decode_o.is_fdiv_op = 1'b1;
    end
    `VANILLA_FSQRT_S: begin
      fp_decode_o.is_fsqrt_op = 1'b1;
    end
    `VANILLA_FEQ_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFEQ;
    end
    `VANILLA_FLE_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFLE;
    end
    `VANILLA_FLT_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFLT;
    end
    // f2i signed
    `VANILLA_FCVT_W_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFCVT_W_S;
    end
    // f2i unsigned
    `VANILLA_FCVT_WU_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFCVT_WU_S;
    end
    `VANILLA_FCLASS_S: begin
      fp_decode_o.is_fpu_int_op = 1'b1;
      fp_decode_o.fpu_int_op = eFCLASS;
    end
    // move f->i
    `VANILLA_FMV_X_W: begin
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
    `VANILLA_MULH, `VANILLA_MULHSU, `VANILLA_MULHU: begin
      decode_o.unsupported = 1'b1;
    end
    default: begin
      decode_o.unsupported = 1'b0;
    end
  endcase
end

endmodule
