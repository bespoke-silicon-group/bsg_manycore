/**
 *    instr_expander.v
 *
 */


`include "bsg_vanilla_defines.vh"


module instr_expander
  import bsg_vanilla_pkg::*;
  (
    input clk_i
    , input reset_i

    , input stall_i
    , input flush_i

    , input  instruction_s instr_i
    , output instruction_s exp_instr_o

    , output logic stall_instr_exp_o
    , output logic is_expand_head_o
    , output logic is_expand_tail_o
  );


  // Expander states
  typedef enum logic {
    eSTART
    ,eFLWADD4
  } exp_state_e;

  exp_state_e exp_state_r, exp_state_n;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      exp_state_r <= eSTART;
    end
    else begin
      exp_state_r <= exp_state_n;
    end
  end


  // Registers for rd, rs1, rs2
  logic rd_wen, rs1_wen, rs2_wen;
  logic [RV32_reg_addr_width_gp-1:0]  rd_r, rs1_r, rs2_r,
                                      rs1_n, rs2_n, rd_n;

  bsg_dff_en #(.width_p(RV32_reg_addr_width_gp)) rd_dff (
    .clk_i(clk_i)
    ,.en_i(rd_wen)
    ,.data_i(rd_n)
    ,.data_o(rd_r)
  );
  bsg_dff_en #(.width_p(RV32_reg_addr_width_gp)) rs1_dff (
    .clk_i(clk_i)
    ,.en_i(rs1_wen)
    ,.data_i(rs1_n)
    ,.data_o(rs1_r)
  );
  bsg_dff_en #(.width_p(RV32_reg_addr_width_gp)) rs2_dff (
    .clk_i(clk_i)
    ,.en_i(rs2_wen)
    ,.data_i(rs2_n)
    ,.data_o(rs2_r)
  );

  // Counter to track how many FLWADD has been generated.
  logic counter_clear, counter_up;
  logic [1:0] counter_lo;
  bsg_counter_clear_up #(
    .max_val_p(3)
    ,.init_val_p(0)
  ) counter0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(counter_clear)
    ,.up_i(counter_up)
    ,.count_o(counter_lo)
  );


  // check if flwadd4
  wire freeze = (stall_i | flush_i);
  wire is_flwadd4_op = (instr_i ==? `RV32_FLWADD4);
  wire counter_max_val = (2'b11 == counter_lo);


  // Next state logic
  always_comb begin
    exp_instr_o = instr_i;
    stall_instr_exp_o = 1'b0;
    is_expand_head_o = 1'b0;
    is_expand_tail_o = 1'b0;

    rd_wen = 1'b0;
    rs1_wen = 1'b0;
    rs2_wen = 1'b0;
    rd_n = instr_i.rd + 1'b1;
    rs1_n = instr_i.rs1;
    rs2_n = instr_i.rs2;

    counter_clear = 1'b0;
    counter_up = 1'b0;

    case (exp_state_r)

      // Waiting for FLWADD4 to appear.
      eSTART: begin
        if (is_flwadd4_op) begin
          // Expand the first FLWADD
          exp_instr_o = {7'b0, instr_i.rs2, instr_i.rs1, 3'b000, instr_i.rd, `RV32_CUSTOM_OP};
          exp_state_n = freeze
            ? eSTART
            : eFLWADD4;
          stall_instr_exp_o = ~freeze;
          rd_wen = ~freeze;
          rs1_wen = ~freeze;
          rs2_wen = ~freeze;
          counter_up = ~freeze;
          is_expand_head_o = 1'b1;
        end
        else begin
          stall_instr_exp_o = 1'b0;
          exp_instr_o = instr_i;
          exp_state_n = eSTART;
        end
      end

      // Expanding FLWADD4
      eFLWADD4: begin
        //stall_instr_exp_o = ~flush_i | ~counter_max_val;
        stall_instr_exp_o = flush_i
          ? 1'b0
          : ~counter_max_val;
        exp_instr_o = {7'b0, rs2_r, rs1_r, 3'b000, rd_r, `RV32_CUSTOM_OP};
        exp_state_n = stall_i
          ? eFLWADD4
          : (flush_i 
            ? eSTART
            : (counter_max_val
              ? eSTART
              : eFLWADD4));

        rd_n = rd_r + 1'b1;
        rd_wen = ~freeze & ~counter_max_val;
        is_expand_tail_o = counter_max_val;

        counter_clear = stall_i
          ? 1'b0
          : (flush_i
            ? 1'b1
            : counter_max_val);
        counter_up = stall_i
          ? 1'b0
          : (flush_i
            ? 1'b0
            : ~counter_max_val);
      end

      // illegal state
      default: begin
        exp_state_n = eSTART;
      end
    endcase
  end

  


endmodule
