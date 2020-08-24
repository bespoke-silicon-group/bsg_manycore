/**
 *  hash_function_shared.v
 *  Given a shared EVA, this module calculates the 
 *  destination tile's X/Y coordinates, as well as the 
 *  local offset within that tile.
 *
 *  Input address shared_eva_i format: 
 *   UNUSED    -    ADDR    -              Y             -               X            -    Stripe    -    00
 *  <11-x-y>   -  <12 - s>  -   <y = tg_dim_y_width_i>   -   <x = tg_dim_x_width_i>   -   <shared_addr.hash>   -    <2>
 *  Stripe is lowest bits of offset from local dmem
 */

module hash_function_shared
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter x_cord_width_p="inv"
    ,parameter y_cord_width_p="inv"
  )
  (
    input [data_width_p-1:0] eva_i
    ,input [x_cord_width_p-1:0] tg_dim_x_width_i
    ,input [y_cord_width_p-1:0] tg_dim_y_width_i
    ,output logic [x_cord_width_p-1:0] x_o
    ,output logic [y_cord_width_p-1:0] y_o
    ,output logic [epa_word_addr_width_gp-1:0] addr_o
  );

  `declare_bsg_manycore_shared_addr_s;

  bsg_manycore_shared_addr_s shared_addr;
  assign shared_addr = eva_i;

  always_comb begin
    // Hash bits cannot be larger than the entire address bits
    if (shared_addr.hash > max_local_offset_width_gp) begin
      x_o = '0;
      y_o = '0;
      addr_o = '0;
    end
   
    else begin
      // X coordinate
      for (integer i = 0; i < tg_dim_x_width_i; i = i + 1) begin
        x_o[i] = shared_addr.addr[i+shared_addr.hash];
      end

      // Y coordinate
      for (integer i = 0; i < tg_dim_y_width_i; i = i + 1) begin
        y_o[i] = shared_addr.addr[i+tg_dim_x_width_i+shared_addr.hash];
      end

      // The LSB bits of address are stripe
      for (integer i = 0; i < shared_addr.hash; i = i + 1) begin
          addr_o[i] = shared_addr.addr[i];
      end

      // The MSB bits of address are the local offset
      for (integer i = shared_addr.hash; i < epa_word_addr_width_gp; i = i + 1) begin
          addr_o[i] = shared_addr.addr[i+tg_dim_y_width_i+tg_dim_x_width_i];
      end
    end
  end

endmodule
