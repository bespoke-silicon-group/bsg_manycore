/**
 *  fpu_int.v
 *  
 *  FPU for instructions that writes back to integer regfile.
 *
 *  - FCLASS
 *  - FLE, FLT, FEQ
 *  - FCVT.
 */

`include "definitions.vh"
`include "parameters.vh"

module fpu_int
  #(parameter e_p=8
    , parameter m_p=23
    , parameter data_width_p = RV32_reg_data_width_gp
  )
  (
    input [data_width_p-1:0] rs1_i
    , input [data_width_p-1:0] rs2_i
    , input fp_decode_s fp_decode_i
    , output logic [data_width_p-1:0] result_o
  );

  // classify
  //
  logic [data_width_p-1:0] class_lo;

  bsg_fpu_classify #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) classify (
    .a_i(rs1_i)
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
    .a_i(rs1_i)
    ,.signed_i()

    ,.z_o()
    ,.invalid_o()    
  );

  // cmp
  //
  bsg_fpu_cmp #(
    .e_p(e_p)
    ,.m_p(m_p)
  ) cmp (
  );


endmodule
