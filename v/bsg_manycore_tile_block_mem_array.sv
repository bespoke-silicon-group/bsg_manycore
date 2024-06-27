/**
 *    bsg_manycore_tile_block_mem_array.sv
 */


`include "bsg_manycore_defines.svh"


module bsg_manycore_tile_block_mem_array
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(icache_block_size_in_words_p)
    , `BSG_INV_PARAM(mem_size_in_words_p)

    // number of tiles in a pod;
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , localparam x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , localparam y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    , localparam manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input [num_tiles_x_p-1:0] reset_i
    , output logic [num_tiles_x_p-1:0] reset_o

    // manycore links;
    , input  [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // coord id;
    , input [num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    , input [num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
    , output [num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_o
    , output [num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_o
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:N] ver_link_sif_li, ver_link_sif_lo;

  
  for (genvar x = 0; x < num_tiles_x_p; x++) begin: mx
    bsg_manycore_tile_block_mem #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.mem_size_in_words_p(mem_size_in_words_p)
      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)    

      ,.num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)
    ) bmem (
      .clk_i(clk_i)
      ,.reset_i(reset_i[x])
      ,.reset_o(reset_o[x])

      ,.ver_link_sif_i(ver_link_sif_li[x])
      ,.ver_link_sif_o(ver_link_sif_lo[x])

      ,.global_x_i(global_x_i[x])
      ,.global_y_i(global_y_i[x])
      ,.global_x_o(global_x_o[x])
      ,.global_y_o(global_y_o[x])
    );


    // connect North;
    assign ver_link_sif_o[N][x] = ver_link_sif_lo[x][N];
    assign ver_link_sif_li[x][N] = ver_link_sif_i[N][x];

    // connect South;
    assign ver_link_sif_o[S][x] = ver_link_sif_lo[x][S];
    assign ver_link_sif_li[x][S] = ver_link_sif_i[S][x];
  end



endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_tile_block_mem_array)
