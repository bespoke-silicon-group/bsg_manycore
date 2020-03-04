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
  parameter extra_io_rows_p = 1;

  parameter data_width_p = 32;
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;
  parameter epa_byte_addr_width_p = 18;

  parameter axi_id_width_p = 6;
  parameter axi_addr_width_p = 64;
  parameter axi_data_width_p = 256;
  parameter axi_burst_len_p = 1;

  parameter dram_ctrl_burst_len_p = 1;
  parameter dram_ctrl_addr_width_p = 29; // 512 MB

  // derived param
  parameter axi_strb_width_lp = (axi_data_width_p>>3);
  parameter x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p);
  parameter y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p + extra_io_rows_p);

  parameter vcache_size_p = vcache_sets_p * vcache_ways_p * vcache_block_size_in_words_p;
  parameter dram_ch_addr_width_p = `BSG_SAFE_CLOG2(bsg_dram_size_p)-x_cord_width_lp; // virtual bank addr width (in word)
  parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3);
  parameter cache_addr_width_lp=(bsg_max_epa_width_p-1+byte_offset_width_lp);
  parameter data_mask_width_lp=(data_width_p>>3);


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
    ,.reset_cycles_hi_p(200)
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
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(bsg_max_epa_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
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
  // connects to (0,0)
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
      |(bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr4)
      |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr4)) begin: lv1_dma

    // for now blocking and non-blocking shares the same wire, since interface is
    // the same. But it might change in the future.
    import bsg_cache_pkg::*;
    localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(cache_addr_width_lp);

    logic [num_tiles_x_p-1:0][dma_pkt_width_lp-1:0] dma_pkt;
    logic [num_tiles_x_p-1:0] dma_pkt_v_lo;
    logic [num_tiles_x_p-1:0] dma_pkt_yumi_li;

    logic [num_tiles_x_p-1:0][data_width_p-1:0] dma_data_li;
    logic [num_tiles_x_p-1:0] dma_data_v_li;
    logic [num_tiles_x_p-1:0] dma_data_ready_lo;

    logic [num_tiles_x_p-1:0][data_width_p-1:0] dma_data_lo;
    logic [num_tiles_x_p-1:0] dma_data_v_lo;
    logic [num_tiles_x_p-1:0] dma_data_yumi_li;

  end


  // LEVEL 1
  if (bsg_manycore_mem_cfg_p == e_infinite_mem) begin
    
    for (genvar i = 0; i < num_tiles_x_p; i++) begin
      bsg_nonsynth_mem_infinite #(
        .data_width_p(data_width_p)
        ,.addr_width_p(bsg_max_epa_width_p)
        ,.x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
      ) mem_infty (
        .clk_i(core_clk)
        ,.reset_i(reset_r[2])

        ,.link_sif_i(ver_link_lo[S][i])
        ,.link_sif_o(ver_link_li[S][i])
        
        ,.my_x_i((x_cord_width_lp)'(i))
        ,.my_y_i((y_cord_width_lp)'(num_tiles_y_p))
      );
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
          |(bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr4)) begin: lv1_vcache


    for (genvar i = 0; i < num_tiles_x_p; i++) begin: vcache

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

        ,.link_sif_i(ver_link_lo[S][i])
        ,.link_sif_o(ver_link_li[S][i])
  
        ,.dma_pkt_o(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_o(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_i(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_i(lv1_dma.dma_data_li[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_o(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_o(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_i(lv1_dma.dma_data_yumi_li[i])
     );
      
    end
  
    bind bsg_cache vcache_profiler #(
      .data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
    ) vcache_prof (
      .*
      ,.global_ctr_i($root.spmd_testbench.global_ctr)
      ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
      ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
    );

  end
  else if ((bsg_manycore_mem_cfg_p == e_vcache_non_blocking_axi4_nonsynth_mem)
          |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr4)) begin: lv1_vcache_nb

    for (genvar i = 0; i < num_tiles_x_p; i++) begin: vcache

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

        ,.link_sif_i(ver_link_lo[S][i])
        ,.link_sif_o(ver_link_li[S][i])

        ,.dma_pkt_o(lv1_dma.dma_pkt[i])
        ,.dma_pkt_v_o(lv1_dma.dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_i(lv1_dma.dma_pkt_yumi_li[i])

        ,.dma_data_i(lv1_dma.dma_data_li[i])
        ,.dma_data_v_i(lv1_dma.dma_data_v_li[i])
        ,.dma_data_ready_o(lv1_dma.dma_data_ready_lo[i])

        ,.dma_data_o(lv1_dma.dma_data_lo[i])
        ,.dma_data_v_o(lv1_dma.dma_data_v_lo[i])
        ,.dma_data_yumi_i(lv1_dma.dma_data_yumi_li[i])
     );
      
    end

    bind bsg_cache_non_blocking vcache_non_blocking_profiler #(
      .data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
      ,.id_width_p(id_width_p)
      ,.block_size_in_words_p(block_size_in_words_p)
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

    logic [axi_id_width_p-1:0] axi_awid;
    logic [axi_addr_width_p-1:0] axi_awaddr;
    logic [7:0] axi_awlen;
    logic [2:0] axi_awsize;
    logic [1:0] axi_awburst;
    logic [3:0] axi_awcache;
    logic [2:0] axi_awprot;
    logic axi_awlock;
    logic axi_awvalid;
    logic axi_awready;

    logic [axi_data_width_p-1:0] axi_wdata;
    logic [axi_strb_width_lp-1:0] axi_wstrb;
    logic axi_wlast;
    logic axi_wvalid;
    logic axi_wready;

    logic [axi_id_width_p-1:0] axi_bid;
    logic [1:0] axi_bresp;
    logic axi_bvalid;
    logic axi_bready;

    logic [axi_id_width_p-1:0] axi_arid;
    logic [axi_addr_width_p-1:0] axi_araddr;
    logic [7:0] axi_arlen;
    logic [2:0] axi_arsize;
    logic [1:0] axi_arburst;
    logic [3:0] axi_arcache;
    logic [2:0] axi_arprot;
    logic axi_arlock;
    logic axi_arvalid;
    logic axi_arready;

    logic [axi_id_width_p-1:0] axi_rid;
    logic [axi_data_width_p-1:0] axi_rdata;
    logic [1:0] axi_rresp;
    logic axi_rlast;
    logic axi_rvalid;
    logic axi_rready;

    bsg_cache_to_axi_hashed #(
      .addr_width_p(cache_addr_width_lp)
      ,.block_size_in_words_p(vcache_block_size_in_words_p)
      ,.data_width_p(data_width_p)
      ,.num_cache_p(num_tiles_x_p)

      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
    ) cache_to_axi (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])

      ,.dma_pkt_i(lv1_dma.dma_pkt)
      ,.dma_pkt_v_i(lv1_dma.dma_pkt_v_lo)
      ,.dma_pkt_yumi_o(lv1_dma.dma_pkt_yumi_li)

      ,.dma_data_o(lv1_dma.dma_data_li)
      ,.dma_data_v_o(lv1_dma.dma_data_v_li)
      ,.dma_data_ready_i(lv1_dma.dma_data_ready_lo)

      ,.dma_data_i(lv1_dma.dma_data_lo)
      ,.dma_data_v_i(lv1_dma.dma_data_v_lo)
      ,.dma_data_yumi_o(lv1_dma.dma_data_yumi_li)

      ,.axi_awid_o(axi_awid)
      ,.axi_awaddr_o(axi_awaddr)
      ,.axi_awlen_o(axi_awlen)
      ,.axi_awsize_o(axi_awsize)
      ,.axi_awburst_o(axi_awburst)
      ,.axi_awcache_o(axi_awcache)
      ,.axi_awprot_o(axi_awprot)
      ,.axi_awlock_o(axi_awlock)
      ,.axi_awvalid_o(axi_awvalid)
      ,.axi_awready_i(axi_awready)

      ,.axi_wdata_o(axi_wdata)
      ,.axi_wstrb_o(axi_wstrb)
      ,.axi_wlast_o(axi_wlast)
      ,.axi_wvalid_o(axi_wvalid)
      ,.axi_wready_i(axi_wready)

      ,.axi_bid_i(axi_bid)
      ,.axi_bresp_i(axi_bresp)
      ,.axi_bvalid_i(axi_bvalid)
      ,.axi_bready_o(axi_bready)

      ,.axi_arid_o(axi_arid)
      ,.axi_araddr_o(axi_araddr)
      ,.axi_arlen_o(axi_arlen)
      ,.axi_arsize_o(axi_arsize)
      ,.axi_arburst_o(axi_arburst)
      ,.axi_arcache_o(axi_arcache)
      ,.axi_arprot_o(axi_arprot)
      ,.axi_arlock_o(axi_arlock)
      ,.axi_arvalid_o(axi_arvalid)
      ,.axi_arready_i(axi_arready)

      ,.axi_rid_i(axi_rid)
      ,.axi_rdata_i(axi_rdata)
      ,.axi_rresp_i(axi_rresp)
      ,.axi_rlast_i(axi_rlast)
      ,.axi_rvalid_i(axi_rvalid)
      ,.axi_rready_o(axi_rready)
    );

  end
  else if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr4)
          |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr4)) begin: lv2_dmc

  
    logic app_en;
    logic app_rdy;
    logic [2:0] app_cmd;
    logic [dram_ctrl_addr_width_p-1:0] app_addr;

    logic app_wdf_wren;
    logic app_wdf_rdy;
    logic [data_width_p-1:0] app_wdf_data;
    logic [data_mask_width_lp-1:0] app_wdf_mask;
    logic app_wdf_end;

    logic app_rd_data_valid;
    logic [data_width_p-1:0] app_rd_data;
    logic app_rd_data_end;

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
    
      ,.dma_pkt_i(lv1_dma.dma_pkt)
      ,.dma_pkt_v_i(lv1_dma.dma_pkt_v_lo)
      ,.dma_pkt_yumi_o(lv1_dma.dma_pkt_yumi_li)

      ,.dma_data_o(lv1_dma.dma_data_li)
      ,.dma_data_v_o(lv1_dma.dma_data_v_li)
      ,.dma_data_ready_i(lv1_dma.dma_data_ready_lo)

      ,.dma_data_i(lv1_dma.dma_data_lo)
      ,.dma_data_v_i(lv1_dma.dma_data_v_lo)
      ,.dma_data_yumi_o(lv1_dma.dma_data_yumi_li)

      ,.app_en_o(app_en)
      ,.app_rdy_i(app_rdy)
      ,.app_cmd_o(app_cmd)
      ,.app_addr_o(app_addr)
  
      ,.app_wdf_wren_o(app_wdf_wren)
      ,.app_wdf_rdy_i(app_wdf_rdy)
      ,.app_wdf_data_o(app_wdf_data)
      ,.app_wdf_mask_o(app_wdf_mask)
      ,.app_wdf_end_o(app_wdf_end)

      ,.app_rd_data_valid_i(app_rd_data_valid)
      ,.app_rd_data_i(app_rd_data)
      ,.app_rd_data_end_i(app_rd_data_end)
    );

  end


  // LEVEL 3
  //
  if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem)
     |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_axi4_nonsynth_mem)) begin

    bsg_nonsynth_manycore_axi_mem #(
      .axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
      ,.mem_els_p(bsg_dram_size_p/(axi_data_width_p/data_width_p))
      ,.bsg_dram_included_p(bsg_dram_included_p)
    ) axi_mem (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])

      ,.axi_awid_i(lv2_axi4.axi_awid)
      ,.axi_awaddr_i(lv2_axi4.axi_awaddr)
      ,.axi_awvalid_i(lv2_axi4.axi_awvalid)
      ,.axi_awready_o(lv2_axi4.axi_awready)

      ,.axi_wdata_i(lv2_axi4.axi_wdata)
      ,.axi_wstrb_i(lv2_axi4.axi_wstrb)
      ,.axi_wlast_i(lv2_axi4.axi_wlast)
      ,.axi_wvalid_i(lv2_axi4.axi_wvalid)
      ,.axi_wready_o(lv2_axi4.axi_wready)

      ,.axi_bid_o(lv2_axi4.axi_bid)
      ,.axi_bresp_o(lv2_axi4.axi_bresp)
      ,.axi_bvalid_o(lv2_axi4.axi_bvalid)
      ,.axi_bready_i(lv2_axi4.axi_bready)

      ,.axi_arid_i(lv2_axi4.axi_arid)
      ,.axi_araddr_i(lv2_axi4.axi_araddr)
      ,.axi_arvalid_i(lv2_axi4.axi_arvalid)
      ,.axi_arready_o(lv2_axi4.axi_arready)

      ,.axi_rid_o(lv2_axi4.axi_rid)
      ,.axi_rdata_o(lv2_axi4.axi_rdata)
      ,.axi_rresp_o(lv2_axi4.axi_rresp)
      ,.axi_rlast_o(lv2_axi4.axi_rlast)
      ,.axi_rvalid_o(lv2_axi4.axi_rvalid)
      ,.axi_rready_i(lv2_axi4.axi_rready)
    );
    
  end
  else if ((bsg_manycore_mem_cfg_p == e_vcache_blocking_dmc_lpddr4)
          |(bsg_manycore_mem_cfg_p == e_vcache_non_blocking_dmc_lpddr4)) begin

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

    logic dfi_clk;
    logic dfi_clk_2x;

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

    wire ddr_ck_p;
    wire ddr_ck_n;
    wire ddr_cke;
    wire ddr_cs_n;
    wire ddr_ras_n;
    wire ddr_cas_n;
    wire ddr_we_n;
    wire [2:0] ddr_ba;
    wire [15:0] ddr_addr;

    wire [(dq_data_width_p>>3)-1:0] ddr_dm_oen_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dm_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_p_oen_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_p_ien_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_p_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_p_li;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_n_oen_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_n_ien_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_n_lo;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_n_li;
    wire [dq_data_width_p-1:0] ddr_dq_oen_lo;
    wire [dq_data_width_p-1:0] ddr_dq_lo;
    wire [dq_data_width_p-1:0] ddr_dq_li;
  
    wire [(dq_data_width_p>>3)-1:0] ddr_dm;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_p;
    wire [(dq_data_width_p>>3)-1:0] ddr_dqs_n;
    wire [dq_data_width_p-1:0] ddr_dq;
    
    bsg_dmc #(
      .ui_addr_width_p(ui_addr_width_p)
      ,.ui_data_width_p(ui_data_width_p)
      ,.burst_data_width_p(burst_data_width_p)
      ,.dq_data_width_p(dq_data_width_p)
    ) dmc (
      .dmc_p_i(dmc_p)
      ,.sys_rst_i(reset_r[2])

      ,.app_addr_i(lv2_dmc.app_addr[2+:ui_addr_width_p]) // word_address
      ,.app_cmd_i(lv2_dmc.app_cmd)
      ,.app_en_i(lv2_dmc.app_en)
      ,.app_rdy_o(lv2_dmc.app_rdy)

      ,.app_wdf_wren_i(lv2_dmc.app_wdf_wren)
      ,.app_wdf_data_i(lv2_dmc.app_wdf_data)
      ,.app_wdf_mask_i(lv2_dmc.app_wdf_mask)
      ,.app_wdf_end_i(lv2_dmc.app_wdf_end)
      ,.app_wdf_rdy_o(lv2_dmc.app_wdf_rdy)

      ,.app_rd_data_valid_o(lv2_dmc.app_rd_data_valid)
      ,.app_rd_data_o(lv2_dmc.app_rd_data)
      ,.app_rd_data_end_o(lv2_dmc.app_rd_data_end)

      ,.app_ref_req_i(1'b0)
      ,.app_ref_ack_o()
      ,.app_zq_req_i(1'b0)
      ,.app_zq_ack_o()
      ,.app_sr_req_i(1'b0)
      ,.app_sr_active_o()

      ,.init_calib_complete_o()

      ,.ddr_ck_p_o(ddr_ck_p)
      ,.ddr_ck_n_o(ddr_ck_n)
      ,.ddr_cke_o(ddr_cke)
      ,.ddr_ba_o(ddr_ba)
      ,.ddr_addr_o(ddr_addr)
      ,.ddr_cs_n_o(ddr_cs_n)
      ,.ddr_ras_n_o(ddr_ras_n)
      ,.ddr_cas_n_o(ddr_cas_n)
      ,.ddr_we_n_o(ddr_we_n)
      ,.ddr_reset_n_o()
      ,.ddr_odt_o()

      ,.ddr_dm_oen_o(ddr_dm_oen_lo)
      ,.ddr_dm_o(ddr_dm_lo)
      ,.ddr_dqs_p_oen_o(ddr_dqs_p_oen_lo)
      ,.ddr_dqs_p_ien_o(ddr_dqs_p_ien_lo)
      ,.ddr_dqs_p_o(ddr_dqs_p_lo)
      ,.ddr_dqs_p_i(ddr_dqs_p_li)

      ,.ddr_dqs_n_oen_o()
      ,.ddr_dqs_n_ien_o()
      ,.ddr_dqs_n_o()
      ,.ddr_dqs_n_i()

      ,.ddr_dq_oen_o(ddr_dq_oen_lo)
      ,.ddr_dq_o(ddr_dq_lo)
      ,.ddr_dq_i(ddr_dq_li)

      ,.ui_clk_i(core_clk)

      ,.dfi_clk_2x_i(~dfi_clk_2x) // invert this clk, so the posedge of 1x and 2x clk are aligned.
      ,.dfi_clk_i(dfi_clk)

      ,.ui_clk_sync_rst_o()
      ,.device_temp_o()
    );    

    `define den2048Mb
    `define sg5
    `define x16
    `define FULL_MEM

    for (genvar i = 0; i < 2; i++) begin
      mobile_ddr ddr_inst (
        .Dq(ddr_dq[16*i+:16])
        ,.Dqs(ddr_dqs_p[2*i+:2])
        ,.Addr(ddr_addr[13:0])
        ,.Ba(ddr_ba[1:0])
        ,.Clk(ddr_ck_p)
        ,.Clk_n(ddr_ck_n)
        ,.Cke(ddr_cke)
        ,.Cs_n(ddr_cs_n)
        ,.Ras_n(ddr_ras_n)
        ,.Cas_n(ddr_cas_n)
        ,.We_n(ddr_we_n)
        ,.Dm(ddr_dm[2*i+:2])
      );
    end

    for (genvar i = 0; i< dq_group_lp; i++) begin
      assign ddr_dm[i] = ddr_dm_oen_lo[i] ? 1'bz : ddr_dm_lo[i];
      assign ddr_dqs_p[i] = ddr_dqs_p_oen_lo[i] ? 1'bz : ddr_dqs_p_lo[i];
      assign ddr_dqs_p_li[i] = ddr_dqs_p_ien_lo[i] ? 1'b1 : ddr_dqs_p[i];
    end

    for (genvar i = 0; i < dq_data_width_p; i++) begin
      assign ddr_dq[i] = ddr_dq_oen_lo[i] ? 1'bz : ddr_dq_lo[i];
      assign ddr_dq_li[i] = ddr_dq[i];
    end

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

  for (genvar i = 0; i < num_tiles_x_p; i++) begin: n_tieoff
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_n (
      .clk_i(core_clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(ver_link_lo[N][i])
      ,.link_sif_o(ver_link_li[N][i])
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


