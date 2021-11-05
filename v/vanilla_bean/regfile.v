/**
 *    regfile.v
 *
 *    register file
 *    
 *    Use sel_sram_latch_rf_p to pick an implementation.
 *    
 *    @author tommy
 */

`include "bsg_defines.v"

module regfile
  #(`BSG_INV_PARAM(width_p)
    , `BSG_INV_PARAM(els_p)
    , `BSG_INV_PARAM(num_rs_p)
    , `BSG_INV_PARAM(x0_tied_to_zero_p)
    // FF-based = 0
    // Latch-based = 1
    // SRAM-based = 2
    , parameter sel_sram_latch_rf_p=0

    , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
  )
  (
    input clk_i
    , input reset_i

    , input w_v_i
    , input [addr_width_lp-1:0] w_addr_i
    , input [width_p-1:0] w_data_i
    
    , input [num_rs_p-1:0] r_v_i
    , input [num_rs_p-1:0][addr_width_lp-1:0] r_addr_i
    , output logic [num_rs_p-1:0][width_p-1:0] r_data_o
  );


  if (sel_sram_latch_rf_p == 2) begin: sram
    regfile_hard #(
      .width_p(width_p)
      ,.els_p(els_p)
      ,.num_rs_p(num_rs_p)
      ,.x0_tied_to_zero_p(x0_tied_to_zero_p)
    ) rf (.*);
  end
  else if (sel_sram_latch_rf_p == 1) begin: latch
    bsg_mem_multiport_latch #(
      .width_p(width_p)
      ,.els_p(els_p)
      ,.num_rs_p(num_rs_p)
      ,.x0_tied_to_zero_p(x0_tied_to_zero_p)
    ) rf (.*);
  end
  else if (sel_sram_latch_rf_p == 0) begin: ff
    regfile_synth #(
      .width_p(width_p)
      ,.els_p(els_p)
      ,.num_rs_p(num_rs_p)
      ,.x0_tied_to_zero_p(x0_tied_to_zero_p)
    ) rf (.*);
  end
  // synopsys translate_off
  else begin
    $error("[BSG_ERROR] Invalid configuration.");
  end
  // synopsys translate_on



endmodule

`BSG_ABSTRACT_MODULE(regfile)
