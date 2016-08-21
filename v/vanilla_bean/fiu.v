`include "parameters.v"
`include "definitions.v"

`include "float_definitions.v"

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
        `RV32_FEQ_S:
         begin
         end
        `RV32_FLE_S:
         begin
         end
/*TODO
        `RV32_FLT_S:
        `RV32_FSGNJ_S:
        `RV32_FSGNJN_S:   
        `RV32_FSGNJX_S:   
        `RV32_FCLASS_S:   
        `RV32_FCVT_W_S:
        `RV32_FCVT_S_W:
*/
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
            $display("FIU : fcsr_in_value %08x, f_fcsr_s_o: %08x",
fcsr_in_value, f_fcsr_s_o);
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

        default:
        begin
        end
    endcase
end

endmodule 
