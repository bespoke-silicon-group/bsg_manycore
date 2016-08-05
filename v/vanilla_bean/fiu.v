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
        `RV32_FMV_S_X:   
         begin
            result_o = frs1_i; 
         end
      default:
        begin
        end
    endcase
  end

endmodule 
