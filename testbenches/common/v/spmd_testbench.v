/**
 *    spmd_testbench.v
 *
 */ 


module spmd_testbench();
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;

  parameter num_pods_x_p  = `BSG_MACHINE_PODS_X;
  parameter num_pods_y_p  = `BSG_MACHINE_PODS_Y;
  parameter num_tiles_x_p = `BSG_MACHINE_GLOBAL_X;
  parameter num_tiles_y_p = `BSG_MACHINE_GLOBAL_Y;
  parameter x_cord_width_p = 7;
  parameter y_cord_width_p = 7;
  parameter pod_x_cord_width_p = 3;
  parameter pod_y_cord_width_p = 4;
  parameter data_width_p = 32;
  parameter addr_width_p = `BSG_MACHINE_MAX_EPA_WIDTH; // word addr
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;
  parameter ruche_factor_X_p    = `BSG_MACHINE_RUCHE_FACTOR_X;

  parameter vcache_data_width_p = data_width_p;
  parameter vcache_sets_p = `BSG_MACHINE_VCACHE_SET;
  parameter vcache_ways_p = `BSG_MACHINE_VCACHE_WAY;
  parameter vcache_block_size_in_words_p = `BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS; // in words
  parameter vcache_dma_data_width_p = `BSG_MACHINE_VCACHE_DMA_DATA_WIDTH; // in bits
  parameter vcache_size_p = vcache_sets_p*vcache_ways_p*vcache_block_size_in_words_p;
  parameter vcache_addr_width_p=(addr_width_p-1+`BSG_SAFE_CLOG2(data_width_p>>3));  // in bytes

  parameter wh_flit_width_p = vcache_dma_data_width_p;
  parameter wh_ruche_factor_p = 2;
  parameter wh_cid_width_p = `BSG_SAFE_CLOG2(2*wh_ruche_factor_p); // north + south row of vcaches
  parameter wh_len_width_p = `BSG_SAFE_CLOG2(1+(vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)); // header + addr + data
  parameter wh_cord_width_p = x_cord_width_p;

  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter reset_depth_p = 3;


  // clock and reset
  parameter core_clk_period_p = 1000; // 1000 ps == 1 GHz
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
    ,.ruche_factor_X_p(ruche_factor_X_p)

    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_addr_width_p(vcache_addr_width_p)

    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_ruche_factor_p(wh_ruche_factor_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)

    ,.bsg_manycore_mem_cfg_p(bsg_manycore_mem_cfg_p)
    ,.bsg_dram_size_p(bsg_dram_size_p)

    ,.reset_depth_p(reset_depth_p)
  ) tb (
    .clk_i(core_clk)
    ,.reset_i(global_reset)

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


  // SPMD LOADER
  logic print_stat_v;
  logic [data_width_p-1:0] print_stat_tag;
  bsg_nonsynth_manycore_io_complex #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.io_x_cord_p(`BSG_MACHINE_HOST_X_CORD)
    ,.io_y_cord_p(`BSG_MACHINE_HOST_Y_CORD)
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
  int vanilla_pc_cov_arg;
  logic vanilla_pc_cov_en;
  initial begin
    status = $value$plusargs("vanilla_pc_cov_en=%d", vanilla_pc_cov_arg);
    assign vanilla_pc_cov_en = (vanilla_pc_cov_arg == 1);
  end

  // global counter
  logic [31:0] global_ctr;
  bsg_cycle_counter global_cc (
    .clk_i(core_clk)
    ,.reset_i(reset_r)
    ,.ctr_r_o(global_ctr)
  );


endmodule
