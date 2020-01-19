/**
 *  fpu_float_aux.v
 *
 */


module fpu_float_aux
  import bsg_vanilla_pkg::*;
  #(parameter e_p=8
    , parameter m_p=23
    , parameter data_width_p=RV32_reg_data_width_gp
  )
  (
    input clk_i
    ,input reset_i
    ,input en_i

    ,input v_i
    ,input [data_width_p-1:0] a_i
    ,input [data_width_p-1:0] b_i
    ,input fp_float_decode_s fp_float_decode_i
    ,output logic ready_o

    ,output logic v_o
    ,output logic [data_width_p-1:0] z_o
    ,input yumi_i

  );


  // min_max, sign inject, FMV, datapath
  //
  logic [data_width_p-1:0] min_lo;
  logic [data_width_p-1:0] max_lo;
  logic [data_width_p-1:0] aux_result;

  bsg_fpu_cmp #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) min_max (
    .a_i(a_i)
    ,.b_i(b_i)

    ,.eq_o()
    ,.lt_o()
    ,.le_o()

    ,.lt_le_invalid_o()
    ,.eq_invalid_o()

    ,.min_o(min_lo)
    ,.max_o(max_lo)
    ,.min_max_invalid_o()
  );

  always_comb begin
    if (fp_float_decode_i.fmin_op) begin
      aux_result = min_lo;
    end
    else if (fp_float_decode_i.fmax_op) begin
      aux_result = max_lo;
    end
    else if (fp_float_decode_i.fsgnj_op) begin
      aux_result = {b_i[data_width_p-1], a_i[0+:data_width_p-1]};
    end
    else if (fp_float_decode_i.fsgnjn_op) begin
      aux_result = {~b_i[data_width_p-1], a_i[0+:data_width_p-1]};
    end
    else if (fp_float_decode_i.fsgnjx_op) begin
      aux_result = {a_i[data_width_p-1] ^ b_i[data_width_p-1], a_i[0+:data_width_p-1]};
    end
    else begin
      aux_result = a_i; // this covers FMV
    end
  end

  // pipeline ctrl
  //
  logic stall;
  logic v_r;
  logic [data_width_p-1:0] aux_result_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_r <= 1'b0;
    end
    else begin
      if (~stall & en_i) begin
        v_r <= v_i;
        if (v_i) begin
          aux_result_r <= aux_result;
        end
      end

    end
  end


  assign v_o = v_r;
  assign stall = v_r & ~yumi_i;
  assign ready_o = ~stall & en_i;
  assign z_o = aux_result_r;


endmodule
