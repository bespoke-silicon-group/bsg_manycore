`include "float_definitions.v"

module float_add_mul #( parameter operand_width_p = 32,
                                  instr_width_p   = 32) 
    ( input [operand_width_p-1:0]   frs1_i
     ,input [operand_width_p-1:0]   frs2_i
     ,input [instr_width_p-1:0]     op_i
     ,output[operand_width_p-1:0]   result_o
    );

    assign result_o  = $shortrealtobits( 
                        $bitstoshortreal(frs1_i) + $bitstoshortreal(frs2_i)
                       );

endmodule
