//====================================================================
// imul_idiv_iterative.v
// 11/16/2016, shawnless.xie@gmail.com
//====================================================================
//
// The risc-v 32 bit mul and div instruction implementation module
`include "parameters.v"

//should not change the width_p because idiv is not parameterizable
module imul_idiv_iterative #(width_p= 32)
    (input                  reset_i
	,input                  clk_i

	,input                  v_i      //there is a request
    ,output                 ready_o  //imul_idiv_module is idle

    ,input [width_p-1: 0]   opA_i
	,input [width_p-1: 0]   opB_i
    //the funct3 bits in the instruction encoding
    ,input [2:0]            funct3

	,output                       v_o      //result is valid
	,output logic [width_p-1: 0]  result_o
    ,input                        yumi_i
    );
////////////////////////////////////////////////////////////
// Generates input signal for MUL and DIV
logic idiv_v, signed_div, gets_quotient; 

logic imul_v, signed_opA, signed_opB, gets_high_part;

always_comb begin
  imul_v          = 1'b0;
  signed_opA      = 1'b0;
  signed_opB      = 1'b0;
  gets_high_part  = 1'b0;

  idiv_v          = 1'b0;
  signed_div      = 1'b0;
  gets_quotient   = 1'b0;

  unique casez (funct3)
    `MD_MUL_FUN3: // MUL
      begin
        imul_v            = v_i;
        signed_opA        = 1'b1;
        signed_opB        = 1'b1;
        gets_high_part    = 1'b0;
      end

    `MD_MULH_FUN3: // MULH
      begin
        imul_v            = v_i;
        signed_opA        = 1'b1;
        signed_opB        = 1'b1;
        gets_high_part    = 1'b1;
      end

    `MD_MULHSU_FUN3: // MULHSU
      begin
        imul_v            = v_i;
        signed_opA        = 1'b1;
        signed_opB        = 1'b0;
        gets_high_part    = 1'b1;
      end

    `MD_MULHU_FUN3: // MULHU
      begin
        imul_v            = v_i;
        signed_opA        = 1'b0;
        signed_opB        = 1'b0;
        gets_high_part    = 1'b1;
      end

    `MD_DIV_FUN3: // DIV
      begin
        idiv_v            = v_i ;
        signed_div        = 1'b1;
        gets_quotient     = 1'b1;
      end

    `MD_DIVU_FUN3: // DIVU
      begin
        idiv_v            = v_i ;
        signed_div        = 1'b0;
        gets_quotient     = 1'b1;
      end

    `MD_REM_FUN3: // REM
      begin
        idiv_v            = v_i ;
        signed_div        = 1'b1;
        gets_quotient     = 1'b0;
      end

    default://3'b111: // REMU
      begin
        idiv_v            = v_i ;
        signed_div        = 1'b0;
        gets_quotient     = 1'b0;
      end
  endcase
end

////////////////////////////////////////////////////////////
//              MUL instance
wire                imul_ready, imul_v_o;
wire [width_p-1:0]  imul_result;
bsg_imul_iterative  #( .width_p(32) )imul
    (.reset_i
	,.clk_i

	,.v_i               (imul_v     )//there is a request
    ,.ready_o           (imul_ready )//idiv is idle 

    ,.opA_i             (opA_i      )
	,.signed_opA_i      (signed_opA )
	,.opB_i             (opB_i      )
	,.signed_opB_i      (signed_opB )
    ,.gets_high_part_i  (gets_high_part)

	,.v_o               (imul_v_o   ) 
	,.result_o          (imul_result)
    ,.yumi_i            (yumi_i     )
    );


////////////////////////////////////////////////////////////
//             DIV   instance
wire                idiv_ready, idiv_v_o;
wire [width_p-1:0]  quotient,   remainder;
bsg_idiv_iterative  idiv (
	 .reset_i
	,.clk_i

	,.v_i               (idiv_v     )//there is a request
    ,.ready_o           (idiv_ready )//idiv is idle 

    ,.dividend_i        (opA_i      )
	,.divisor_i         (opB_i      )
	,.signed_div_i      (signed_div )

	,.v_o               (idiv_v_o   )//result is valid
	,.quotient_o        (quotient   )
	,.remainder_o       (remainder  )
    ,.yumi_i            (yumi_i     )
    );

////////////////////////////////////////////////////////////
//           Outputs 
logic gets_quotient_r;
always_ff@(posedge clk_i ) begin
    if( reset_i)                    gets_quotient_r <= 1'b0;
    else if(idiv_v & idiv_ready)    gets_quotient_r <= gets_quotient;
end

// select the result, one-hot style
always_comb begin
    unique if(imul_v_o )        
                result_o = imul_result;
           else if( idiv_v_o & gets_quotient_r )
                result_o = quotient;                 
           else 
                result_o = remainder;
end

assign  v_o     = idiv_v_o      |   imul_v_o ;
assign  ready_o = idiv_ready    &   imul_ready;

endmodule
