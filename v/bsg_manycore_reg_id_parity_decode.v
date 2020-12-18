module bsg_manycore_reg_id_parity_decode
  import bsg_manycore_pkg::*;
  #(parameter data_width_p=32
    , parameter reg_id_width_p=bsg_manycore_reg_id_width_gp
  )
  (
    input [data_width_p-1:0] data_i
    , output logic [reg_id_width_p-1:0] reg_id_o
  );


  assign reg_id_o = data_i[0+:reg_id_width_p]
    ^ data_i[8+:reg_id_width_p]
    ^ data_i[16+:reg_id_width_p]
    ^ data_i[24+:reg_id_width_p];

endmodule
