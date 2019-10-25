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
  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_max_epa_width_p = `BSG_MACHINE_MAX_EPA_WIDTH;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
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
  parameter x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p);
  parameter y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p + extra_io_rows_p);

  parameter vcache_size_p = vcache_sets_p * vcache_ways_p * vcache_block_size_in_words_p;
  parameter dram_ch_addr_width_p = `BSG_SAFE_CLOG2(bsg_dram_size_p)-x_cord_width_lp; // virtual bank addr width (in word)
  parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3);
  parameter cache_addr_width_lp=(bsg_max_epa_width_p-1+byte_offset_width_lp);


  // print machine settings
  initial begin
    $display("MACHINE SETTINGS:");
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X                 = %d", num_tiles_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_Y                 = %d", num_tiles_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_SET               = %d", vcache_sets_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_WAY               = %d", vcache_ways_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS  = %d", vcache_block_size_in_words_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_SIZE_WORDS          = %d", bsg_dram_size_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_DRAM_INCLUDED            = %d", bsg_dram_included_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MAX_EPA_WIDTH            = %d", bsg_max_epa_width_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MEM_CFG                  = %s", bsg_manycore_mem_cfg_p.name());
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


  // bsg_manycore has 3 flops that reset signal needs to go through.
  // So we are trying to match that here.
  logic [2:0] reset_r;

  always_ff @ (posedge clk) begin
    reset_r[0] <= reset;
    reset_r[1] <= reset_r[0];
    reset_r[2] <= reset_r[1];
  end


  // instantiate manycore
  //
  `declare_bsg_manycore_link_sif_s(bsg_max_epa_width_p,data_width_p,
    x_cord_width_lp,y_cord_width_lp,load_id_width_p);

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
    ,.load_id_width_p(load_id_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
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

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
  ) io (
    .clk_i(clk)
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
    .clk_i(clk)
    ,.reset_i(reset_r[2])
    ,.ctr_r_o(global_ctr)
  );


  //                              //
  // Configurable Memory System   //
  //                              //

  // LEVEL 1
  if (bsg_manycore_mem_cfg_p == e_infinite_mem) begin
    
    for (genvar i = 0; i < num_tiles_x_p; i++) begin
      bsg_nonsynth_mem_infinite #(
        .data_width_p(data_width_p)
        ,.addr_width_p(bsg_max_epa_width_p)
        ,.x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
        ,.load_id_width_p(load_id_width_p)
      ) mem_infty (
        .clk_i(clk)
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
  else if (bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem) begin: lv1_vcache

    import bsg_cache_pkg::*;
  
    `declare_bsg_cache_dma_pkt_s(cache_addr_width_lp);
    bsg_cache_dma_pkt_s [num_tiles_x_p-1:0] dma_pkt;
    logic [num_tiles_x_p-1:0] dma_pkt_v_lo;
    logic [num_tiles_x_p-1:0] dma_pkt_yumi_li;

    logic [num_tiles_x_p-1:0][data_width_p-1:0] dma_data_li;
    logic [num_tiles_x_p-1:0] dma_data_v_li;
    logic [num_tiles_x_p-1:0] dma_data_ready_lo;

    logic [num_tiles_x_p-1:0][data_width_p-1:0] dma_data_lo;
    logic [num_tiles_x_p-1:0] dma_data_v_lo;
    logic [num_tiles_x_p-1:0] dma_data_yumi_li;

    for (genvar i = 0; i < num_tiles_x_p; i++) begin

      bsg_manycore_vcache_blocking #(
        .data_width_p(data_width_p)
        ,.addr_width_p(bsg_max_epa_width_p)
        ,.block_size_in_words_p(vcache_block_size_in_words_p)
        ,.sets_p(vcache_sets_p)
        ,.ways_p(vcache_ways_p)
    
        ,.x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
        ,.load_id_width_p(load_id_width_p)
      ) vcache (
        .clk_i(clk)
        ,.reset_i(reset_r[1])

        ,.link_sif_i(ver_link_lo[S][i])
        ,.link_sif_o(ver_link_li[S][i])

        ,.my_x_i((x_cord_width_lp)'(i))
        ,.my_y_i((y_cord_width_lp)'(num_tiles_y_p))
  
        ,.dma_pkt_o(dma_pkt[i])
        ,.dma_pkt_v_o(dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_i(dma_pkt_yumi_li[i])

        ,.dma_data_i(dma_data_li[i])
        ,.dma_data_v_i(dma_data_v_li[i])
        ,.dma_data_ready_o(dma_data_ready_lo[i])

        ,.dma_data_o(dma_data_lo[i])
        ,.dma_data_v_o(dma_data_v_lo[i])
        ,.dma_data_yumi_i(dma_data_yumi_li[i])
     );
      
    end
  
    bind bsg_cache vcache_profiler #(
      .data_width_p(data_width_p)
    ) vcache_prof (
      .*
      ,.global_ctr_i($root.spmd_testbench.global_ctr)
      ,.print_stat_v_i($root.spmd_testbench.print_stat_v)
      ,.print_stat_tag_i($root.spmd_testbench.print_stat_tag)
    );

  end

  // LEVEL 2
  //
  if (bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem) begin: lv2_axi4

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
      .clk_i(clk)
      ,.reset_i(reset_r[2])

      ,.dma_pkt_i(lv1_vcache.dma_pkt)
      ,.dma_pkt_v_i(lv1_vcache.dma_pkt_v_lo)
      ,.dma_pkt_yumi_o(lv1_vcache.dma_pkt_yumi_li)

      ,.dma_data_o(lv1_vcache.dma_data_li)
      ,.dma_data_v_o(lv1_vcache.dma_data_v_li)
      ,.dma_data_ready_i(lv1_vcache.dma_data_ready_lo)

      ,.dma_data_i(lv1_vcache.dma_data_lo)
      ,.dma_data_v_i(lv1_vcache.dma_data_v_lo)
      ,.dma_data_yumi_o(lv1_vcache.dma_data_yumi_li)

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


  // LEVEL 3
  //
  if (bsg_manycore_mem_cfg_p == e_vcache_blocking_axi4_nonsynth_mem) begin

    bsg_nonsynth_manycore_axi_mem #(
      .axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
      ,.mem_els_p(bsg_dram_size_p/(axi_data_width_p/data_width_p))
      ,.bsg_dram_included_p(bsg_dram_included_p)
    ) axi_mem (
      .clk_i(clk)
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
  for (genvar i = 0; i < num_tiles_y_p; i++) begin

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_w (
      .clk_i(clk)
      ,.reset_i(reset_r[2])
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
      ,.reset_i(reset_r[2])
      ,.link_sif_i(hor_link_lo[E][i])
      ,.link_sif_o(hor_link_li[E][i])
    );
  end

  for (genvar i = 0; i < num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_n (
      .clk_i(clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(ver_link_lo[N][i])
      ,.link_sif_o(ver_link_li[N][i])
    );
  end

  for (genvar i = 1; i < num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_io (
      .clk_i(clk)
      ,.reset_i(reset_r[2])
      ,.link_sif_i(io_link_lo[i])
      ,.link_sif_o(io_link_li[i])
    );
  end


endmodule


