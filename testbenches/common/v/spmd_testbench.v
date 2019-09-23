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
  parameter bsg_mem_cfg_e bsg_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter bsg_branch_trace_en_p = `BSG_MACHINE_BRANCH_TRACE_EN;

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
    $display("[INFO][TESTBENCH] BSG_MACHINE_MEM_CFG                  = %s", bsg_mem_cfg_p.name());
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
    ,.branch_trace_en_p(bsg_branch_trace_en_p)
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
  logic [axi_id_width_p-1:0] awid;
  logic [axi_addr_width_p-1:0] awaddr;
  logic [7:0] awlen;
  logic [2:0] awsize;
  logic [1:0] awburst;
  logic [3:0] awcache;
  logic [2:0] awprot;
  logic awlock;
  logic awvalid;
  logic awready;

  logic [axi_data_width_p-1:0] wdata;
  logic [axi_strb_width_lp-1:0] wstrb;
  logic wlast;
  logic wvalid;
  logic wready;

  logic [axi_id_width_p-1:0] bid;
  logic [1:0] bresp;
  logic bvalid;
  logic bready;

  logic [axi_id_width_p-1:0] arid;
  logic [axi_addr_width_p-1:0] araddr;
  logic [7:0] arlen;
  logic [2:0] arsize;
  logic [1:0] arburst;
  logic [3:0] arcache;
  logic [2:0] arprot;
  logic arlock;
  logic arvalid;
  logic arready;

  logic [axi_id_width_p-1:0] rid;
  logic [axi_data_width_p-1:0] rdata;
  logic [1:0] rresp;
  logic rlast;
  logic rvalid;
  logic rready;


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
  ) memsys (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.link_sif_i(ver_link_lo[S])
    ,.link_sif_o(ver_link_li[S])

    ,.axi_awid_o(awid)
    ,.axi_awaddr_o(awaddr)
    ,.axi_awlen_o(awlen)
    ,.axi_awsize_o(awsize)
    ,.axi_awburst_o(awburst)
    ,.axi_awcache_o(awcache)
    ,.axi_awprot_o(awprot)
    ,.axi_awlock_o(awlock)
    ,.axi_awvalid_o(awvalid)
    ,.axi_awready_i(awready)

    ,.axi_wdata_o(wdata)
    ,.axi_wstrb_o(wstrb)
    ,.axi_wlast_o(wlast)
    ,.axi_wvalid_o(wvalid)
    ,.axi_wready_i(wready)

    ,.axi_bid_i(bid)
    ,.axi_bresp_i(bresp)
    ,.axi_bvalid_i(bvalid)
    ,.axi_bready_o(bready)

    ,.axi_arid_o(arid)
    ,.axi_araddr_o(araddr)
    ,.axi_arlen_o(arlen)
    ,.axi_arsize_o(arsize)
    ,.axi_arburst_o(arburst)
    ,.axi_arcache_o(arcache)
    ,.axi_arprot_o(arprot)
    ,.axi_arlock_o(arlock)
    ,.axi_arvalid_o(arvalid)
    ,.axi_arready_i(arready)

    ,.axi_rid_i(rid)
    ,.axi_rdata_i(rdata)
    ,.axi_rresp_i(rresp)
    ,.axi_rlast_i(rlast)
    ,.axi_rvalid_i(rvalid)
    ,.axi_rready_o(rready)

  );


  bsg_manycore_axi_mem #(
    .axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)
    ,.mem_els_p(bsg_dram_size_p/(axi_data_width_p/data_width_p))
  ) axi_mem (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.axi_awid_i(awid)
    ,.axi_awaddr_i(awaddr)
    ,.axi_awvalid_i(awvalid)
    ,.axi_awready_o(awready)

    ,.axi_wdata_i(wdata)
    ,.axi_wstrb_i(wstrb)
    ,.axi_wlast_i(wlast)
    ,.axi_wvalid_i(wvalid)
    ,.axi_wready_o(wready)

    ,.axi_bid_o(bid)
    ,.axi_bresp_o(bresp)
    ,.axi_bvalid_o(bvalid)
    ,.axi_bready_i(bready)

    ,.axi_arid_i(arid)
    ,.axi_araddr_i(araddr)
    ,.axi_arvalid_i(arvalid)
    ,.axi_arready_o(arready)

    ,.axi_rid_o(rid)
    ,.axi_rdata_o(rdata)
    ,.axi_rresp_o(rresp)
    ,.axi_rlast_o(rlast)
    ,.axi_rvalid_o(rvalid)
    ,.axi_rready_i(rready)
  );


  // synopsys translate_off
  always_ff @ (negedge clk) begin
    if (~reset) begin
      if (bsg_dram_included_p == 0) begin
        assert(awvalid !== 1'b1) else
          $error("[BSG_ERROR][TESTBENCH] DRAM write detected in no DRAM mode!!!");
        assert(arvalid !== 1'b1) else
          $error("[BSG_ERROR][TESTBENCH] DRAM read detected in no DRAM mode!!!");
      end
    end
  end
  // synopsys translate_on

 
  // vanilla core tracer
  //
  int status;
  int trace_arg;
  logic trace_en;

  initial begin
    status = $value$plusargs("vanilla_trace_en=%d", trace_arg);
    assign trace_en = (trace_arg == 1);
  end

  bind vanilla_core vanilla_core_trace #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
  ) vtrace (
    .*
    ,.trace_en_i($root.spmd_testbench.trace_en)
  );

  bind vanilla_core instr_trace #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) itrace(
    .*
    ,.trace_en_i($root.spmd_testbench.trace_en)
  );

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
    ,.dmem_size_p(dmem_size_p)
  ) vcore_prof (
    .*
    ,.global_ctr_i($root.spmd_testbench.global_ctr)
    ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
    ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
  );

  if (bsg_mem_cfg_p == e_mem_cfg_default) begin
  
    bind bsg_cache vcache_profiler #(
      .data_width_p(data_width_p)
    ) vcache_prof (
      .*
      ,.global_ctr_i($root.spmd_testbench.global_ctr)
      ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
      ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
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
      ,.trace_en_i($root.spmd_testbench.trace_en)
    );

  end
  else if (bsg_mem_cfg_p == e_mem_cfg_infinite) begin
    bind bsg_nonsynth_mem_infinite infinite_mem_profiler #(
      .data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) infinite_mem_prof (
      .*
      ,.global_ctr_i($root.spmd_testbench.global_ctr)
      ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
      ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
    );
  end

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


