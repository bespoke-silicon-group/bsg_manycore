/**
 *  bsg_manycore_pod_mesh_block_mem.sv
 *
 *  manycore pod with vcache replaced with block mem;
 */


`include "bsg_manycore_defines.svh"


module bsg_manycore_pod_mesh_block_mem
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(barrier_ruche_factor_X_p)

    , `BSG_INV_PARAM(dmem_size_p)
    , `BSG_INV_PARAM(icache_entries_p)
    , `BSG_INV_PARAM(icache_tag_width_p)
    , `BSG_INV_PARAM(icache_block_size_in_words_p)

    , `BSG_INV_PARAM(vcache_addr_width_p)
    , `BSG_INV_PARAM(vcache_data_width_p)
    , `BSG_INV_PARAM(vcache_ways_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_size_p)
    , `BSG_INV_PARAM(vcache_dma_data_width_p)
    , `BSG_INV_PARAM(vcache_word_tracking_p)
    , `BSG_INV_PARAM(ipoly_hashing_p)

    , parameter mem_size_in_words_p = (2**29)

    , localparam x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    , manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter reset_depth_p = 3
    
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}
  )
  (
    input clk_i

    // vertical router links;
    , input  [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // horizontal local links;
    , input  [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o

    // bsg_tag;
    , input bsg_tag_s  pod_tags_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);


  // bsg tag reset;
  logic reset_lo;
  logic [num_tiles_x_p-1:0] reset_r;
  bsg_tag_client #(
    .width_p($bits(bsg_manycore_pod_tag_payload_s))
  ) btc (
    .bsg_tag_i(pod_tags_i)
    ,.recv_clk_i(clk_i)
    ,.recv_new_r_o()
    ,.recv_data_r_o(reset_lo)
  );
  bsg_dff_chain #(
    .width_p(num_tiles_x_p)
    ,.num_stages_p(reset_depth_p-1)
  ) reset_dff (
    .clk_i(clk_i)
    ,.data_i({num_tiles_x_p{reset_lo}})
    ,.data_o(reset_r)
  );


  // north block mem array;
  logic [num_tiles_x_p-1:0] north_bm_reset_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] north_bm_global_x_li, north_bm_global_x_lo;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] north_bm_global_y_li, north_bm_global_y_lo;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] north_bm_ver_link_sif_li,
                                                   north_bm_ver_link_sif_lo;

  bsg_manycore_tile_block_mem_array #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.mem_size_in_words_p(mem_size_in_words_p)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
  ) north_bm (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.reset_o(north_bm_reset_lo)

    ,.ver_link_sif_i(north_bm_ver_link_sif_li)
    ,.ver_link_sif_o(north_bm_ver_link_sif_lo)

    ,.global_x_i(north_bm_global_x_li)
    ,.global_y_i(north_bm_global_y_li)
    ,.global_x_o(north_bm_global_x_lo)
    ,.global_y_o(north_bm_global_y_lo)
  );


  // connect north;
  assign north_bm_ver_link_sif_li[N] = ver_link_sif_i[N]; 
  assign ver_link_sif_o[N] = north_bm_ver_link_sif_lo[N]; 

  
  // inject coordinates;
  for (genvar x = 0; x < num_tiles_x_p; x++) begin
    assign north_bm_global_x_li[x] = x_cord_width_p'(num_tiles_x_p+x);
    assign north_bm_global_y_li[x] = y_cord_width_p'(num_tiles_y_p-1);
  end


  // compute array;
  logic [num_tiles_x_p-1:0] mc_reset_li, mc_reset_lo;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_p-1:0] mc_hor_link_sif_li, mc_hor_link_sif_lo;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] mc_ver_link_sif_li, mc_ver_link_sif_lo;
  logic [S:N][num_tiles_x_p-1:0] mc_ver_barrier_link_li, mc_ver_barrier_link_lo;
  logic [E:W][num_tiles_y_p-1:0] mc_hor_barrier_link_li, mc_hor_barrier_link_lo;
  logic [E:W][num_tiles_y_p-1:0][barrier_ruche_factor_X_p-1:0] mc_barrier_ruche_link_li, mc_barrier_ruche_link_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] mc_global_x_li, mc_global_x_lo;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] mc_global_y_li, mc_global_y_lo;

  bsg_manycore_tile_compute_array_mesh #(
    .dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)

    ,.subarray_num_tiles_x_p(num_tiles_x_p)
    ,.subarray_num_tiles_y_p(num_tiles_y_p)
    ,.ipoly_hashing_p(ipoly_hashing_p)

    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
  ) mc (
    .clk_i(clk_i)
    ,.reset_i(mc_reset_li)
    ,.reset_o(mc_reset_lo)

    ,.hor_link_sif_i(mc_hor_link_sif_li)
    ,.hor_link_sif_o(mc_hor_link_sif_lo)

    ,.ver_link_sif_i(mc_ver_link_sif_li)
    ,.ver_link_sif_o(mc_ver_link_sif_lo)

    ,.ver_barrier_link_i(mc_ver_barrier_link_li)
    ,.ver_barrier_link_o(mc_ver_barrier_link_lo)
    ,.hor_barrier_link_i(mc_hor_barrier_link_li)
    ,.hor_barrier_link_o(mc_hor_barrier_link_lo)
    ,.barrier_ruche_link_i(mc_barrier_ruche_link_li)
    ,.barrier_ruche_link_o(mc_barrier_ruche_link_lo)

    ,.global_x_i(mc_global_x_li)
    ,.global_y_i(mc_global_y_li)
    ,.global_x_o(mc_global_x_lo)
    ,.global_y_o(mc_global_y_lo)
  );


  // connection with north bm;
  assign mc_reset_li = north_bm_reset_lo;
  assign mc_ver_link_sif_li[N] = north_bm_ver_link_sif_lo[S];
  assign north_bm_ver_link_sif_li[S] = mc_ver_link_sif_lo[N];
  assign mc_global_x_li = north_bm_global_x_lo;
  assign mc_global_y_li = north_bm_global_y_lo;


  // horizontal local links;
  assign mc_hor_link_sif_li = hor_link_sif_i;
  assign hor_link_sif_o = mc_hor_link_sif_lo;


  // tie-off barrier links;
  for (genvar y = 0; y < num_tiles_y_p; y++) begin
    // local;
    assign mc_hor_barrier_link_li[W][y] = 1'b0;
    assign mc_hor_barrier_link_li[E][y] = 1'b0;

    // ruche west;
    assign mc_barrier_ruche_link_li[W][y][0] = 1'b0;
    for (genvar r = 1; r < barrier_ruche_factor_X_p; r++) begin
      if (barrier_ruche_factor_X_p % 2 == 0) begin
        assign mc_barrier_ruche_link_li[W][y][r] = ((r%2)==0) ? 1'b0 : 1'b1;
      end
      else begin
        assign mc_barrier_ruche_link_li[W][y][r] = ((r%2)==0) ? 1'b1 : 1'b0;
      end
    end

    // ruche east;
    for (genvar r = 0; r < barrier_ruche_factor_X_p; r++) begin
      assign mc_barrier_ruche_link_li[E][y][r] = ((r%2)==0) ? 1'b0 : 1'b1;
    end
  end


  // south block mem array;
  logic [num_tiles_x_p-1:0] south_bm_reset_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] south_bm_global_x_li;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] south_bm_global_y_li;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] south_bm_ver_link_sif_li,
                                                   south_bm_ver_link_sif_lo;

  bsg_manycore_tile_block_mem_array #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.mem_size_in_words_p(mem_size_in_words_p)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
  ) south_bm (
    .clk_i(clk_i)
    ,.reset_i(mc_reset_lo)
    ,.reset_o(south_bm_reset_lo)

    ,.ver_link_sif_i(south_bm_ver_link_sif_li)
    ,.ver_link_sif_o(south_bm_ver_link_sif_lo)

    ,.global_x_i(south_bm_global_x_li)
    ,.global_y_i(south_bm_global_y_li)
    ,.global_x_o()
    ,.global_y_o()
  );

  assign south_bm_ver_link_sif_li[N] = mc_ver_link_sif_lo[S];
  assign mc_ver_link_sif_li[S] = south_bm_ver_link_sif_lo[N];

  assign south_bm_ver_link_sif_li[S] = ver_link_sif_i[S]; 
  assign ver_link_sif_o[S] = south_bm_ver_link_sif_lo[S]; 

  assign south_bm_global_x_li = mc_global_x_lo;
  assign south_bm_global_y_li = mc_global_y_lo;


endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_pod_mesh_block_mem)
