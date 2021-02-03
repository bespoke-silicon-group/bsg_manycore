`include "bsg_noc_links.vh"

module bsg_manycore_pod_ruche
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"

    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)
  
    , parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"
   
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
    
    , parameter reset_depth_p=3

    , parameter manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter manycore_ruche_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)
  )
  (
    // manycore 
    input clk_i

    , input  [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o

    , input  [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    , input  [E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][manycore_ruche_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][manycore_ruche_link_sif_width_lp-1:0] ruche_link_o


    // vcache
    , input  [E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] north_wh_link_sif_i
    , output [E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] north_wh_link_sif_o
    , input [pod_x_cord_width_p-1:0] north_vcache_pod_x_i
    , input [pod_y_cord_width_p-1:0] north_vcache_pod_y_i
    , input bsg_tag_s north_bsg_tag_i


    , input  [E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] south_wh_link_sif_i
    , output [E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] south_wh_link_sif_o
    , input [pod_x_cord_width_p-1:0] south_vcache_pod_x_i
    , input [pod_y_cord_width_p-1:0] south_vcache_pod_y_i
    , input bsg_tag_s south_bsg_tag_i

    // pod cord
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i

  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);


  // bsg tag clients
  bsg_manycore_pod_tag_payload_s north_tag_payload;
  bsg_manycore_pod_tag_payload_s south_tag_payload;

  bsg_tag_client #(
    .width_p($bits(bsg_manycore_pod_tag_payload_s))
    ,.default_p(0)
  ) btc_n (
    .bsg_tag_i(north_bsg_tag_i)
    ,.recv_clk_i(clk_i)
    ,.recv_reset_i(1'b0)
    ,.recv_new_r_o()
    ,.recv_data_r_o(north_tag_payload)
  );

  bsg_tag_client #(
    .width_p($bits(bsg_manycore_pod_tag_payload_s))
    ,.default_p(0)
  ) btc_s (
    .bsg_tag_i(south_bsg_tag_i)
    ,.recv_clk_i(clk_i)
    ,.recv_reset_i(1'b0)
    ,.recv_new_r_o()
    ,.recv_data_r_o(south_tag_payload)
  );



  // manycore array
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] mc_ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] mc_ver_link_sif_lo;

  bsg_manycore_tile_compute_array_ruche #(
    .dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.reset_depth_p(reset_depth_p)
  ) mc (
    .clk_i(clk_i)
    ,.reset_i({south_tag_payload.reset, north_tag_payload.reset}) // {S,N}
    
    ,.hor_link_sif_i(hor_link_sif_i)
    ,.hor_link_sif_o(hor_link_sif_o)

    ,.ver_link_sif_i(mc_ver_link_sif_li)
    ,.ver_link_sif_o(mc_ver_link_sif_lo)

    ,.ruche_link_i(ruche_link_i)
    ,.ruche_link_o(ruche_link_o)

    ,.pod_x_i(pod_x_i)
    ,.pod_y_i(pod_y_i)
  );

  
  // vcache row (north)
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] north_vc_ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] north_vc_ver_link_sif_lo;

  bsg_manycore_tile_vcache_array #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)

    ,.vcache_addr_width_p(vcache_addr_width_p)
    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)

    ,.wh_ruche_factor_p(wh_ruche_factor_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)

    ,.reset_depth_p(reset_depth_p)
  ) north_vc_row (
    .clk_i(clk_i)
    ,.reset_i(north_tag_payload.reset)
    
    ,.wh_link_sif_i(north_wh_link_sif_i)
    ,.wh_link_sif_o(north_wh_link_sif_o)
    
    ,.ver_link_sif_i(north_vc_ver_link_sif_li)
    ,.ver_link_sif_o(north_vc_ver_link_sif_lo)

    ,.pod_x_i(north_vcache_pod_x_i)
    ,.pod_y_i(north_vcache_pod_y_i)
    ,.my_y_i({y_subcord_width_lp{1'b1}})
    ,.my_cid_i(1'b0) // north row local cid

    ,.wh_dest_east_not_west_i(north_tag_payload.wh_dest_east_not_west)
  );


  // vcache row (south)
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] south_vc_ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] south_vc_ver_link_sif_lo;

  bsg_manycore_tile_vcache_array #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)

    ,.vcache_addr_width_p(vcache_addr_width_p)
    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)

    ,.wh_ruche_factor_p(wh_ruche_factor_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)

    ,.reset_depth_p(reset_depth_p)
  ) south_vc_row (
    .clk_i(clk_i)
    ,.reset_i(south_tag_payload.reset)
    
    ,.wh_link_sif_i(south_wh_link_sif_i)
    ,.wh_link_sif_o(south_wh_link_sif_o)
    
    ,.ver_link_sif_i(south_vc_ver_link_sif_li)
    ,.ver_link_sif_o(south_vc_ver_link_sif_lo)

    ,.pod_x_i(south_vcache_pod_x_i)
    ,.pod_y_i(south_vcache_pod_y_i)
    ,.my_y_i({y_subcord_width_lp{1'b0}})
    ,.my_cid_i(1'b1) // south row local cid

    ,.wh_dest_east_not_west_i(south_tag_payload.wh_dest_east_not_west)
  );


  // connect ver links
  assign ver_link_sif_o[N] = north_vc_ver_link_sif_lo[N];
  assign north_vc_ver_link_sif_li[N] = ver_link_sif_i[N];

  assign north_vc_ver_link_sif_li[S] = mc_ver_link_sif_lo[N];
  assign mc_ver_link_sif_li[N] = north_vc_ver_link_sif_lo[S];

  assign south_vc_ver_link_sif_li[N] = mc_ver_link_sif_lo[S];
  assign mc_ver_link_sif_li[S] = south_vc_ver_link_sif_lo[N];

  assign ver_link_sif_o[S] = south_vc_ver_link_sif_lo[S];
  assign south_vc_ver_link_sif_li[S] = ver_link_sif_i[S];


endmodule
