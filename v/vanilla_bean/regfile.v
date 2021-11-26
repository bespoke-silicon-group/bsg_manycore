/**
 *    regfile.v
 *
 *    register file
 *
 *    use harden_p to choose between synthesized and hardened version.
 *
 *    @author tommy
 */

`include "bsg_defines.v"

module regfile
  #(`BSG_INV_PARAM(width_p)
    , `BSG_INV_PARAM(els_p)
    , `BSG_INV_PARAM(num_rs_p)
    , `BSG_INV_PARAM(x0_tied_to_zero_p)
    , harden_p=0

    , localparam addr_width_lp=`BSG_SAFE_CLOG2(els_p)
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


  if (harden_p) begin: hard
    regfile_hard #(
      .width_p(width_p)
      ,.els_p(els_p)
      ,.num_rs_p(num_rs_p)
      ,.x0_tied_to_zero_p(x0_tied_to_zero_p)
    ) rf (.*);
  end
  else begin: synth
    regfile_synth #(
      .width_p(width_p)
      ,.els_p(els_p)
      ,.num_rs_p(num_rs_p)
      ,.x0_tied_to_zero_p(x0_tied_to_zero_p)
    ) rf (.*);
  end



endmodule

`BSG_ABSTRACT_MODULE(regfile)
