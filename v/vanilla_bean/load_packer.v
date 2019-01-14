module load_packer
 #(parameter data_width_p = RV32_reg_data_width_gp
  )
  (input [data_width_p-1:0]        mem_data_i

  ,input                           unsigned_load_i
  ,input                           byte_load_i
  ,input                           hex_load_i
  ,input [1:0]                     part_sel_i

  ,output logic [data_width_p-1:0] load_data_o
  );

  logic [data_width_p-1:0] loaded_byte;
  always_comb
  begin
    unique casez (part_sel_i)
      2'b00:    loaded_byte = mem_data_i[0+:8];
      2'b01:    loaded_byte = mem_data_i[8+:8];
      2'b10:    loaded_byte = mem_data_i[16+:8];
      default:  loaded_byte = mem_data_i[24+:8];
    endcase
  end


  wire [RV32_reg_data_width_gp-1:0] loaded_hex = (|part_sel_i)
                                                   ? mem_data_i[16+:16]
                                                   : mem_data_i[0+:16];
  
  always_comb
  begin
    if (byte_load_i)
      load_data_o = (unsigned_load_i)
                      ? 32'(loaded_byte[7:0])
                      : {{24{loaded_byte[7]}}, loaded_byte[7:0]};
    else if(hex_load_i)
      load_data_o = (unsigned_load_i)
                      ? 32'(loaded_hex[15:0])
                      : {{24{loaded_hex[15]}}, loaded_hex[15:0]};
    else
      load_data_o = mem_data_i;
  end

endmodule
