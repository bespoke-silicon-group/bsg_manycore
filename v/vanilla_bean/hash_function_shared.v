/**
 *  hash_function_shared.v
 *  Given a shared EVA, this module calculates the 
 *  destination tile's X/Y coordinates, as well as the 
 *  local offset within that tile.
 *
 *  The input hash indicates the stripe size of the tile 
 *  group shared array. Stripe bits are selected accordingly.
 *
 */

module hash_function_shared
  import bsg_manycore_pkg::*;
  #(parameter width_p="inv"
    ,parameter x_cord_width_p
    ,parameter y_cord_width_p
    ,parameter x_cord_width_lp
    ,parameter y_cord_width_lp
    ,parameter hash_width_p
  )
  (
    input [width_p-1:0] shared_eva_i
    ,input [hash_width_p-1:0] hash
    ,output logic [x_cord_width_p-1:0] x_o
    ,output logic [y_cord_width_p-1:0] y_o
    ,output logic [epa_word_addr_width_gp-1:0] addr_o
  );


  always_comb begin
    // Hash bits cannot be larger than the entire address bits
    // TODO: add an assert
    if (hash > max_local_offset_width_gp) begin
      x_o = 0;
      y_o = 0;
      addr_o = 0;
    end
   
    else begin
      for (integer i = 0; i < x_cord_width_lp; i = i + 1) begin
        x_o[i] = shared_eva_i[i+hash];
      end

      for (integer i = 0; i < y_cord_width_lp; i = i + 1) begin
        y_o[i] = shared_eva_i[i+x_cord_width_lp+hash];
      end

      // The LSB bits of address are stripe
      for (integer i = 0; i < hash; i = i + 1) begin
          addr_o[i] = shared_eva_i[i];
      end

      // The MSB bits of address are the local offset
      for (integer i = hash; i < epa_word_addr_width_gp; i = i + 1) begin
          addr_o[i] = shared_eva_i[i+y_cord_width_lp+x_cord_width_lp];
      end
    end
  end

endmodule
