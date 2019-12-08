/**
 *  fpu_int.v
 *  
 *  FPU for instructions that writes back to integer regfile.
 *
 *  - FCLASS
 *  - FLE, FLT, FEQ
 *  - FCVT.
 */


module fpu_int
  import bsg_vanilla_pkg::*;
  #(parameter e_p=8
    , parameter m_p=23
    , parameter data_width_p = RV32_reg_data_width_gp
  )
  (
    input [data_width_p-1:0] a_i
    , input [data_width_p-1:0] b_i
    , input fp_int_decode_s fp_int_decode_i
    , output logic [data_width_p-1:0] result_o
  );

  // classify
  //
  logic [data_width_p-1:0] class_lo;

  bsg_fpu_classify #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) classify (
    .a_i(a_i)
    ,.class_o(class_lo)
  );

  // f2i
  //
  logic f2i_signed_li;
  logic [data_width_p-1:0] f2i_z_lo;

  bsg_fpu_f2i #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) f2i (
    .a_i(a_i)
    ,.signed_i(f2i_signed_li)

    ,.z_o(f2i_z_lo)
    ,.invalid_o()    
  );

  // cmp
  //
  logic eq_lo;
  logic lt_lo;
  logic le_lo;  

  bsg_fpu_cmp #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) cmp (
    .a_i(a_i)
    ,.b_i(b_i)

    ,.eq_o(eq_lo)
    ,.lt_o(lt_lo)
    ,.le_o(le_lo)

    ,.lt_le_invalid_o()
    ,.eq_invalid_o()

    ,.min_o()
    ,.max_o()

    ,.min_max_invalid_o()
  );

  // ctrl logic
  //
  always_comb begin
    f2i_signed_li = 1'b0;

    if (fp_int_decode_i.feq_op) begin
      result_o = {{(data_width_p-1){1'b0}}, eq_lo};
    end
    else if (fp_int_decode_i.fle_op) begin
      result_o = {{(data_width_p-1){1'b0}}, le_lo};
    end
    else if (fp_int_decode_i.flt_op) begin
      result_o = {{(data_width_p-1){1'b0}}, lt_lo};
    end
    else if (fp_int_decode_i.fcvt_w_s_op) begin
      f2i_signed_li = 1'b1;
      result_o = f2i_z_lo;
    end
    else if (fp_int_decode_i.fcvt_wu_s_op) begin
      f2i_signed_li = 1'b0;
      result_o = f2i_z_lo;
    end
    else if (fp_int_decode_i.fclass_op) begin
      result_o = class_lo;
    end
    else begin
      result_o = a_i; // covers fmv
    end
  end


endmodule
