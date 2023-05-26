/**
 *    bsg_nonsynth_manycore_testbench.v
 *
 */

`include "bsg_manycore_defines.vh"
`include "bsg_cache.vh"

module bsg_nonsynth_manycore_testbench
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  import bsg_tag_pkg::*;
  import bsg_cache_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;
  import bsg_manycore_network_cfg_pkg::*;
  #(parameter `BSG_INV_PARAM(num_pods_x_p)
    , parameter `BSG_INV_PARAM(num_pods_y_p)
    , parameter `BSG_INV_PARAM(num_tiles_x_p)
    , parameter `BSG_INV_PARAM(num_tiles_y_p)
    , parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)
    , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
    , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
    , parameter `BSG_INV_PARAM(addr_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)
    , parameter `BSG_INV_PARAM(dmem_size_p)
    , parameter `BSG_INV_PARAM(icache_entries_p)
    , parameter `BSG_INV_PARAM(icache_tag_width_p)
    , parameter `BSG_INV_PARAM(icache_block_size_in_words_p)
    , parameter `BSG_INV_PARAM(ruche_factor_X_p)
    , parameter `BSG_INV_PARAM(barrier_ruche_factor_X_p)

    , parameter `BSG_INV_PARAM(num_subarray_x_p)
    , parameter `BSG_INV_PARAM(num_subarray_y_p)

    , parameter `BSG_INV_PARAM(num_vcache_rows_p)
    , parameter `BSG_INV_PARAM(vcache_data_width_p)
    , parameter `BSG_INV_PARAM(vcache_sets_p)
    , parameter `BSG_INV_PARAM(vcache_ways_p)
    , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p) // in words
    , parameter `BSG_INV_PARAM(vcache_dma_data_width_p) // in bits
    , parameter `BSG_INV_PARAM(vcache_size_p) // in words
    , parameter `BSG_INV_PARAM(vcache_addr_width_p) // byte addr
    , parameter `BSG_INV_PARAM(num_vcaches_per_channel_p)
    , parameter vcache_word_tracking_p = 1

    , parameter `BSG_INV_PARAM(wh_flit_width_p)
    , parameter wh_ruche_factor_p = 2
    , parameter `BSG_INV_PARAM(wh_cid_width_p)
    , parameter `BSG_INV_PARAM(wh_len_width_p)
    , parameter `BSG_INV_PARAM(wh_cord_width_p)

    , parameter bsg_manycore_network_cfg_e bsg_manycore_network_cfg_p = e_network_half_ruche_x
    , parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = e_vcache_test_mem
    , parameter `BSG_INV_PARAM(bsg_dram_size_p) // in word
    , parameter reset_depth_p = 3

    , parameter enable_vcore_profiling_p=0
    , parameter enable_router_profiling_p=0
    , parameter enable_cache_profiling_p=0
    , parameter enable_vanilla_core_trace_p = 0
    , parameter enable_remote_op_profiling_p = 0

    , parameter enable_vcore_pc_coverage_p=0

    , parameter enable_vanilla_core_pc_histogram_p=0

    , parameter cache_bank_addr_width_lp = `BSG_SAFE_CLOG2(bsg_dram_size_p/(2*num_tiles_x_p*num_vcache_rows_p)*4) // byte addr
    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    // This is used to define heterogeneous arrays. Each index defines
    // the type of an X/Y coordinate in the array. This is a vector of
    // num_tiles_x_p*num_tiles_y_p ints; type "0" is the
    // default. See bsg_manycore_hetero_socket.v for more types.
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}
  )
  (
    input clk_i
    , input reset_i

    , input dram_clk_i

    , output tag_done_o
    
    , input  [link_sif_width_lp-1:0] io_link_sif_i
    , output [link_sif_width_lp-1:0] io_link_sif_o
  );


  // print machine settings
  initial begin
    $display("MACHINE SETTINGS:");
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X                 = %d", num_tiles_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_Y                 = %d", num_tiles_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_SET               = %d", vcache_sets_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_WAY               = %d", vcache_ways_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS  = %d", vcache_block_size_in_words_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MAX_EPA_WIDTH            = %d", addr_width_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MEM_CFG                  = %s", bsg_manycore_mem_cfg_p.name());
    $display("[INFO][TESTBENCH] BSG_MACHINE_NETWORK_CFG              = %s", bsg_manycore_network_cfg_p.name());
    $display("[INFO][TESTBENCH] BSG_MACHINE_RUCHE_FACTOR_X           = %d", ruche_factor_X_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_BARRIER_RUCHE_FACTOR_X   = %d", barrier_ruche_factor_X_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_SUBARRAY_X               = %d", num_subarray_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_SUBARRAY_Y               = %d", num_subarray_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_ORIGIN_X_CORD            = %d", `BSG_MACHINE_ORIGIN_X_CORD);
    $display("[INFO][TESTBENCH] BSG_MACHINE_ORIGIN_Y_CORD            = %d", `BSG_MACHINE_ORIGIN_Y_CORD);
    $display("[INFO][TESTBENCH] BSG_MACHINE_NUM_VCACHE_ROWS          = %d", num_vcache_rows_p);
    $display("[INFO][TESTBENCH] vcache_word_tracking_p               = %d", vcache_word_tracking_p);
    $display("[INFO][TESTBENCH] enable_vcore_profiling_p             = %d", enable_vcore_profiling_p);
    $display("[INFO][TESTBENCH] enable_router_profiling_p            = %d", enable_router_profiling_p);
    $display("[INFO][TESTBENCH] enable_cache_profiling_p             = %d", enable_cache_profiling_p);
    $display("[INFO][TESTBENCH] enable_vcore_pc_coverage_p           = %d", enable_vcore_pc_coverage_p);
  end


  // BSG TAG MASTER
  logic tag_done_lo;
  bsg_tag_s [num_pods_y_p-1:0][num_pods_x_p-1:0] pod_tags_lo;

  bsg_nonsynth_manycore_tag_master #(
    .num_pods_x_p(num_pods_x_p)
    ,.num_pods_y_p(num_pods_y_p)
    ,.wh_cord_width_p(wh_cord_width_p)
  ) mtm (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.tag_done_o(tag_done_lo)
    ,.pod_tags_o(pod_tags_lo)
  );   
  
  assign tag_done_o = tag_done_lo;

  // deassert reset when tag programming is done.
  wire reset = ~tag_done_lo;
  logic reset_r;
  bsg_dff_chain #(
    .width_p(1)
    ,.num_stages_p(reset_depth_p)
  ) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset)
    ,.data_o(reset_r)
  );

  logic dram_reset_r;
  bsg_sync_sync #(.width_p(1)) dram_reset_bss (
    .oclk_i(dram_clk_i)
    ,.iclk_data_i(reset_r)
    ,.oclk_data_o(dram_reset_r)
  );


  // instantiate manycore
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  bsg_manycore_link_sif_s [S:N][(num_pods_x_p*num_tiles_x_p)-1:0] ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][(num_pods_x_p*num_tiles_x_p)-1:0] ver_link_sif_lo;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_li;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_lo;
  bsg_manycore_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] hor_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] ruche_link_li;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] ruche_link_lo;

  if (bsg_manycore_network_cfg_p == e_network_half_ruche_x) begin: fi1
    bsg_manycore_pod_ruche_array #(
      .num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)
      ,.pod_x_cord_width_p(pod_x_cord_width_p)
      ,.pod_y_cord_width_p(pod_y_cord_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.ruche_factor_X_p(ruche_factor_X_p)
      ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
      ,.num_subarray_x_p(num_subarray_x_p)
      ,.num_subarray_y_p(num_subarray_y_p)

      ,.dmem_size_p(dmem_size_p)
      ,.icache_entries_p(icache_entries_p)
      ,.icache_tag_width_p(icache_tag_width_p)
      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

      ,.num_vcache_rows_p(num_vcache_rows_p)
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_size_p(vcache_size_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
      ,.wh_len_width_p(wh_len_width_p)

      ,.num_pods_y_p(num_pods_y_p)
      ,.num_pods_x_p(num_pods_x_p)

      ,.reset_depth_p(reset_depth_p)
      ,.hetero_type_vec_p(hetero_type_vec_p)
    ) DUT (
      .clk_i(clk_i)

      ,.ver_link_sif_i(ver_link_sif_li)
      ,.ver_link_sif_o(ver_link_sif_lo)

      ,.wh_link_sif_i(wh_link_sif_li)
      ,.wh_link_sif_o(wh_link_sif_lo)

      ,.hor_link_sif_i(hor_link_sif_li)
      ,.hor_link_sif_o(hor_link_sif_lo)

      ,.ruche_link_i(ruche_link_li)
      ,.ruche_link_o(ruche_link_lo)

      ,.pod_tags_i(pod_tags_lo) 
    );
  end
  else if (bsg_manycore_network_cfg_p == e_network_mesh) begin: fi1
    bsg_manycore_pod_mesh_array #(
      .num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)
      ,.pod_x_cord_width_p(pod_x_cord_width_p)
      ,.pod_y_cord_width_p(pod_y_cord_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
      ,.num_subarray_x_p(num_subarray_x_p)
      ,.num_subarray_y_p(num_subarray_y_p)

      ,.dmem_size_p(dmem_size_p)
      ,.icache_entries_p(icache_entries_p)
      ,.icache_tag_width_p(icache_tag_width_p)
      ,.icache_block_size_in_words_p(icache_block_size_in_words_p)

      ,.num_vcache_rows_p(num_vcache_rows_p)
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_size_p(vcache_size_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
      ,.wh_len_width_p(wh_len_width_p)

      ,.num_pods_y_p(num_pods_y_p)
      ,.num_pods_x_p(num_pods_x_p)

      ,.reset_depth_p(reset_depth_p)
      ,.hetero_type_vec_p(hetero_type_vec_p)
    ) DUT (
      .clk_i(clk_i)

      ,.ver_link_sif_i(ver_link_sif_li)
      ,.ver_link_sif_o(ver_link_sif_lo)

      ,.wh_link_sif_i(wh_link_sif_li)
      ,.wh_link_sif_o(wh_link_sif_lo)

      ,.hor_link_sif_i(hor_link_sif_li)
      ,.hor_link_sif_o(hor_link_sif_lo)

      ,.pod_tags_i(pod_tags_lo) 
    );
  end
  else begin
    initial begin
      $error("Invalid bsg_manycore_network_cfg_p.");
    end
  end

  // Invert WH ruche links
  // hardcoded for ruche factor = 2
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] buffered_wh_link_sif_li;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] buffered_wh_link_sif_lo;
  for (genvar i = W; i <= E; i++) begin
    for (genvar j = 0; j < num_pods_y_p; j++) begin
      for (genvar k = N; k <= S; k++) begin
        for (genvar v = 0; v < num_vcache_rows_p; v++) begin
          for (genvar r = 0; r < wh_ruche_factor_p; r++) begin
            if (r == 0) begin
              assign wh_link_sif_li[i][j][k][v][r] = buffered_wh_link_sif_li[i][j][k][v][r];
              assign buffered_wh_link_sif_lo[i][j][k][v][r] = wh_link_sif_lo[i][j][k][v][r];
            end
            else begin
              assign wh_link_sif_li[i][j][k][v][r] = ~buffered_wh_link_sif_li[i][j][k][v][r];
              assign buffered_wh_link_sif_lo[i][j][k][v][r] = ~wh_link_sif_lo[i][j][k][v][r];
            end
          end
        end
      end
    end
  end

  // IO ROUTER
  localparam rev_use_credits_lp = 5'b00001;
  localparam int rev_fifo_els_lp[4:0] = '{2,2,2,2,3};
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:P] io_link_sif_li;
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:P] io_link_sif_lo;

  for (genvar x = 0; x < num_pods_x_p*num_tiles_x_p; x++) begin: io_rtr_x
    bsg_manycore_mesh_node #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.stub_p(4'b0100) // stub north
      ,.rev_use_credits_p(rev_use_credits_lp)
      ,.rev_fifo_els_p(rev_fifo_els_lp)
    ) io_rtr (
      .clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.links_sif_i(io_link_sif_li[x][S:W])
      ,.links_sif_o(io_link_sif_lo[x][S:W])

      ,.proc_link_sif_i(io_link_sif_li[x][P])
      ,.proc_link_sif_o(io_link_sif_lo[x][P])

      ,.global_x_i(x_cord_width_p'(num_tiles_x_p+x))
      ,.global_y_i(y_cord_width_p'(0))
    );

    // connect to pod array
    assign ver_link_sif_li[N][x] = io_link_sif_lo[x][S];
    assign io_link_sif_li[x][S] = ver_link_sif_lo[N][x];

    // connect between io rtr
    if (x < (num_pods_x_p*num_tiles_x_p)-1) begin
      assign io_link_sif_li[x][E] = io_link_sif_lo[x+1][W];
      assign io_link_sif_li[x+1][W] = io_link_sif_lo[x][E];
    end
  end



  // Host link connection
  assign io_link_sif_li[0][P] = io_link_sif_i;
  assign io_link_sif_o = io_link_sif_lo[0][P];




  //                              //
  // Configurable Memory System   //
  //                              //
  localparam logic [e_max_val-1:0] mem_cfg_lp = (1 << bsg_manycore_mem_cfg_p);

  if (mem_cfg_lp[e_vcache_test_mem]) begin: test_mem
    // in bytes
    // north + south row of vcache
    localparam longint unsigned mem_size_lp = (2**30)*num_pods_x_p/wh_ruche_factor_p/num_vcache_rows_p/2;
    localparam num_vcaches_per_test_mem_lp = (num_tiles_x_p*num_pods_x_p)/wh_ruche_factor_p/2;

    for (genvar i = W; i <= E; i++) begin: hs                           // horizontal side
      for (genvar j = 0; j < num_pods_y_p; j++) begin: py               // pod y
        for (genvar k = N; k <= S; k++) begin: vs                       // vertical side
          for (genvar v = 0; v < num_vcache_rows_p; v++) begin: vr      // vcache row
            for (genvar r = 0; r < wh_ruche_factor_p; r++) begin: rf    // ruching
              bsg_nonsynth_wormhole_test_mem #(
                .vcache_data_width_p(vcache_data_width_p)
                ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
                ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
                ,.num_vcaches_p(num_vcaches_per_test_mem_lp)
                ,.wh_cid_width_p(wh_cid_width_p)
                ,.wh_flit_width_p(wh_flit_width_p)
                ,.wh_cord_width_p(wh_cord_width_p)
                ,.wh_len_width_p(wh_len_width_p)
                ,.wh_ruche_factor_p(wh_ruche_factor_p)
                ,.no_concentration_p(1)
                ,.mem_size_p(mem_size_lp)
              ) test_mem (
                .clk_i(clk_i)
                ,.reset_i(reset_r)

                ,.wh_link_sif_i(buffered_wh_link_sif_lo[i][j][k][v][r])
                ,.wh_link_sif_o(buffered_wh_link_sif_li[i][j][k][v][r])
              );
            end
          end
        end
      end
    end

  end
  else if (mem_cfg_lp[e_vcache_hbm2]) begin: hbm2
    

    `define dram_pkg `BSG_MACHINE_DRAMSIM3_PKG
    parameter hbm2_data_width_p = `dram_pkg::data_width_p;
    parameter hbm2_channel_addr_width_p = `dram_pkg::channel_addr_width_p;
    parameter hbm2_num_channels_p = `dram_pkg::num_channels_p;
      
    parameter num_total_vcaches_lp = (num_pods_x_p*num_pods_y_p*2*num_tiles_x_p*num_vcache_rows_p);
    parameter lg_num_total_vcaches_lp = `BSG_SAFE_CLOG2(num_total_vcaches_lp);
    parameter num_vcaches_per_link_lp = (num_tiles_x_p*num_pods_x_p)/wh_ruche_factor_p/2; // # of vcaches attached to each link

    parameter num_total_channels_lp = num_total_vcaches_lp/num_vcaches_per_channel_p;
    parameter num_dram_lp = `BSG_CDIV(num_total_channels_lp,hbm2_num_channels_p);

    parameter lg_wh_ruche_factor_lp = `BSG_SAFE_CLOG2(wh_ruche_factor_p);
    parameter lg_num_vcaches_per_link_lp = `BSG_SAFE_CLOG2(num_vcaches_per_link_lp);

    // WH to cache dma
    `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p, vcache_block_size_in_words_p);
    bsg_cache_dma_pkt_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_v_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_yumi_li;

    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_li;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_v_li;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_ready_lo;

    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_v_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_yumi_li;


    for (genvar i = W; i <= E; i++) begin: hs
      for (genvar j = 0; j < num_pods_y_p; j++) begin: py
        for (genvar k = N; k <= S; k++) begin: py
          for (genvar n = 0; n < num_vcache_rows_p; n++) begin: row
            for (genvar r = 0; r < wh_ruche_factor_p; r++) begin: rf

              // This code is preserved from the previous mapping algorithm. For this specific
              //   testbench, only "no_concentration_p" is used
              //  if (no_concentration_p) begin
              //    assign send_cache_id = header_flit_in.src_cord[lg_wh_ruche_factor_lp+:lg_num_vcaches_lp];
              //
              //  end
              //  else begin
              //    if (num_pods_x_p == 1) begin
              //      // For pod 1x1, there are 1 HBM on each side of west and east.
              //      // Left half of top and bottom vcaches (16 total) maps to ch0 of HBM2 on west.
              //      // Right half of top and bottom vcaches (16 total) maps to ch0 of HBM2 on east.
              //      assign send_cache_id = {
              //        (1)'(header_flit_in.cid/wh_ruche_factor_p),
              //        header_flit_in.src_cord[lg_num_tiles_x_lp-2:0]
              //      };
              //    end
              //    else begin
              //      //  The left half of the pod array maps to HBM2 on the left side, and the right half on the right.
              //      //  HBM2 channels are allocated to pods starting from the top left corner.
              //      //  Within a pod, a row of vcaches (16) is allocated to a channel, so that there is one-to-one mapping from
              //      //  vcache to HBM2 bank.
              //      //
              //      //
              //      // For pod 4x4
              //      //
              //      // [dev0-ch0] [dev0-ch2] [dev2-ch0] [dev2-ch2]
              //      // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
              //      // [dev0-ch1] [dev0-ch3] [dev2-ch1] [dev2-ch3]
              //      //
              //      // [dev0-ch4] [dev0-ch6] [dev2-ch4] [dev2-ch6]
              //      // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
              //      // [dev0-ch5] [dev0-ch7] [dev2-ch5] [dev2-ch7]
              //      //
              //      // [dev1-ch0] [dev1-ch2] [dev3-ch0] [dev3-ch2]
              //      // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
              //      // [dev1-ch1] [dev0-ch3] [dev3-ch1] [dev3-ch3]
              //      //
              //      // [dev1-ch4] [dev1-ch6] [dev3-ch4] [dev3-ch6]
              //      // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
              //      // [dev1-ch5] [dev1-ch7] [dev3-ch5] [dev3-ch7]
              //      //
              //      assign send_cache_id = {
              //        (lg_num_pods_x_lp-1)'((header_flit_in.src_cord[wh_cord_width_p-1:lg_num_tiles_x_lp] - pod_start_x_p)%(num_pods_x_p/2)),
              //        (1)'(header_flit_in.cid/wh_ruche_factor_p),
              //        header_flit_in.src_cord[lg_num_tiles_x_lp-1:0]
              //      };
              //    end

              `declare_bsg_cache_wh_header_flit_s(wh_flit_width_p,wh_cord_width_p,wh_len_width_p,wh_cid_width_p);
              bsg_cache_wh_header_flit_s header_flit_in;
              assign header_flit_in = buffered_wh_link_sif_lo[i][j][k][n][r].data;

              wire [lg_num_vcaches_per_link_lp-1:0] dma_id_li = (num_vcaches_per_link_lp == 1)
                ? 1'b0
                : header_flit_in.src_cord[lg_wh_ruche_factor_lp+:lg_num_vcaches_per_link_lp];

              bsg_wormhole_to_cache_dma_fanout#(
                .num_dma_p(num_vcaches_per_link_lp)
                ,.dma_addr_width_p(vcache_addr_width_p)
                ,.dma_mask_width_p(vcache_block_size_in_words_p)
                ,.dma_burst_len_p(vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)

                ,.wh_flit_width_p(wh_flit_width_p)
                ,.wh_cid_width_p(wh_cid_width_p)
                ,.wh_len_width_p(wh_len_width_p)
                ,.wh_cord_width_p(wh_cord_width_p)
              ) wh_to_dma (
                .clk_i(clk_i)
                ,.reset_i(reset_r)
    
                ,.wh_link_sif_i     (buffered_wh_link_sif_lo[i][j][k][n][r])
                ,.wh_dma_id_i       (dma_id_li)
                ,.wh_link_sif_o     (buffered_wh_link_sif_li[i][j][k][n][r])

                ,.dma_pkt_o         (dma_pkt_lo[i][j][k][n][r])
                ,.dma_pkt_v_o       (dma_pkt_v_lo[i][j][k][n][r])
                ,.dma_pkt_yumi_i    (dma_pkt_yumi_li[i][j][k][n][r])

                ,.dma_data_i        (dma_data_li[i][j][k][n][r])
                ,.dma_data_v_i      (dma_data_v_li[i][j][k][n][r])
                ,.dma_data_ready_and_o (dma_data_ready_lo[i][j][k][n][r])

                ,.dma_data_o        (dma_data_lo[i][j][k][n][r])
                ,.dma_data_v_o      (dma_data_v_lo[i][j][k][n][r])
                ,.dma_data_yumi_i   (dma_data_yumi_li[i][j][k][n][r])
              );
            end
          end
        end
      end
    end


    // cache DMA to DRAMSIM3
    // assign vcache DMA to correct HBM2 channel / bank
    bsg_cache_dma_pkt_s [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_pkt_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_pkt_v_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_pkt_yumi_li;

    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0][vcache_dma_data_width_p-1:0] remapped_dma_data_li;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_v_li;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_ready_lo;

    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0][vcache_dma_data_width_p-1:0] remapped_dma_data_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_v_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_yumi_li;


    vcache_dma_to_dram_channel_map #(
      .num_pods_y_p(num_pods_y_p)
      ,.num_pods_x_p(num_pods_x_p)
      ,.num_tiles_x_p(num_tiles_x_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)

      ,.num_vcache_rows_p(num_vcache_rows_p)
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ) dma_map (
      // unmapped
      .dma_pkt_i                    (dma_pkt_lo)
      ,.dma_pkt_v_i                 (dma_pkt_v_lo)
      ,.dma_pkt_yumi_o              (dma_pkt_yumi_li)

      ,.dma_data_o                  (dma_data_li)
      ,.dma_data_v_o                (dma_data_v_li)
      ,.dma_data_ready_i            (dma_data_ready_lo)

      ,.dma_data_i                  (dma_data_lo)
      ,.dma_data_v_i                (dma_data_v_lo)
      ,.dma_data_yumi_o             (dma_data_yumi_li)

      // remapped
      ,.remapped_dma_pkt_o          (remapped_dma_pkt_lo)
      ,.remapped_dma_pkt_v_o        (remapped_dma_pkt_v_lo)
      ,.remapped_dma_pkt_yumi_i     (remapped_dma_pkt_yumi_li)
      
      ,.remapped_dma_data_i         (remapped_dma_data_li)
      ,.remapped_dma_data_v_i       (remapped_dma_data_v_li)
      ,.remapped_dma_data_ready_o   (remapped_dma_data_ready_lo)

      ,.remapped_dma_data_o         (remapped_dma_data_lo)
      ,.remapped_dma_data_v_o       (remapped_dma_data_v_lo)
      ,.remapped_dma_data_yumi_i    (remapped_dma_data_yumi_li)
    );
        

    // DRAMSIM3
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_v_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_write_not_read_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][hbm2_channel_addr_width_p-1:0] dramsim3_ch_addr_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][(hbm2_data_width_p>>3)-1:0] dramsim3_mask_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_yumi_lo;

    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][hbm2_data_width_p-1:0] dramsim3_data_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_data_v_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_data_yumi_lo;

    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][hbm2_data_width_p-1:0] dramsim3_data_lo;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_data_v_lo;
    `dram_pkg::dram_ch_addr_s [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_read_done_ch_addr_lo;
    
    for (genvar i = 0; i < num_dram_lp; i++) begin
      bsg_nonsynth_dramsim3 #(
        .channel_addr_width_p (hbm2_channel_addr_width_p)
        ,.data_width_p        (hbm2_data_width_p)
        ,.num_channels_p      (hbm2_num_channels_p)
        ,.num_columns_p       (`dram_pkg::num_columns_p)
        ,.num_rows_p          (`dram_pkg::num_rows_p)
        ,.num_ba_p            (`dram_pkg::num_ba_p)
        ,.num_bg_p            (`dram_pkg::num_bg_p)
        ,.num_ranks_p         (`dram_pkg::num_ranks_p)
        ,.address_mapping_p   (`dram_pkg::address_mapping_p)
        ,.size_in_bits_p      (`dram_pkg::size_in_bits_p)
        ,.config_p            (`dram_pkg::config_p)
        ,.init_mem_p          (1)
        ,.base_id_p           (i*hbm2_num_channels_p)
        ,.masked_p            (1)
      ) hbm0 (
        .clk_i                (dram_clk_i)
        ,.reset_i             (dram_reset_r)
      
        ,.v_i                 (dramsim3_v_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.write_not_read_i    (dramsim3_write_not_read_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.ch_addr_i           (dramsim3_ch_addr_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.yumi_o              (dramsim3_yumi_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])

        ,.data_v_i            (dramsim3_data_v_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.data_i              (dramsim3_data_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.mask_i              (dramsim3_mask_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.data_yumi_o         (dramsim3_data_yumi_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])

        ,.data_v_o            (dramsim3_data_v_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.data_o              (dramsim3_data_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.read_done_ch_addr_o (dramsim3_read_done_ch_addr_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])


        ,.print_stat_clk_i    (clk_i)
        ,.print_stat_reset_i  (reset_r)
        ,.print_stat_v_i      ($root.`HOST_MODULE_PATH.print_stat_v)
        ,.print_stat_tag_i    ($root.`HOST_MODULE_PATH.print_stat_tag)

        ,.write_done_o        ()
        ,.write_done_ch_addr_o()
      );
    end


    // cache to test dram
    // This is the address format coming out of cache dma.
    typedef struct packed {
      logic [$clog2(`dram_pkg::num_ba_p)-1:0] ba;
      logic [$clog2(`dram_pkg::num_bg_p)-1:0] bg;
      logic [$clog2(`dram_pkg::num_rows_p)-1:0] ro;
      logic [$clog2(`dram_pkg::num_columns_p)-1:0] co;
      logic [$clog2(`dram_pkg::data_width_p>>3)-1:0] byte_offset;
    } dram_ch_addr_s; 

    dram_ch_addr_s [num_total_channels_lp-1:0] test_dram_ch_addr_lo;
    logic [num_total_channels_lp-1:0][hbm2_channel_addr_width_p-1:0] test_dram_ch_addr_li;

    for (genvar i = 0; i < num_total_channels_lp; i++) begin

      bsg_cache_to_test_dram #(
        .num_cache_p(num_vcaches_per_channel_p)
        ,.addr_width_p(vcache_addr_width_p)
        ,.data_width_p(vcache_data_width_p)
        ,.block_size_in_words_p(vcache_block_size_in_words_p)
        ,.cache_bank_addr_width_p(cache_bank_addr_width_lp)
        ,.dma_data_width_p(vcache_dma_data_width_p)
      
        ,.dram_channel_addr_width_p(hbm2_channel_addr_width_p)
        ,.dram_data_width_p(hbm2_data_width_p)
      ) cache_to_tram (
        .core_clk_i           (clk_i)
        ,.core_reset_i        (reset_r)

        ,.dma_pkt_i           (remapped_dma_pkt_lo[i])
        ,.dma_pkt_v_i         (remapped_dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_o      (remapped_dma_pkt_yumi_li[i])

        ,.dma_data_o          (remapped_dma_data_li[i])
        ,.dma_data_v_o        (remapped_dma_data_v_li[i])
        ,.dma_data_ready_i    (remapped_dma_data_ready_lo[i])

        ,.dma_data_i          (remapped_dma_data_lo[i])
        ,.dma_data_v_i        (remapped_dma_data_v_lo[i])
        ,.dma_data_yumi_o     (remapped_dma_data_yumi_li[i])


        ,.dram_clk_i              (dram_clk_i)
        ,.dram_reset_i            (dram_reset_r)
    
        ,.dram_req_v_o            (dramsim3_v_li[i])
        ,.dram_write_not_read_o   (dramsim3_write_not_read_li[i])
        ,.dram_ch_addr_o          (test_dram_ch_addr_lo[i])
        ,.dram_req_yumi_i         (dramsim3_yumi_lo[i])

        ,.dram_data_v_o           (dramsim3_data_v_li[i])
        ,.dram_data_o             (dramsim3_data_li[i])
        ,.dram_mask_o             (dramsim3_mask_li[i])
        ,.dram_data_yumi_i        (dramsim3_data_yumi_lo[i])

        ,.dram_data_v_i           (dramsim3_data_v_lo[i])
        ,.dram_data_i             (dramsim3_data_lo[i])
        ,.dram_ch_addr_i          (test_dram_ch_addr_li[i])
      );

      // manycore to dramsim3 address hashing
      // dramsim3 uses ro-bg-ba-co-bo as address map, so we are changing the mapping here.
      assign dramsim3_ch_addr_li[i] = {
        test_dram_ch_addr_lo[i].ro,
        test_dram_ch_addr_lo[i].bg,
        test_dram_ch_addr_lo[i].ba,
        test_dram_ch_addr_lo[i].co,
        test_dram_ch_addr_lo[i].byte_offset
      };

      // dramsim3 to manycore address hashing
      // address coming out of dramsim3 is also ro-bg-ba-co-bo, so we are changing it back to the format that cache dma uses.
      assign test_dram_ch_addr_li[i] = {
        dramsim3_read_done_ch_addr_lo[i].ba,
        dramsim3_read_done_ch_addr_lo[i].bg,
        dramsim3_read_done_ch_addr_lo[i].ro,
        dramsim3_read_done_ch_addr_lo[i].co,
        dramsim3_read_done_ch_addr_lo[i].byte_offset
      };
    end
  end













  ////                        ////
  ////      TIE OFF           ////
  ////                        ////


  // IO P tie off
  for (genvar i = 1; i < num_pods_x_p*num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) io_p_tieoff (
      .clk_i(clk_i)
      ,.reset_i(reset_r)
      ,.link_sif_i(io_link_sif_lo[i][P])
      ,.link_sif_o(io_link_sif_li[i][P])
    );
  end

  // IO west end tieoff
  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) io_w_tieoff (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_sif_i(io_link_sif_lo[0][W])
    ,.link_sif_o(io_link_sif_li[0][W])
  );

  // IO east end tieoff
  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) io_e_tieoff (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_sif_i(io_link_sif_lo[(num_pods_x_p*num_tiles_x_p)-1][E])
    ,.link_sif_o(io_link_sif_li[(num_pods_x_p*num_tiles_x_p)-1][E])
  );


  // SOUTH VER LINK TIE OFFS
  for (genvar i = 0; i < num_pods_x_p*num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) ver_s_tieoff (
      .clk_i(clk_i)
      ,.reset_i(reset_r)
      ,.link_sif_i(ver_link_sif_lo[S][i])
      ,.link_sif_o(ver_link_sif_li[S][i])
    );
  end


  // HOR TIEOFF (local link)
  for (genvar i = W; i <= E; i++) begin
    for (genvar j = 0; j < num_pods_y_p; j++) begin
      for (genvar k = 0; k < num_tiles_y_p; k++) begin
        bsg_manycore_link_sif_tieoff #(
          .addr_width_p(addr_width_p)
          ,.data_width_p(data_width_p)
          ,.x_cord_width_p(x_cord_width_p)
          ,.y_cord_width_p(y_cord_width_p)
        ) hor_tieoff (
          .clk_i(clk_i)
          ,.reset_i(reset_r)
          ,.link_sif_i(hor_link_sif_lo[i][j][k])
          ,.link_sif_o(hor_link_sif_li[i][j][k])
        );
      end
    end
  end


  // RUCHE LINK TIEOFF (west)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      // if ruche factor is even, tieoff with '1
      // if ruche factor is odd,  tieoff with '0
      assign ruche_link_li[W][j][k] = (ruche_factor_X_p%2 == 0) ? '1 : '0;
    end
  end

  // RUCHE LINK TIEOFF (east)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      // always tieoff with '0;
      assign ruche_link_li[E][j][k] = '0;
    end
  end
  








//                  //
//    PROFILERS     //
//                  //

// NOTE: Verilator does not allow parameter-controlled module binds
// (There's an issue filed, but not fixed as of 4.222). There are two ways we can fix this:
//
// 1. Clock gate the profilers based on the profiler parameter. E.g.:
//   ,.clk_i(clk_i && $root.`HOST_MODULE_PATH.testbench.enable_vcore_profiling_p)
//
// 2. Disable the profilers using Macros.
//
// Using clock gating was somewhat controversial, so for the moment we
// are controling the instantiation using macros *** FOR VERILATOR
// ONLY ***
//
// I agree that this is super annoying but until it gets fixed, this
// is the only way to prevent Verilator from running the profilers and
// slowing down simulation.

// Exponential parsing from surelog: https://github.com/chipsalliance/Surelog/issues/2035
`ifndef SURELOG
`ifndef VERILATOR_WORKAROUND_DISABLE_VCORE_PROFILING
if (enable_vcore_profiling_p) begin
  // vanilla core profiler
   bind vanilla_core vanilla_core_profiler #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.data_width_p(data_width_p)
    ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
    ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
  ) vcore_prof (
    .*
    ,.clk_i(clk_i)
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
  );
end
`endif

`ifndef VERILATOR_WORKAROUND_DISABLE_REMOTE_OP_PROFILING
if (enable_remote_op_profiling_p) begin
  bind network_tx remote_load_trace #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
    ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
  ) rlt (
    .*
    ,.clk_i(clk_i)
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
  );
end
`endif

`ifndef VERILATOR_WORKAROUND_DISABLE_VCACHE_PROFILING
if (enable_cache_profiling_p) begin
  bind bsg_cache vcache_profiler #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.block_size_in_words_p(block_size_in_words_p)
    ,.header_print_p({`BSG_STRINGIFY(`HOST_MODULE_PATH),".testbench.fi1.DUT.py[0].podrow.px[0].pod.north_vc_x[0].north_vc_row.vc_y[0].vc_x[0].vc.cache.vcache_prof"})
    ,.ways_p(ways_p)
  ) vcache_prof (
    // everything else
    .*
    ,.clk_i(clk_i)
    // bsg_cache_miss
    ,.chosen_way_n(miss.chosen_way_n)
    // from testbench
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
  );

  end
`endif

// Covergroups are not fully supported by Verilator 4.213
`ifndef VERILATOR
`ifndef VERILATOR_WORKAROUND_DISABLE_ROUTER_PROFILER
if (enable_router_profiling_p) begin
  bind bsg_mesh_router router_profiler #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.dims_p(dims_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.XY_order_p(XY_order_p)
    ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
    ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
    ,.num_tiles_x_p(`BSG_MACHINE_GLOBAL_X)
    ,.num_tiles_y_p(`BSG_MACHINE_GLOBAL_Y)
  ) rp0 (
    .*
    ,.clk_i(clk_i)
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
  );
end
`endif

`ifndef VERILATOR_WORKAROUND_DISABLE_VCORE_COVERAGE
if (enable_vcore_pc_coverage_p) begin
  bind vanilla_core bsg_nonsynth_manycore_vanilla_core_pc_cov #(
    .icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
  )
  pc_cov (
    .*
    ,.clk_i(clk_i)
    ,.coverage_en_i($root.`HOST_MODULE_PATH.coverage_en)
  );
end
`endif
`endif
`endif

  ///             ///
  ///   TRACER    ///
  ///             ///
  
`ifndef VERILATOR_WORKAROUND_DISABLE_VCORE_TRACE
if (enable_vanilla_core_trace_p) begin
  bind vanilla_core vanilla_core_trace #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
  ) trace0 (
    .*
    ,.clk_i(clk_i)
  );
end
`endif

  //////////////////
  // PC Histogram //
  //////////////////
`ifndef VERILATOR_WORKAROUND_DISABLE_PC_HISTOGRAM
if (enable_vanilla_core_pc_histogram_p) begin
  bind vanilla_core vanilla_core_pc_histogram
    #(.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.data_width_p(data_width_p)
      ,.icache_tag_width_p(icache_tag_width_p)
      ,.icache_entries_p(icache_entries_p)
      ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
      ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
      )
  vcore_pc_hist
    (.*);
end // if (enable_vanilla_core_pc_histogram_p)
`endif


endmodule

`BSG_ABSTRACT_MODULE(bsg_nonsynth_manycore_testbench)

