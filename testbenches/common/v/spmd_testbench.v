/**
 *  spmd_testbench.v
 *
 */

module spmd_testbench;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;

  // defines from VCS
  // rename it to something more familiar.
  parameter num_tiles_x_p = `BSG_MACHINE_GLOBAL_X;
  parameter num_tiles_y_p = `BSG_MACHINE_GLOBAL_Y;
  parameter vcache_sets_p = `BSG_MACHINE_VCACHE_SET;
  parameter vcache_ways_p = `BSG_MACHINE_VCACHE_WAY;
  parameter vcache_block_size_in_words_p = `BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS; // in words
  parameter vcache_dma_data_width_p = `BSG_MACHINE_VCACHE_DMA_DATA_WIDTH; // in bits
  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_max_epa_width_p = `BSG_MACHINE_MAX_EPA_WIDTH;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter bsg_branch_trace_en_p = `BSG_MACHINE_BRANCH_TRACE_EN;
  parameter vcache_miss_fifo_els_p = `BSG_MACHINE_VCACHE_MISS_FIFO_ELS;

  // constant params
  parameter data_width_p = 32;
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;

  parameter axi_id_width_p = 6;
  parameter axi_addr_width_p = 64;
  parameter axi_data_width_p = 256;
  parameter axi_burst_len_p = 1;

  // dmc param
  parameter dram_ctrl_addr_width_p = 29; // 512 MB

  // dramsim3 HBM2 param
  `define dram_pkg bsg_dramsim3_hbm2_8gb_x128_pkg
  parameter hbm2_data_width_p = `dram_pkg::data_width_p;
  parameter hbm2_channel_addr_width_p = `dram_pkg::channel_addr_width_p;
  parameter hbm2_num_channels_p = `dram_pkg::num_channels_p;

  // derived param
  parameter axi_strb_width_lp = (axi_data_width_p>>3);
  parameter x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p);
  parameter y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p + 2);

  parameter vcache_size_p = vcache_sets_p * vcache_ways_p * vcache_block_size_in_words_p;
  parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3);
  parameter cache_addr_width_lp=(bsg_max_epa_width_p-1+byte_offset_width_lp);
  parameter data_mask_width_lp=(data_width_p>>3);

  parameter cache_bank_addr_width_lp = `BSG_SAFE_CLOG2(bsg_dram_size_p/(2*num_tiles_x_p)*4);

  // print machine settings
  initial begin
    $display("MACHINE SETTINGS:");
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X                 = %d", num_tiles_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_Y                 = %d", num_tiles_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_SET               = %d", vcache_sets_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_WAY               = %d", vcache_ways_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS  = %d", vcache_block_size_in_words_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_MISS_FIFO_ELS     = %d", vcache_miss_fifo_els_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_SIZE_WORDS          = %d", bsg_dram_size_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_INCLUDED            = %d", bsg_dram_included_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MAX_EPA_WIDTH            = %d", bsg_max_epa_width_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MEM_CFG                  = %s", bsg_manycore_mem_cfg_p.name());
  end


  // clock and reset generation
  //
  parameter core_clk_period_p = 1000; // 1000 ps == 1 GHz

  bit core_clk;
  bit reset;

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
    ,.async_reset_o(reset)
  );


  // bsg_manycore has 3 flops that reset signal needs to go through.
  // So we are trying to match that here.
  logic [2:0] reset_r;

  always_ff @ (posedge core_clk) begin
    reset_r[0] <= reset;
    reset_r[1] <= reset_r[0];
    reset_r[2] <= reset_r[1];
  end


  // instantiate manycore
  //
  `declare_bsg_manycore_link_sif_s(bsg_max_epa_width_p,data_width_p,
    x_cord_width_lp,y_cord_width_lp);

  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] ver_link_li, ver_link_lo;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_p-1:0] hor_link_li, hor_link_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_li, io_link_lo;

  bsg_manycore #(
    .dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(bsg_max_epa_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.branch_trace_en_p(bsg_branch_trace_en_p)
  ) DUT (
    .clk_i(core_clk)
    ,.reset_i(reset)

    ,.hor_link_sif_i(hor_link_li)
    ,.hor_link_sif_o(hor_link_lo)

    ,.ver_link_sif_i(ver_link_li)
    ,.ver_link_sif_o(ver_link_lo)

    ,.io_link_sif_i(io_link_li)
    ,.io_link_sif_o(io_link_lo)
  );


  // instantiate the loader and moniter
  // connects to P-port of (x,y)=(0,1)
  logic print_stat_v;
  logic [data_width_p-1:0] print_stat_tag;

  bsg_nonsynth_manycore_io_complex #(
    .addr_width_p(bsg_max_epa_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
  ) io (
    .clk_i(core_clk)
    ,.reset_i(reset_r[2])
    ,.io_link_sif_i(io_link_lo[0])
    ,.io_link_sif_o(io_link_li[0])
    ,.print_stat_v_o(print_stat_v)
    ,.print_stat_tag_o(print_stat_tag)
    ,.loader_done_o()
  );


  // global counter
  //
  logic [31:0] global_ctr;

  bsg_cycle_counter global_cc (
    .clk_i(core_clk)
    ,.reset_i(reset_r[2])
    ,.ctr_r_o(global_ctr)
  );


  //                              //
  // Configurable Memory System   //
  //                              //
  if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem)
      |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_axi4_nonsynth_mem)
      |(bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr)
      |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr)
      |(bsg_manycore_mem_cfg_p == e_vcache_blocking_dramsim3_hbm2)
      ) begin: lv1_dma

    // for now blocking and non-blocking shares the same wire, since interface is
    // the same. But it might change in the future.
    import bsg_cache_pkg::*;
    localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(cache_addr_width_lp);

    logic [S:N][num_tiles_x_p-1:0][dma_pkt_width_lp-1:0] dma_pkt;
    logic [S:N][num_tiles_x_p-1:0] dma_pkt_v_lo;
    logic [S:N][num_tiles_x_p-1:0] dma_pkt_yumi_li;

    logic [S:N][num_tiles_x_p-1:0][vcache_dma_data_width_p-1:0] dma_data_li;
    logic [S:N][num_tiles_x_p-1:0] dma_data_v_li;
    logic [S:N][num_tiles_x_p-1:0] dma_data_ready_lo;

    logic [S:N][num_tiles_x_p-1:0][vcache_dma_data_width_p-1:0] dma_data_lo;
    logic [S:N][num_tiles_x_p-1:0] dma_data_v_lo;
    logic [S:N][num_tiles_x_p-1:0] dma_data_yumi_li;

  end

  // LEVEL 1
  if (bsg_manycore_mem_cfg_p == e_infinite_mem) begin: lv1_infty

    for (genvar j = N; j <= S; j++) begin: y
      for (genvar i = 0; i < num_tiles_x_p; i++) begin: x
        bsg_nonsynth_mem_infinite #(
          .data_width_p(data_width_p)
          ,.addr_width_p(bsg_max_epa_width_p)
          ,.x_cord_width_p(x_cord_width_lp)
          ,.y_cord_width_p(y_cord_width_lp)
        ) mem_infty (
          .clk_i(core_clk)
          ,.reset_i(reset_r[2])

          ,.link_sif_i(ver_link_lo[j][i])
          ,.link_sif_o(ver_link_li[j][i])
        
          ,.my_x_i((x_cord_width_lp)'(i))
          ,.my_y_i((y_cord_width_lp)'(0))
        );
      end
    end
    
    
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
  else if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem)
          |(bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr)
          |(bsg_manycore_mem_cfg_p == e_vcache_blocking_dramsim3_hbm2)
          ) begin: lv1_vcache

    for (genvar j = N; j <= S; j++) begin: y
      for (genvar i = 0; i < num_tiles_x_p; i++) begin: x
        bsg_manycore_vcache_blocking #(
          .data_width_p(data_width_p)
          ,.addr_width_p(bsg_max_epa_width_p)
          ,.block_size_in_words_p(vcache_block_size_in_words_p)
          ,.sets_p(vcache_sets_p)
          ,.ways_p(vcache_ways_p)
          ,.dma_data_width_p(vcache_dma_data_width_p)
          ,.x_cord_width_p(x_cord_width_lp)
          ,.y_cord_width_p(y_cord_width_lp)
        ) vcache (
          .clk_i(core_clk)
          ,.reset_i(reset_r[1])

          ,.link_sif_i(ver_link_lo[j][i])
          ,.link_sif_o(ver_link_li[j][i])
  
          ,.dma_pkt_o(lv1_dma.dma_pkt[j][i])
          ,.dma_pkt_v_o(lv1_dma.dma_pkt_v_lo[j][i])
          ,.dma_pkt_yumi_i(lv1_dma.dma_pkt_yumi_li[j][i])

          ,.dma_data_i(lv1_dma.dma_data_li[j][i])
          ,.dma_data_v_i(lv1_dma.dma_data_v_li[j][i])
          ,.dma_data_ready_o(lv1_dma.dma_data_ready_lo[j][i])

          ,.dma_data_o(lv1_dma.dma_data_lo[j][i])
          ,.dma_data_v_o(lv1_dma.dma_data_v_lo[j][i])
          ,.dma_data_yumi_i(lv1_dma.dma_data_yumi_li[j][i])
        );
      end
    end

    bind bsg_cache vcache_profiler #(
      .data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
      ,.header_print_p("y[3].x[0]")
    ) vcache_prof (
      .*
      ,.global_ctr_i($root.spmd_testbench.global_ctr)
      ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
      ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
    );

  end
  else if ((bsg_manycore_mem_cfg_p == e_vcache_non_blocking_axi4_nonsynth_mem)
          |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr)) begin: lv1_vcache_nb

    for (genvar j = N; j <= S; j++) begin: y
      for (genvar i = 0; i < num_tiles_x_p; i++) begin: x
        bsg_manycore_vcache_non_blocking #(
          .data_width_p(data_width_p)
          ,.addr_width_p(bsg_max_epa_width_p)
          ,.block_size_in_words_p(vcache_block_size_in_words_p)
          ,.sets_p(vcache_sets_p)
          ,.ways_p(vcache_ways_p)
          ,.miss_fifo_els_p(vcache_miss_fifo_els_p)
          ,.x_cord_width_p(x_cord_width_lp)
          ,.y_cord_width_p(y_cord_width_lp)
        ) vcache (
          .clk_i(core_clk)
          ,.reset_i(reset_r[1])

          ,.link_sif_i(ver_link_lo[j][i])
          ,.link_sif_o(ver_link_li[j][i])

          ,.dma_pkt_o(lv1_dma.dma_pkt[j][i])
          ,.dma_pkt_v_o(lv1_dma.dma_pkt_v_lo[j][i])
          ,.dma_pkt_yumi_i(lv1_dma.dma_pkt_yumi_li[j][i])

          ,.dma_data_i(lv1_dma.dma_data_li[j][i])
          ,.dma_data_v_i(lv1_dma.dma_data_v_li[j][i])
          ,.dma_data_ready_o(lv1_dma.dma_data_ready_lo[j][i])

          ,.dma_data_o(lv1_dma.dma_data_lo[j][i])
          ,.dma_data_v_o(lv1_dma.dma_data_v_lo[j][i])
          ,.dma_data_yumi_i(lv1_dma.dma_data_yumi_li[j][i])
        );
      end
    end

    bind bsg_cache_non_blocking vcache_non_blocking_profiler #(
      .data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
      ,.id_width_p(id_width_p)
      ,.block_size_in_words_p(block_size_in_words_p)
      ,.header_print_p("y[3].x[0]")
    ) vcache_prof (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.tl_data_mem_pkt_i(tl_data_mem_pkt_lo)
      ,.tl_data_mem_pkt_v_i(tl_data_mem_pkt_v_lo)
      ,.tl_data_mem_pkt_ready_i(tl_data_mem_pkt_ready_li)

      ,.mhu_idle_i(mhu_idle)

      ,.mhu_data_mem_pkt_i(mhu_data_mem_pkt_lo)
      ,.mhu_data_mem_pkt_v_i(mhu_data_mem_pkt_v_lo)
      ,.mhu_data_mem_pkt_yumi_i(mhu_data_mem_pkt_yumi_li)

      ,.miss_fifo_data_i(miss_fifo_data_li)
      ,.miss_fifo_v_i(miss_fifo_v_li)
      ,.miss_fifo_ready_i(miss_fifo_ready_lo)

      ,.dma_pkt_i(dma_pkt_o)
      ,.dma_pkt_v_i(dma_pkt_v_o)
      ,.dma_pkt_yumi_i(dma_pkt_yumi_i)

      ,.global_ctr_i($root.spmd_testbench.global_ctr)
      ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
      ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
    );
  end

  
  // LEVEL 2
  //
  if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem)
      |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_axi4_nonsynth_mem)) begin: lv2_axi4

    logic [S:N][axi_id_width_p-1:0] axi_awid;
    logic [S:N][axi_addr_width_p-1:0] axi_awaddr;
    logic [S:N][7:0] axi_awlen;
    logic [S:N][2:0] axi_awsize;
    logic [S:N][1:0] axi_awburst;
    logic [S:N][3:0] axi_awcache;
    logic [S:N][2:0] axi_awprot;
    logic [S:N] axi_awlock;
    logic [S:N] axi_awvalid;
    logic [S:N] axi_awready;

    logic [S:N][axi_data_width_p-1:0] axi_wdata;
    logic [S:N][axi_strb_width_lp-1:0] axi_wstrb;
    logic [S:N] axi_wlast;
    logic [S:N] axi_wvalid;
    logic [S:N] axi_wready;

    logic [S:N][axi_id_width_p-1:0] axi_bid;
    logic [S:N][1:0] axi_bresp;
    logic [S:N] axi_bvalid;
    logic [S:N] axi_bready;

    logic [S:N][axi_id_width_p-1:0] axi_arid;
    logic [S:N][axi_addr_width_p-1:0] axi_araddr;
    logic [S:N][7:0] axi_arlen;
    logic [S:N][2:0] axi_arsize;
    logic [S:N][1:0] axi_arburst;
    logic [S:N][3:0] axi_arcache;
    logic [S:N][2:0] axi_arprot;
    logic [S:N] axi_arlock;
    logic [S:N] axi_arvalid;
    logic [S:N] axi_arready;

    logic [S:N][axi_id_width_p-1:0] axi_rid;
    logic [S:N][axi_data_width_p-1:0] axi_rdata;
    logic [S:N][1:0] axi_rresp;
    logic [S:N] axi_rlast;
    logic [S:N] axi_rvalid;
    logic [S:N] axi_rready;

    for (genvar i = N; i <= S; i++) begin
      // bsg_cache_to_axi_hashed does not support dma_data_width_p yet.
      // For this configuration, we just expect dma_data_width_p to be 32.
      bsg_cache_to_axi_hashed #(
        .addr_width_p(cache_addr_width_lp)
        ,.block_size_in_words_p(vcache_block_size_in_words_p)
        ,.data_width_p(data_width_p)
        ,.num_cache_p(num_tiles_x_p)

        ,.axi_id_width_p(axi_id_width_p)
        ,.axi_addr_width_p(axi_addr_width_p)
        ,.axi_data_width_p(axi_data_width_p)
        ,.axi_burst_len_p(axi_burst_len_p)
      ) cache_to_axi0 (
        .clk_i(core_clk)
        ,.reset_i(reset_r[2])

        ,.dma_pkt_i(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_i(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_o(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_o(lv1_dma.dma_data_li[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_i(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_i(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_o(lv1_dma.dma_data_yumi_li[i])

        ,.axi_awid_o(axi_awid[i])
        ,.axi_awaddr_o(axi_awaddr[i])
        ,.axi_awlen_o(axi_awlen[i])
        ,.axi_awsize_o(axi_awsize[i])
        ,.axi_awburst_o(axi_awburst[i])
        ,.axi_awcache_o(axi_awcache[i])
        ,.axi_awprot_o(axi_awprot[i])
        ,.axi_awlock_o(axi_awlock[i])
        ,.axi_awvalid_o(axi_awvalid[i])
        ,.axi_awready_i(axi_awready[i])

        ,.axi_wdata_o(axi_wdata[i])
        ,.axi_wstrb_o(axi_wstrb[i])
        ,.axi_wlast_o(axi_wlast[i])
        ,.axi_wvalid_o(axi_wvalid[i])
        ,.axi_wready_i(axi_wready[i])

        ,.axi_bid_i(axi_bid[i])
        ,.axi_bresp_i(axi_bresp[i])
        ,.axi_bvalid_i(axi_bvalid[i])
        ,.axi_bready_o(axi_bready[i])

        ,.axi_arid_o(axi_arid[i])
        ,.axi_araddr_o(axi_araddr[i])
        ,.axi_arlen_o(axi_arlen[i])
        ,.axi_arsize_o(axi_arsize[i])
        ,.axi_arburst_o(axi_arburst[i])
        ,.axi_arcache_o(axi_arcache[i])
        ,.axi_arprot_o(axi_arprot[i])
        ,.axi_arlock_o(axi_arlock[i])
        ,.axi_arvalid_o(axi_arvalid[i])
        ,.axi_arready_i(axi_arready[i])

        ,.axi_rid_i(axi_rid[i])
        ,.axi_rdata_i(axi_rdata[i])
        ,.axi_rresp_i(axi_rresp[i])
        ,.axi_rlast_i(axi_rlast[i])
        ,.axi_rvalid_i(axi_rvalid[i])
        ,.axi_rready_o(axi_rready[i])
      );
    end
  end
  else if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr)
          |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr)) begin: lv2_dmc

    logic [S:N] app_en;
    logic [S:N] app_rdy;
    logic [S:N][2:0] app_cmd;
    logic [S:N][dram_ctrl_addr_width_p-1:0] app_addr;

    logic [S:N] app_wdf_wren;
    logic [S:N] app_wdf_rdy;
    logic [S:N][data_width_p-1:0] app_wdf_data;
    logic [S:N][data_mask_width_lp-1:0] app_wdf_mask;
    logic [S:N] app_wdf_end;

    logic [S:N] app_rd_data_valid;
    logic [S:N][data_width_p-1:0] app_rd_data;
    logic [S:N] app_rd_data_end;

    for (genvar i = N; i <= S; i++) begin: cache_to_dmc
      bsg_cache_to_dram_ctrl #(
        .num_cache_p(num_tiles_x_p)
        ,.addr_width_p(cache_addr_width_lp)
        ,.data_width_p(data_width_p)
        ,.block_size_in_words_p(vcache_block_size_in_words_p)
        ,.dram_ctrl_burst_len_p(vcache_block_size_in_words_p)
        ,.dram_ctrl_addr_width_p(dram_ctrl_addr_width_p)
      ) cache_to_dram_ctrl (
        .clk_i(core_clk)
        ,.reset_i(reset_r[2])

        ,.dram_size_i(3'b100) // 4Gb
    
        ,.dma_pkt_i(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_i(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_o(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_o(lv1_dma.dma_data_li[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_i(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_i(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_o(lv1_dma.dma_data_yumi_li[i])

        ,.app_en_o(app_en[i])
        ,.app_rdy_i(app_rdy[i])
        ,.app_cmd_o(app_cmd[i])
        ,.app_addr_o(app_addr[i])
  
        ,.app_wdf_wren_o(app_wdf_wren[i])
        ,.app_wdf_rdy_i(app_wdf_rdy[i])
        ,.app_wdf_data_o(app_wdf_data[i])
        ,.app_wdf_mask_o(app_wdf_mask[i])
        ,.app_wdf_end_o(app_wdf_end[i])

        ,.app_rd_data_valid_i(app_rd_data_valid[i])
        ,.app_rd_data_i(app_rd_data[i])
        ,.app_rd_data_end_i(app_rd_data_end[i])
      );
    end
  end
  else if (bsg_manycore_mem_cfg_p == e_vcache_blocking_dramsim3_hbm2) begin: lv2_hbm2

    
    typedef struct packed {
      logic [1:0] bg;
      logic [1:0] ba;
      logic [14:0] ro;
      logic [5:0] co;
      logic [4:0] byte_offset;
    } dram_ch_addr_s; 
  
    logic [S:N] dram_req_v_lo;
    logic [S:N] dram_write_not_read_lo;
    dram_ch_addr_s [S:N] dram_ch_addr_lo;
    logic [S:N] dram_req_yumi_li;

    logic [S:N] dram_data_v_lo;
    logic [S:N][hbm2_data_width_p-1:0] dram_data_lo;
    logic [S:N] dram_data_yumi_li;
    
    logic [S:N] dram_data_v_li;
    logic [S:N][hbm2_data_width_p-1:0] dram_data_li;
    dram_ch_addr_s [S:N] dram_ch_addr_li;
    
 
    for (genvar i = N; i <= S; i++) begin
      bsg_cache_to_test_dram #(
        .num_cache_p(num_tiles_x_p)
        ,.addr_width_p(cache_addr_width_lp)
        ,.data_width_p(data_width_p)
        ,.block_size_in_words_p(vcache_block_size_in_words_p)
        ,.cache_bank_addr_width_p(cache_bank_addr_width_lp)
        ,.dma_data_width_p(vcache_dma_data_width_p)

        ,.dram_channel_addr_width_p(hbm2_channel_addr_width_p)
        ,.dram_data_width_p(hbm2_data_width_p)
      ) cache_to_test_dram0 (
        .core_clk_i(core_clk)
        ,.core_reset_i(reset_r[2])
      
        ,.dma_pkt_i(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_i(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_o(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_o(lv1_dma.dma_data_li[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_i(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_i(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_o(lv1_dma.dma_data_yumi_li[i])

        ,.dram_clk_i(core_clk)
        ,.dram_reset_i(reset_r[2])
    
        ,.dram_req_v_o(dram_req_v_lo[i])
        ,.dram_write_not_read_o(dram_write_not_read_lo[i])
        ,.dram_ch_addr_o(dram_ch_addr_lo[i])
        ,.dram_req_yumi_i(dram_req_yumi_li[i])

        ,.dram_data_v_o(dram_data_v_lo[i])
        ,.dram_data_o(dram_data_lo[i])
        ,.dram_data_yumi_i(dram_data_yumi_li[i])

        ,.dram_data_v_i(dram_data_v_li[i])
        ,.dram_data_i(dram_data_li[i])
        ,.dram_ch_addr_i(dram_ch_addr_li[i])
      );    
    end
  end


  // LEVEL 3
  //
  if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem)
     |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_axi4_nonsynth_mem)) begin: lv3_axi_mem

    for (genvar i = N; i <= S; i++) begin
      bsg_nonsynth_manycore_axi_mem #(
        .axi_id_width_p(axi_id_width_p)
        ,.axi_addr_width_p(axi_addr_width_p)
        ,.axi_data_width_p(axi_data_width_p)
        ,.axi_burst_len_p(axi_burst_len_p)
        ,.mem_els_p(bsg_dram_size_p/(2*axi_data_width_p/data_width_p))
        ,.bsg_dram_included_p(bsg_dram_included_p)
      ) axi_mem0 (
        .clk_i(core_clk)
        ,.reset_i(reset_r[2])

        ,.axi_awid_i(lv2_axi4.axi_awid[i])
        ,.axi_awaddr_i(lv2_axi4.axi_awaddr[i])
        ,.axi_awvalid_i(lv2_axi4.axi_awvalid[i])
        ,.axi_awready_o(lv2_axi4.axi_awready[i])

        ,.axi_wdata_i(lv2_axi4.axi_wdata[i])
        ,.axi_wstrb_i(lv2_axi4.axi_wstrb[i])
        ,.axi_wlast_i(lv2_axi4.axi_wlast[i])
        ,.axi_wvalid_i(lv2_axi4.axi_wvalid[i])
        ,.axi_wready_o(lv2_axi4.axi_wready[i])

        ,.axi_bid_o(lv2_axi4.axi_bid[i])
        ,.axi_bresp_o(lv2_axi4.axi_bresp[i])
        ,.axi_bvalid_o(lv2_axi4.axi_bvalid[i])
        ,.axi_bready_i(lv2_axi4.axi_bready[i])

        ,.axi_arid_i(lv2_axi4.axi_arid[i])
        ,.axi_araddr_i(lv2_axi4.axi_araddr[i])
        ,.axi_arvalid_i(lv2_axi4.axi_arvalid[i])
        ,.axi_arready_o(lv2_axi4.axi_arready[i])

        ,.axi_rid_o(lv2_axi4.axi_rid[i])
        ,.axi_rdata_o(lv2_axi4.axi_rdata[i])
        ,.axi_rresp_o(lv2_axi4.axi_rresp[i])
        ,.axi_rlast_o(lv2_axi4.axi_rlast[i])
        ,.axi_rvalid_o(lv2_axi4.axi_rvalid[i])
        ,.axi_rready_i(lv2_axi4.axi_rready[i])
      );
    end
  end
  else if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr)
          |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr)) begin: lv3_dmc

    import bsg_dmc_pkg::*;

    bsg_dmc_s dmc_p;
    assign dmc_p.trefi = 16'd1023;
    assign dmc_p.tmrd = 4'd1;
    assign dmc_p.trfc = 4'd15;
    assign dmc_p.trc = 4'd10;
    assign dmc_p.trp = 4'd2;
    assign dmc_p.tras = 4'd7;
    assign dmc_p.trrd = 4'd1;
    assign dmc_p.trcd = 4'd2;
    assign dmc_p.twr = 4'd7;
    assign dmc_p.twtr = 4'd7;
    assign dmc_p.trtp = 4'd3;
    assign dmc_p.tcas = 4'd3;
    assign dmc_p.col_width = 4'd11;
    assign dmc_p.row_width = 4'd14;
    assign dmc_p.bank_width = 2'd2;
    assign dmc_p.dqs_sel_cal = 2'd3;
    assign dmc_p.init_cmd_cnt = 4'd5;

    localparam ui_addr_width_p = 27; // word address (512 MB)
    localparam ui_data_width_p = data_width_p;
    localparam burst_data_width_p = data_width_p * vcache_block_size_in_words_p;
    localparam dq_data_width_p = data_width_p;
    localparam dq_group_lp = dq_data_width_p >> 3;

    localparam dfi_clk_period_p = 5000;     // 200 MHz
    localparam dfi_clk_2x_period_p = 2500;  // 400 MHz

    bit dfi_clk;
    bit dfi_clk_2x;

    bsg_nonsynth_clock_gen #(
      .cycle_time_p(dfi_clk_period_p)
    ) dfi_cg (
      .o(dfi_clk)
    );
    
    bsg_nonsynth_clock_gen #(
      .cycle_time_p(dfi_clk_2x_period_p)
    ) dfi_2x_cg (
      .o(dfi_clk_2x)
    );

    wire [S:N] ddr_ck_p;
    wire [S:N] ddr_ck_n;
    wire [S:N] ddr_cke;
    wire [S:N] ddr_cs_n;
    wire [S:N] ddr_ras_n;
    wire [S:N] ddr_cas_n;
    wire [S:N] ddr_we_n;
    wire [S:N][2:0] ddr_ba;
    wire [S:N][15:0] ddr_addr;

    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dm_oen_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dm_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_p_oen_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_p_ien_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_p_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_p_li;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_n_oen_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_n_ien_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_n_lo;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_n_li;
    wire [S:N][dq_data_width_p-1:0] ddr_dq_oen_lo;
    wire [S:N][dq_data_width_p-1:0] ddr_dq_lo;
    wire [S:N][dq_data_width_p-1:0] ddr_dq_li;
  
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dm;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_p;
    wire [S:N][(dq_data_width_p>>3)-1:0] ddr_dqs_n;
    wire [S:N][dq_data_width_p-1:0] ddr_dq;
   
    for (genvar j = N; j <= S; j++) begin 
      bsg_dmc #(
        .ui_addr_width_p(ui_addr_width_p)
        ,.ui_data_width_p(ui_data_width_p)
        ,.burst_data_width_p(burst_data_width_p)
        ,.dq_data_width_p(dq_data_width_p)
      ) dmc (
        .dmc_p_i(dmc_p)
        ,.sys_rst_i(reset_r[2])

        ,.app_addr_i(lv2_dmc.app_addr[j][2+:ui_addr_width_p]) // word_address
        ,.app_cmd_i(lv2_dmc.app_cmd[j])
        ,.app_en_i(lv2_dmc.app_en[j])
        ,.app_rdy_o(lv2_dmc.app_rdy[j])

        ,.app_wdf_wren_i(lv2_dmc.app_wdf_wren[j])
        ,.app_wdf_data_i(lv2_dmc.app_wdf_data[j])
        ,.app_wdf_mask_i(lv2_dmc.app_wdf_mask[j])
        ,.app_wdf_end_i(lv2_dmc.app_wdf_end[j])
        ,.app_wdf_rdy_o(lv2_dmc.app_wdf_rdy[j])

        ,.app_rd_data_valid_o(lv2_dmc.app_rd_data_valid[j])
        ,.app_rd_data_o(lv2_dmc.app_rd_data[j])
        ,.app_rd_data_end_o(lv2_dmc.app_rd_data_end[j])

        ,.app_ref_req_i(1'b0)
        ,.app_ref_ack_o()
        ,.app_zq_req_i(1'b0)
        ,.app_zq_ack_o()
        ,.app_sr_req_i(1'b0)
        ,.app_sr_active_o()

        ,.init_calib_complete_o()

        ,.ddr_ck_p_o(ddr_ck_p[j])
        ,.ddr_ck_n_o(ddr_ck_n[j])
        ,.ddr_cke_o(ddr_cke[j])
        ,.ddr_ba_o(ddr_ba[j])
        ,.ddr_addr_o(ddr_addr[j])
        ,.ddr_cs_n_o(ddr_cs_n[j])
        ,.ddr_ras_n_o(ddr_ras_n[j])
        ,.ddr_cas_n_o(ddr_cas_n[j])
        ,.ddr_we_n_o(ddr_we_n[j])
        ,.ddr_reset_n_o()
        ,.ddr_odt_o()

        ,.ddr_dm_oen_o(ddr_dm_oen_lo[j])
        ,.ddr_dm_o(ddr_dm_lo[j])
        ,.ddr_dqs_p_oen_o(ddr_dqs_p_oen_lo[j])
        ,.ddr_dqs_p_ien_o(ddr_dqs_p_ien_lo[j])
        ,.ddr_dqs_p_o(ddr_dqs_p_lo[j])
        ,.ddr_dqs_p_i(ddr_dqs_p_li[j])

        ,.ddr_dqs_n_oen_o()
        ,.ddr_dqs_n_ien_o()
        ,.ddr_dqs_n_o()
        ,.ddr_dqs_n_i()

        ,.ddr_dq_oen_o(ddr_dq_oen_lo[j])
        ,.ddr_dq_o(ddr_dq_lo[j])
        ,.ddr_dq_i(ddr_dq_li[j])

        ,.ui_clk_i(core_clk)

        ,.dfi_clk_2x_i(~dfi_clk_2x) // invert this clk, so the posedge of 1x and 2x clk are aligned.
        ,.dfi_clk_i(dfi_clk)

        ,.ui_clk_sync_rst_o()
        ,.device_temp_o()
      );    

      for (genvar i = 0; i < 2; i++) begin
        mobile_ddr ddr_inst (
          .Dq(ddr_dq[j][16*i+:16])
          ,.Dqs(ddr_dqs_p[j][2*i+:2])
          ,.Addr(ddr_addr[j][13:0])
          ,.Ba(ddr_ba[j][1:0])
          ,.Clk(ddr_ck_p[j])
          ,.Clk_n(ddr_ck_n[j])
          ,.Cke(ddr_cke[j])
          ,.Cs_n(ddr_cs_n[j])
          ,.Ras_n(ddr_ras_n[j])
          ,.Cas_n(ddr_cas_n[j])
          ,.We_n(ddr_we_n[j])
          ,.Dm(ddr_dm[j][2*i+:2])
        );
      end

      for (genvar i = 0; i< dq_group_lp; i++) begin
        assign ddr_dm[j][i] = ddr_dm_oen_lo[j][i] ? 1'bz : ddr_dm_lo[j][i];
        assign ddr_dqs_p[j][i] = ddr_dqs_p_oen_lo[j][i] ? 1'bz : ddr_dqs_p_lo[j][i];
        assign ddr_dqs_p_li[j][i] = ddr_dqs_p_ien_lo[j][i] ? 1'b1 : ddr_dqs_p[j][i];
      end

      for (genvar i = 0; i < dq_data_width_p; i++) begin
        assign ddr_dq[j][i] = ddr_dq_oen_lo[j][i] ? 1'bz : ddr_dq_lo[j][i];
        assign ddr_dq_li[j][i] = ddr_dq[j][i];
      end
    end
  end
  else if (bsg_manycore_mem_cfg_p == e_vcache_blocking_dramsim3_hbm2) begin: lv3_hbm2

    typedef struct packed {
      logic [14:0] ro;
      logic [1:0] bg;
      logic [1:0] ba;
      logic [5:0] co;
      logic [4:0] byte_offset;
    } dram_ch_addr_rev_s;

    logic [hbm2_num_channels_p-1:0] dramsim3_v_li;
    logic [hbm2_num_channels_p-1:0] dramsim3_write_not_read_li;
    logic [hbm2_num_channels_p-1:0][hbm2_channel_addr_width_p-1:0] dramsim3_ch_addr_li;
    logic [hbm2_num_channels_p-1:0] dramsim3_yumi_lo;

    logic [hbm2_num_channels_p-1:0][hbm2_data_width_p-1:0] dramsim3_data_li;
    logic [hbm2_num_channels_p-1:0] dramsim3_data_v_li;
    logic [hbm2_num_channels_p-1:0] dramsim3_data_yumi_lo;

    logic [hbm2_num_channels_p-1:0][hbm2_data_width_p-1:0] dramsim3_data_lo;
    logic [hbm2_num_channels_p-1:0] dramsim3_data_v_lo;
    dram_ch_addr_rev_s [hbm2_num_channels_p-1:0] dramsim3_ch_addr_lo;
    
    bsg_nonsynth_dramsim3 #(
      .channel_addr_width_p(hbm2_channel_addr_width_p)
      ,.data_width_p(hbm2_data_width_p)
      ,.num_channels_p(hbm2_num_channels_p)
      ,.num_columns_p(`dram_pkg::num_columns_p)
      ,.address_mapping_p(`dram_pkg::address_mapping_p)
      ,.size_in_bits_p(`dram_pkg::size_in_bits_p)
      ,.config_p(`dram_pkg::config_p)
      ,.init_mem_p(1)
    ) hbm0 (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
    
      ,.v_i(dramsim3_v_li)
      ,.write_not_read_i(dramsim3_write_not_read_li)
      ,.ch_addr_i(dramsim3_ch_addr_li)
      ,.yumi_o(dramsim3_yumi_lo)

      ,.data_v_i(dramsim3_data_v_li)
      ,.data_i(dramsim3_data_li)
      ,.data_yumi_o(dramsim3_data_yumi_lo)

      ,.data_v_o(dramsim3_data_v_lo)
      ,.data_o(dramsim3_data_lo)
      ,.read_done_ch_addr_o(dramsim3_ch_addr_lo)

      ,.write_done_o()
      ,.write_done_ch_addr_o()
    );

    // north = channel0
    assign dramsim3_v_li[0] = lv2_hbm2.dram_req_v_lo[N];
    assign dramsim3_write_not_read_li[0] = lv2_hbm2.dram_write_not_read_lo[N];
    assign dramsim3_ch_addr_li[0] = {
      lv2_hbm2.dram_ch_addr_lo[N].ro,
      lv2_hbm2.dram_ch_addr_lo[N].bg,
      lv2_hbm2.dram_ch_addr_lo[N].ba,
      lv2_hbm2.dram_ch_addr_lo[N].co,
      lv2_hbm2.dram_ch_addr_lo[N].byte_offset
    };
    assign lv2_hbm2.dram_req_yumi_li[N] = dramsim3_yumi_lo[0];

    assign dramsim3_data_v_li[0] = lv2_hbm2.dram_data_v_lo[N];
    assign dramsim3_data_li[0] = lv2_hbm2.dram_data_lo[N];
    assign lv2_hbm2.dram_data_yumi_li[N] = dramsim3_data_yumi_lo[0];

    assign lv2_hbm2.dram_data_v_li[N] = dramsim3_data_v_lo[0];
    assign lv2_hbm2.dram_data_li[N] = dramsim3_data_lo[0];
    assign lv2_hbm2.dram_ch_addr_li[N] = {
      dramsim3_ch_addr_lo[0].bg,
      dramsim3_ch_addr_lo[0].ba,
      dramsim3_ch_addr_lo[0].ro,
      dramsim3_ch_addr_lo[0].co,
      dramsim3_ch_addr_lo[0].byte_offset
    };

    // south = channel1
    assign dramsim3_v_li[1] = lv2_hbm2.dram_req_v_lo[S];
    assign dramsim3_write_not_read_li[1] = lv2_hbm2.dram_write_not_read_lo[S];
    assign dramsim3_ch_addr_li[1] = {
      lv2_hbm2.dram_ch_addr_lo[S].ro,
      lv2_hbm2.dram_ch_addr_lo[S].bg,
      lv2_hbm2.dram_ch_addr_lo[S].ba,
      lv2_hbm2.dram_ch_addr_lo[S].co,
      lv2_hbm2.dram_ch_addr_lo[S].byte_offset
    };
    assign lv2_hbm2.dram_req_yumi_li[S] = dramsim3_yumi_lo[1];

    assign dramsim3_data_v_li[1] = lv2_hbm2.dram_data_v_lo[S];
    assign dramsim3_data_li[1] = lv2_hbm2.dram_data_lo[S];
    assign lv2_hbm2.dram_data_yumi_li[S] = dramsim3_data_yumi_lo[1];

    assign lv2_hbm2.dram_data_v_li[S] = dramsim3_data_v_lo[1];
    assign lv2_hbm2.dram_data_li[S] = dramsim3_data_lo[1];
    assign lv2_hbm2.dram_ch_addr_li[S] = {
      dramsim3_ch_addr_lo[1].bg,
      dramsim3_ch_addr_lo[1].ba,
      dramsim3_ch_addr_lo[1].ro,
      dramsim3_ch_addr_lo[1].co,
      dramsim3_ch_addr_lo[1].byte_offset
    };

  end

 
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
  bind vanilla_core vanilla_core_profiler #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.header_print_x_cord_p(0)
    ,.header_print_y_cord_p(2)
  ) vcore_prof (
    .*
    ,.global_ctr_i($root.spmd_testbench.global_ctr)
    ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
    ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
    ,.trace_en_i($root.spmd_testbench.trace_en)
  );

  // tieoffs
  //
  for (genvar i = 0; i < num_tiles_y_p; i++) begin: we_tieoff

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_w (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(hor_link_lo[W][i])
      ,.link_sif_o(hor_link_li[W][i])
    );

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_e (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(hor_link_lo[E][i])
      ,.link_sif_o(hor_link_li[E][i])
    );
  end

  for (genvar i = 1; i < num_tiles_x_p; i++) begin: io_tieoff
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_io (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(io_link_lo[i])
      ,.link_sif_o(io_link_li[i])
    );
  end

endmodule


