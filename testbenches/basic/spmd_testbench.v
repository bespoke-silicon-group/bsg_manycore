/**
 *  spmd_testbench.v
 *
 */

module spmd_testbench;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  import bsg_mem_cfg_pkg::*;

  // defines from VCS
  parameter bsg_global_x_p = `BSG_MACHINE_GLOBAL_X;
  parameter bsg_global_y_p = `BSG_MACHINE_GLOBAL_Y;
  parameter bsg_vcache_set_p = `BSG_MACHINE_VCACHE_SET;
  parameter bsg_vcache_way_p = `BSG_MACHINE_VCACHE_WAY;
  parameter bsg_vcache_block_size_p = `BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS; // in words
  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_max_epa_width_p = `BSG_MACHINE_MAX_EPA_WIDTH;
  parameter bsg_mem_cfg_e bsg_mem_cfg_p = e_mem_cfg_default;

  // constant params

  parameter extra_io_rows_p = 1;

  parameter data_width_p = 32;
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;
  parameter epa_byte_addr_width_p = 18;
  parameter load_id_width_p = 12;

  parameter axi_id_width_p = 6;
  parameter axi_addr_width_p = 64;
  parameter axi_data_width_p = 256;
  parameter axi_burst_len_p = 1;

  // derived param
  parameter axi_strb_width_lp = (axi_data_width_p>>3);
  parameter x_cord_width_lp = `BSG_SAFE_CLOG2(bsg_global_x_p);
  parameter y_cord_width_lp = `BSG_SAFE_CLOG2(bsg_global_y_p + extra_io_rows_p);


  parameter vcache_size_p = bsg_vcache_set_p * bsg_vcache_way_p * bsg_vcache_block_size_p;
  parameter dram_ch_addr_width_p = `BSG_SAFE_CLOG2(bsg_dram_size_p)-x_cord_width_lp; // virtual bank addr width (in word)


  // print machine settings
  initial begin
    $display("MACHINE SETTINGS:");
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X                 = %d", bsg_global_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_Y                 = %d", bsg_global_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_SET               = %d", bsg_vcache_set_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_WAY               = %d", bsg_vcache_way_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS  = %d", bsg_vcache_block_size_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_SIZE_WORDS          = %d", bsg_dram_size_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_INCLUDED            = %d", bsg_dram_included_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MAX_EPA_WIDTH            = %d", bsg_max_epa_width_p);
  end


  // clock and reset generation
  //
  parameter cycle_time_p = 20; // clock period

  wire clk;
  wire reset;

  bsg_nonsynth_clock_gen #(
    .cycle_time_p(cycle_time_p)
  ) clock_gen (
    .o(clk)
  );

  bsg_nonsynth_reset_gen #(
    .num_clocks_p(1)
    ,.reset_cycles_lo_p(1)
    ,.reset_cycles_hi_p(10)
  ) reset_gen (
    .clk_i(clk)
    ,.async_reset_o(reset)
  );


  // The manycore has a 2-FF pipelined reset in 16nm, therefore we need
  // to add a 2 cycle latency to all other modules.
  logic reset_r, reset_rr;

  always_ff @ (posedge clk) begin
    reset_r <= reset;
    reset_rr <= reset_r;
  end


  // instantiate manycore
  //
  `declare_bsg_manycore_link_sif_s(bsg_max_epa_width_p,data_width_p,
    x_cord_width_lp,y_cord_width_lp,load_id_width_p);

  bsg_manycore_link_sif_s [S:N][bsg_global_x_p-1:0] ver_link_li, ver_link_lo;
  bsg_manycore_link_sif_s [E:W][bsg_global_y_p-1:0] hor_link_li, hor_link_lo;
  bsg_manycore_link_sif_s [bsg_global_x_p-1:0] io_link_li, io_link_lo;

  bsg_manycore #(
    .dmem_size_p(dmem_size_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(bsg_vcache_block_size_p)
    ,.vcache_sets_p(bsg_vcache_set_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(bsg_max_epa_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.num_tiles_x_p(bsg_global_x_p)
    ,.num_tiles_y_p(bsg_global_y_p)
  ) DUT (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.hor_link_sif_i(hor_link_li)
    ,.hor_link_sif_o(hor_link_lo)

    ,.ver_link_sif_i(ver_link_li)
    ,.ver_link_sif_o(ver_link_lo)

    ,.io_link_sif_i(io_link_li)
    ,.io_link_sif_o(io_link_lo)
  );


  // instantiate the loader and moniter
  // connects to (0,0)
  logic print_stat_v;
  logic [data_width_p-1:0] print_stat_tag;

  bsg_nonsynth_manycore_io_complex #(
    .addr_width_p(bsg_max_epa_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)
    ,.load_id_width_p(load_id_width_p)

    ,.num_tiles_x_p(bsg_global_x_p)
    ,.num_tiles_y_p(bsg_global_y_p)
  ) io (
    .clk_i(clk)
    ,.reset_i(reset_rr)
    ,.io_link_sif_i(io_link_lo[0])
    ,.io_link_sif_o(io_link_li[0])
    ,.print_stat_v_o(print_stat_v)
    ,.print_stat_tag_o(print_stat_tag)
    ,.loader_done_o()
  );


  // configurable memory system
  //
  memory_system #(
    .mem_cfg_p(bsg_mem_cfg_p)

    ,.bsg_global_x_p(bsg_global_x_p)
    ,.bsg_global_y_p(bsg_global_y_p)

    ,.data_width_p(data_width_p)
    ,.addr_width_p(bsg_max_epa_width_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)
    ,.load_id_width_p(load_id_width_p)
    
    ,.sets_p(bsg_vcache_set_p)
    ,.ways_p(bsg_vcache_way_p)
    ,.block_size_in_words_p(bsg_vcache_block_size_p)

    ,.axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)

    ,.bsg_dram_included_p(bsg_dram_included_p)
    ,.bsg_dram_size_p(bsg_dram_size_p)

  ) memsys (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.link_sif_i(ver_link_lo[S])
    ,.link_sif_o(ver_link_li[S])
  );

 
  // vanilla core tracer
  //
  if (1) begin
    bind vanilla_core vanilla_core_trace #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.icache_tag_width_p(icache_tag_width_p)
      ,.icache_entries_p(icache_entries_p)
      ,.data_width_p(data_width_p)
      ,.dmem_size_p(dmem_size_p)
    ) vtrace (
      .*
    );

    bind vanilla_core instr_trace #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) itrace(
      .*
    );

    bind bsg_manycore_link_to_cache bsg_manycore_link_to_cache_tracer #(
      .link_addr_width_p(link_addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.cache_addr_width_lp(cache_addr_width_lp)
      ,.bsg_cache_pkt_width_lp(bsg_cache_pkt_width_lp)
    ) mlctrace (
      .*
    );

  end

  // profiler
  //
  logic [31:0] global_ctr;

  bsg_cycle_counter global_cc (
    .clk_i(clk)
    ,.reset_i(reset)
    ,.ctr_r_o(global_ctr)
  );


  bind vanilla_core vanilla_core_profiler #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
  ) vcore_prof (
    .*
    ,.global_ctr_i($root.spmd_testbench.global_ctr)
    ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
    ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
  );
  
  bind bsg_cache vcache_profiler #(
    .data_width_p(data_width_p)
  ) vcache_prof (
    .*
    ,.global_ctr_i($root.spmd_testbench.global_ctr)
    ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
    ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
  );

  // tieoffs
  //
  for (genvar i = 0; i < bsg_global_y_p; i++) begin

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_w (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(hor_link_lo[W][i])
      ,.link_sif_o(hor_link_li[W][i])
    );

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_e (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(hor_link_lo[E][i])
      ,.link_sif_o(hor_link_li[E][i])
    );
  end

  for (genvar i = 0; i < bsg_global_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_n (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(ver_link_lo[N][i])
      ,.link_sif_o(ver_link_li[N][i])
    );
  end

  for (genvar i = 1; i < bsg_global_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_io (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(io_link_lo[i])
      ,.link_sif_o(io_link_li[i])
    );
  end


endmodule


