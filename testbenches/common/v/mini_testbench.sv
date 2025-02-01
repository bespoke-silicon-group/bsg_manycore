/**
 *    mini_testbench.sv
 *
 */

`include "bsg_manycore_defines.svh"

module mini_testbench
  import bsg_tag_pkg::*;
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;
  import bsg_manycore_network_cfg_pkg::*;
  ();

  parameter num_pods_x_p  = `BSG_MACHINE_PODS_X;
  parameter num_pods_y_p  = `BSG_MACHINE_PODS_Y;
  parameter num_tiles_x_p = `BSG_MACHINE_GLOBAL_X;
  parameter num_tiles_y_p = `BSG_MACHINE_GLOBAL_Y;
  parameter x_cord_width_p = `BSG_MACHINE_X_CORD_WIDTH;
  parameter y_cord_width_p = `BSG_MACHINE_Y_CORD_WIDTH;
  parameter pod_x_cord_width_p = x_cord_width_p - `BSG_SAFE_CLOG2(num_tiles_x_p);
  parameter pod_y_cord_width_p = y_cord_width_p - `BSG_SAFE_CLOG2(num_tiles_y_p);
  parameter num_subarray_x_p = `BSG_MACHINE_SUBARRAY_X;
  parameter num_subarray_y_p = `BSG_MACHINE_SUBARRAY_Y;
  parameter data_width_p = 32;
  parameter addr_width_p = `BSG_MACHINE_MAX_EPA_WIDTH; // word addr
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;
  parameter icache_block_size_in_words_p = 4;

  parameter vcache_data_width_p = data_width_p;
  parameter vcache_sets_p = `BSG_MACHINE_VCACHE_SET;
  parameter vcache_ways_p = `BSG_MACHINE_VCACHE_WAY;
  parameter vcache_block_size_in_words_p = `BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS; // in words
  parameter vcache_dma_data_width_p = `BSG_MACHINE_VCACHE_DMA_DATA_WIDTH; // in bits
  parameter vcache_size_p = vcache_sets_p*vcache_ways_p*vcache_block_size_in_words_p;
  parameter vcache_addr_width_p=(addr_width_p-1+`BSG_SAFE_CLOG2(data_width_p>>3));  // in bytes
  parameter vcache_word_tracking_p = `BSG_MACHINE_VCACHE_WORD_TRACKING;
  parameter num_vcaches_per_channel_p = `BSG_MACHINE_NUM_VCACHES_PER_CHANNEL;  
  parameter ipoly_hashing_p = `BSG_MACHINE_IPOLY_HASHING;

  parameter wh_flit_width_p = vcache_dma_data_width_p;
  parameter wh_cid_width_p = `BSG_SAFE_CLOG2(2);
  parameter wh_len_width_p = `BSG_SAFE_CLOG2(2+(vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)); // header + addr + mask + data
  parameter wh_cord_width_p = x_cord_width_p;

  parameter tag_els_p=1024;
  parameter tag_local_els_p=1;
  parameter tag_lg_width_p=4;

  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter bsg_manycore_network_cfg_e bsg_manycore_network_cfg_p = `BSG_MACHINE_NETWORK_CFG;
  parameter reset_depth_p = 3;


  // Clock;
  parameter core_clk_period_p = 1000; // 1000 ps == 1 GHz

  bit core_clk, core_reset;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(core_clk_period_p)
  ) clock_gen (
    .o(core_clk)
  );

  bsg_nonsynth_reset_gen #(
    .num_clocks_p(1)
    ,.reset_cycles_lo_p(0)
    ,.reset_cycles_hi_p(16)
  ) reset_gen (
    .clk_i(core_clk)
    ,.async_reset_o(core_reset)
  );

  
  // TAG trace replay;
  logic tr_tag_clk_lo, tr_tag_data_lo, tr_tag_done_lo;

  bsg_nonsynth_miniblade_tag_trace_replay #(
    .tag_els_p(tag_els_p)
  ) tr0 (
    .clk_i(core_clk)
    ,.reset_i(core_reset)
  
    ,.tag_clk_o(tr_tag_clk_lo)
    ,.tag_data_o(tr_tag_data_lo)
    ,.tag_done_o(tr_tag_done_lo)
  );

  wire reset = ~tr_tag_done_lo;


  // Declare links;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p,wh_link_sif_s);
  bsg_manycore_link_sif_s [E:W] io_link_sif_li, io_link_sif_lo;
  wh_link_sif_s [S:N][E:W] wh_link_sif_li, wh_link_sif_lo;


  // DUT;
  bsg_miniblade_pod #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    
    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)

    ,.vcache_size_p(vcache_size_p)
    ,.vcache_addr_width_p(vcache_addr_width_p)
    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ,.vcache_word_tracking_p(vcache_word_tracking_p)
    ,.ipoly_hashing_p(ipoly_hashing_p) 

    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)
    ,.wh_len_width_p(wh_len_width_p)
  
    ,.tag_els_p(tag_els_p)
    ,.tag_local_els_p(tag_local_els_p)
    ,.tag_lg_width_p(tag_lg_width_p)
  ) DUT (
    .clk_i(core_clk)

    // bsg_tag interface;
    ,.tag_clk_i(tr_tag_clk_lo)
    ,.tag_data_i(tr_tag_data_lo)
    ,.node_id_offset_i('0)   
 
    // IO links;
    // west = stubbed;
    // east = connect to noc block; connects to corner IO router (proc);
    ,.io_link_sif_i(io_link_sif_li)
    ,.io_link_sif_o(io_link_sif_lo)

    // wormhole ports;
    ,.north_wh_link_sif_i(wh_link_sif_li[N])
    ,.north_wh_link_sif_o(wh_link_sif_lo[N])
    ,.south_wh_link_sif_i(wh_link_sif_li[S])
    ,.south_wh_link_sif_o(wh_link_sif_lo[S])

    // stubbed ports;
    ,.mc_link_sif_i('0)
    ,.mc_link_sif_o()
    ,.mc_barrier_link_i('0)
    ,.mc_barrier_link_o()
    ,.svc_ver_link_i('0)
    ,.svc_ver_link_o()
    ,.global_x_o()
    ,.global_y_o()
    ,.reset_o()
  );


  // Wormhole memory banks;
  localparam longint unsigned mem_size_lp = (2**30); // size in bytes (1GB each)

  for (genvar i = N; i <= S; i++) begin
    bsg_nonsynth_wormhole_test_mem #(
      .vcache_data_width_p(vcache_data_width_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.num_vcaches_p(num_tiles_x_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.mem_size_p(mem_size_lp)
      ,.no_concentration_p(1)
    ) test_mem (
      .clk_i(core_clk)
      ,.reset_i(reset)

      ,.wh_link_sif_i(wh_link_sif_lo[i][E])
      ,.wh_link_sif_o(wh_link_sif_li[i][E])
    );

    // tieoff;
    assign wh_link_sif_li[i][W] = '0;
  end



  // SPMD LOADER
  bsg_nonsynth_manycore_io_complex #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.io_x_cord_p(`BSG_MACHINE_HOST_X_CORD)
    ,.io_y_cord_p(`BSG_MACHINE_HOST_Y_CORD)
    ,.saif_toggle_scope_p("inv")
  ) io (
    .clk_i(core_clk)
    ,.reset_i(reset)
    ,.io_link_sif_i(io_link_sif_lo[E])
    ,.io_link_sif_o(io_link_sif_li[E])
    ,.print_stat_v_o()
    ,.print_stat_tag_o()
    ,.loader_done_o()
  );

  assign io_link_sif_li[W] = '0; // tieoff;



endmodule
