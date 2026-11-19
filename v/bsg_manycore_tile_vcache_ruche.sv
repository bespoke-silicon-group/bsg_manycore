/**
 *    bsg_manycore_tile_vcache_ruche.sv
 *
 *    A vcache tile with vertical mesh and Y ruche links, and horizontal
 *    wormhole ruche links for cache DMA. Y forward links omit destination X;
 *    reverse links retain the full return packet.
 */

`include "bsg_manycore_defines.svh"
`include "bsg_cache.svh"

module bsg_manycore_tile_vcache_ruche
  import bsg_noc_pkg::*;
  import bsg_cache_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(ruche_factor_Y_p)

    , `BSG_INV_PARAM(vcache_addr_width_p)
    , `BSG_INV_PARAM(vcache_data_width_p)
    , `BSG_INV_PARAM(vcache_ways_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_dma_data_width_p)
    , `BSG_INV_PARAM(vcache_word_tracking_p)

    , `BSG_INV_PARAM(icache_block_size_in_words_p)
    // wh_ruche_factor_p supported only for 2^n, n>0.
    , `BSG_INV_PARAM(wh_ruche_factor_p)
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)
    , localparam int wh_cord_markers_pos_lp[1:0] = '{wh_cord_width_p, 0}

    , parameter req_fifo_els_p=4

    , localparam lg_wh_ruche_factor_lp = `BSG_SAFE_CLOG2(wh_ruche_factor_p)

    , y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)
    , dims_lp = (ruche_factor_Y_p > 0) ? 4 : 2
    , dirs_lp = 2*dims_lp
    , ruche_y_lanes_lp = `BSG_MAX(1,ruche_factor_Y_p)

    , manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , ruche_y_link_sif_width_lp =
      `bsg_manycore_ruche_y_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , wh_link_sif_width_lp =
      `bsg_ready_and_link_sif_width(wh_flit_width_p)

    , parameter vcache_amo_support_p = (1 << e_cache_amo_swap)
                                | (1 << e_cache_amo_or)
                                | (1 << e_cache_amo_add)
  )
  (
    input clk_i
    , input reset_i
    , output logic reset_o

    , input  [wh_ruche_factor_p-1:0][E:W][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [wh_ruche_factor_p-1:0][E:W][wh_link_sif_width_lp-1:0] wh_link_sif_o

    , input  [S:N][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    , input  [ruche_y_lanes_lp-1:0][S:N][ruche_y_link_sif_width_lp-1:0] ver_ruche_link_i
    , output [ruche_y_lanes_lp-1:0][S:N][ruche_y_link_sif_width_lp-1:0] ver_ruche_link_o

    // manycore cord
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i

    , output logic [x_cord_width_p-1:0] global_x_o
    , output logic [y_cord_width_p-1:0] global_y_o
  );

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  `declare_bsg_cache_pkt_s(vcache_addr_width_p,vcache_data_width_p);
  `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p, vcache_block_size_in_words_p);

  // reset dff
  logic reset_r;
  bsg_dff #(
    .width_p(1)
  ) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );

  assign reset_o = reset_r;

  // feedthrough coordinate bits
  logic [x_cord_width_p-1:0] global_x_r;
  logic [y_cord_width_p-1:0] global_y_r;

  bsg_dff #(
    .width_p(x_cord_width_p)
  ) x_dff (
    .clk_i(clk_i)
    ,.data_i(global_x_i)
    ,.data_o(global_x_r)
  );

  bsg_dff #(
    .width_p(y_cord_width_p)
  ) y_dff (
    .clk_i(clk_i)
    ,.data_i(global_y_i)
    ,.data_o(global_y_r)
  );

  assign global_x_o = global_x_r;
  assign global_y_o = y_cord_width_p'(global_y_r+1);

  // vcache connects to P; horizontal manycore directions are stubbed.
  bsg_manycore_link_sif_s [dirs_lp:W] link_sif_li, link_sif_lo;
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo;

  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.dims_p(dims_lp)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
    ,.stub_p(dirs_lp'((ruche_factor_Y_p > 0) ? 8'b00110011 : 4'b0011))
    ,.fwd_fifo_els_p('{default:2})
    ,.rev_fifo_els_p('{default:2})
  ) rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.links_sif_i(link_sif_li)
    ,.links_sif_o(link_sif_lo)
    ,.proc_link_sif_i(proc_link_sif_li)
    ,.proc_link_sif_o(proc_link_sif_lo)
    ,.global_x_i(global_x_r)
    ,.global_y_i(global_y_r)
  );

  assign ver_link_sif_o[S] = link_sif_lo[S];
  assign link_sif_li[S] = ver_link_sif_i[S];
  assign ver_link_sif_o[N] = link_sif_lo[N];
  assign link_sif_li[N] = ver_link_sif_i[N];

  assign link_sif_li[E] = '0;
  assign link_sif_li[W] = '0;

  bsg_manycore_ruche_y_link_sif_s [ruche_y_lanes_lp-1:0][S:N] ruche_link_li, ruche_link_lo;
  assign ruche_link_li = ver_ruche_link_i;
  assign ver_ruche_link_o = ruche_link_lo;

  if (ruche_factor_Y_p > 0) begin: y_ruche
    assign link_sif_li[RE] = '0;
    assign link_sif_li[RW] = '0;
    for (genvar d = N; d <= S; d++) begin: ry
      localparam ruche_dir_lp = (d == N) ? RN : RS;
      assign link_sif_li[ruche_dir_lp].fwd =
        `bsg_manycore_ruche_y_link_fwd_inject_dest_x(x_cord_width_p,ruche_link_li[0][d].fwd,global_x_r);
      assign link_sif_li[ruche_dir_lp].rev = ruche_link_li[0][d].rev;
      assign ruche_link_lo[0][d].fwd =
        `bsg_manycore_link_sif_fwd_filter_dest_x(x_cord_width_p,link_sif_lo[ruche_dir_lp].fwd);
      assign ruche_link_lo[0][d].rev = link_sif_lo[ruche_dir_lp].rev;
    end

    for (genvar i = 1; i < ruche_factor_Y_p; i++) begin: ry_feedthrough
      assign ruche_link_lo[i][N] = ruche_link_li[i][S];
      assign ruche_link_lo[i][S] = ruche_link_li[i][N];
    end
  end
  else begin: mesh
    assign ruche_link_lo = '0;
  end

  // link_to_cache
  bsg_cache_pkt_s cache_pkt;
  logic cache_v_li;
  logic cache_yumi_lo;
  logic [vcache_data_width_p-1:0] cache_data_lo;
  logic cache_v_lo;
  logic cache_yumi_li;
  logic v_we_lo;
  logic wh_dest_east_not_west_lo;

  bsg_manycore_link_to_cache #(
    .link_addr_width_p(addr_width_p) // word addr
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.sets_p(vcache_sets_p)
    ,.ways_p(vcache_ways_p)
    ,.block_size_in_words_p(vcache_block_size_in_words_p)
    ,.fifo_els_p(req_fifo_els_p)
  ) link_to_cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)
    ,.cache_pkt_o(cache_pkt)
    ,.v_o(cache_v_li)
    ,.yumi_i(cache_yumi_lo)
    ,.data_i(cache_data_lo)
    ,.v_i(cache_v_lo)
    ,.yumi_o(cache_yumi_li)
    ,.v_we_i(v_we_lo)
    ,.wh_dest_east_not_west_o(wh_dest_east_not_west_lo)
  );

  // vcache
  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic dma_pkt_v_lo;
  logic dma_pkt_yumi_li;
  logic [vcache_dma_data_width_p-1:0] dma_data_li;
  logic dma_data_v_li;
  logic dma_data_ready_lo;
  logic [vcache_dma_data_width_p-1:0] dma_data_lo;
  logic dma_data_v_lo;
  logic dma_data_yumi_li;

  bsg_cache #(
    .addr_width_p(vcache_addr_width_p)
    ,.data_width_p(vcache_data_width_p)
    ,.block_size_in_words_p(vcache_block_size_in_words_p)
    ,.sets_p(vcache_sets_p)
    ,.ways_p(vcache_ways_p)
    ,.word_tracking_p(vcache_word_tracking_p)
    ,.dma_data_width_p(vcache_dma_data_width_p)
    ,.amo_support_p(vcache_amo_support_p)
  ) cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.cache_pkt_i(cache_pkt)
    ,.v_i(cache_v_li)
    ,.yumi_o(cache_yumi_lo)
    ,.data_o(cache_data_lo)
    ,.v_o(cache_v_lo)
    ,.yumi_i(cache_yumi_li)
    ,.v_we_o(v_we_lo)
    ,.dma_pkt_o(dma_pkt_lo)
    ,.dma_pkt_v_o(dma_pkt_v_lo)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_li)
    ,.dma_data_i(dma_data_li)
    ,.dma_data_v_i(dma_data_v_li)
    ,.dma_data_ready_and_o(dma_data_ready_lo)
    ,.dma_data_o(dma_data_lo)
    ,.dma_data_v_o(dma_data_v_lo)
    ,.dma_data_yumi_i(dma_data_yumi_li)
  );

  // cache DMA to wormhole
  wh_link_sif_s cache_wh_link_li, cache_wh_link_lo;
  bsg_cache_dma_to_wormhole #(
    .dma_addr_width_p(vcache_addr_width_p)
    ,.dma_mask_width_p(vcache_block_size_in_words_p)
    ,.dma_burst_len_p(vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)
    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)
  ) dma_to_wh (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.dma_pkt_i(dma_pkt_lo)
    ,.dma_pkt_v_i(dma_pkt_v_lo)
    ,.dma_pkt_yumi_o(dma_pkt_yumi_li)
    ,.dma_data_o(dma_data_li)
    ,.dma_data_v_o(dma_data_v_li)
    ,.dma_data_ready_and_i(dma_data_ready_lo)
    ,.dma_data_i(dma_data_lo)
    ,.dma_data_v_i(dma_data_v_lo)
    ,.dma_data_yumi_o(dma_data_yumi_li)
    ,.wh_link_sif_i(cache_wh_link_li)
    ,.wh_link_sif_o(cache_wh_link_lo)
    ,.my_wh_cord_i(global_x_r)
    ,.dest_wh_cord_i({wh_cord_width_p{wh_dest_east_not_west_lo}})
    ,.dest_wh_cid_i('0)
    ,.my_wh_cid_i({~global_y_r[y_subcord_width_lp-1], {wh_ruche_factor_p>1{global_x_r[0+:lg_wh_ruche_factor_lp]}}})
  );

  // wormhole router
  wh_link_sif_s [E:P] wh_link_li, wh_link_lo;
  bsg_wormhole_router #(
    .flit_width_p(wh_flit_width_p)
    ,.dims_p(1)
    ,.cord_markers_pos_p(wh_cord_markers_pos_lp)
    ,.len_width_p(wh_len_width_p)
  ) wh_rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_i(wh_link_li)
    ,.link_o(wh_link_lo)
    ,.my_cord_i(global_x_r)
  );

  assign wh_link_li[P] = cache_wh_link_lo;
  assign cache_wh_link_li = wh_link_lo[P];

  assign wh_link_sif_o[0][E] = wh_link_lo[E];
  assign wh_link_li[E] = wh_link_sif_i[0][E];
  assign wh_link_sif_o[0][W] = wh_link_lo[W];
  assign wh_link_li[W] = wh_link_sif_i[0][W];

  for (genvar i = 1; i < wh_ruche_factor_p; i++) begin
    assign wh_link_sif_o[i][E] = wh_link_sif_i[i][W];
    assign wh_link_sif_o[i][W] = wh_link_sif_i[i][E];
  end

  // synopsys translate_off
  initial begin
    assert(ruche_factor_Y_p == 0 || ruche_factor_Y_p >= 2)
      else $fatal(1, "ruche_factor_Y_p must be 0 or greater or equal to 2.");
  end
  // synopsys translate_on
endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_vcache_ruche)
