`include "parameters.vh"
`include "definitions.vh"

`include "float_definitions.vh"

typedef int unsigned unsigned_int;
typedef int signed   signed_int;

module fiu ( input [RV32_freg_data_width_gp-1:0] frs1_i
            ,input [RV32_freg_data_width_gp-1:0] frs2_i
            ,input  instruction_s op_i
            ,input  f_fcsr_s     f_fcsr_s_i
            ,output f_fcsr_s     f_fcsr_s_o
            ,output logic [RV32_freg_data_width_gp-1:0] result_o
           );

//The MV.S.X result
logic [RV32_freg_data_width_gp-1:0]  mv_s_x_result; 
bsg_recFNFromFN mv_s_x_RecF(  
                .io_a   (  frs1_i[RV32_reg_data_width_gp-1:0]   )
               ,.io_out (  mv_s_x_result                        )
                 );

//The MV.X.S result
logic [RV32_reg_data_width_gp-1:0]   mv_x_s_result; 
bsg_fNFromRecFN mv_x_s_FN(  
                .io_a   ( frs1_i    )
               ,.io_out ( mv_x_s_result )
                 );

//The CVT.W.S result
logic [RV32_reg_data_width_gp-1:0]  cvt_w_s_result; 
logic [2:0]                         cvt_w_s_flags_3;

RecFNToIN  mv_w_s_0(
    .io_in               ( frs1_i                )
   ,.io_roundingMode     ( f_fcsr_s_i.frm[1:0]   )
   ,.io_signedOut        ( ~op_i.rs2[0]          ) 
   ,.io_out              ( cvt_w_s_result        )
   ,.io_intExceptionFlags( cvt_w_s_flags_3       )
);

//The CVT.S.W result
logic [RV32_freg_data_width_gp-1:0]  cvt_s_w_result; 
logic [RV32_fflags_width_gp-1:0]     cvt_s_w_flags;
INToRecFN mv_s_w_0(
    .io_signedIn        ( ~op_i.rs2[0]          )
   ,.io_in              ( frs1_i[31:0]          )
   ,.io_roundingMode    ( f_fcsr_s_i.frm[1:0]   )
   ,.io_out             ( cvt_s_w_result        )
   ,.io_exceptionFlags  ( cvt_s_w_flags         )
);
//The FClass result
logic [RV32_reg_data_width_gp-1:0]  fclass_result; 
bsg_classifyRecFN fclass_0(
    .io_a               ( frs1_i                )
   ,.io_out             ( fclass_result         )
);

//The compare result
logic fcmp_is_lt, fcmp_is_eq, fcmp_is_gt;
logic [RV32_fflags_width_gp-1:0]  fcmp_flags;
CompareRecFN fcmp_0(
    .io_a               ( frs1_i                )
   ,.io_b               ( frs2_i                )
   ,.io_signaling       ( 1'b1                  )
   ,.io_lt              ( fcmp_is_lt            )
   ,.io_eq              ( fcmp_is_eq            )
   ,.io_gt              ( fcmp_is_gt            )
   ,.io_exceptionFlags  ( fcmp_flags            )
);

localparam csri_pad_width       = RV32_fcsr_width_gp - RV32_reg_addr_width_gp;

localparam fcsr_read_pad_width  =RV32_reg_data_width_gp - RV32_fcsr_width_gp;
localparam frm_read_pad_width   =RV32_reg_data_width_gp - RV32_frm_width_gp;
localparam fflags_read_pad_width=RV32_reg_data_width_gp - RV32_fflags_width_gp;

wire[31:20] fcsr_addr   =  op_i[31:20]; 

always_comb
  begin
    result_o        = 'dx;
    unique casez (op_i)
        `RV32_CSRRW, `RV32_CSRRWI, `RV32_CSRRS, `RV32_CSRRSI,
        `RV32_CSRRC, `RV32_CSRRCI:
        unique casez( fcsr_addr )
            RV32_csr_addr_frm:
                result_o        = { {frm_read_pad_width{1'b0}}, f_fcsr_s_i.frm};  

            RV32_csr_addr_fflags:
                result_o            = { {fflags_read_pad_width{1'b0}}, f_fcsr_s_i.fflags};  

            RV32_csr_addr_fcsr:
                result_o        = { {fcsr_read_pad_width{1'b0}}, f_fcsr_s_i};  
            default:
            begin
            end
        endcase
        `RV32_FMV_S_X:
            result_o = mv_s_x_result;
        `RV32_FMV_X_S:   
            result_o = {1'b0, mv_x_s_result}; 
        `RV32_FCVT_W_S:
            result_o = {1'b0, cvt_w_s_result};
        `RV32_FCVT_S_W:
            result_o = cvt_s_w_result;
        `RV32_FSGNJ_S:
            result_o = {frs2_i[RV32_freg_data_width_gp-1],
                        frs1_i[RV32_freg_data_width_gp-2:0]} ;
        `RV32_FSGNJN_S:   
            result_o = {~frs2_i[RV32_freg_data_width_gp-1],
                        frs1_i[RV32_freg_data_width_gp-2:0]} ;
        `RV32_FSGNJX_S:   
            result_o = {frs2_i[RV32_freg_data_width_gp-1]^frs1_i[RV32_freg_data_width_gp-1],
                        frs1_i[RV32_freg_data_width_gp-2:0]} ;
        `RV32_FCLASS_S: 
            result_o = fclass_result;
        `RV32_FEQ_S:
            result_o = {31'b0, fcmp_is_eq };
        `RV32_FLE_S:
            result_o = {31'b0, ~fcmp_is_gt};
        `RV32_FLT_S:
            result_o = {31'b0, fcmp_is_lt };
        `RV32_FMIN_S:
            result_o =  fcmp_is_lt ? frs1_i : frs2_i;
        `RV32_FMAX_S:
            result_o =  fcmp_is_gt ? frs1_i : frs2_i;
      default:
        begin
        end
    endcase
  end



// The FCSR signals.
logic[RV32_fcsr_width_gp-1:0]  fcsr_in_value;
assign fcsr_in_value = ~op_i.funct3[2] 
               ? frs1_i[RV32_fcsr_width_gp-1:0]       //from register 
               : { {csri_pad_width{1'b0}}, op_i.rs1 };//from imm5

always_comb
  begin
    f_fcsr_s_o       = 'dx;
    unique casez (op_i)
        `RV32_CSRRW, `RV32_CSRRWI:
        begin
        unique casez( fcsr_addr )
            RV32_csr_addr_frm:
                f_fcsr_s_o.frm  = fcsr_in_value[RV32_frm_width_gp-1:0];

            RV32_csr_addr_fflags:
                f_fcsr_s_o.fflags   = fcsr_in_value[RV32_fflags_width_gp-1:0];

            RV32_csr_addr_fcsr:
                f_fcsr_s_o      = fcsr_in_value;
            default:
            begin
            end
        endcase
        end
        `RV32_CSRRS, `RV32_CSRRSI:
        unique casez( fcsr_addr )
            RV32_csr_addr_frm:
                f_fcsr_s_o.frm  = f_fcsr_s_i.frm | fcsr_in_value[RV32_frm_width_gp-1:0];

            RV32_csr_addr_fflags:
                f_fcsr_s_o.fflags   = f_fcsr_s_i.fflags | fcsr_in_value[RV32_fflags_width_gp-1:0];

            RV32_csr_addr_fcsr:
                f_fcsr_s_o      = f_fcsr_s_i | fcsr_in_value;
            default:
            begin
            end
        endcase 
        `RV32_CSRRC, `RV32_CSRRCI:
        unique casez( fcsr_addr )
            RV32_csr_addr_frm:
                f_fcsr_s_o.frm  = f_fcsr_s_i.frm & (~fcsr_in_value[RV32_frm_width_gp-1:0]);

            RV32_csr_addr_fflags:
                f_fcsr_s_o.fflags   = f_fcsr_s_i.fflags &(~ fcsr_in_value[RV32_fflags_width_gp-1:0]);

            RV32_csr_addr_fcsr:
                f_fcsr_s_o      = f_fcsr_s_i & (~fcsr_in_value);
            default:
            begin
            end
        endcase
        `RV32_FCVT_W_S:
            f_fcsr_s_o.fflags = {2'b0, cvt_w_s_flags_3};
        `RV32_FCVT_S_W:
            f_fcsr_s_o.fflags = cvt_s_w_flags;
        `RV32_FLE_S, `RV32_FEQ_S, `RV32_FLT_S:
            f_fcsr_s_o.fflags = fcmp_flags;
        default:
        begin
        end
    endcase
end

endmodule 
