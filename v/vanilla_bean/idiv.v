/**
 *    idiv.v
 *
 *    Iterative Integer Divider/Remainder.
 *
 */


module idiv 
  import bsg_vanilla_pkg::*;
  #(parameter data_width_p=RV32_reg_data_width_gp
    ,parameter reg_addr_width_p=RV32_reg_addr_width_gp
  )
  (
    input clk_i
    , input reset_i

    , input v_i
    , input [data_width_p-1:0] rs1_i
    , input [data_width_p-1:0] rs2_i
    , input [reg_addr_width_p-1:0] rd_i
    // corresponds to instruction[13:12] or funct3[1:0]
    , input idiv_op_e op_i    
    , output logic ready_o

    , output logic v_o
    , output logic [reg_addr_width_p-1:0] rd_o
    , output logic [data_width_p-1:0] result_o
    , input yumi_i
  );


  logic [data_width_p-1:0] quotient_lo;
  logic [data_width_p-1:0] remainder_lo;
  wire signed_div_li = (op_i == eREM) | (op_i == eDIV);
 
  bsg_idiv_iterative idiv0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(v_i)
    ,.ready_and_o(ready_o)

    ,.dividend_i(rs1_i)
    ,.divisor_i(rs2_i)
    ,.signed_div_i(signed_div_li)

    ,.v_o(v_o)
    ,.quotient_o(quotient_lo)
    ,.remainder_o(remainder_lo)
    ,.yumi_i(yumi_i)
  );


  logic rem_r;
  logic [reg_addr_width_p-1:0] rd_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      rd_r <= '0;
      rem_r <= 1'b0;
    end
    else begin
      if (v_i & ready_o) begin
        rd_r <= rd_i;
        rem_r <= ((op_i == eREM) | (op_i == eREMU));
      end
    end
  end  
 
  assign rd_o = rd_r;
  
  assign result_o = rem_r
    ? remainder_lo
    : quotient_lo;


endmodule
