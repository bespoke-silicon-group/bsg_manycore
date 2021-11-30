/**
 *  load_packer.v
 *
 */

`include "bsg_defines.v"

module load_packer
  import bsg_vanilla_pkg::*;
  #(data_width_p = RV32_reg_data_width_gp)
  (
    input [data_width_p-1:0] mem_data_i

    , input unsigned_load_i
    , input byte_load_i
    , input hex_load_i
    , input [1:0] part_sel_i

    , output logic [data_width_p-1:0] load_data_o
  );

  logic [7:0] loaded_byte;
  logic [15:0] loaded_half;

  bsg_mux #(
    .width_p(8)
    ,.els_p(data_width_p>>3)
  ) byte_sel_mux (
    .data_i(mem_data_i)
    ,.sel_i(part_sel_i)
    ,.data_o(loaded_byte)
  );

  bsg_mux #(
    .width_p(16)
    ,.els_p(data_width_p>>4)
  ) half_sel_mux (
    .data_i(mem_data_i)
    ,.sel_i(part_sel_i[1])
    ,.data_o(loaded_half)
  );

  logic half_sigext;
  logic byte_sigext;

  assign half_sigext = ~unsigned_load_i & loaded_half[15];
  assign byte_sigext = ~unsigned_load_i & loaded_byte[7];

  
  always_comb begin
    if (byte_load_i) begin
      load_data_o = {{24{byte_sigext}}, loaded_byte};
    end
    else if (hex_load_i) begin
      load_data_o = {{16{half_sigext}}, loaded_half};
    end
    else begin
      load_data_o = mem_data_i;
    end
  end

endmodule

