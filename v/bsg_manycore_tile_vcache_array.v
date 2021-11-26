/**
 *    bsg_manycore_tile_vcache_array.v
 *  
 *    This module instantiates vcaches and associated ruche buffers.
 */

`include "bsg_manycore_defines.vh"

module bsg_manycore_tile_vcache_array
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)

    // Number of tiles in a pod
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    
    , localparam x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , localparam y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    // Number of tiles in a subarray 
    , parameter `BSG_INV_PARAM(subarray_num_tiles_x_p)

    , `BSG_INV_PARAM(num_vcache_rows_p )
    , `BSG_INV_PARAM(vcache_addr_width_p )
    , `BSG_INV_PARAM(vcache_data_width_p )
    , `BSG_INV_PARAM(vcache_ways_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_dma_data_width_p)

    , `BSG_INV_PARAM(wh_ruche_factor_p)
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)

    , num_clk_ports_p=1
    //, parameter reset_depth_p = 3

    , localparam manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)
  )
  (
    input [num_clk_ports_p-1:0] clk_i
    , input [subarray_num_tiles_x_p-1:0] reset_i
    , output logic [subarray_num_tiles_x_p-1:0] reset_o

    , input  [E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o  
    
    , input  [S:N][subarray_num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][subarray_num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // coord id
    , input [subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    , input [subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
    , output [subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_o
    , output [subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_o
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);

  logic [num_vcache_rows_p-1:0][subarray_num_tiles_x_p-1:0] reset_li, reset_lo;
  wh_link_sif_s [num_vcache_rows_p-1:0][subarray_num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] wh_link_sif_li, wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_vcache_rows_p-1:0][subarray_num_tiles_x_p-1:0][S:N] ver_link_sif_li, ver_link_sif_lo;
  logic [num_vcache_rows_p-1:0][subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_li, global_x_lo;
  logic [num_vcache_rows_p-1:0][subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_li, global_y_lo;

  // instantiate vcaches.
  for (genvar y = 0; y < num_vcache_rows_p; y++) begin: vc_y
    for (genvar x = 0; x < subarray_num_tiles_x_p; x++) begin: vc_x
      bsg_manycore_tile_vcache #(
        .addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.num_tiles_y_p(num_tiles_y_p)  

        ,.vcache_addr_width_p(vcache_addr_width_p)
        ,.vcache_data_width_p(vcache_data_width_p)
        ,.vcache_ways_p(vcache_ways_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_dma_data_width_p(vcache_dma_data_width_p)

        ,.wh_ruche_factor_p(wh_ruche_factor_p)
        ,.wh_cid_width_p(wh_cid_width_p)
        ,.wh_flit_width_p(wh_flit_width_p)
        ,.wh_len_width_p(wh_len_width_p)
        ,.wh_cord_width_p(wh_cord_width_p)
      ) vc (
        .clk_i(clk_i[x/(subarray_num_tiles_x_p/num_clk_ports_p)])
        ,.reset_i(reset_li[y][x])
        ,.reset_o(reset_lo[y][x])

        ,.wh_link_sif_i(wh_link_sif_li[y][x])
        ,.wh_link_sif_o(wh_link_sif_lo[y][x])

        ,.ver_link_sif_i(ver_link_sif_li[y][x])
        ,.ver_link_sif_o(ver_link_sif_lo[y][x])

        ,.global_x_i(global_x_li[y][x])
        ,.global_y_i(global_y_li[y][x])

        ,.global_x_o(global_x_lo[y][x])
        ,.global_y_o(global_y_lo[y][x])

      );
    
      // connect north
      if (y == 0) begin
        assign reset_li[y][x] = reset_i[x];
        assign global_x_li[y][x] = global_x_i[x];
        assign global_y_li[y][x] = global_y_i[x];

        assign ver_link_sif_o[N][x] = ver_link_sif_lo[y][x][N];
        assign ver_link_sif_li[y][x][N] = ver_link_sif_i[N][x];
      end

      // connect between rows
      if (y < num_vcache_rows_p-1) begin
        assign reset_li[y+1][x] = reset_lo[y][x];
        assign global_x_li[y+1][x] = global_x_lo[y][x];
        assign global_y_li[y+1][x] = global_y_lo[y][x];

        assign ver_link_sif_li[y+1][x][N] = ver_link_sif_lo[y][x][S];
        assign ver_link_sif_li[y][x][S] = ver_link_sif_lo[y+1][x][N];
      end

      // connect south
      if (y == num_vcache_rows_p-1) begin
        assign reset_o[x] = reset_lo[y][x];
        assign global_x_o[x] = global_x_lo[y][x];
        assign global_y_o[x] = global_y_lo[y][x];
    
        assign ver_link_sif_o[S][x] = ver_link_sif_lo[y][x][S];
        assign ver_link_sif_li[y][x][S] = ver_link_sif_i[S][x];
      end
      
    end
  end



  // connect wh ruche link
  for (genvar r = 0; r < num_vcache_rows_p; r++) begin: rr
    for (genvar c = 0; c < subarray_num_tiles_x_p; c++) begin: rc
      for (genvar l = 0; l < wh_ruche_factor_p; l++) begin: rl // ruche stage
        if (c == subarray_num_tiles_x_p-1) begin: cl

          bsg_ruche_buffer #(
            .width_p(wh_link_sif_width_lp)
            ,.ruche_factor_p(wh_ruche_factor_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_w (
            .i(wh_link_sif_i[E][r][l])
            ,.o(wh_link_sif_li[r][c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E])
          );

          bsg_ruche_buffer #(
            .width_p(wh_link_sif_width_lp)
            ,.ruche_factor_p(wh_ruche_factor_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_e (
            .i(wh_link_sif_lo[r][c][l][E])
            ,.o(wh_link_sif_o[E][r][(l+1) % wh_ruche_factor_p])
          );

        end
        else begin: cn

          bsg_ruche_buffer #(
            .width_p(wh_link_sif_width_lp)
            ,.ruche_factor_p(wh_ruche_factor_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_w (
            .i(wh_link_sif_lo[r][c+1][l][W])
            ,.o(wh_link_sif_li[r][c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E])
          );

          bsg_ruche_buffer #(
            .width_p(wh_link_sif_width_lp)
            ,.ruche_factor_p(wh_ruche_factor_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_e (
            .i(wh_link_sif_lo[r][c][l][E])
            ,.o(wh_link_sif_li[r][c+1][(l+1) % wh_ruche_factor_p][W])
          );

        end
      end
    end
  end


  // connect edge ruche links
  for (genvar r = 0; r < num_vcache_rows_p; r++) begin
    for (genvar l = 0; l < wh_ruche_factor_p; l++) begin
      //  west
      assign wh_link_sif_o[W][r][l] = wh_link_sif_lo[r][0][l][W];
      assign wh_link_sif_li[r][0][l][W] = wh_link_sif_i[W][r][l];
    end
  end 



endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_vcache_array)
