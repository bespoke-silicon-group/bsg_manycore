`ifndef _float_parameters_v_
`define _float_parameters_v_


///////////////////////////////////////////////////////////////////////////////
//RV32F Instruction encodings
`define RV32_FLS_FUN3       3'b010
`define RV32_FDLS_FUN3      3'b011
`define RV32_FMAC_FUN7      7'b?????_00
`define RV32_FADD_FUN7      7'b0000_000
`define RV32_FSUB_FUN7      7'b0000_100
`define RV32_FMUL_FUN7      7'b0001_000
`define RV32_FDIV_FUN7      7'b0001_100
`define RV32_FSQRT_FUN7     7'b0101_100
`define RV32_FSGN_FUN7      7'b0010_000
`define RV32_FMINMAX_FUN7   7'b0010_100
`define RV32_FCVT_W_S_FUN7  7'b1100_000
`define RV32_FCVT_S_W_FUN7  7'b1101_000
`define RV32_FMV_X_S_FUN7   7'b1110_000
`define RV32_FMV_S_X_FUN7   7'b1111_000
`define RV32_FCLASS_FUN7    7'b1110_000
`define RV32_FCMP_FUN7      7'b1010_000

`define RV32_FLW        `RV32_Itype( `RV32_LOAD_FP, `RV32_FLS_FUN3)
`define RV32_FSW        `RV32_Stype( `RV32_STORE_FP,`RV32_FLS_FUN3)
`define RV32_FLD        `RV32_Itype( `RV32_LOAD_FP, `RV32_FDLS_FUN3)
`define RV32_FSD        `RV32_Stype( `RV32_STORE_FP,`RV32_FDLS_FUN3)

`define RV32_FMADD_S    `RV32_Rtype( `RV32_MADD,    3'b???, `RV32_FMAC_FUN7)
`define RV32_FMSUB_S    `RV32_Rtype( `RV32_MSUB,    3'b???, `RV32_FMAC_FUN7)
`define RV32_FNMSUB_S   `RV32_Rtype( `RV32_NMSUB,   3'b???, `RV32_FMAC_FUN7)
`define RV32_FNMADD_S   `RV32_Rtype( `RV32_NMADD,   3'b???, `RV32_FMAC_FUN7)
`define RV32_FADD_S     `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FADD_FUN7)
`define RV32_FSUB_S     `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FSUB_FUN7)
`define RV32_FMUL_S     `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FMUL_FUN7)
`define RV32_FDIV_S     `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FDIV_FUN7)
`define RV32_FSQRT_S    `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FSQRT_FUN7)
`define RV32_FSGNJ_S    `RV32_Rtype( `RV32_OP_FP,   3'b000, `RV32_FSGN_FUN7)
`define RV32_FSGNJN_S   `RV32_Rtype( `RV32_OP_FP,   3'b001, `RV32_FSGN_FUN7)
`define RV32_FSGNJX_S   `RV32_Rtype( `RV32_OP_FP,   3'b010, `RV32_FSGN_FUN7)
`define RV32_FMIN_S     `RV32_Rtype( `RV32_OP_FP,   3'b000, `RV32_FMINMAX_FUN7)
`define RV32_FMAX_S     `RV32_Rtype( `RV32_OP_FP,   3'b001, `RV32_FMINMAX_FUN7)

//CVT.W.S and CVT.WU.S, Have to futher check rs2.
`define RV32_FCVT_W_S   `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FCVT_W_S_FUN7)
//CVT.W.S and CVT.WU.S, Have to futher check rs2.
`define RV32_FCVT_S_W   `RV32_Rtype( `RV32_OP_FP,   3'b???, `RV32_FCVT_S_W_FUN7)

`define RV32_FMV_X_S    `RV32_Rtype( `RV32_OP_FP,   3'b000, `RV32_FMV_X_S_FUN7)
`define RV32_FMV_S_X    `RV32_Rtype( `RV32_OP_FP,   3'b000, `RV32_FMV_S_X_FUN7)
`define RV32_FCLASS_S   `RV32_Rtype( `RV32_OP_FP,   3'b001, `RV32_FCLASS_FUN7)

`define RV32_FEQ_S      `RV32_Rtype( `RV32_OP_FP,   3'b010, `RV32_FCMP_FUN7)
`define RV32_FLT_S      `RV32_Rtype( `RV32_OP_FP,   3'b001, `RV32_FCMP_FUN7)
`define RV32_FLE_S      `RV32_Rtype( `RV32_OP_FP,   3'b000, `RV32_FCMP_FUN7)

localparam RV32_freg_data_width_gp = 33;

//CSR regsiter definition
localparam RV32_csr_addr_fflags    =12'h001;
localparam RV32_csr_addr_frm       =12'h002;
localparam RV32_csr_addr_fcsr      =12'h003;
localparam RV32_fflags_width_gp    = 5;
localparam RV32_frm_width_gp       = 3;
localparam RV32_fcsr_width_gp      = RV32_fflags_width_gp + RV32_frm_width_gp;

`endif
