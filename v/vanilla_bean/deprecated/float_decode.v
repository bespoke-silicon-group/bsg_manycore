`include "parameters.vh"
`include "definitions.vh"
`include "float_parameters.vh"
`include "float_definitions.vh"

/**
 *  This module defines a decode unit that looks at the instruction
 *  and sets a bunch of control signals that descibe the use of the
 *  instruction.
 */
module float_decode
(
    input  instruction_s f_instruction_i,
    output f_decode_s    f_decode_o
);


// Op Writes RF -- integer register file write operation
always_comb
    unique casez (f_instruction_i.op)
        `RV32_SYSTEM:
            f_decode_o.op_writes_rf = 1'b1;
        `RV32_OP_FP:
            unique casez(f_instruction_i.funct7)
                // FMV_X_S is the same with FCLASS
                `RV32_FCVT_W_S_FUN7, `RV32_FMV_X_S_FUN7, //`RV32_FCLASS_FUN7,
                `RV32_FCMP_FUN7:
                    f_decode_o.op_writes_rf = 1'b1;

                default:
                    f_decode_o.op_writes_rf = 1'b0;
            endcase 
        default:
            f_decode_o.op_writes_rf = 1'b0;
    endcase

// Is Mem Op -- data memory operation
always_comb
    unique casez (f_instruction_i.op)
        `RV32_LOAD_FP, `RV32_STORE_FP:
            //We have to handle the FLD/FSD instruction
            f_decode_o.is_mem_op = (f_instruction_i.funct3 == `RV32_FLS_FUN3)
                                 | (f_instruction_i.funct3 == `RV32_FDLS_FUN3);
        default:
            f_decode_o.is_mem_op = 1'b0;
    endcase


// Is Load Op -- data memory load operation
always_comb
    unique casez (f_instruction_i.op)
        `RV32_LOAD_FP:
            //We have to handle the FLD/FSD instruction
            f_decode_o.is_load_op = (f_instruction_i.funct3 == `RV32_FLS_FUN3)
                                  | (f_instruction_i.funct3 == `RV32_FDLS_FUN3);
        default:
            f_decode_o.is_load_op = 1'b0;
    endcase

// Is Store Op -- data memory store operation
always_comb
    unique casez (f_instruction_i.op)
        `RV32_STORE_FP:
            //We have to handle the FLD/FSD instruction
            f_decode_o.is_store_op = (f_instruction_i.funct3 == `RV32_FLS_FUN3)
                                   | (f_instruction_i.funct3 == `RV32_FDLS_FUN3);
        default:
            f_decode_o.is_store_op = 1'b0;
  endcase

// declares if Op writes to the floating register file
always_comb
    unique casez (f_instruction_i.op)
        `RV32_LOAD_FP:
            //We have to handle the FLD/FSD instruction
            f_decode_o.op_writes_frf = (f_instruction_i.funct3 == `RV32_FLS_FUN3)
                                     | (f_instruction_i.funct3 == `RV32_FDLS_FUN3);
        `RV32_MADD, `RV32_MSUB, `RV32_NMADD, `RV32_NMSUB:
            f_decode_o.op_writes_frf = 1'b1;
        `RV32_OP_FP:
            unique casez( f_instruction_i.funct7 )
                `RV32_FADD_FUN7, `RV32_FSUB_FUN7, `RV32_FMUL_FUN7,
                `RV32_FDIV_FUN7, `RV32_FSQRT_FUN7,`RV32_FMINMAX_FUN7,
                `RV32_FMV_S_X_FUN7, `RV32_FCVT_S_W_FUN7,`RV32_FSGN_FUN7:
                    f_decode_o.op_writes_frf = 1'b1;
                default:
                    f_decode_o.op_writes_frf = 1'b0;
            endcase
        default:
            f_decode_o.op_writes_frf = 1'b0;
    endcase

// declares if Op should be send to FAM 
always_comb
    unique casez( f_instruction_i.op )
        `RV32_MADD,   `RV32_MSUB,  `RV32_NMADD,      `RV32_NMSUB:
           f_decode_o.is_fam_op = 1'b1; 
        `RV32_OP_FP:
                unique casez( f_instruction_i.funct7 )
                `RV32_FADD_FUN7, `RV32_FSUB_FUN7, `RV32_FMUL_FUN7,
                `RV32_FDIV_FUN7, `RV32_FSQRT_FUN7:
                    f_decode_o.is_fam_op = 1'b1; 
                default:
                    f_decode_o.is_fam_op = 1'b0;
            endcase
        default
            f_decode_o.is_fam_op = 1'b0;
    endcase

// declares if Op should be execute by FPI  
always_comb
    unique casez( f_instruction_i.op )
        `RV32_SYSTEM:
            f_decode_o.is_fpi_op = 1'b1;
        `RV32_OP_FP:
                unique casez( f_instruction_i.funct7 )
                // FMV_X_S is the same with FCLASS
                `RV32_FSGN_FUN7, `RV32_FCVT_W_S_FUN7,`RV32_FCVT_S_W_FUN7,
                `RV32_FMV_S_X_FUN7, `RV32_FMV_X_S_FUN7,//`RV32_FCLASS_FUN7,
                `RV32_FCMP_FUN7,`RV32_FMINMAX_FUN7:
                    f_decode_o.is_fpi_op = 1'b1; 
                default:
                    f_decode_o.is_fpi_op = 1'b0;
            endcase
        default
            f_decode_o.is_fpi_op = 1'b0;
    endcase

// declares if Op reads from the first integer  register file port
always_comb
    unique casez( f_instruction_i.op )
        `RV32_SYSTEM:
            f_decode_o.op_reads_rf1 = 1'b1;
        `RV32_OP_FP:
            unique casez( f_instruction_i.funct7)
                `RV32_FCVT_S_W_FUN7, `RV32_FMV_S_X_FUN7:
                    f_decode_o.op_reads_rf1 = 1'b1;
                default:
                    f_decode_o.op_reads_rf1 = 1'b0; 
            endcase 
        default:
            f_decode_o.op_reads_rf1 = 1'b0;
    endcase


// declares if Op reads from the first floating register file port
always_comb
    unique casez( f_instruction_i.op )
        `RV32_MADD, `RV32_NMADD, `RV32_MSUB, `RV32_NMSUB:
            f_decode_o.op_reads_frf1 = 1'b1;
        `RV32_OP_FP:
            unique casez( f_instruction_i.funct7)
                `RV32_FCVT_S_W_FUN7, `RV32_FMV_S_X_FUN7:
                    f_decode_o.op_reads_frf1 = 1'b0;
                default:
                    f_decode_o.op_reads_frf1 = 1'b1; 
            endcase 
        default:
            f_decode_o.op_reads_frf1 = 1'b0;
    endcase
// declares if Op reads from the second floating register file port
always_comb
    unique casez( f_instruction_i.op )
        `RV32_STORE_FP,`RV32_MADD, `RV32_NMADD, `RV32_MSUB, `RV32_NMSUB:
            f_decode_o.op_reads_frf2 = 1'b1;
        `RV32_OP_FP:
            unique casez( f_instruction_i.funct7)
            // FCLASS is the same with `FMV_X_S
            `RV32_FSQRT_FUN7, `RV32_FCVT_W_S_FUN7, `RV32_FMV_X_S_FUN7, //`RV32_FCLASS_FUN7,
            `RV32_FCVT_S_W_FUN7, `RV32_FMV_S_X_FUN7:
                f_decode_o.op_reads_frf2 = 1'b0;
            default:
                f_decode_o.op_reads_frf2 = 1'b1;
            endcase
        default:
            f_decode_o.op_reads_frf2 = 1'b0; 
    endcase

// declares if Op reads from the third floating register file port
always_comb
    unique casez( f_instruction_i.op )
        `RV32_MADD, `RV32_NMADD, `RV32_MSUB, `RV32_NMSUB:
            f_decode_o.op_reads_frf3 = 1'b1;
       default:
            f_decode_o.op_reads_frf3 = 1'b0; 
    endcase



// declares if op is a FCSR operations.

assign f_decode_o.is_fcsr_op =  (f_instruction_i.op         == `RV32_SYSTEM)
                               &(f_instruction_i.funct3     != 3'b0        )
                               &(f_instruction_i[31:20]     < 12'h4        );


//declare if op writes the fflags
always_comb
    unique casez( f_instruction_i.op )
        `RV32_MADD, `RV32_NMADD, `RV32_MSUB, `RV32_NMSUB:
            f_decode_o.op_writes_fflags = 1'b1;
        `RV32_OP_FP:
            unique casez( f_instruction_i.funct7)
            // FCLASS is the same with `FMV_X_S
            `RV32_FSQRT_FUN7, `RV32_FCVT_W_S_FUN7,`RV32_FCVT_S_W_FUN7 ,
            `RV32_FADD_FUN7, `RV32_FSUB_FUN7, `RV32_FMUL_FUN7,
            `RV32_FCMP_FUN7:
                f_decode_o.op_writes_fflags = 1'b1;
            default:
                f_decode_o.op_writes_fflags = 1'b0;
            endcase
        default:
            f_decode_o.op_writes_fflags = 1'b0;
    endcase

endmodule
