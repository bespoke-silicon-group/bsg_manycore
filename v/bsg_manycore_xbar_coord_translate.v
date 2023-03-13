`include "bsg_manycore_defines.vh"


module bsg_manycore_xbar_coord_translate
  #(parameter `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(host_x_cord_p)   
    , `BSG_INV_PARAM(host_y_cord_p)   
    , `BSG_INV_PARAM(fwd_not_rev_p)

    , localparam num_out_lp = (fwd_not_rev_p
                              ? 1+(num_tiles_x_p*num_tiles_y_p)+(2*num_tiles_x_p)
                              : 1+(num_tiles_x_p*num_tiles_y_p))
    , lg_num_out_lp = `BSG_SAFE_CLOG2(num_out_lp)
  )
  (
    input [y_cord_width_p+x_cord_width_p-1:0] cord_i
    , output logic [num_out_lp-1:0] sel_one_hot_o
    //, output logic [lg_num_out_lp-1] sel_id_o
  );

  logic [y_cord_width_p-1:0] y_cord;
  logic [x_cord_width_p-1:0] x_cord;
  assign {y_cord, x_cord} = cord_i;

  logic host_sel;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0] tile_sel;
  logic [num_tiles_x_p-1:0] north_vc_sel, south_vc_sel;

  // Host
  assign host_sel = (y_cord == host_y_cord_p)
                 && (x_cord == host_x_cord_p);

  // Tiles
  wire is_tile_coord = (y_cord >= num_tiles_y_p)
                    && (y_cord < num_tiles_y_p*2)
                    && (x_cord >= num_tiles_x_p)
                    && (x_cord < num_tiles_x_p*2);
  wire [x_cord_width_p-1:0] tile_x = x_cord - num_tiles_x_p;
  wire [y_cord_width_p-1:0] tile_y = y_cord - num_tiles_y_p;
  
  always_comb begin
    tile_sel = '0;
    if (is_tile_coord) begin
      tile_sel[tile_y][tile_x] = 1'b1;
    end
  end
  
  // vcaches
  wire is_north_vc = (y_cord == (num_tiles_y_p-1))
                  && (x_cord >= num_tiles_x_p)
                  && (x_cord < num_tiles_x_p*2);
  wire is_south_vc = (y_cord == (num_tiles_y_p*2))
                  && (x_cord >= num_tiles_x_p)
                  && (x_cord < num_tiles_x_p*2);
  always_comb begin
    north_vc_sel = '0;
    south_vc_sel = '0;
    if (is_north_vc) begin
      north_vc_sel[tile_x] = 1'b1;
    end
    if (is_south_vc) begin
      south_vc_sel[tile_x] = 1'b1;
    end
  end

  // outputs;
  assign sel_one_hot_o = fwd_not_rev_p
                       ? {south_vc_sel, north_vc_sel, tile_sel, host_sel}
                       : {tile_sel, host_sel};
/*
  bsg_encode_one_hot #(
  ) enc0 (
    .i()
    ,.addr_o()
  );
*/
endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_xbar_coord_translate)
