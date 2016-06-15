`include "parameters.v"
`include "definitions.v"

module alu ( input [RV32_reg_data_width_gp-1:0] rs1_i
            ,input [RV32_reg_data_width_gp-1:0] rs2_i
            ,input  instruction_s op_i
            ,output logic [RV32_reg_data_width_gp-1:0] result_o
            ,output logic jump_now_o
           );

logic        is_imm_op, sub_not_add,
             carry, sum_is_zero, sign_ex_or_zero;
logic [4:0]  sh_amount;
logic [31:0] op2;
logic [32:0] sum; 
logic [31:0] adder_input;
logic [32:0] shr_out;
logic [31:0] shl_out, xor_out, and_out, or_out;

assign is_imm_op    = (op_i[6:0] ==? `RV32_OP_IMM) 
                       | (op_i[6:0] ==? `RV32_LOAD)
                       | (op_i[6:0] ==? `RV32_JALR_OP);
assign op2          = (op_i[6:0] == `RV32_STORE) 
                       ? `RV32_signext_Simm(op_i)
                       : (is_imm_op ? `RV32_signext_Iimm(op_i) : rs2_i);
assign adder_input  = sub_not_add ? (~op2) : op2;
assign sh_amount    = is_imm_op ? op_i.rs2 : rs2_i[4:0];

assign {carry,sum} = {rs1_i[31], rs1_i} + {adder_input[31], adder_input} + sub_not_add;
assign sum_is_zero = ~(| sum[31:0]);
assign shr_out     = $signed ({sign_ex_or_zero, rs1_i}) >>> sh_amount;
assign shl_out     = rs1_i << sh_amount;
assign xor_out     = rs1_i ^ op2;
assign and_out     = rs1_i & op2;
assign or_out      = rs1_i | op2;

always_comb
  begin
    jump_now_o      = 1'bx;
    result_o        = 32'dx;
    sub_not_add     = 1'bx;
    sign_ex_or_zero = 1'bx;

    unique casez (op_i)
      `RV32_LUI, `RV32_AUIPC:    
        result_o = `RV32_signext_Uimm(op_i); 
      
      `RV32_ADDI, `RV32_ADD, 
      `RV32_LB, `RV32_LH, `RV32_LW, `RV32_LBU, `RV32_LHU,
      `RV32_SB, `RV32_SH, `RV32_SW:
        begin
          result_o = sum[31:0];
          sub_not_add = 1'b0;
        end

      `RV32_LR_W:
        begin
          result_o = rs1_i[31:0];
        end
      
      `RV32_SLTI, `RV32_SLT:   
        begin
          sub_not_add = 1'b1;
          result_o    = {{31{1'b0}},sum[32]};
        end
      
      `RV32_SLTIU, `RV32_SLTU:  
        begin 
          sub_not_add = 1'b1;
          result_o    = {{31{1'b0}},~carry};
        end
      
      `RV32_XORI, `RV32_XOR:   
        result_o = xor_out;
      
      `RV32_ORI, `RV32_OR:    
        result_o = or_out; 
      
      `RV32_ANDI, `RV32_AND:   
        result_o = and_out; 
      
      `RV32_SLLI, `RV32_SLL:   
        result_o = shl_out;
      
      `RV32_SRLI, `RV32_SRL:   
        begin
          result_o        = shr_out[31:0];
          sign_ex_or_zero = 1'b0;
        end
      
      `RV32_SRAI, `RV32_SRA:   
        begin
          result_o        = shr_out[31:0];
          sign_ex_or_zero = rs1_i[31];
        end
      
      `RV32_SUB:    
        begin
          result_o = sum[31:0];
          sub_not_add = 1'b1;
        end
      
      `RV32_JALR:   
        begin
          sub_not_add = 1'b0;
          result_o = sum[31:0] & 32'hfffe;
        end

      `RV32_BEQ:
        begin
          sub_not_add = 1'b1;
          jump_now_o = sum_is_zero;
        end

      `RV32_BNE:  
        begin
          sub_not_add = 1'b1;
          jump_now_o = ~sum_is_zero;
        end
      
      `RV32_BLT:  
        begin
          sub_not_add = 1'b1;
          jump_now_o  = sum[32];
        end
      
      `RV32_BGE:  
        begin
          sub_not_add = 1'b1;
          jump_now_o = ~sum[32];
        end
      
      `RV32_BLTU: 
        begin
          sub_not_add = 1'b1;
          jump_now_o = ~carry;
        end
      
      `RV32_BGEU: 
        begin
          sub_not_add = 1'b1;
          jump_now_o  = carry;
        end

      default:
        begin
        end
    endcase
  end

endmodule 
