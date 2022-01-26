`include "bsg_vanilla_defines.vh"

module mem_pipeline
  import bsg_vanilla_pkg::*;
  (
    input clk_i
    , input reset_i

    , input en_i
    , input mem_signals_s data_i
    , output mem_signals_s data_o
  );

  // ctrl DFF
  logic [3:0] ctrl_in, ctrl_out;
  assign ctrl_in =  {
    data_i.write_rd,
    data_i.write_frd,
    data_i.local_load,
    data_i.icache_miss
  };
  assign {
    data_o.write_rd,
    data_o.write_frd,
    data_o.local_load,
    data_o.icache_miss
  } = ctrl_out;

  bsg_dff_reset_en #(
    .width_p(4)
    ,.reset_val_p(0)
  ) dff_ctrl (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(en_i)
    ,.data_i(ctrl_in)
    ,.data_o(ctrl_out)
  );

  // load info DFF
  logic [4:0] load_info_in, load_info_out;
  assign load_info_in = {
    data_i.is_byte_op,
    data_i.is_hex_op,
    data_i.is_load_unsigned,
    data_i.byte_sel
  };
  assign {
    data_o.is_byte_op,
    data_o.is_hex_op,
    data_o.is_load_unsigned,
    data_o.byte_sel
  } = load_info_out;

  bsg_dff_reset_en #(
    .width_p(5)
    ,.reset_val_p(0)
  ) dff_load_info (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(en_i & data_i.local_load & data_i.write_rd)
    ,.data_i(load_info_in)
    ,.data_o(load_info_out)
  );

  // rd_addr DFF
  bsg_dff_reset_en #(
    .width_p(RV32_reg_addr_width_gp)
    ,.reset_val_p(0)
  ) dff_rd_addr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(en_i & (data_i.write_rd | data_i.write_frd))
    ,.data_i(data_i.rd_addr)
    ,.data_o(data_o.rd_addr)
  );
  

  // exe_result DFF
  bsg_dff_en #( 
    .width_p(RV32_reg_data_width_gp)
  ) dff_exe_result (
    .clk_i(clk_i)
    ,.en_i(en_i & data_i.write_rd)
    ,.data_i(data_i.exe_result)
    ,.data_o(data_o.exe_result)
  );

endmodule
