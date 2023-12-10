/**
 *    spmd_testbench.v
 *
 */ 

`include "bsg_manycore_defines.svh"

module spmd_testbench
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;
  import bsg_manycore_network_cfg_pkg::*;
  (output bit reset_o);

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
  parameter ruche_factor_X_p    = `BSG_MACHINE_RUCHE_FACTOR_X;
  parameter barrier_ruche_factor_X_p    = `BSG_MACHINE_BARRIER_RUCHE_FACTOR_X;


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
  parameter wh_ruche_factor_p = `BSG_MACHINE_WH_RUCHE_FACTOR;
  parameter wh_cid_width_p = `BSG_SAFE_CLOG2(2*wh_ruche_factor_p); // no concentration in this testbench; cid is ignored.
  parameter wh_len_width_p = `BSG_SAFE_CLOG2(2+(vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)); // header + addr + mask + data
  parameter wh_cord_width_p = x_cord_width_p;

  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter bsg_manycore_network_cfg_e bsg_manycore_network_cfg_p = `BSG_MACHINE_NETWORK_CFG;
  parameter reset_depth_p = 3;


  // clock and reset
  parameter core_clk_period_p = 1000; // 1000 ps == 1 GHz
  parameter dram_clk_period_p = 1000; // 1000 ps == 1 GHz
  bit core_clk;
  bit global_reset;
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
    ,.async_reset_o(global_reset)
  );

  bit dram_clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(core_clk_period_p)
  ) dram_cg (
    .o(dram_clk)
  );
  

  // testbench
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s io_link_sif_li, io_link_sif_lo;
  logic tag_done_lo;

  bsg_nonsynth_manycore_testbench #(
    .num_pods_x_p(num_pods_x_p)
    ,.num_pods_y_p(num_pods_y_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)

    ,.num_subarray_x_p(num_subarray_x_p)
    ,.num_subarray_y_p(num_subarray_y_p)

    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_addr_width_p(vcache_addr_width_p)
    ,.vcache_word_tracking_p(vcache_word_tracking_p)
    ,.num_vcaches_per_channel_p(num_vcaches_per_channel_p)
    ,.ipoly_hashing_p(ipoly_hashing_p)

    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_ruche_factor_p(wh_ruche_factor_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)

    ,.bsg_manycore_network_cfg_p(bsg_manycore_network_cfg_p)
    ,.bsg_manycore_mem_cfg_p(bsg_manycore_mem_cfg_p)
    ,.bsg_dram_size_p(bsg_dram_size_p)

    ,.reset_depth_p(reset_depth_p)

`ifdef BSG_ENABLE_PROFILING
    ,.enable_vcore_profiling_p(1)
    ,.enable_router_profiling_p(1)
    ,.enable_cache_profiling_p(1)
    ,.enable_remote_op_profiling_p(1)
`endif
`ifdef BSG_ENABLE_COVERAGE
    ,.enable_vcore_pc_coverage_p(1)
`endif
`ifdef BSG_ENABLE_VANILLA_CORE_TRACE
    ,.enable_vanilla_core_trace_p(1)
`endif
`ifdef BSG_ENABLE_PC_HISTOGRAM
    ,.enable_vanilla_core_pc_histogram_p(1)
`endif
  // DR: If the instance name is changed, the bind statements in the
  // file where this module is defined, and header strings in the
  // profilers need to be changed as well.
  ) testbench (
    .clk_i(core_clk)
    ,.reset_i(global_reset)

    ,.dram_clk_i(dram_clk)

    ,.io_link_sif_i(io_link_sif_li)
    ,.io_link_sif_o(io_link_sif_lo)

    ,.tag_done_o(tag_done_lo)
  );

  // reset is deasserted when tag programming is done.
  logic reset_r;
  bsg_dff_chain #(
    .width_p(1)
    ,.num_stages_p(reset_depth_p)
  ) reset_dff (
    .clk_i(core_clk)
    ,.data_i(~tag_done_lo)
    ,.data_o(reset_r)
  );
  assign reset_o = reset_r;


  // SPMD LOADER
  logic print_stat_v;
  logic [data_width_p-1:0] print_stat_tag;
  bsg_nonsynth_manycore_io_complex #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
    ,.io_x_cord_p(`BSG_MACHINE_HOST_X_CORD)
    ,.io_y_cord_p(`BSG_MACHINE_HOST_Y_CORD)
    ,.saif_toggle_scope_p("spmd_testbench.testbench.fi1.DUT.podrow.px[0].pod.mc_y[0].mc_x[0].mc.y[0].x[0].tile")
  ) io (
    .clk_i(core_clk)
    ,.reset_i(reset_r)
    ,.io_link_sif_i(io_link_sif_lo)
    ,.io_link_sif_o(io_link_sif_li)
    ,.print_stat_v_o(print_stat_v)
    ,.print_stat_tag_o(print_stat_tag)
    ,.loader_done_o()
  );

  // reset dff


  // trace enable
  int status;
  int trace_arg;
  logic trace_en;
  initial begin
    status = $value$plusargs("vanilla_trace_en=%d", trace_arg);
    assign trace_en = (trace_arg == 1);
  end
  
  // coverage enable
  int coverage_arg;
  logic coverage_en;
  initial begin
    status = $value$plusargs("coverage_en=%d", coverage_arg);
    assign coverage_en = (coverage_arg == 1);
  end

  // global counter
  logic [31:0] global_ctr;
  bsg_cycle_counter global_cc (
    .clk_i(core_clk)
    ,.reset_i(reset_r)
    ,.ctr_r_o(global_ctr)
  );

endmodule
