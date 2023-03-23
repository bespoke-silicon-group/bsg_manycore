/**
 *    bsg_manycore_pod_xbar.v
 *
 */


`include "bsg_manycore_defines.vh"


module bsg_manycore_pod_xbar
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)

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

    , `BSG_INV_PARAM(barrier_ruche_factor_X_p)

    , `BSG_INV_PARAM(wh_ruche_factor_p)
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)

    , `BSG_INV_PARAM(host_x_cord_p)
    , `BSG_INV_PARAM(host_y_cord_p)

    , parameter ruche_factor_X_p = 3

    , parameter fwd_fifo_els_p=32
    , parameter rev_fifo_els_p=32

    , localparam  manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)
  )
  ( 
    input clk_i
    , input reset_i
  
    // Host link
    , input        [manycore_link_sif_width_lp-1:0] host_link_i
    , output logic [manycore_link_sif_width_lp-1:0] host_link_o
    
    // vcache wormhole links
    , input        [E:W][S:N][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output logic [E:W][S:N][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o
  );


  localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p);
  localparam y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p);

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);


  // Manycore tiles;
  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0] core_link_sif_li, core_link_sif_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] barrier_link_li, barrier_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][barrier_ruche_factor_X_p-1:0][E:W] barrier_ruche_link_li, barrier_ruche_link_lo;

  for (genvar r = 0; r < num_tiles_y_p; r++) begin: y
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: x
      bsg_manycore_tile_compute_xbar #(
        .dmem_size_p(dmem_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)
        ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
        ,.vcache_size_p(vcache_size_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
        ,.fwd_fifo_els_p(fwd_fifo_els_p)
        ,.rev_fifo_els_p(rev_fifo_els_p)
      ) tile (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_i(core_link_sif_li[r][c])
        ,.link_o(core_link_sif_lo[r][c])

        ,.barrier_link_i(barrier_link_li[r][c])
        ,.barrier_link_o(barrier_link_lo[r][c])
        ,.barrier_ruche_link_i(barrier_ruche_link_li[r][c])
        ,.barrier_ruche_link_o(barrier_ruche_link_lo[r][c])
    
        ,.global_x_i({pod_x_cord_width_p'(1), x_subcord_width_lp'(c)})
        ,.global_y_i({pod_y_cord_width_p'(1), y_subcord_width_lp'(r)})
      );
    end
  end 

  // connect barrier links
  bsg_mesh_stitch #(
    .width_p(1)
    ,.x_max_p(num_tiles_x_p)
    ,.y_max_p(num_tiles_y_p)
  ) barr_link (
    .outs_i(barrier_link_lo)
    ,.ins_o(barrier_link_li)
    ,.hor_i('0)
    ,.hor_o()
    ,.ver_i('0)
    ,.ver_o()
  );

  // barrier ruche links;
  for (genvar r = 0; r < num_tiles_y_p; r++) begin
    for (genvar c = 0; c < num_tiles_x_p-1; c++) begin
      for (genvar l = 0; l < barrier_ruche_factor_X_p; l++) begin
        assign barrier_ruche_link_li[r][c][(l+barrier_ruche_factor_X_p-1) % barrier_ruche_factor_X_p][E] 
          = barrier_ruche_link_lo[r][c+1][l][W];
        assign barrier_ruche_link_li[r][c+1][(l+1)%barrier_ruche_factor_X_p][W] 
          = barrier_ruche_link_lo[r][c][l][E];
      end
    end
  end


  for (genvar r = 0; r < num_tiles_y_p; r++) begin
    for (genvar l = 0; l < barrier_ruche_factor_X_p; l++) begin
      assign barrier_ruche_link_li[r][0][l][W] = 1'b0;
      assign barrier_ruche_link_li[r][num_tiles_x_p-1][l][E] = 1'b0;
    end
  end

  // vcache tiles;
  wh_link_sif_s [num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] north_vc_wh_link_sif_li, north_vc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] north_vc_link_sif_li, north_vc_link_sif_lo;

  wh_link_sif_s [num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] south_vc_wh_link_sif_li, south_vc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] south_vc_link_sif_li, south_vc_link_sif_lo;

  for (genvar c = 0; c < num_tiles_x_p; c++) begin: vc_x
    bsg_manycore_tile_vcache_xbar #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.num_tiles_y_p(num_tiles_y_p)

      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) north_vc (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.wh_link_sif_i(north_vc_wh_link_sif_li[c])
      ,.wh_link_sif_o(north_vc_wh_link_sif_lo[c])
      ,.link_sif_i(north_vc_link_sif_li[c])
      ,.link_sif_o(north_vc_link_sif_lo[c])
      ,.global_x_i({pod_x_cord_width_p'(1), x_subcord_width_lp'(c)})
      ,.global_y_i({pod_y_cord_width_p'(0), {y_subcord_width_lp{1'b1}}})
    );

    bsg_manycore_tile_vcache_xbar #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.num_tiles_y_p(num_tiles_y_p)

      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) south_vc (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.wh_link_sif_i(south_vc_wh_link_sif_li[c])
      ,.wh_link_sif_o(south_vc_wh_link_sif_lo[c])
      ,.link_sif_i(south_vc_link_sif_li[c])
      ,.link_sif_o(south_vc_link_sif_lo[c])
      ,.global_x_i({pod_x_cord_width_p'(1), x_subcord_width_lp'(c)})
      ,.global_y_i({pod_y_cord_width_p'(2), {y_subcord_width_lp{1'b0}}})
    );

  end


  // connect vcache wh links;
  for (genvar c = 0; c < num_tiles_x_p; c++) begin
    for (genvar l = 0; l < wh_ruche_factor_p; l++) begin
      if (c == num_tiles_x_p-1) begin
        // north
        assign north_vc_wh_link_sif_li[c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E] = ~wh_link_sif_i[E][N][l];
        assign wh_link_sif_o[E][N][(l+1) % wh_ruche_factor_p] = ~north_vc_wh_link_sif_lo[c][l][E];
        // south
        assign south_vc_wh_link_sif_li[c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E] = ~wh_link_sif_i[E][S][l];
        assign wh_link_sif_o[E][S][(l+1) % wh_ruche_factor_p] = ~south_vc_wh_link_sif_lo[c][l][E];
      end
      else begin
        // north
        assign north_vc_wh_link_sif_li[c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E] = ~north_vc_wh_link_sif_lo[c+1][l][W];
        assign north_vc_wh_link_sif_li[c+1][(l+1) % wh_ruche_factor_p][W] = ~north_vc_wh_link_sif_lo[c][l][E];
        // south
        assign south_vc_wh_link_sif_li[c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E] = ~south_vc_wh_link_sif_lo[c+1][l][W];
        assign south_vc_wh_link_sif_li[c+1][(l+1) % wh_ruche_factor_p][W] = ~south_vc_wh_link_sif_lo[c][l][E];
      end

      // west edge
      if (c == 0) begin
        // north
        assign wh_link_sif_o[W][N][l] = north_vc_wh_link_sif_lo[c][l][W];
        assign north_vc_wh_link_sif_li[c][l][W] = wh_link_sif_i[W][N][l];
        // south
        assign wh_link_sif_o[W][S][l] = south_vc_wh_link_sif_lo[c][l][W];
        assign south_vc_wh_link_sif_li[c][l][W] = wh_link_sif_i[W][S][l];
      end
    end
  end



  // Crossbar;
  bsg_manycore_xbar #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_p)
    ,.rev_fifo_els_p(rev_fifo_els_p)
    ,.host_x_cord_p(host_x_cord_p)
    ,.host_y_cord_p(host_y_cord_p)
  ) xbar (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    // host
    ,.host_link_i(host_link_i)
    ,.host_link_o(host_link_o)
    // core
    ,.core_link_sif_i(core_link_sif_lo)
    ,.core_link_sif_o(core_link_sif_li)
    // vcache
    ,.vc_link_sif_i({south_vc_link_sif_lo, north_vc_link_sif_lo})
    ,.vc_link_sif_o({south_vc_link_sif_li, north_vc_link_sif_li})
  );




endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_pod_xbar)
