`include "parameters.v"
`include "definitions.v"
`include "float_parameters.v"
`include "float_definitions.v"

/**
 *
 *  The shared Floating Add & Multiply unit.
 */
module fam #(
                parameter in_data_width_p   = -1,
                parameter out_data_width_p  = -1,
                parameter num_fifo_p        = -1,
                //How mayny pipelines in FAM
                parameter num_pipe_p        = 3 
            )
        ( input                              clk_i
        , input                              reset_i
        , input  f_fam_in_s [num_fifo_p-1:0] fam_in_s_i
        , output f_fam_out_s[num_fifo_p-1:0] fam_out_s_o
        );
/////////////////////////////////////////////
// The last pipe register is the fifo
localparam num_pipe_regs_p = num_pipe_p -1;

//FIFO to n_to_1 signals.
logic  [num_fifo_p-1:0]                         fpi_out_v_o    ; 
logic  [num_fifo_p-1:0]                         fpi_out_yumi_i ; 
f_fam_in_data_s  [num_fifo_p-1:0]               fpi_out_data_s_o; 

//FAM to N fifo signals.
logic  [num_fifo_p-1: 0 ]                       fam_out_v_o ; 
logic  [num_fifo_p-1: 0 ]                       fam_out_ready_o ; 

//n_to_1 output signals
logic                           fam_in_v_o      ;
f_fam_in_data_s                 fam_in_data_s_o ;
logic                           fam_in_from     ;

logic [RV32_reg_data_width_gp-1:0] fam_result   ;

//the pipeline register 
f_fam_pipe_regs_s [num_pipe_regs_p-1:0]  fam_pipe_reg;


genvar n;
// input fifo0
generate for( n=0; n< num_fifo_p; n++) 
begin:fpi_out_fifo
bsg_fifo_1r1w_small #(  .width_p ( in_data_width_p)
                       ,.els_p   ( 2              )
                       ,.ready_THEN_valid_p( 1    )
                    )
   in_fifo    ( .clk_i  ( clk_i     )
               ,.reset_i( reset_i   )

               ,.v_i    (fam_in_s_i   [n].v_i        )
               ,.ready_o(fam_out_s_o  [n].ready_o    )
               ,.data_i (fam_in_s_i   [n].data_s_i   )

               ,.v_o    (fpi_out_v_o       [n ]    )
               ,.data_o (fpi_out_data_s_o  [n ]    )
               ,.yumi_i (fpi_out_yumi_i    [n ]    )
    );

end
endgenerate

bsg_round_robin_n_to_1 #( .width_p  ( in_data_width_p   )
                         ,.num_in_p ( 2                 )
                         ,.strict_p ( 0                 ) //must NOT wait  
                       ) 
    fam_n_to_1(  .clk_i    ( clk_i        )
               , .reset_i  ( reset_i      )

               // to fifos
               , .data_i   (fpi_out_data_s_o)
               , .v_i      (fpi_out_v_o  )
               , .yumi_o   (fpi_out_yumi_i)

               // to downstream
               , .v_o      (fam_in_v_o     )
               , .data_o   (fam_in_data_s_o)
               , .tag_o    (fam_in_from    )
               , .yumi_i   (fam_in_v_o     )   
     );

//////////////////////////////////////////////////////////////
// instantiate the actual computing logic
float_add_mul #(  
                  .operand_width_p( RV32_reg_data_width_gp  )
                 ,.instr_width_p  ( RV32_instr_width_gp     )
               )
 share_add_mul(.frs1_i            (fam_in_data_s_o.frs1_to_exe    )
              ,.frs2_i            (fam_in_data_s_o.frs2_to_exe    )
              ,.op_i              (fam_in_data_s_o.f_instruction  )
              ,.result_o          (fam_result)
              );
//////////////////////////////////////////////////////////////
// the pipeline registers
always_ff @ (posedge clk_i)
begin
    if (reset_i )
        fam_pipe_reg[0]  <= '0;
    else 
        fam_pipe_reg[0]<= '{
            result          : fam_result    ,
            fam_in_from     : fam_in_from   ,
            op_writes_frf   : fam_in_v_o   
        };
end

genvar p;

for( p=1; p< num_pipe_regs_p; p++)
begin: fam_pipe
   always_ff @( posedge clk_i)
   begin
    if (reset_i )
        fam_pipe_reg[p]  <= '0;
    else 
        fam_pipe_reg[p]  <= fam_pipe_reg[p-1];
  end
end

//////////////////////////////////////////////////////////////
// The output fifos


genvar k;

generate for(k=0; k<num_fifo_p; k++) 
begin: fam_out_fifo

assign fam_out_v_o[k] = (fam_pipe_reg[num_pipe_regs_p-1].fam_in_from == k )
                       & fam_pipe_reg[num_pipe_regs_p-1].op_writes_frf;
// input fifos
// As FAM instruciton was issued in ID stage, and can't be stopped, there 
// may be most (num_pipe_p +1 ) instructions stuck in FAM while ALU is stalled.

bsg_fifo_1r1w_small #(  .width_p  ( RV32_reg_data_width_gp )
                       ,.els_p    ( num_pipe_p+1           )
                    )
   out_fifo   ( .clk_i  ( clk_i     )
               ,.reset_i( reset_i   )

               ,.v_i    ( fam_out_v_o[k] )
               ,.ready_o( fam_out_ready_o[k]) // it should be always ready
               ,.data_i ( fam_pipe_reg[num_pipe_regs_p-1].result )

               ,.v_o    ( fam_out_s_o[k].v_o      )
               ,.data_o ( fam_out_s_o[k].data_o   )
               ,.yumi_i ( fam_in_s_i [k].yumi_i   )
    );
end
endgenerate

endmodule
