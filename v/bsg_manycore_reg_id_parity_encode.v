module bsg_manycore_reg_id_parity_encode
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
    , output [reg_id_width_p-1:0] reg_id_o
    , output bsg_manycore_packet_op_e op_o
  );


  always_comb begin
    data_o = data_i;

    if (mask_i == 4'b1111) begin
      data_o = data_i;
    end
    else if (mask_i == 4'b0011) begin
      data_o[15:0]  = data_i[15:0];
      data_o[23:16] = {3'b0, data_i[4:0] ^ data_i[12:8]};
      data_o[31:24] = {3'b0, reg_id_i};
    end
    else if (mask_i == 4'b1100) begin
      data_o[31:16] = data_i[15:0];
      data_o[7:0]   = {3'b0, data_i[4:0] ^ data_i[12:8]};
      data_o[15:8]  = {3'b0, reg_id_i};
    end
    else if (mask_i == 4'b0100 || mask_i == 4'b1000) begin
      data_o[31:24] = data_i[7:0];
      data_o[23:16] = data_i[7:0];
      data_o[15:8]  = '0;
      data_o[7:0]   = {3'b0, reg_id_i};
    end
    else if (mask_i == 4'b0010 || mask_i == 4'b0001) begin
      data_o[31:24] = '0;
      data_o[23:16] = {3'b0, reg_id_i};
      data_o[15:8]  = data_i[7:0];
      data_o[7:0]   = data_i[7:0];
    end

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
