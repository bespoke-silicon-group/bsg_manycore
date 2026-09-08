/**
 *    vcache_dma_to_dram_channel_map.v
 *
 */ 

`include "bsg_defines.sv"
`include "bsg_cache.svh"
`include "bsg_noc_links.svh"

module vcache_dma_to_dram_channel_map 
  import bsg_cache_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter `BSG_INV_PARAM(num_pods_y_p)
    , parameter `BSG_INV_PARAM(num_pods_x_p)
    , parameter `BSG_INV_PARAM(num_tiles_x_p)

    , parameter `BSG_INV_PARAM(wh_ruche_factor_p)

    , parameter `BSG_INV_PARAM(vcache_addr_width_p)
    , parameter `BSG_INV_PARAM(vcache_dma_data_width_p)
    , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)

    // Normally, divide columns between east/west and then among cache-to-DRAM lanes.
    // With one column and one lane, division gives zero, but each used east link serves one cache.
    , parameter num_vcaches_per_link_lp = `BSG_MAX(1, (num_tiles_x_p*num_pods_x_p)/wh_ruche_factor_p/2)
    , parameter num_total_vcaches_lp = (num_pods_x_p*num_pods_y_p*2*num_tiles_x_p)

    , parameter num_vcaches_per_slice_lp = (num_pods_x_p == 1)
        ? (num_tiles_x_p/2)
        : (num_tiles_x_p)
    , parameter cache_dma_pkt_width_lp=`bsg_cache_dma_pkt_width(vcache_addr_width_p, vcache_block_size_in_words_p)
  )
  (
    // unmapped
    input          [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][cache_dma_pkt_width_lp-1:0] dma_pkt_i
    , input        [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_v_i
    , output logic [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_yumi_o

    , output logic [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_o
    , output logic [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_v_o
    , input        [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_ready_i

    , input        [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_i
    , input        [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_v_i
    , output logic [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_yumi_o
    
    // remapped
    , output logic [num_total_vcaches_lp-1:0][cache_dma_pkt_width_lp-1:0] remapped_dma_pkt_o
    , output logic [num_total_vcaches_lp-1:0] remapped_dma_pkt_v_o
    , input        [num_total_vcaches_lp-1:0] remapped_dma_pkt_yumi_i

    , input        [num_total_vcaches_lp-1:0][vcache_dma_data_width_p-1:0] remapped_dma_data_i
    , input        [num_total_vcaches_lp-1:0] remapped_dma_data_v_i
    , output logic [num_total_vcaches_lp-1:0] remapped_dma_data_ready_o

    , output logic [num_total_vcaches_lp-1:0][vcache_dma_data_width_p-1:0] remapped_dma_data_o
    , output logic [num_total_vcaches_lp-1:0] remapped_dma_data_v_o
    , input        [num_total_vcaches_lp-1:0] remapped_dma_data_yumi_i

  );


  `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p, vcache_block_size_in_words_p);


  if (num_tiles_x_p == 1 && num_pods_x_p == 1) begin: single_column
    // This wiring requires one cache-to-DRAM lane per endpoint, so its lane index is always 0.
    // Runtime initialization sends both caches east; keep the unused west handshakes inactive.
    initial assert (wh_ruche_factor_p == 1)
      else $error("Single-column HBM wiring requires WH factor 1");
    assign dma_pkt_yumi_o[W] = '0;
    assign dma_data_o[W] = '0;
    assign dma_data_v_o[W] = '0;
    assign dma_data_yumi_o[W] = '0;
    for (genvar y = 0; y < num_pods_y_p; y++) begin: py
      for (genvar k = N; k <= S; k++) begin: ns
        // Each pod row contributes two caches, ordered north then south.
        // Thus row y occupies indices 2*y and 2*y+1, with the same mapping for data and handshakes.
        localparam idx = 2*y + (k == S);
        assign remapped_dma_pkt_o[idx] = dma_pkt_i[E][y][k][0][0];
        assign remapped_dma_pkt_v_o[idx] = dma_pkt_v_i[E][y][k][0][0];
        assign dma_pkt_yumi_o[E][y][k][0][0] = remapped_dma_pkt_yumi_i[idx];
        assign dma_data_o[E][y][k][0][0] = remapped_dma_data_i[idx];
        assign dma_data_v_o[E][y][k][0][0] = remapped_dma_data_v_i[idx];
        assign remapped_dma_data_ready_o[idx] = dma_data_ready_i[E][y][k][0][0];
        assign remapped_dma_data_o[idx] = dma_data_i[E][y][k][0][0];
        assign remapped_dma_data_v_o[idx] = dma_data_v_i[E][y][k][0][0];
        assign dma_data_yumi_o[E][y][k][0][0] = remapped_dma_data_yumi_i[idx];
      end
    end
  end else begin: multiple_columns
  // cache dma unruched mapping
  bsg_cache_dma_pkt_s [E:W][num_pods_y_p-1:0][S:N][(num_tiles_x_p*num_pods_x_p/2)-1:0] unruched_dma_pkt_lo;
  logic [E:W][num_pods_y_p-1:0][S:N][(num_tiles_x_p*num_pods_x_p/2)-1:0][vcache_dma_data_width_p-1:0] unruched_dma_data_li, unruched_dma_data_lo;
  logic [E:W][num_pods_y_p-1:0][S:N][(num_tiles_x_p*num_pods_x_p/2)-1:0] unruched_dma_pkt_v_lo, unruched_dma_pkt_yumi_li, 
                                                                                                unruched_dma_data_v_li, unruched_dma_data_ready_lo,
                                                                                                unruched_dma_data_v_lo, unruched_dma_data_yumi_li;

  for (genvar i = W; i <= E; i++) begin
    for (genvar j = 0; j < num_pods_y_p; j++) begin
      for (genvar k = N; k <= S; k++) begin
        for (genvar l = 0; l < (num_tiles_x_p*num_pods_x_p/2); l++) begin

            assign unruched_dma_pkt_lo[i][j][k][l] = dma_pkt_i[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p];
            assign unruched_dma_pkt_v_lo[i][j][k][l] = dma_pkt_v_i[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p];
            assign dma_pkt_yumi_o[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p] = unruched_dma_pkt_yumi_li[i][j][k][l];

            assign dma_data_o[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p] = unruched_dma_data_li[i][j][k][l];
            assign dma_data_v_o[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p] = unruched_dma_data_v_li[i][j][k][l];
            assign unruched_dma_data_ready_lo[i][j][k][l] = dma_data_ready_i[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p];

            assign unruched_dma_data_lo[i][j][k][l] = dma_data_i[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p];
            assign unruched_dma_data_v_lo[i][j][k][l] = dma_data_v_i[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p];
            assign dma_data_yumi_o[i][j][k][l%wh_ruche_factor_p][l/wh_ruche_factor_p] = unruched_dma_data_yumi_li[i][j][k][l];

        end
      end
    end
  end

  // flatten rows
  bsg_cache_dma_pkt_s [E:W][num_pods_y_p-1:0][(num_tiles_x_p*num_pods_x_p)-1:0] flattened_dma_pkt_lo;
  logic [E:W][num_pods_y_p-1:0][(num_tiles_x_p*num_pods_x_p)-1:0][vcache_dma_data_width_p-1:0] flattened_dma_data_li, flattened_dma_data_lo;
  logic [E:W][num_pods_y_p-1:0][(num_tiles_x_p*num_pods_x_p)-1:0] flattened_dma_pkt_v_lo, flattened_dma_pkt_yumi_li, 
                                                                                    flattened_dma_data_v_li, flattened_dma_data_ready_lo,
                                                                                    flattened_dma_data_v_lo, flattened_dma_data_yumi_li;

  for (genvar i = W; i <= E; i++) begin
    for (genvar j = 0; j < num_pods_y_p; j++) begin
      for (genvar k = N; k <= S; k++) begin
        for (genvar l = 0; l < (num_tiles_x_p*num_pods_x_p/2); l++) begin

            localparam idx = (l % num_vcaches_per_slice_lp)
              + ((k == S) ? num_vcaches_per_slice_lp : 0)
              + (l/num_vcaches_per_slice_lp)*(2*num_vcaches_per_slice_lp);

            assign flattened_dma_pkt_lo[i][j][idx]   = unruched_dma_pkt_lo[i][j][k][l];
            assign flattened_dma_pkt_v_lo[i][j][idx] = unruched_dma_pkt_v_lo[i][j][k][l];
            assign unruched_dma_pkt_yumi_li[i][j][k][l] = flattened_dma_pkt_yumi_li[i][j][idx];

            assign unruched_dma_data_li[i][j][k][l] = flattened_dma_data_li[i][j][idx];
            assign unruched_dma_data_v_li[i][j][k][l] = flattened_dma_data_v_li[i][j][idx];
            assign flattened_dma_data_ready_lo[i][j][idx] = unruched_dma_data_ready_lo[i][j][k][l];

            assign flattened_dma_data_lo[i][j][idx] = unruched_dma_data_lo[i][j][k][l];
            assign flattened_dma_data_v_lo[i][j][idx] = unruched_dma_data_v_lo[i][j][k][l];
            assign unruched_dma_data_yumi_li[i][j][k][l] = flattened_dma_data_yumi_li[i][j][idx];

        end
      end
    end
  end


  // connect to remapped
  assign remapped_dma_pkt_o = flattened_dma_pkt_lo;
  assign remapped_dma_pkt_v_o = flattened_dma_pkt_v_lo;
  assign flattened_dma_pkt_yumi_li = remapped_dma_pkt_yumi_i;

  assign flattened_dma_data_li = remapped_dma_data_i;
  assign flattened_dma_data_v_li = remapped_dma_data_v_i;
  assign remapped_dma_data_ready_o = flattened_dma_data_ready_lo;


  assign remapped_dma_data_o = flattened_dma_data_lo;
  assign remapped_dma_data_v_o = flattened_dma_data_v_lo;
  assign flattened_dma_data_yumi_li = remapped_dma_data_yumi_i;

  end


endmodule

`BSG_ABSTRACT_MODULE(vcache_dma_to_dram_channel_map)
