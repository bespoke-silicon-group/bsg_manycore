
`include "bsg_defines.v"

module bsg_manycore_reg_id_decode
  import bsg_manycore_pkg::*;
  #(parameter data_width_p=32
    , localparam data_mask_width_lp=data_width_p>>3
    , parameter reg_id_width_p=bsg_manycore_reg_id_width_gp
  )
  (
    input [data_width_p-1:0] data_i
    , input [data_mask_width_lp-1:0] mask_i
    , output logic [reg_id_width_p-1:0] reg_id_o
  );

  
  assign reg_id_o =
    (data_i[0+:reg_id_width_p] & {reg_id_width_p{~mask_i[0]}})
    | (data_i[8+:reg_id_width_p] & {reg_id_width_p{~mask_i[1]}})
    | (data_i[16+:reg_id_width_p] & {reg_id_width_p{~mask_i[2]}})
    | (data_i[24+:reg_id_width_p] & {reg_id_width_p{~mask_i[3]}});

endmodule

