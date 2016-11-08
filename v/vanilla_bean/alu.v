`include "parameters.v"
`include "definitions.v"

`ifdef bsg_FPU
`include "float_definitions.v"
`endif

module alu #(imem_addr_width_p = "inv")
           ( input [RV32_reg_data_width_gp-1:0] rs1_i
            ,input [RV32_reg_data_width_gp-1:0] rs2_i
            ,input [RV32_reg_data_width_gp-1:0] pc_plus4_i
            ,input  instruction_s op_i
            ,output logic [RV32_reg_data_width_gp-1:0] result_o
            ,output logic [imem_addr_width_p-1:0] jalr_addr_o
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

/////////////////////////////////////////////////////////
assign is_imm_op    = (op_i.op ==? `RV32_OP_IMM) | (op_i.op ==? `RV32_JALR_OP);

/////////////////////////////////////////////////////////
assign op2          = is_imm_op ? `RV32_signext_Iimm(op_i) : rs2_i;
///////////////////////////////////////////////////////////


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
    result_o        = 32'dx;
    jalr_addr_o     = 32'dx;
    sub_not_add     = 1'bx;
    sign_ex_or_zero = 1'bx;

    unique casez (op_i)
      `RV32_LUI:
        result_o = `RV32_signext_Uimm(op_i);

      `RV32_AUIPC:
        result_o = `RV32_signext_Uimm(op_i) + pc_plus4_i - 3'b100;

      `RV32_ADDI, `RV32_ADD:
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
//          jalr_addr_o = sum[31:0] & 32'hfffe;
          jalr_addr_o = sum[2+:imem_addr_width_p];
          result_o    = pc_plus4_i;
        end

      `RV32_JAL:
        begin
          result_o    =pc_plus4_i;
        end
      default:
        begin
        end
    endcase
  end

//logic for branch instruction
wire rs1_eq_rs2             = (rs1_i == rs2_i );
wire rs1_lt_rs2_unsigned    = (rs1_i <  rs2_i );
wire rs1_lt_rs2_signed      = ( $signed(rs1_i) < $signed( rs2_i ) );

always_comb
begin
    unique casez(op_i )
      `RV32_BEQ:    jump_now_o = rs1_eq_rs2;
      `RV32_BNE:    jump_now_o = ~rs1_eq_rs2;
      `RV32_BLT:    jump_now_o = rs1_lt_rs2_signed;
      `RV32_BGE:    jump_now_o = ~rs1_lt_rs2_signed;
      `RV32_BLTU:   jump_now_o = rs1_lt_rs2_unsigned;
      `RV32_BGEU:   jump_now_o = ~rs1_lt_rs2_unsigned;
      default:      jump_now_o = 1'b0;
    endcase
end

endmodule
