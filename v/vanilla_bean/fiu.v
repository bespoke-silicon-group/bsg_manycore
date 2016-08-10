`include "parameters.v"
`include "definitions.v"

`include "float_definitions.v"

typedef int unsigned unsigned_int;
typedef int signed   signed_int;

module fiu ( input [RV32_reg_data_width_gp-1:0] frs1_i
            ,input [RV32_reg_data_width_gp-1:0] frs2_i
            ,input  instruction_s op_i
            ,output logic [RV32_reg_data_width_gp-1:0] result_o
           );

f_bit_s frs1_s,frs2_s;
f_bit_s result_s;

assign  frs1_s = frs1_i;
assign  frs2_s = frs2_i;

always_comb
  begin
    result_s        = 32'dx;
    unique casez (op_i)
        `RV32_FMV_S_X,`RV32_FMV_X_S:   
         begin
            result_s = frs1_i; 
         end
        `RV32_FEQ_S:
         begin
            result_s = ( frs1_i == frs2_i );
         end
        `RV32_FLE_S:
         begin
            result_s = ( $bitstoshortreal(frs1_i) <= $bitstoshortreal(frs2_i) );
         end
        `RV32_FLT_S:
            result_s = ( $bitstoshortreal(frs1_i) <  $bitstoshortreal(frs2_i) );
        `RV32_FSGNJ_S:
         begin
            result_s ='{
              sign     :frs2_s.sign, 
              exp      :frs1_s.exp,
              mant     :frs1_s.mant
           };
         end
        `RV32_FSGNJN_S:   
            result_s ='{
              sign     :~frs2_s.sign, 
              exp      :frs1_s.exp,
              mant     :frs1_s.mant
           };
        `RV32_FSGNJX_S:   
            result_s ='{
              sign     :frs1_s.sign ^ frs2_s.sign, 
              exp      :frs1_s.exp,
              mant     :frs1_s.mant
           };
        `RV32_FCLASS_S:   
        begin
            result_s = fclass( frs1_s) ;
            $display("FCLASS: frs1=%08x, result_s=%08x", frs1_s, result_s);
        end
        `RV32_FCVT_W_S:
           if( op_i.rs2[0] == 1'b1 ) //FCVT.WU.S
                result_s = unsigned_int'( $bitstoshortreal(frs1_i) );             
           else //FCVT.W.S.
                result_s = signed_int'( $bitstoshortreal(frs1_i) );             
        `RV32_FCVT_S_W:
           if( op_i.rs2[0] == 1'b1 ) //FCVT.S.WU.
                result_s = $shortrealtobits( shortreal'( frs1_i ) );             
           else //FCVT.S.W
                result_s = $shortrealtobits( shortreal'( signed'(frs1_i) ) );             
      default:
        begin
        end
    endcase
  end

assign result_o = result_s;


//The function to perform the floating point classify operation
function f_bit_s fclass( input f_bit_s frs1_s );
    automatic logic is_max_exp    = ( frs1_s.exp  == 8'd255 );
    automatic logic is_zero_exp   = ( frs1_s.exp  == 8'd0   );
    automatic logic is_zero_mant  = ( frs1_s.mant == 23'b0  ); 
    automatic logic is_quite_NaN  = ( frs1_s.mant[22]==1'b1 )
                                  & (frs1_s.mant[21:0] == 22'b0 ) 
                                  & (~frs1_s.sign);
    // negtive infinite 
    fclass[0] = frs1_s.sign & is_max_exp & is_zero_mant;
    // negtive normal number
    fclass[1] = frs1_s.sign & (~is_max_exp) & (~is_zero_exp);
    // negtive subnormal number
    fclass[2] = frs1_s.sign & (is_zero_exp) & (~is_zero_mant);
    // negtive zero
    fclass[3] = frs1_s.sign & (is_zero_exp) & (is_zero_mant);
    // positve zero
    fclass[4] = (~frs1_s.sign) & (is_zero_exp) & (is_zero_mant);
    // positive subnormal number
    fclass[5] = (~frs1_s.sign) & (is_zero_exp) & (~is_zero_mant);
    // postitive normal number
    fclass[6] = (~frs1_s.sign) & (~is_max_exp) & (~is_zero_exp);
    // postitive  infinite 
    fclass[7] = (~frs1_s.sign) & is_max_exp & is_zero_mant;
    // signaling NaN
    fclass[8] = is_max_exp & (~is_zero_mant) & (~ is_quite_NaN);  
    // quite NaN
    fclass[9] = is_max_exp & (~is_zero_mant) &  is_quite_NaN;  

    fclass[31:10] = 22'b0;
endfunction    


endmodule 
