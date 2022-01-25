`include "bsg_vanilla_defines.vh"

module flw_wb_pipeline
  import bsg_vanilla_pkg::*;
  (
    input clk_i
    , input reset_i
    
    , input en_i
    , input flw_wb_signals_s data_i
    , output flw_wb_signals_s data_o
  );  

  bsg_dff_reset_en #(
    .width_p(1)
    ,.reset_val_p(0)
  ) dff_valid (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(en_i)
    ,.data_i(data_i.valid)
    ,.data_o(data_o.valid)
  );
  
  wire data_en = en_i & data_i.valid;
  
  bsg_dff_reset_en #( 
    .width_p(RV32_reg_addr_width_gp)
    ,.reset_val_p(0)
  ) dff_addr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(data_en)
    ,.data_i(data_i.rd_addr)
    ,.data_o(data_o.rd_addr)
  );

  bsg_dff_en #( 
    .width_p(RV32_reg_data_width_gp)
  ) dff_data (
    .clk_i(clk_i)
    ,.en_i(data_en)
    ,.data_i(data_i.rf_data)
    ,.data_o(data_o.rf_data)
  );


endmodule
