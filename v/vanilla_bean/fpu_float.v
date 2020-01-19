/**
 *  fpu_float.v
 *
 *  3-stage pipelined FPU. Only the instructions that writes back to FP
 *  regfile goes here.
 *
 *  - FADD
 *  - FSUB
 *  - FMUL
 *  - FSGNJ
 *  - FSGNJN
 *  - FSGNJX
 *  - FMIN
 *  - FMAX
 *  - FCVT.S.W (i2f)
 *  - FCVT.S.WU (i2f unsigned)
 *
 */


module fpu_float
  import bsg_vanilla_pkg::*;
  #(parameter e_p=8
    , parameter m_p=23
    , parameter data_width_p = RV32_reg_data_width_gp
    , parameter reg_addr_width_p = RV32_reg_addr_width_gp
  )
  (
    input clk_i
    , input reset_i

    , input v_i
    , input fp_float_decode_s fp_float_decode_i
    , input [data_width_p-1:0] a_i
    , input [data_width_p-1:0] b_i
    , input [reg_addr_width_p-1:0] rd_i
    , output logic ready_o

    , output logic v_o
    , output logic [data_width_p-1:0] result_o
    , output logic [reg_addr_width_p-1:0] rd_o
    , input yumi_i
  );


  logic stall; 
  assign stall = v_o & ~yumi_i;

  // add_sub
  //
  logic add_sub_en_li;
  logic add_sub_v_li;
  logic sub_li;
  logic add_sub_ready_lo;
  logic add_sub_yumi_li;
  logic add_sub_v_lo;
  logic [data_width_p-1:0] add_sub_z_lo;

  bsg_fpu_add_sub #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) add_sub (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(add_sub_en_li)
  
    ,.v_i(add_sub_v_li)
    ,.a_i(a_i)
    ,.b_i(b_i)
    ,.sub_i(sub_li)
    ,.ready_o(add_sub_ready_lo)

    ,.v_o(add_sub_v_lo)
    ,.z_o(add_sub_z_lo)
    ,.unimplemented_o()
    ,.invalid_o()
    ,.overflow_o()
    ,.underflow_o()
    ,.yumi_i(add_sub_yumi_li)
  );

  // mul
  //
  logic mul_en_li;
  logic mul_v_li;
  logic mul_ready_lo;
  logic mul_v_lo;
  logic [data_width_p-1:0] mul_z_lo;
  logic mul_yumi_li;

  bsg_fpu_mul #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) mul (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(mul_en_li)

    ,.v_i(mul_v_li)
    ,.a_i(a_i)
    ,.b_i(b_i)
    ,.ready_o(mul_ready_lo)

    ,.v_o(mul_v_lo)
    ,.z_o(mul_z_lo)
    ,.unimplemented_o()
    ,.invalid_o()
    ,.overflow_o()
    ,.underflow_o()
    ,.yumi_i(mul_yumi_li)
  );

  // i2f
  //
  logic i2f_en_li;
  logic i2f_v_li;
  logic i2f_signed_li;
  logic i2f_ready_lo;  
  logic i2f_v_lo;
  logic [data_width_p-1:0] i2f_z_lo;
  logic i2f_yumi_li;

  bsg_fpu_i2f #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) i2f (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(i2f_en_li)

    ,.v_i(i2f_v_li)
    ,.signed_i(i2f_signed_li)
    ,.a_i(a_i)
    ,.ready_o(i2f_ready_lo)

    ,.v_o(i2f_v_lo)
    ,.z_o(i2f_z_lo)
    ,.yumi_i(i2f_yumi_li)
  );

  // aux
  //
  logic aux_en_li;
  logic aux_v_li;
  logic aux_ready_lo;
  logic aux_v_lo;
  logic [data_width_p-1:0] aux_z_lo;
  logic aux_yumi_li;

  fpu_float_aux fp_aux (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(aux_en_li)
    
    ,.v_i(aux_v_li)
    ,.a_i(a_i)
    ,.b_i(b_i)
    ,.fp_float_decode_i(fp_float_decode_i)
    ,.ready_o(aux_ready_lo)

    ,.v_o(aux_v_lo)
    ,.z_o(aux_z_lo)
    ,.yumi_i(aux_yumi_li)
  );


  // input logic
  //
  logic is_aux_op;

  assign is_aux_op =
    fp_float_decode_i.fsgnj_op
    | fp_float_decode_i.fsgnjn_op
    | fp_float_decode_i.fsgnjx_op
    | fp_float_decode_i.fmin_op
    | fp_float_decode_i.fmax_op
    | fp_float_decode_i.fmv_w_x_op;

  always_comb begin
    ready_o = 1'b0;
    add_sub_v_li = 1'b0;
    sub_li = 1'b0;
    mul_v_li = 1'b0;
    i2f_v_li = 1'b0;
    aux_v_li = 1'b0;
    i2f_signed_li = 1'b0;

    if (fp_float_decode_i.fadd_op) begin
      add_sub_v_li = v_i;
      sub_li = 1'b0;
      ready_o = add_sub_ready_lo;
    end
    else if (fp_float_decode_i.fsub_op) begin
      add_sub_v_li = v_i;
      sub_li = 1'b1;
      ready_o = add_sub_ready_lo;
    end
    else if (fp_float_decode_i.fmul_op) begin
      mul_v_li = v_i;
      ready_o = mul_ready_lo;
    end
    else if (fp_float_decode_i.fcvt_s_w_op) begin
      i2f_v_li = v_i;
      i2f_signed_li = 1'b1;
      ready_o = i2f_ready_lo;
    end
    else if (fp_float_decode_i.fcvt_s_wu_op) begin
      i2f_v_li = v_i;
      i2f_signed_li = 1'b0;
      ready_o = i2f_ready_lo;
    end
    else if (is_aux_op) begin
      aux_v_li = v_i;
      ready_o = aux_ready_lo;
    end
    else begin
      // same as default
    end

  end
  
  // i2f / aux pipeline
  // 
  logic v_2_r;
  logic v_3_r;
  logic [data_width_p-1:0] result_2_r;
  logic [data_width_p-1:0] result_3_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_2_r <= 1'b0;
      v_3_r <= 1'b0;
    end 
    else begin
      if (~stall) begin
        v_2_r <= aux_v_lo | i2f_v_lo;

        if (aux_v_lo) begin
          result_2_r <= aux_z_lo;
        end
        else if (i2f_v_lo) begin
          result_2_r <= i2f_z_lo;
        end

        v_3_r <= v_2_r;

        if (v_2_r) begin
          result_3_r <= result_2_r;
        end
      end
    end
  end

  assign aux_yumi_li = aux_v_lo & ~stall; 
  assign i2f_yumi_li = i2f_v_lo & ~stall;
  assign aux_en_li = ~stall;
  assign i2f_en_li = ~stall;

  // output logic
  //
  always_comb begin

    add_sub_yumi_li = 1'b0;
    add_sub_en_li = 1'b0;
    mul_yumi_li = 1'b0;
    mul_en_li = 1'b0; 
    result_o = add_sub_z_lo;
    v_o = 1'b0;

    if (add_sub_v_lo) begin
      v_o = 1'b1;
      result_o = add_sub_z_lo;
      add_sub_yumi_li = yumi_i;
      add_sub_en_li = yumi_i;
      mul_en_li = yumi_i;
    end
    else if (mul_v_lo) begin
      v_o = 1'b1;
      result_o = mul_z_lo;
      mul_yumi_li = yumi_i;
      add_sub_en_li = yumi_i;
      mul_en_li = yumi_i;
    end
    else if (v_3_r) begin
      v_o = 1'b1;
      result_o = result_3_r;
      add_sub_en_li = yumi_i;
      mul_en_li = yumi_i;
    end
    else begin
      mul_en_li = 1'b1;
      add_sub_en_li =1'b1;
    end
  end

  // rd pipeline
  //
  logic [reg_addr_width_p-1:0] rd_1_r, rd_2_r, rd_3_r;

  always_ff @ (posedge clk_i) begin
    if (~stall) begin
      if (v_i) begin
        rd_1_r <= rd_i;
      end
      rd_2_r <= rd_1_r;
      rd_3_r <= rd_2_r;
    end
  end

  assign rd_o = rd_3_r;


  // synopsys translate_off

  always_ff @ (negedge clk_i) begin
    assert($countones({add_sub_v_lo, mul_v_lo, v_3_r}) <= 1)
      else $error("multiple valid in fpu_float pipeline.");
  end  
  
  // synopsys translate_on


endmodule
