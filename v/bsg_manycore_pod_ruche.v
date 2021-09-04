/**
 *    bsg_manycore_pod_ruche.v
 *
 *    manycore pod with ruche network.
 *
 */


`include "bsg_defines.v"
`include "bsg_noc_links.vh"

module bsg_manycore_pod_ruche
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  #(// number of tiles in a pod
    parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"

    // This determines how to divide the pod into smaller hierarchical blocks.
    , parameter num_subarray_x_p="inv"
    , parameter num_subarray_y_p="inv"
    // Number of tiles in a subarray
    , parameter subarray_num_tiles_x_lp = (num_tiles_x_p/num_subarray_x_p)
    , parameter subarray_num_tiles_y_lp = (num_tiles_y_p/num_subarray_y_p)
    
    // coordinate width within a pod
    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)
  
    , parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"
 
    , parameter num_vcache_rows_p="inv"  
    , parameter vcache_addr_width_p="inv" 
    , parameter vcache_data_width_p="inv" 
    , parameter vcache_ways_p="inv"
    , parameter vcache_sets_p="inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_size_p="inv"
    , parameter vcache_dma_data_width_p="inv"

    , parameter ruche_factor_X_p="inv"
  
    , parameter wh_ruche_factor_p="inv"
    , parameter wh_cid_width_p="inv"
    , parameter wh_flit_width_p="inv"
    , parameter wh_cord_width_p="inv"
    , parameter wh_len_width_p="inv"
    
    // number of clock ports on vcache/tile subarray
    , parameter num_clk_ports_p=1

    , parameter manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter manycore_ruche_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)

    // This is used to define heterogeneous arrays. Each index defines
    // the type of an X/Y coordinate in the array. This is a vector of
    // num_tiles_x_p*num_tiles_y_p ints; type "0" is the
    // default. See bsg_manycore_hetero_socket.v for more types.
    `ifndef SYNTHESIS
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}
    `endif
  )
  (
    // manycore 
    input clk_i
    , input [num_tiles_x_p-1:0] reset_i

    , input  [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o

    , input  [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    , input  [E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][manycore_ruche_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][manycore_ruche_link_sif_width_lp-1:0] ruche_link_o


    // vcache
    , input  [E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] north_wh_link_sif_i
    , output [E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] north_wh_link_sif_o

    , input  [E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] south_wh_link_sif_i
    , output [E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] south_wh_link_sif_o


    // pod cord (should be all same value for all columns)
    , input [num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    , input [num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);


  // vcache row (north)
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0] north_vc_reset_lo;
  wh_link_sif_s [num_subarray_x_p-1:0][E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] north_vc_wh_link_sif_li;
  wh_link_sif_s [num_subarray_x_p-1:0][E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] north_vc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_subarray_x_p-1:0][S:N][subarray_num_tiles_x_lp-1:0] north_vc_ver_link_sif_li;
  bsg_manycore_link_sif_s [num_subarray_x_p-1:0][S:N][subarray_num_tiles_x_lp-1:0] north_vc_ver_link_sif_lo;
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][x_cord_width_p-1:0] north_vc_global_x_li;
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][y_cord_width_p-1:0] north_vc_global_y_li;
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][x_cord_width_p-1:0] north_vc_global_x_lo;
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][y_cord_width_p-1:0] north_vc_global_y_lo;

  for (genvar x = 0; x < num_subarray_x_p; x++) begin: north_vc_x
    bsg_manycore_tile_vcache_array #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.pod_x_cord_width_p(pod_x_cord_width_p)
      ,.pod_y_cord_width_p(pod_y_cord_width_p)

      ,.num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)

      ,.subarray_num_tiles_x_p(subarray_num_tiles_x_lp)

      ,.num_vcache_rows_p(num_vcache_rows_p)
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

      ,.num_clk_ports_p(num_clk_ports_p)
    ) north_vc_row (
      .clk_i({num_clk_ports_p{clk_i}})

      ,.reset_i(reset_i[(subarray_num_tiles_x_lp*x)+:subarray_num_tiles_x_lp])
      ,.reset_o(north_vc_reset_lo[x])

      ,.wh_link_sif_i(north_vc_wh_link_sif_li[x])
      ,.wh_link_sif_o(north_vc_wh_link_sif_lo[x])
    
      ,.ver_link_sif_i(north_vc_ver_link_sif_li[x])
      ,.ver_link_sif_o(north_vc_ver_link_sif_lo[x])

      ,.global_x_i(north_vc_global_x_li[x])
      ,.global_y_i(north_vc_global_y_li[x])
      ,.global_x_o(north_vc_global_x_lo[x])
      ,.global_y_o(north_vc_global_y_lo[x])
    );


    // connect coordinates
    assign north_vc_global_x_li[x] = global_x_i[x*subarray_num_tiles_x_lp+:subarray_num_tiles_x_lp];
    assign north_vc_global_y_li[x] = global_y_i[x*subarray_num_tiles_x_lp+:subarray_num_tiles_x_lp];

    // connect north ver link
    assign ver_link_sif_o[N][(x*subarray_num_tiles_x_lp)+:subarray_num_tiles_x_lp] = north_vc_ver_link_sif_lo[x][N];
    assign north_vc_ver_link_sif_li[x][N] = ver_link_sif_i[N][(x*subarray_num_tiles_x_lp)+:subarray_num_tiles_x_lp]; 

    // connect wh link to west
    if (x == 0) begin
      assign north_wh_link_sif_o[W] = north_vc_wh_link_sif_lo[x][W];
      assign north_vc_wh_link_sif_li[x][W] = north_wh_link_sif_i[W];
    end

    // connect wh link to east
    if (x == num_subarray_x_p-1) begin
      assign north_wh_link_sif_o[E] = north_vc_wh_link_sif_lo[x][E];
      assign north_vc_wh_link_sif_li[x][E] = north_wh_link_sif_i[E];
    end
   
    // connect wh links between vc arrays
    if (x < num_subarray_x_p-1) begin
      assign north_vc_wh_link_sif_li[x+1][W] = north_vc_wh_link_sif_lo[x][E];
      assign north_vc_wh_link_sif_li[x][E] = north_vc_wh_link_sif_lo[x+1][W];
    end

  end



  // manycore subarray
  bsg_manycore_link_sif_s [num_subarray_y_p-1:0][num_subarray_x_p-1:0][E:W][subarray_num_tiles_y_lp-1:0] mc_hor_link_sif_li;
  bsg_manycore_link_sif_s [num_subarray_y_p-1:0][num_subarray_x_p-1:0][E:W][subarray_num_tiles_y_lp-1:0] mc_hor_link_sif_lo;
  bsg_manycore_link_sif_s [num_subarray_y_p-1:0][num_subarray_x_p-1:0][S:N][subarray_num_tiles_x_lp-1:0] mc_ver_link_sif_li;
  bsg_manycore_link_sif_s [num_subarray_y_p-1:0][num_subarray_x_p-1:0][S:N][subarray_num_tiles_x_lp-1:0] mc_ver_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [num_subarray_y_p-1:0][num_subarray_x_p-1:0][E:W][subarray_num_tiles_y_lp-1:0][ruche_factor_X_p-1:0] mc_ruche_link_li;
  bsg_manycore_ruche_x_link_sif_s [num_subarray_y_p-1:0][num_subarray_x_p-1:0][E:W][subarray_num_tiles_y_lp-1:0][ruche_factor_X_p-1:0] mc_ruche_link_lo;
  logic [num_subarray_y_p-1:0][num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][x_cord_width_p-1:0] mc_global_x_li;
  logic [num_subarray_y_p-1:0][num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][y_cord_width_p-1:0] mc_global_y_li;
  logic [num_subarray_y_p-1:0][num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][x_cord_width_p-1:0] mc_global_x_lo;
  logic [num_subarray_y_p-1:0][num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][y_cord_width_p-1:0] mc_global_y_lo;

  logic [num_subarray_y_p-1:0][num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0] mc_reset_li;
  logic [num_subarray_y_p-1:0][num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0] mc_reset_lo;

  // Split the hetero_type_vec_p array into sub-arrays.
  `ifndef SYNTHESIS
  typedef int hetero_type_sub_vec[0:(subarray_num_tiles_y_lp*subarray_num_tiles_x_lp) - 1];
  function hetero_type_sub_vec get_subarray_hetero_type_vec(int y, int x);
    hetero_type_sub_vec vec;
    for (int sy_i = 0; sy_i < subarray_num_tiles_y_lp; sy_i++) begin
      for (int sx_i = 0; sx_i < subarray_num_tiles_x_lp; sx_i++) begin
        vec[sy_i*subarray_num_tiles_x_lp + sx_i] = hetero_type_vec_p[(sy_i + y * subarray_num_tiles_y_lp) * num_tiles_x_p + x * subarray_num_tiles_x_lp + sx_i];
      end
    end
    return vec;
  endfunction
  `endif

  for (genvar y = 0; y < num_subarray_y_p; y++) begin: mc_y
    for (genvar x = 0; x < num_subarray_x_p; x++) begin: mc_x
      bsg_manycore_tile_compute_array_ruche #(
        .dmem_size_p(dmem_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)

        ,.num_vcache_rows_p(num_vcache_rows_p)
        ,.vcache_size_p(vcache_size_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)

        ,.subarray_num_tiles_x_p(subarray_num_tiles_x_lp)
        ,.subarray_num_tiles_y_p(subarray_num_tiles_y_lp)

        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.ruche_factor_X_p(ruche_factor_X_p)
          `ifndef SYNTHESIS
        ,.hetero_type_vec_p(get_subarray_hetero_type_vec(y, x))
          `endif
        ,.num_clk_ports_p(num_clk_ports_p)
      ) mc (
        .clk_i({num_clk_ports_p{clk_i}})

        ,.reset_i(mc_reset_li[y][x])
        ,.reset_o(mc_reset_lo[y][x])
    
        ,.hor_link_sif_i(mc_hor_link_sif_li[y][x])
        ,.hor_link_sif_o(mc_hor_link_sif_lo[y][x])

        ,.ver_link_sif_i(mc_ver_link_sif_li[y][x])
        ,.ver_link_sif_o(mc_ver_link_sif_lo[y][x])

        ,.ruche_link_i(mc_ruche_link_li[y][x])
        ,.ruche_link_o(mc_ruche_link_lo[y][x])

        ,.global_x_i(mc_global_x_li[y][x])
        ,.global_y_i(mc_global_y_li[y][x])
        ,.global_x_o(mc_global_x_lo[y][x])
        ,.global_y_o(mc_global_y_lo[y][x])
      );

      // connect to north vcache
      if (y == 0) begin
        // ver link
        assign north_vc_ver_link_sif_li[x][S] = mc_ver_link_sif_lo[y][x][N];
        assign mc_ver_link_sif_li[y][x][N] = north_vc_ver_link_sif_lo[x][S];
        // coordinates
        assign mc_global_x_li[y][x] = north_vc_global_x_lo[x];
        assign mc_global_y_li[y][x] = north_vc_global_y_lo[x];
        // reset
        assign mc_reset_li[y][x] = north_vc_reset_lo[x];
      end
  
      // connect ver links to the next row
      if (y < num_subarray_y_p-1) begin
        // ver link
        assign mc_ver_link_sif_li[y+1][x][N] = mc_ver_link_sif_lo[y][x][S];
        assign mc_ver_link_sif_li[y][x][S] = mc_ver_link_sif_lo[y+1][x][N];
        // coordinates
        assign mc_global_x_li[y+1][x] = mc_global_x_lo[y][x];
        assign mc_global_y_li[y+1][x] = mc_global_y_lo[y][x];
        // reset
        assign mc_reset_li[y+1][x] = mc_reset_lo[y][x];
      end

      // connect to west
      if (x == 0) begin
        // local link
        assign hor_link_sif_o[W][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp] = mc_hor_link_sif_lo[y][x][W];
        assign mc_hor_link_sif_li[y][x][W] = hor_link_sif_i[W][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp];
        // ruche link
        assign ruche_link_o[W][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp] = mc_ruche_link_lo[y][x][W];
        assign mc_ruche_link_li[y][x][W] = ruche_link_i[W][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp];
      end

      // connect hor links to the next col
      if (x < num_subarray_x_p-1) begin
        // local
        assign mc_hor_link_sif_li[y][x+1][W] = mc_hor_link_sif_lo[y][x][E];
        assign mc_hor_link_sif_li[y][x][E] = mc_hor_link_sif_lo[y][x+1][W];
        // ruche
        assign mc_ruche_link_li[y][x+1][W] = mc_ruche_link_lo[y][x][E];
        assign mc_ruche_link_li[y][x][E] = mc_ruche_link_lo[y][x+1][W];
      end

      // connect to east
      if (x == num_subarray_x_p-1) begin
        // local
        assign hor_link_sif_o[E][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp] = mc_hor_link_sif_lo[y][x][E];
        assign mc_hor_link_sif_li[y][x][E] = hor_link_sif_i[E][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp];
        // ruche
        assign ruche_link_o[E][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp] = mc_ruche_link_lo[y][x][E];
        assign mc_ruche_link_li[y][x][E] = ruche_link_i[E][y*subarray_num_tiles_y_lp+:subarray_num_tiles_y_lp];
      end

    end
  end


  // vcache row (south)
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0] south_vc_reset_li;
  wh_link_sif_s [num_subarray_x_p-1:0][E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] south_vc_wh_link_sif_li;
  wh_link_sif_s [num_subarray_x_p-1:0][E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] south_vc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_subarray_x_p-1:0][S:N][subarray_num_tiles_x_lp-1:0] south_vc_ver_link_sif_li;
  bsg_manycore_link_sif_s [num_subarray_x_p-1:0][S:N][subarray_num_tiles_x_lp-1:0] south_vc_ver_link_sif_lo;
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][x_cord_width_p-1:0] south_vc_global_x_li;
  logic [num_subarray_x_p-1:0][subarray_num_tiles_x_lp-1:0][y_cord_width_p-1:0] south_vc_global_y_li;
  
  for (genvar x = 0; x < num_subarray_x_p; x++) begin: south_vc_x
    bsg_manycore_tile_vcache_array #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.pod_x_cord_width_p(pod_x_cord_width_p)
      ,.pod_y_cord_width_p(pod_y_cord_width_p)

      ,.num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)

      ,.subarray_num_tiles_x_p(subarray_num_tiles_x_lp)

      ,.num_vcache_rows_p(num_vcache_rows_p)
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

      ,.num_clk_ports_p(num_clk_ports_p)
    ) south_vc_row (
      .clk_i({num_clk_ports_p{clk_i}})
      ,.reset_i(south_vc_reset_li[x])
      ,.reset_o()
    
      ,.wh_link_sif_i(south_vc_wh_link_sif_li[x])
      ,.wh_link_sif_o(south_vc_wh_link_sif_lo[x])
    
      ,.ver_link_sif_i(south_vc_ver_link_sif_li[x])
      ,.ver_link_sif_o(south_vc_ver_link_sif_lo[x])

      ,.global_x_i(south_vc_global_x_li[x])
      ,.global_y_i(south_vc_global_y_li[x])
      ,.global_x_o()
      ,.global_y_o()
    );

    // connect reset
    assign south_vc_reset_li[x] = mc_reset_lo[num_subarray_y_p-1][x];

    // connect ver link to manycore
    assign south_vc_ver_link_sif_li[x][N] = mc_ver_link_sif_lo[num_subarray_y_p-1][x][S];
    assign mc_ver_link_sif_li[num_subarray_y_p-1][x][S] = south_vc_ver_link_sif_lo[x][N];
 
    // connect ver link to south
    assign ver_link_sif_o[S][x*subarray_num_tiles_x_lp+:subarray_num_tiles_x_lp] = south_vc_ver_link_sif_lo[x][S];
    assign south_vc_ver_link_sif_li[x][S] = ver_link_sif_i[S][x*subarray_num_tiles_x_lp+:subarray_num_tiles_x_lp];
   
    // coordinate
    assign south_vc_global_x_li[x] = mc_global_x_lo[num_subarray_y_p-1][x];
    assign south_vc_global_y_li[x] = mc_global_y_lo[num_subarray_y_p-1][x];

    // connect wh link to west
    if (x == 0) begin
      assign south_wh_link_sif_o[W] = south_vc_wh_link_sif_lo[x][W];
      assign south_vc_wh_link_sif_li[x][W] = south_wh_link_sif_i[W];
    end

    // connect wh link to east
    if (x == num_subarray_x_p-1) begin
      assign south_wh_link_sif_o[E] = south_vc_wh_link_sif_lo[x][E];
      assign south_vc_wh_link_sif_li[x][E] = south_wh_link_sif_i[E];
    end
   
    // connect wh links between vc arrays
    if (x < num_subarray_x_p-1) begin
      assign south_vc_wh_link_sif_li[x+1][W] = south_vc_wh_link_sif_lo[x][E];
      assign south_vc_wh_link_sif_li[x][E] = south_vc_wh_link_sif_lo[x+1][W];
    end

  end


endmodule
