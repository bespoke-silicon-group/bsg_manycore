/**
 *  bsg_manycore_pod_half_torus_block_mem.sv
 *
 *  manycore pod with vcache replaced with block mem;
 */


`include "bsg_manycore_defines.svh"


module bsg_manycore_pod_half_torus_block_mem
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
    ,localparam num_vc_lp=2
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

    // bsg_tag;
    , input bsg_tag_s  pod_tags_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_vc_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,num_vc_lp);


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
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0] mc_reset_li, mc_reset_lo;
  bsg_manycore_link_sif_s    [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:N] mc_ver_link_sif_li, mc_ver_link_sif_lo;
  bsg_manycore_vc_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][E:W] mc_hor_link_sif_li, mc_hor_link_sif_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] mc_barrier_link_li, mc_barrier_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][E:W] mc_barrier_ruche_link_li, mc_barrier_ruche_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][x_cord_width_p-1:0] mc_global_x_li, mc_global_x_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][y_cord_width_p-1:0] mc_global_y_li, mc_global_y_lo;

  for (genvar r = 0; r < num_tiles_y_p; r++) begin: y
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: x
      bsg_manycore_tile_compute_half_torus #(
        .dmem_size_p     (dmem_size_p)
        ,.vcache_size_p (vcache_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)
        ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.hetero_type_p(0)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
        ,.ipoly_hashing_p(ipoly_hashing_p)
      ) tile (
        .clk_i(clk_i)
        ,.reset_i(mc_reset_li[r][c])
        ,.reset_o(mc_reset_lo[r][c])
        // local link;
        ,.ver_link_i(mc_ver_link_sif_li[r][c])
        ,.ver_link_o(mc_ver_link_sif_lo[r][c])
        ,.hor_link_i(mc_hor_link_sif_li[r][c])
        ,.hor_link_o(mc_hor_link_sif_lo[r][c])
        // barrier link;
        ,.barrier_link_i(mc_barrier_link_li[r][c])
        ,.barrier_link_o(mc_barrier_link_lo[r][c])
        // barrier ruche link;
        ,.barrier_ruche_link_i(mc_barrier_ruche_link_li[r][c])
        ,.barrier_ruche_link_o(mc_barrier_ruche_link_lo[r][c])
        // tile coordinate;
        ,.global_x_i(mc_global_x_li[r][c])
        ,.global_y_i(mc_global_y_li[r][c])
        ,.global_x_o(mc_global_x_lo[r][c])
        ,.global_y_o(mc_global_y_lo[r][c])
      );

      // connect north;
      if (r == 0) begin
        assign mc_reset_li[r][c] = north_bm_reset_lo[c];
        assign mc_global_x_li[r][c] = north_bm_global_x_lo[c];
        assign mc_global_y_li[r][c] = north_bm_global_y_lo[c];
        assign mc_ver_link_sif_li[r][c][N] = north_bm_ver_link_sif_lo[S][c];
        assign mc_barrier_link_li[r][c][N] = 1'b0;
      end
      else begin
        assign mc_reset_li[r][c] = mc_reset_lo[r-1][c];
        assign mc_global_x_li[r][c] = mc_global_x_lo[r-1][c];
        assign mc_global_y_li[r][c] = mc_global_y_lo[r-1][c];
        assign mc_ver_link_sif_li[r][c][N] = mc_ver_link_sif_lo[r-1][c][S];
        assign mc_barrier_link_li[r][c][N] = mc_barrier_link_lo[r-1][c][S];
      end
    

      // connect south;
      if (r == num_tiles_y_p-1) begin
        assign mc_ver_link_sif_li[r][c][S] = south_bm_ver_link_sif_lo[N][c];
        assign mc_barrier_link_li[r][c][S] = 1'b0;
      end
      else begin
        assign mc_ver_link_sif_li[r][c][S] = mc_ver_link_sif_lo[r+1][c][N];
        assign mc_barrier_link_li[r][c][S] = mc_barrier_link_lo[r+1][c][N];
      end


      // connect west - vc links;
      if (c == 0) begin
        assign mc_hor_link_sif_li[r][c][W] = mc_hor_link_sif_lo[r][c+1][W];
      end
      else if (c == 1) begin
        assign mc_hor_link_sif_li[r][c][W] = mc_hor_link_sif_lo[r][c-1][W];
      end
      else begin
        assign mc_hor_link_sif_li[r][c][W] = mc_hor_link_sif_lo[r][c-2][E];
      end

      // connect east - vc links;
      if (c == num_tiles_x_p-1) begin
        assign mc_hor_link_sif_li[r][c][E] = mc_hor_link_sif_lo[r][c-1][E];
      end
      else if (c == num_tiles_x_p-2) begin
        assign mc_hor_link_sif_li[r][c][E] = mc_hor_link_sif_lo[r][c+1][E];
      end
      else begin
        assign mc_hor_link_sif_li[r][c][E] = mc_hor_link_sif_lo[r][c+2][W];
      end

      // connect west - barrier local;
      if (c == 0) begin
        assign mc_barrier_link_li[r][c][W] = 1'b0;
      end
      else begin
        assign mc_barrier_link_li[r][c][W] = mc_barrier_link_lo[r][c-1][E];
      end
      // connect east - barrier local;
      if (c == num_tiles_x_p-1) begin
        assign mc_barrier_link_li[r][c][E] = 1'b0;
      end
      else begin
        assign mc_barrier_link_li[r][c][E] = mc_barrier_link_lo[r][c+1][W];
      end
      // connect west - barrier ruche;
      if (c < barrier_ruche_factor_X_p) begin
        assign mc_barrier_ruche_link_li[r][c][W] = 1'b0;
      end
      else begin
        assign mc_barrier_ruche_link_li[r][c][W] = mc_barrier_ruche_link_lo[r][c-barrier_ruche_factor_X_p][E];
      end
      // connect east - barrier ruche;
      if (c > num_tiles_x_p-1-barrier_ruche_factor_X_p) begin
        assign mc_barrier_ruche_link_li[r][c][E] = 1'b0;
      end
      else begin
        assign mc_barrier_ruche_link_li[r][c][E] = mc_barrier_ruche_link_lo[r][c+barrier_ruche_factor_X_p][W];
      end

    end
  end


  // connection with north bm;
  for (genvar c = 0; c < num_tiles_x_p; c++) begin: ny
    assign north_bm_ver_link_sif_li[S][c] = mc_ver_link_sif_lo[0][c][N];
  end


  // south block mem array;

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
    ,.reset_i(mc_reset_lo[num_tiles_y_p-1])
    ,.reset_o()

    ,.ver_link_sif_i(south_bm_ver_link_sif_li)
    ,.ver_link_sif_o(south_bm_ver_link_sif_lo)

    ,.global_x_i(south_bm_global_x_li)
    ,.global_y_i(south_bm_global_y_li)
    ,.global_x_o()
    ,.global_y_o()
  );


  for (genvar c = 0; c < num_tiles_x_p; c++) begin: sy
    assign south_bm_ver_link_sif_li[N][c] = mc_ver_link_sif_lo[num_tiles_y_p-1][c][S];
    assign south_bm_global_x_li[c] = mc_global_x_lo[num_tiles_y_p-1][c];
    assign south_bm_global_y_li[c] = mc_global_y_lo[num_tiles_y_p-1][c];
  end

  // connect south;
  assign south_bm_ver_link_sif_li[S] = ver_link_sif_i[S];
  assign ver_link_sif_o[S] = south_bm_ver_link_sif_lo[S];

endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_pod_half_torus_block_mem)
