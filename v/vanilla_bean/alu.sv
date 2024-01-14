
`include "bsg_manycore_instruction_defines.svh"

module alu
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(pc_width_p ))
           ( input [reg_data_width_gp-1:0] rs1_i
            ,input [reg_data_width_gp-1:0] rs2_i
            ,input [reg_data_width_gp-1:0] pc_plus4_i
            ,input  instruction_s op_i
            ,output logic [reg_data_width_gp-1:0] result_o
            ,output logic [pc_width_p-1:0] jalr_addr_o
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
assign is_imm_op    = (op_i.op ==? `MANYCORE_OP_IMM) | (op_i.op ==? `MANYCORE_JALR_OP);

/////////////////////////////////////////////////////////
assign op2          = is_imm_op ? `MANYCORE_signext_Iimm(op_i) : rs2_i;
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
    result_o        = 32'd0;
    jalr_addr_o     = 32'd0;
    sub_not_add     = 1'b0;
    sign_ex_or_zero = 1'b0;

    unique casez (op_i)
      `MANYCORE_LUI:
        result_o = `MANYCORE_signext_Uimm(op_i);

      `MANYCORE_AUIPC:
        result_o = `MANYCORE_signext_Uimm(op_i) + pc_plus4_i - 3'b100;

      `MANYCORE_ADDI, `MANYCORE_ADD:
        begin
          result_o = sum[31:0];
          sub_not_add = 1'b0;
        end

      `MANYCORE_SLTI, `MANYCORE_SLT:
        begin
          sub_not_add = 1'b1;
          result_o    = {{31{1'b0}},sum[32]};
        end

      `MANYCORE_SLTIU, `MANYCORE_SLTU:
        begin
          sub_not_add = 1'b1;
          result_o    = {{31{1'b0}},~carry};
        end

      `MANYCORE_XORI, `MANYCORE_XOR:
        result_o = xor_out;

      `MANYCORE_ORI, `MANYCORE_OR:
        result_o = or_out;

      `MANYCORE_ANDI, `MANYCORE_AND:
        result_o = and_out;

      `MANYCORE_SLLI, `MANYCORE_SLL:
        result_o = shl_out;

      `MANYCORE_SRLI, `MANYCORE_SRL:
        begin
          result_o        = shr_out[31:0];
          sign_ex_or_zero = 1'b0;
        end

      `MANYCORE_SRAI, `MANYCORE_SRA:
        begin
          result_o        = shr_out[31:0];
          sign_ex_or_zero = rs1_i[31];
        end

      `MANYCORE_SUB:
        begin
          result_o = sum[31:0];
          sub_not_add = 1'b1;
        end

      `MANYCORE_JALR:
        begin
          sub_not_add = 1'b0;
//          jalr_addr_o = sum[31:0] & 32'hfffe;
          jalr_addr_o = sum[2+:pc_width_p];
          result_o    = pc_plus4_i;
        end

      `MANYCORE_JAL:
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
      `MANYCORE_BEQ:    jump_now_o = rs1_eq_rs2;
      `MANYCORE_BNE:    jump_now_o = ~rs1_eq_rs2;
      `MANYCORE_BLT:    jump_now_o = rs1_lt_rs2_signed;
      `MANYCORE_BGE:    jump_now_o = ~rs1_lt_rs2_signed;
      `MANYCORE_BLTU:   jump_now_o = rs1_lt_rs2_unsigned;
      `MANYCORE_BGEU:   jump_now_o = ~rs1_lt_rs2_unsigned;
      default:      jump_now_o = 1'b0;
    endcase
end

endmodule

`BSG_ABSTRACT_MODULE(alu)
