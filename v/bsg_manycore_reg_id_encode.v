/**
 *    bsg_manycore_reg_id_encode.v
 *
 *    encode reg_id into the data field for non-word sized access.
 *
 *    data_i should be byte-selected for its access size.
 */

`include "bsg_defines.v"

module bsg_manycore_reg_id_encode
  import bsg_manycore_pkg::*;
  #(parameter data_width_p=32
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter reg_id_width_p=bsg_manycore_reg_id_width_gp
  )
  ( 
    input [data_width_p-1:0] data_i
    , input [data_mask_width_lp-1:0] mask_i
    , input [reg_id_width_p-1:0] reg_id_i

    , output logic [data_width_p-1:0] data_o
    , output logic [reg_id_width_p-1:0] reg_id_o
    , output bsg_manycore_packet_op_e op_o
  );


  bsg_mux_segmented #(
    .segments_p(data_mask_width_lp)
    ,.segment_width_p(8)
  ) mux0 (
    .data0_i({4{3'b0,reg_id_i}})
    ,.data1_i(data_i)
    ,.sel_i(mask_i)
    ,.data_o(data_o)
  );


  always_comb begin

    if (mask_i == 4'b1111) begin
      reg_id_o = reg_id_i;
      op_o = e_remote_sw;
    end
    else begin
      reg_id_o = {1'b0, mask_i};
      op_o = e_remote_store;
    end
  end

endmodule

