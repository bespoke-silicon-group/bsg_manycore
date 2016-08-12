`include "float_definitions.v"

module float_add_mul #( parameter operand_width_p = 32,
                                  instr_width_p   = 32) 
    ( input [operand_width_p-1:0]   frs1_i
     ,input [operand_width_p-1:0]   frs2_i
     ,input [instr_width_p-1:0]     op_i
     ,output[operand_width_p-1:0]   result_o
    );

f_bit_s frs1_s,frs2_s;
f_bit_s result_s;


assign  frs1_s = frs1_i;
assign  frs2_s = frs2_i;

always_comb
begin
    result_s        = 32'dx;
    unique casez (op_i)
        `RV32_FADD_S:   
         begin
            result_s =  $shortrealtobits( 
                            $bitstoshortreal(frs1_i) + $bitstoshortreal(frs2_i)
                        );
         end
        `RV32_FSUB_S:   
         begin
            result_s =  $shortrealtobits( 
                            $bitstoshortreal(frs1_i) - $bitstoshortreal(frs2_i)
                        );
         end
        `RV32_FMUL_S:   
         begin
            result_s =  $shortrealtobits( 
                            $bitstoshortreal(frs1_i) * $bitstoshortreal(frs2_i)
                        );
         end
        `RV32_FDIV_S:   
         begin
            result_s =  $shortrealtobits( 
                            $bitstoshortreal(frs1_i) / $bitstoshortreal(frs2_i)
                        );
         end
        `RV32_FMIN_S:   
         begin
            result_s =  $shortrealtobits( 
                          ( $bitstoshortreal(frs1_i) < $bitstoshortreal(frs2_i)) ?
                            $bitstoshortreal(frs1_i) : $bitstoshortreal(frs2_i)
                        );
         end
        `RV32_FMAX_S:   
         begin
            result_s =  $shortrealtobits( 
                          ( $bitstoshortreal(frs1_i) > $bitstoshortreal(frs2_i)) ?
                            $bitstoshortreal(frs1_i) : $bitstoshortreal(frs2_i)
                        );
         end
        `RV32_FSQRT_S:
         begin
           $error("SQRT instruction not implemented!"); 
         end
        `RV32_FSQRT_S:
         begin
           $error("SQRT instruction not implemented!"); 
         end
         `RV32_FMADD_S,`RV32_FMSUB_S, `RV32_FNMADD_S, `RV32_FNMSUB_S:    
         begin
           $error("FMAC instruction not implemented!"); 
         end
         default:
         begin
         end
    endcase
end

assign result_o = result_s;

endmodule
