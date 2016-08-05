`include "parameters.v"
`include "definitions.v"

`include "float_definitions.v"

module fiu ( input [RV32_reg_data_width_gp-1:0] frs1_i
            ,input [RV32_reg_data_width_gp-1:0] frs2_i
            ,input  instruction_s op_i
            ,output logic [RV32_reg_data_width_gp-1:0] result_o
           );


always_comb
  begin
    result_o        = 32'dx;
    unique casez (op_i)
        `RV32_FMV_S_X,`RV32_FMV_X_S:   
         begin
            result_o = frs1_i; 
         end
        `RV32_FEQ_S:
         begin
            result_o = ( frs1_i == frs2_i );
            $display("result_o = %8x", result_o);
         end
        `RV32_FLE_S:
            result_o = ( $bitstoshortreal(frs1_i) <= $bitstoshortreal(frs2_i) );
        `RV32_FLT_S:
            result_o = ( $bitstoshortreal(frs1_i) <  $bitstoshortreal(frs2_i) );
      default:
        begin
        end
    endcase
  end

endmodule 
