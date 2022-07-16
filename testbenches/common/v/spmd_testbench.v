/**
 *    spmd_testbench.v
 *
 */ 


module spmd_testbench();
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}

  parameter num_pods_x_p  = `BSG_MACHINE_PODS_X;
  parameter num_pods_y_p  = `BSG_MACHINE_PODS_Y;
  parameter num_tiles_x_p = `BSG_MACHINE_GLOBAL_X;
  parameter num_tiles_y_p = `BSG_MACHINE_GLOBAL_Y;
  parameter x_cord_width_p = 7;
  parameter y_cord_width_p = 7;
  parameter pod_x_cord_width_p = 3;
  parameter pod_y_cord_width_p = 4;
  parameter num_subarray_x_p = `BSG_MACHINE_SUBARRAY_X;
  parameter num_subarray_y_p = `BSG_MACHINE_SUBARRAY_Y;
  parameter data_width_p = 32;
  parameter addr_width_p = `BSG_MACHINE_MAX_EPA_WIDTH; // word addr
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;
  parameter ruche_factor_X_p    = `BSG_MACHINE_RUCHE_FACTOR_X;

  parameter num_vcache_rows_p = `BSG_MACHINE_NUM_VCACHE_ROWS;
  parameter vcache_data_width_p = data_width_p;
  parameter vcache_sets_p = `BSG_MACHINE_VCACHE_SET;
  parameter vcache_ways_p = `BSG_MACHINE_VCACHE_WAY;
  parameter vcache_block_size_in_words_p = `BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS; // in words
  parameter vcache_dma_data_width_p = `BSG_MACHINE_VCACHE_DMA_DATA_WIDTH; // in bits
  parameter vcache_size_p = vcache_sets_p*vcache_ways_p*vcache_block_size_in_words_p;
  parameter vcache_addr_width_p=(addr_width_p-1+`BSG_SAFE_CLOG2(data_width_p>>3));  // in bytes
  parameter num_vcaches_per_channel_p = `BSG_MACHINE_NUM_VCACHES_PER_CHANNEL;  


  parameter wh_flit_width_p = vcache_dma_data_width_p;
  parameter wh_ruche_factor_p = 2;
  parameter wh_cid_width_p = `BSG_SAFE_CLOG2(2*wh_ruche_factor_p); // no concentration in this testbench; cid is ignored.
  parameter wh_len_width_p = `BSG_SAFE_CLOG2(1+(vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)); // header + addr + data
  parameter wh_cord_width_p = x_cord_width_p;

  parameter bsg_dram_size_p = `BSG_MACHINE_DRAM_SIZE_WORDS; // in words
  parameter bsg_dram_included_p = `BSG_MACHINE_DRAM_INCLUDED;
  parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = `BSG_MACHINE_MEM_CFG;
  parameter reset_depth_p = 3;

  parameter axi_id_width_p   = 1;
  parameter axi_addr_width_p = 34;
  parameter axi_data_width_p = 256;
  parameter axi_burst_len_p  = 1;
  parameter axi_sel_width_p = 4;
  parameter dma_addr_width_p = axi_addr_width_p - axi_sel_width_p;

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

  wire mig_clk = core_clk;
  wire mig_reset = global_reset;



    wire [7:0][axi_addr_width_p-1:0]mem_axi_araddr;
    wire [7:0][1:0]mem_axi_arburst;
    wire [7:0][3:0]mem_axi_arcache;
    wire [7:0][axi_id_width_p-1:0]mem_axi_arid;
    wire [7:0][7:0]mem_axi_arlen;
    wire [7:0][0:0]mem_axi_arlock;
    wire [7:0][2:0]mem_axi_arprot;
    wire [7:0][3:0]mem_axi_arqos;
    wire [7:0]mem_axi_arready;
    wire [7:0][3:0]mem_axi_arregion;
    wire [7:0][2:0]mem_axi_arsize;
    wire [7:0]mem_axi_arvalid;

    wire [7:0][axi_addr_width_p-1:0]mem_axi_awaddr;
    wire [7:0][1:0]mem_axi_awburst;
    wire [7:0][3:0]mem_axi_awcache;
    wire [7:0][axi_id_width_p-1:0]mem_axi_awid;
    wire [7:0][7:0]mem_axi_awlen;
    wire [7:0][0:0]mem_axi_awlock;
    wire [7:0][2:0]mem_axi_awprot;
    wire [7:0][3:0]mem_axi_awqos;
    wire [7:0]mem_axi_awready;
    wire [7:0][3:0]mem_axi_awregion;
    wire [7:0][2:0]mem_axi_awsize;
    wire [7:0]mem_axi_awvalid;

    wire [7:0][axi_id_width_p-1:0]mem_axi_bid;
    wire [7:0]mem_axi_bready;
    wire [7:0][1:0]mem_axi_bresp;
    wire [7:0]mem_axi_bvalid;

    wire [7:0][axi_data_width_p-1:0]mem_axi_rdata;
    wire [7:0][axi_id_width_p-1:0]mem_axi_rid;
    wire [7:0]mem_axi_rlast;
    wire [7:0]mem_axi_rready;
    wire [7:0][1:0]mem_axi_rresp;
    wire [7:0]mem_axi_rvalid;

    wire [7:0][axi_data_width_p-1:0]mem_axi_wdata;
    wire [7:0]mem_axi_wlast;
    wire [7:0]mem_axi_wready;
    wire [7:0][(axi_data_width_p>>3)-1:0]mem_axi_wstrb;
    wire [7:0]mem_axi_wvalid;

    wire [7:0][axi_addr_width_p-1:0]mem_axi_araddr_sel;
    wire [7:0][axi_addr_width_p-1:0]mem_axi_awaddr_sel;

    for (genvar i = 0; i < 8; i++)
      begin
        assign mem_axi_araddr_sel[i] = {(axi_sel_width_p)'(i), mem_axi_araddr[i][dma_addr_width_p-1:0]};
        assign mem_axi_awaddr_sel[i] = {(axi_sel_width_p)'(i), mem_axi_awaddr[i][dma_addr_width_p-1:0]};
      end

  ////                        ////
  ////      Fake Memory       ////
  ////                        ////

    for (genvar i = 0; i < 8; i++) begin: fk_mem

              bsg_nonsynth_manycore_axi_mem
             #(.axi_id_width_p     (axi_id_width_p)
              ,.axi_addr_width_p   (axi_addr_width_p)
              ,.axi_data_width_p   (axi_data_width_p)
              ,.axi_burst_len_p    (axi_burst_len_p)
              //,.mem_els_p          (mem_size_lp/(axi_data_width_p/8))
              ,.mem_els_p(2**29)
              ,.bsg_dram_included_p(1)
              ) axi_mem
              (.clk_i  (mig_clk)
              ,.reset_i(mig_reset)

              ,.axi_awid_i   (mem_axi_awid   [i])
              ,.axi_awaddr_i (mem_axi_awaddr_sel[i])
              ,.axi_awvalid_i(mem_axi_awvalid[i])
              ,.axi_awready_o(mem_axi_awready[i])

              ,.axi_wdata_i  (mem_axi_wdata  [i])
              ,.axi_wstrb_i  (mem_axi_wstrb  [i])
              ,.axi_wlast_i  (mem_axi_wlast  [i])
              ,.axi_wvalid_i (mem_axi_wvalid [i])
              ,.axi_wready_o (mem_axi_wready [i])

              ,.axi_bid_o    (mem_axi_bid    [i])
              ,.axi_bresp_o  (mem_axi_bresp  [i])
              ,.axi_bvalid_o (mem_axi_bvalid [i])
              ,.axi_bready_i (mem_axi_bready [i])

              ,.axi_arid_i   (mem_axi_arid   [i])
              ,.axi_araddr_i (mem_axi_araddr_sel[i])
              ,.axi_arvalid_i(mem_axi_arvalid[i])
              ,.axi_arready_o(mem_axi_arready[i])

              ,.axi_rid_o    (mem_axi_rid    [i])
              ,.axi_rdata_o  (mem_axi_rdata  [i])
              ,.axi_rresp_o  (mem_axi_rresp  [i])
              ,.axi_rlast_o  (mem_axi_rlast  [i])
              ,.axi_rvalid_o (mem_axi_rvalid [i])
              ,.axi_rready_i (mem_axi_rready [i])
              );

    end




  // testbench
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

    ,.num_subarray_x_p(num_subarray_x_p)
    ,.num_subarray_y_p(num_subarray_y_p)

    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_addr_width_p(vcache_addr_width_p)
    ,.num_vcaches_per_channel_p(num_vcaches_per_channel_p)

    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_ruche_factor_p(wh_ruche_factor_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)

    ,.bsg_dram_size_p(bsg_dram_size_p)

    ,.reset_depth_p(reset_depth_p)

`ifdef BSG_ENABLE_PROFILING
    ,.enable_vcore_profiling_p(1)
    ,.enable_router_profiling_p(1)
    ,.enable_cache_profiling_p(1)
`endif				    

    ,.host_x_cord_p(`BSG_MACHINE_HOST_X_CORD)
    ,.host_y_cord_p(`BSG_MACHINE_HOST_Y_CORD)

    ,.axi_id_width_p  (axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p (axi_burst_len_p)
  ) tb (
    .clk_i(core_clk)
    ,.reset_i(global_reset)

    ,.tag_done_o(tag_done_lo)

    ,.mem_axi_araddr  (mem_axi_araddr  )
    ,.mem_axi_arburst (mem_axi_arburst )
    ,.mem_axi_arcache (mem_axi_arcache )
    ,.mem_axi_arid    (mem_axi_arid    )
    ,.mem_axi_arlen   (mem_axi_arlen   )
    ,.mem_axi_arlock  (mem_axi_arlock  )
    ,.mem_axi_arprot  (mem_axi_arprot  )
    ,.mem_axi_arqos   (mem_axi_arqos   )
    ,.mem_axi_arready (mem_axi_arready )
    ,.mem_axi_arregion(mem_axi_arregion)
    ,.mem_axi_arsize  (mem_axi_arsize  )
    ,.mem_axi_arvalid (mem_axi_arvalid )

    ,.mem_axi_awaddr  (mem_axi_awaddr  )
    ,.mem_axi_awburst (mem_axi_awburst )
    ,.mem_axi_awcache (mem_axi_awcache )
    ,.mem_axi_awid    (mem_axi_awid    )
    ,.mem_axi_awlen   (mem_axi_awlen   )
    ,.mem_axi_awlock  (mem_axi_awlock  )
    ,.mem_axi_awprot  (mem_axi_awprot  )
    ,.mem_axi_awqos   (mem_axi_awqos   )
    ,.mem_axi_awready (mem_axi_awready )
    ,.mem_axi_awregion(mem_axi_awregion)
    ,.mem_axi_awsize  (mem_axi_awsize  )
    ,.mem_axi_awvalid (mem_axi_awvalid )

    ,.mem_axi_bid     (mem_axi_bid     )
    ,.mem_axi_bready  (mem_axi_bready  )
    ,.mem_axi_bresp   (mem_axi_bresp   )
    ,.mem_axi_bvalid  (mem_axi_bvalid  )

    ,.mem_axi_rdata   (mem_axi_rdata   )
    ,.mem_axi_rid     (mem_axi_rid     )
    ,.mem_axi_rlast   (mem_axi_rlast   )
    ,.mem_axi_rready  (mem_axi_rready  )
    ,.mem_axi_rresp   (mem_axi_rresp   )
    ,.mem_axi_rvalid  (mem_axi_rvalid  )

    ,.mem_axi_wdata   (mem_axi_wdata   )
    ,.mem_axi_wlast   (mem_axi_wlast   )
    ,.mem_axi_wready  (mem_axi_wready  )
    ,.mem_axi_wstrb   (mem_axi_wstrb   )
    ,.mem_axi_wvalid  (mem_axi_wvalid  )
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




  // reset dff


  // trace enable
  int status;
  int trace_arg;
  logic trace_en;
  initial begin
    status = $value$plusargs("vanilla_trace_en=%d", trace_arg);
    assign trace_en = (trace_arg == 1);
  end

  // global counter
  logic [31:0] global_ctr;
  bsg_cycle_counter global_cc (
    .clk_i(core_clk)
    ,.reset_i(reset_r)
    ,.ctr_r_o(global_ctr)
  );


endmodule
