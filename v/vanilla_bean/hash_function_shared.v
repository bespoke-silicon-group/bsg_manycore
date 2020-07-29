/**
 *  hash_function_shared.v
 *  Given a shared EVA, this module calculates the 
 *  destination tile's X/Y coordinates, as well as the 
 *  local offset within that tile.
 *
 *  The input hash indicates the stripe size of the tile 
 *  group shared array. Stripe bits are selected accordingly.
 *
 *  Input address shared_eva_i format: 
 *   UNUSED    -    ADDR    -              Y             -               X            -    Stripe    -    00
 *  <11-x-y>   -  <12 - s>  -   <y = tg_dim_y_width_i>   -   <x = tg_dim_x_width_i>   -   <hash_i>   -    <2>
 *  Stripe is lowest bits of offset from local dmem
 */

module hash_function_shared
  import bsg_manycore_pkg::*;
  #(parameter width_p="inv"
    ,parameter x_cord_width_p="inv"
    ,parameter y_cord_width_p="inv"
    ,parameter hash_width_p="inv"
  )
  (
    input en_i
    ,input [width_p-1:0] shared_eva_i
    ,input [hash_width_p-1:0] hash_i
    ,input [x_cord_width_p-1:0] tg_dim_x_width_i
    ,input [y_cord_width_p-1:0] tg_dim_y_width_i
    ,output logic [x_cord_width_p-1:0] x_o
    ,output logic [y_cord_width_p-1:0] y_o
    ,output logic [epa_word_addr_width_gp-1:0] addr_o
  );


  always_comb begin
    // Hash bits cannot be larger than the entire address bits
    if (~en_i | (hash_i > max_local_offset_width_gp)) begin
      x_o = '0;
      y_o = '0;
      addr_o = '0;
    end
   
    else begin
      // X coordinate
      for (integer i = 0; i < tg_dim_x_width_i; i = i + 1) begin
        x_o[i] = shared_eva_i[i+hash_i];
      end

      // Y coordinate
      for (integer i = 0; i < tg_dim_y_width_i; i = i + 1) begin
        y_o[i] = shared_eva_i[i+tg_dim_x_width_i+hash_i];
      end

      // The LSB bits of address are stripe
      for (integer i = 0; i < hash_i; i = i + 1) begin
          addr_o[i] = shared_eva_i[i];
      end

      // The MSB bits of address are the local offset
      for (integer i = hash_i; i < epa_word_addr_width_gp; i = i + 1) begin
          addr_o[i] = shared_eva_i[i+tg_dim_y_width_i+tg_dim_x_width_i];
      end
    end
  end

endmodule
