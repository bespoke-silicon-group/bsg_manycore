`include "bsg_manycore_defines.svh"

module bsg_manycore_pod_full_ruche
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  #(// number of tiles in a pod
    `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)

    // coordinate width within a pod
    , x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)
  
    , parameter `BSG_INV_PARAM(dmem_size_p)
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

    , `BSG_INV_PARAM(ruche_factor_X_p)
    , `BSG_INV_PARAM(ruche_factor_Y_p)
    , `BSG_INV_PARAM(barrier_ruche_factor_X_p)
  
    , `BSG_INV_PARAM(wh_ruche_factor_p)
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)

    , `BSG_INV_PARAM(reset_depth_p)

    , localparam manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , manycore_ruche_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)
  )
  (
    // manycore 
    input clk_i
    //, input [num_tiles_x_p-1:0] reset_i

    , input  [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o

    , input  [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    , input  [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_ruche_link_i
    , output [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_ruche_link_o


    // vcache wormhole
    , input  [E:W][S:N][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][S:N][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o

    , input bsg_tag_s pod_tags_i

    // pod cord (should be all same value for all columns)
    //, input [num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    //, input [num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);

  assign hor_link_sif_o = '0;

  // bsg_tag reset;
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



  // manycore tile array;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0] mc_reset_li, mc_reset_lo;
  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] mc_link_li, mc_link_lo;
  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] mc_ruche_link_li, mc_ruche_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] barrier_link_li, barrier_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][E:W] barrier_ruche_link_li, barrier_ruche_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_li, global_x_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_li, global_y_lo;

  // north vc;
  logic [num_tiles_x_p-1:0] nvc_reset_li, nvc_reset_lo;
  wh_link_sif_s [num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] nvc_wh_link_sif_li, nvc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:N] nvc_ver_link_sif_li, nvc_ver_link_sif_lo,
                                                   nvc_ver_ruche_link_sif_li, nvc_ver_ruche_link_sif_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] nvc_global_x_li, nvc_global_x_lo;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] nvc_global_y_li, nvc_global_y_lo;

  // south vc;
  logic [num_tiles_x_p-1:0] svc_reset_li, svc_reset_lo;
  wh_link_sif_s [num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] svc_wh_link_sif_li, svc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:N] svc_ver_link_sif_li, svc_ver_link_sif_lo,
                                                   svc_ver_ruche_link_sif_li, svc_ver_ruche_link_sif_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] svc_global_x_li, svc_global_x_lo;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] svc_global_y_li, svc_global_y_lo;


  // Manycore array;
  for (genvar y = 0; y < num_tiles_y_p; y++) begin: mc_y
    for (genvar x = 0; x < num_tiles_x_p; x++) begin: mc_x
      bsg_manycore_tile_compute_full_ruche #(
        .dmem_size_p(dmem_size_p)
        ,.vcache_size_p(vcache_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)
        ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)

        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
    
        ,.ruche_factor_X_p(ruche_factor_X_p)
        ,.ruche_factor_Y_p(ruche_factor_Y_p)
        ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)

        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.ipoly_hashing_p(ipoly_hashing_p)
      ) tile0 (
        .clk_i(clk_i)
        ,.reset_i(mc_reset_li[y][x])
        ,.reset_o(mc_reset_lo[y][x])

        ,.link_i(mc_link_li[y][x])
        ,.link_o(mc_link_lo[y][x])
        ,.ruche_link_i(mc_ruche_link_li[y][x])
        ,.ruche_link_o(mc_ruche_link_lo[y][x])

        ,.barrier_link_i(barrier_link_li[y][x])
        ,.barrier_link_o(barrier_link_lo[y][x])
        ,.barrier_ruche_link_i(barrier_ruche_link_li[y][x])
        ,.barrier_ruche_link_o(barrier_ruche_link_lo[y][x])

        ,.global_x_i(global_x_li[y][x])
        ,.global_y_i(global_y_li[y][x])
        ,.global_x_o(global_x_lo[y][x])
        ,.global_y_o(global_y_lo[y][x])
      );

      // connect local west;
      if (x == 0) begin
        assign mc_link_li[y][x][W] = '0;
        assign barrier_link_li[y][x][W] = 1'b0;
      end
      else begin
        assign mc_link_li[y][x][W] = mc_link_lo[y][x-1][E];
        assign barrier_link_li[y][x][W] = barrier_link_lo[y][x-1][E];
      end

      // connect local east;
      if (x == num_tiles_x_p-1) begin
        assign mc_link_li[y][x][E] = '0;
        assign barrier_link_li[y][x][E] = 1'b0;
      end
      else begin
        assign mc_link_li[y][x][E] = mc_link_lo[y][x+1][W];
        assign barrier_link_li[y][x][E] = barrier_link_lo[y][x+1][W];
      end
    
      // connect ruche west;
      if (x >= ruche_factor_X_p) begin
        assign mc_ruche_link_li[y][x][W] = mc_ruche_link_lo[y][x-ruche_factor_X_p][E];
      end
      else begin
        assign mc_ruche_link_li[y][x][W] = '0;
      end

      // connect ruche east;
      if (x < num_tiles_x_p-ruche_factor_X_p) begin
        assign mc_ruche_link_li[y][x][E] = mc_ruche_link_lo[y][x+ruche_factor_X_p][W];
      end
      else begin
        assign mc_ruche_link_li[y][x][E] = '0;
      end


      // connect local north;
      if (y == 0) begin
        assign mc_link_li[y][x][N] = nvc_ver_link_sif_lo[x][S];
        assign barrier_link_li[y][x][N] = 1'b0;
        assign mc_reset_li[y][x] = nvc_reset_lo[x];
        assign global_x_li[y][x] = nvc_global_x_lo[x];
        assign global_y_li[y][x] = nvc_global_y_lo[x];
      end
      else begin
        assign mc_link_li[y][x][N] = mc_link_lo[y-1][x][S];
        assign barrier_link_li[y][x][N] = barrier_link_lo[y-1][x][S];
        assign mc_reset_li[y][x] = mc_reset_lo[y-1][x];
        assign global_x_li[y][x] = global_x_lo[y-1][x];
        assign global_y_li[y][x] = global_y_lo[y-1][x];
      end

      // connect local south;
      if (y == num_tiles_y_p-1) begin
        assign mc_link_li[y][x][S] = svc_ver_link_sif_lo[x][N];
        assign barrier_link_li[y][x][S] = 1'b0;
      end
      else begin
        assign mc_link_li[y][x][S] = mc_link_lo[y+1][x][N];
        assign barrier_link_li[y][x][S] = barrier_link_lo[y+1][x][N];
      end

      // connect ruche north;
      if (y == 0) begin
        assign mc_ruche_link_li[y][x][N] = ver_ruche_link_i[N][x];
        assign ver_ruche_link_o[N][x] = mc_ruche_link_lo[y][x][N];
      end
      else if (y == 1) begin
        assign mc_ruche_link_li[y][x][N] = nvc_ver_ruche_link_sif_lo[x][S];
      end
      else begin
        assign mc_ruche_link_li[y][x][N] = mc_ruche_link_lo[y-ruche_factor_Y_p][x][S];
      end

      // connect ruche south;
      if (y == num_tiles_y_p-1) begin
        assign mc_ruche_link_li[y][x][S] = ver_ruche_link_i[S][x];
        assign ver_ruche_link_o[S][x] = mc_ruche_link_lo[y][x][S];
      end
      else if (y == num_tiles_y_p-2) begin
        assign mc_ruche_link_li[y][x][S] = svc_ver_ruche_link_sif_lo[x][N];
      end
      else begin
        assign mc_ruche_link_li[y][x][S] = mc_ruche_link_lo[y+ruche_factor_Y_p][x][N];
      end


      // connect barrier ruche west;
      if (x >= barrier_ruche_factor_X_p) begin
        assign barrier_ruche_link_li[y][x][W] = barrier_ruche_link_lo[y][x-barrier_ruche_factor_X_p][E];
      end
      else begin
        assign barrier_ruche_link_li[y][x][W] = 1'b0;
      end
      // connect barrier ruche east;
      if (x < num_tiles_x_p-barrier_ruche_factor_X_p) begin
        assign barrier_ruche_link_li[y][x][E] = barrier_ruche_link_lo[y][x+barrier_ruche_factor_X_p][W];
      end
      else begin
        assign barrier_ruche_link_li[y][x][E] = 1'b0;
      end

    end
  end


  // North VC;
  for (genvar x = 0; x < num_tiles_x_p; x++) begin: nvc_x
    bsg_manycore_tile_vcache_full_ruche #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.num_tiles_y_p(num_tiles_y_p)
      ,.num_tiles_x_p(num_tiles_x_p)

      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) north_vc (
      .clk_i(clk_i)
      ,.reset_i(nvc_reset_li[x])
      ,.reset_o(nvc_reset_lo[x])

      ,.wh_link_sif_i(nvc_wh_link_sif_li[x])
      ,.wh_link_sif_o(nvc_wh_link_sif_lo[x])

      ,.ver_link_sif_i(nvc_ver_link_sif_li[x])
      ,.ver_link_sif_o(nvc_ver_link_sif_lo[x])

      ,.ver_ruche_link_sif_i(nvc_ver_ruche_link_sif_li[x])
      ,.ver_ruche_link_sif_o(nvc_ver_ruche_link_sif_lo[x])

      ,.global_x_i(nvc_global_x_li[x])
      ,.global_y_i(nvc_global_y_li[x])
      ,.global_x_o(nvc_global_x_lo[x])
      ,.global_y_o(nvc_global_y_lo[x])
    );

    // connect north;
    assign nvc_reset_li[x] = reset_r[x];
    assign nvc_ver_link_sif_li[x][N] = ver_link_sif_i[N][x];
    assign ver_link_sif_o[N][x] = nvc_ver_link_sif_lo[x][N];
    assign nvc_ver_ruche_link_sif_li[x][N] = '0;
    assign nvc_global_x_li[x] = x_cord_width_p'(num_tiles_x_p+x);
    assign nvc_global_y_li[x] = y_cord_width_p'(num_tiles_y_p-1);

    
    // connect south;
    assign nvc_ver_link_sif_li[x][S] = mc_link_lo[0][x][N];
    assign nvc_ver_ruche_link_sif_li[x][S] = mc_ruche_link_lo[1][x][N];


    // connect west;
    if (x == 0) begin
      assign nvc_wh_link_sif_li[x][0][W] = wh_link_sif_i[W][N][0];
      assign nvc_wh_link_sif_li[x][1][W] = wh_link_sif_i[W][N][1];
      assign wh_link_sif_o[W][N][0] = nvc_wh_link_sif_lo[x][0][W];
      assign wh_link_sif_o[W][N][1] = nvc_wh_link_sif_lo[x][1][W];
    end
    else begin
      assign nvc_wh_link_sif_li[x][0][W] = nvc_wh_link_sif_lo[x-1][1][E];
      assign nvc_wh_link_sif_li[x][1][W] = nvc_wh_link_sif_lo[x-1][0][E];
    end


    // connect east;
    if (x == num_tiles_x_p-1) begin
      assign nvc_wh_link_sif_li[x][0][E] = wh_link_sif_i[E][N][1];
      assign nvc_wh_link_sif_li[x][1][E] = wh_link_sif_i[E][N][0];
      assign wh_link_sif_o[E][N][1] = nvc_wh_link_sif_lo[x][0][E];
      assign wh_link_sif_o[E][N][0] = nvc_wh_link_sif_lo[x][1][E];
    end
    else begin
      assign nvc_wh_link_sif_li[x][0][E] = nvc_wh_link_sif_lo[x+1][1][W];
      assign nvc_wh_link_sif_li[x][1][E] = nvc_wh_link_sif_lo[x+1][0][W];
    end
  end


  // South VC;
  for (genvar x = 0; x < num_tiles_x_p; x++) begin: svc_x
    bsg_manycore_tile_vcache_full_ruche #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.num_tiles_y_p(num_tiles_y_p)
      ,.num_tiles_x_p(num_tiles_x_p)

      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) south_vc (
      .clk_i(clk_i)
      ,.reset_i(svc_reset_li[x])
      ,.reset_o(svc_reset_lo[x])

      ,.wh_link_sif_i(svc_wh_link_sif_li[x])
      ,.wh_link_sif_o(svc_wh_link_sif_lo[x])

      ,.ver_link_sif_i(svc_ver_link_sif_li[x])
      ,.ver_link_sif_o(svc_ver_link_sif_lo[x])

      ,.ver_ruche_link_sif_i(svc_ver_ruche_link_sif_li[x])
      ,.ver_ruche_link_sif_o(svc_ver_ruche_link_sif_lo[x])

      ,.global_x_i(svc_global_x_li[x])
      ,.global_y_i(svc_global_y_li[x])
      ,.global_x_o(svc_global_x_lo[x])
      ,.global_y_o(svc_global_y_lo[x])
    );

    // connect north;
    assign svc_reset_li[x] = mc_reset_lo[num_tiles_y_p-1][x];
    assign svc_ver_link_sif_li[x][N] = mc_link_lo[num_tiles_y_p-1][x][S];
    assign svc_ver_ruche_link_sif_li[x][N] = mc_ruche_link_lo[num_tiles_y_p-2][x][S];
    assign svc_global_x_li[x] = global_x_lo[num_tiles_y_p-1][x];
    assign svc_global_y_li[x] = global_y_lo[num_tiles_y_p-1][x];

    
    // connect south;
    assign svc_ver_link_sif_li[x][S] = ver_link_sif_i[S][x];
    assign svc_ver_ruche_link_sif_li[x][S] = '0;
    assign ver_link_sif_o[S][x] = svc_ver_link_sif_lo[x][S];

    // connect west;
    if (x == 0) begin
      assign svc_wh_link_sif_li[x][0][W] = wh_link_sif_i[W][S][0];
      assign svc_wh_link_sif_li[x][1][W] = wh_link_sif_i[W][S][1];
      assign wh_link_sif_o[W][S][0] = svc_wh_link_sif_lo[x][0][W];
      assign wh_link_sif_o[W][S][1] = svc_wh_link_sif_lo[x][1][W];
    end
    else begin
      assign svc_wh_link_sif_li[x][0][W] = svc_wh_link_sif_lo[x-1][1][E];
      assign svc_wh_link_sif_li[x][1][W] = svc_wh_link_sif_lo[x-1][0][E];
    end


    // connect east;
    if (x == num_tiles_x_p-1) begin
      assign svc_wh_link_sif_li[x][0][E] = wh_link_sif_i[E][S][1];
      assign svc_wh_link_sif_li[x][1][E] = wh_link_sif_i[E][S][0];
      assign wh_link_sif_o[E][S][1] = svc_wh_link_sif_lo[x][0][E];
      assign wh_link_sif_o[E][S][0] = svc_wh_link_sif_lo[x][1][E];
    end
    else begin
      assign svc_wh_link_sif_li[x][0][E] = svc_wh_link_sif_lo[x+1][1][W];
      assign svc_wh_link_sif_li[x][1][E] = svc_wh_link_sif_lo[x+1][0][W];
    end

  end






endmodule
