/**
 *    bsg_manycore_tile_vcache.v
 *
 *    A vcache tile that contains bsg_cache, vertical mesh router. horizontal wormhole router.
 *    and bsg_manycore_link_to cache adapter, and bsg_cache dma to wormhole adapter.
 *    this tile can connect to the top and bottom side of the compute tile array.
 *    the vcache DMA interface is connected to the horizontal 1D wormhole ruche network.
 */

`include "bsg_manycore_defines.vh"
`include "bsg_cache.vh"

module bsg_manycore_tile_vcache
  import bsg_noc_pkg::*;
  import bsg_cache_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(num_tiles_y_p)

    , `BSG_INV_PARAM(vcache_addr_width_p)
    , `BSG_INV_PARAM(vcache_data_width_p)
    , `BSG_INV_PARAM(vcache_ways_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_dma_data_width_p)

    // wh_ruche_factor_p supported only for 2^n, n>0.
    , `BSG_INV_PARAM(wh_ruche_factor_p)
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)
    , parameter int wh_cord_markers_pos_lp[1:0] = '{wh_cord_width_p, 0}

    , parameter req_fifo_els_p=4

    , parameter lg_wh_ruche_factor_lp = `BSG_SAFE_CLOG2(wh_ruche_factor_p)

    , parameter y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter wh_link_sif_width_lp = 
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

    // manycore cord
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i

    , output logic [x_cord_width_p-1:0] global_x_o
    , output logic [y_cord_width_p-1:0] global_y_o
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  `declare_bsg_cache_pkt_s(vcache_addr_width_p,vcache_data_width_p);
  `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p);


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



  // mesh router
  // vcache connects to P
  bsg_manycore_link_sif_s [S:W] link_sif_li;
  bsg_manycore_link_sif_s [S:W] link_sif_lo;
  bsg_manycore_link_sif_s proc_link_sif_li;
  bsg_manycore_link_sif_s proc_link_sif_lo;
  
  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    // Because vcaches do not initiate packets, and there are no clients on the same Row,
    // horizontal manycore links are unnecessary.
    ,.stub_p(4'b0011) // stub E and W
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

  // link_to_cache
  bsg_cache_pkt_s cache_pkt;
  logic cache_v_li;
  logic cache_ready_lo;
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
    ,.ready_i(cache_ready_lo)

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
    ,.dma_data_width_p(vcache_dma_data_width_p)
    ,.amo_support_p(vcache_amo_support_p)
  ) cache (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    
    // to manycore
    ,.cache_pkt_i(cache_pkt)
    ,.v_i(cache_v_li)
    ,.ready_o(cache_ready_lo)

    ,.data_o(cache_data_lo)
    ,.v_o(cache_v_lo)
    ,.yumi_i(cache_yumi_li)

    ,.v_we_o(v_we_lo)

    // to wormhole
    ,.dma_pkt_o(dma_pkt_lo)
    ,.dma_pkt_v_o(dma_pkt_v_lo)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

    ,.dma_data_i(dma_data_li)
    ,.dma_data_v_i(dma_data_v_li)
    ,.dma_data_ready_o(dma_data_ready_lo)

    ,.dma_data_o(dma_data_lo)
    ,.dma_data_v_o(dma_data_v_lo)
    ,.dma_data_yumi_i(dma_data_yumi_li)
  );
  

  // cache DMA to wormhole
  wh_link_sif_s cache_wh_link_li;
  wh_link_sif_s cache_wh_link_lo;

  bsg_cache_dma_to_wormhole #(
    .vcache_addr_width_p(vcache_addr_width_p)
    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)

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
    ,.dma_data_ready_i(dma_data_ready_lo)

    ,.dma_data_i(dma_data_lo)
    ,.dma_data_v_i(dma_data_v_lo)
    ,.dma_data_yumi_o(dma_data_yumi_li)

    ,.wh_link_sif_i(cache_wh_link_li)
    ,.wh_link_sif_o(cache_wh_link_lo)

    ,.my_wh_cord_i(global_x_r)
    ,.dest_wh_cord_i({wh_cord_width_p{wh_dest_east_not_west_lo}})
    // concentrator id
    // lower bits come from lower bits of global_x
    // upper bits come from whether its north or south vc.
    ,.my_wh_cid_i({~global_y_r[y_subcord_width_lp-1], global_x_r[0+:lg_wh_ruche_factor_lp]})
  );
 

  // wormhole router
  // vcache DMA connects to P
  wh_link_sif_s [E:P] wh_link_li;
  wh_link_sif_s [E:P] wh_link_lo;

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


  // connect wh ruche links
  assign wh_link_sif_o[0][E] = wh_link_lo[E];
  assign wh_link_li[E] = wh_link_sif_i[0][E];
  assign wh_link_sif_o[0][W] = wh_link_lo[W];
  assign wh_link_li[W] = wh_link_sif_i[0][W];

  // feedthrough ruche links
  for (genvar i = 1; i < wh_ruche_factor_p; i++) begin
    assign wh_link_sif_o[i][E] = wh_link_sif_i[i][W];
    assign wh_link_sif_o[i][W] = wh_link_sif_i[i][E];
  end


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_vcache)
