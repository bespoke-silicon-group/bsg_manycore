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
    ,parameter x_cord_width_lp
    ,parameter y_cord_width_lp
    ,parameter hash_width_lp
  )
  (
    input [width_p-1:0] i
    ,input [hash_width_lp-1:0] hash
    ,output logic [x_cord_width_lp-1:0] x_o
    ,output logic [y_cord_width_lp-1:0] y_o
    ,output logic [epa_word_addr_width_gp-1:0] addr_o
  );


  always_comb begin
    if (hash == 0) begin: s0
      x_o = i[x_cord_width_lp-1:0];
      y_o = i[y_cord_width_lp+x_cord_width_lp-1:x_cord_width_lp];
      addr_o = i[width_p-1:y_cord_width_lp+x_cord_width_lp];
    end
    else if (hash == 1) begin: s1
      x_o = i[x_cord_width_lp+1-1:1];
      y_o = i[y_cord_width_lp+x_cord_width_lp+1-1:x_cord_width_lp+1];
      addr_o = {i[width_p-1:y_cord_width_lp+x_cord_width_lp+1], i[0]};
    end
    else if (hash == 2) begin: s2
      x_o = i[x_cord_width_lp+2-1:2];
      y_o = i[y_cord_width_lp+x_cord_width_lp+2-1:x_cord_width_lp+2];
      addr_o = {i[width_p-1:y_cord_width_lp+x_cord_width_lp+2], i[1:0]};
    end
    else if (hash == 3) begin: s3
      x_o = i[x_cord_width_lp+3-1:3];
      y_o = i[y_cord_width_lp+x_cord_width_lp+3-1:x_cord_width_lp+3];
      addr_o = {i[width_p-1:y_cord_width_lp+x_cord_width_lp+3], i[2:0]};
    end
    else begin: unhandled
      x_o = 0;
      y_o = 0;
      addr_o = 0;
    end
  end

endmodule
