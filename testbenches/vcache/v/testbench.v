/**
 *  testbench.v
 */

module testbench();

  // parameters
  //
  parameter addr_width_p = 28;
  parameter data_width_p = 32;
  parameter num_tiles_x_p = 4;
  parameter num_tiles_y_p = 4;
  parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_tiles_x_p);
  parameter y_cord_width_p = `BSG_SAFE_CLOG2(num_tiles_y_p+2);
  parameter load_id_width_p = 11;
  parameter dmem_size_p = 1024;
  parameter icache_entries_p = 1024;
  parameter icache_tag_width_p = 12;
  parameter dram_ch_addr_width_p = 27;
  parameter epa_addr_width_p = 16;

  parameter num_cache_p = 4;
  parameter sets_p = 512;
  parameter ways_p = 2;
  parameter block_size_in_words_p = 8;

  parameter axi_id_width_p = 6;
  parameter axi_addr_width_p = 64;
  parameter axi_data_width_p = 256;
  parameter axi_strb_width_p = (axi_data_width_p>>3);
  parameter axi_burst_len_p = 1;
  parameter mem_els_p = 2**12;

  parameter spmd_max_out_credits_p = 128;
  parameter max_cycles_p = 1000000;
  parameter loader_x_cord_p = (x_cord_width_p)'(num_tiles_x_p-1);
  parameter loader_y_cord_p = (y_cord_width_p)'(num_tiles_y_p);

  // clock gen
  //
  logic clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(10)
  ) clock_gen (
    .o(clk)
  );

  // reset gen
  //
  logic reset;
  logic reset_r, reset_rr;

  bsg_nonsynth_reset_gen #(
    .reset_cycles_lo_p(0)
    ,.reset_cycles_hi_p(16)
  ) reset_gen (
    .clk_i(clk)
    ,.async_reset_o(reset)
  );

  always_ff @ (posedge clk) begin
    reset_r <= reset;
    reset_rr <= reset_r;
  end

  // manycore
  //
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  bsg_manycore_link_sif_s [num_cache_p-1:0] cache_link_sif_li;
  bsg_manycore_link_sif_s [num_cache_p-1:0] cache_link_sif_lo;
  logic [num_cache_p-1:0][x_cord_width_p-1:0] cache_x_lo;
  logic [num_cache_p-1:0][y_cord_width_p-1:0] cache_y_lo;
  bsg_manycore_link_sif_s loader_link_sif_li;
  bsg_manycore_link_sif_s loader_link_sif_lo;

  bsg_manycore_wrapper #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.epa_addr_width_p(epa_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.num_cache_p(num_cache_p)
  ) manycore (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.cache_link_sif_i(cache_link_sif_li)
    ,.cache_link_sif_o(cache_link_sif_lo)

    ,.cache_x_o(cache_x_lo)
    ,.cache_y_o(cache_y_lo)

    ,.loader_link_sif_i(loader_link_sif_li)
    ,.loader_link_sif_o(loader_link_sif_lo)
  );


  // vcache
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
  logic [axi_strb_width_p-1:0] wstrb;
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

  bsg_cache_wrapper_axi #(
    .num_cache_p(num_cache_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.block_size_in_words_p(block_size_in_words_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)

    ,.axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)

    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
  ) vcache_axi (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.my_x_i(cache_x_lo)
    ,.my_y_i(cache_y_lo)

    ,.link_sif_i(cache_link_sif_lo)
    ,.link_sif_o(cache_link_sif_li)

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

  mock_axi_mem #(
    .axi_id_width_p(axi_id_width_p)
    ,.axi_addr_width_p(axi_addr_width_p)
    ,.axi_data_width_p(axi_data_width_p)
    ,.axi_burst_len_p(axi_burst_len_p)
    ,.mem_els_p(mem_els_p)
  ) axi_mem (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.axi_awid_i(awid)
    ,.axi_awaddr_i(awaddr)
    ,.axi_awlen_i(awlen)
    ,.axi_awsize_i(awsize)
    ,.axi_awburst_i(awburst)
    ,.axi_awcache_i(awcache)
    ,.axi_awprot_i(awprot)
    ,.axi_awlock_i(awlock)
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
    ,.axi_arlen_i(arlen)
    ,.axi_arsize_i(arsize)
    ,.axi_arburst_i(arburst)
    ,.axi_arcache_i(arcache)
    ,.axi_arprot_i(arprot)
    ,.axi_arlock_i(arlock)
    ,.axi_arvalid_i(arvalid)
    ,.axi_arready_o(arready)

    ,.axi_rid_o(rid)
    ,.axi_rdata_o(rdata)
    ,.axi_rresp_o(rresp)
    ,.axi_rlast_o(rlast)
    ,.axi_rvalid_o(rvalid)
    ,.axi_rready_i(rready)
  );

  // manycore monitor
  //
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);

  logic [39:0] cycle_count;

  bsg_cycle_counter #(
    .width_p(40)
    ,.init_val_p(0)
  ) ccounter (
    .clk_i(clk)
    ,.reset_i(reset)
    ,.ctr_r_o(cycle_count)
  );

  bsg_manycore_packet_s loader_data_lo;
  logic loader_v_lo;
  logic loader_ready_li;

  logic pass_thru_v_li;
  logic pass_thru_ready_lo;

  logic [`BSG_SAFE_CLOG2(spmd_max_out_credits_p+1)-1:0] spmd_out_credits;

  logic finish_lo;
  logic success_lo;
  logic timeout_lo;
  
  bsg_nonsynth_manycore_monitor #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.channel_num_p(0)
    ,.max_cycles_p(max_cycles_p)
    ,.pass_thru_p(1)
    ,.pass_thru_max_out_credits_p(spmd_max_out_credits_p)
  ) monitor (
    .clk_i(clk)
    ,.reset_i(reset_rr)
    
    ,.link_sif_i(loader_link_sif_lo)
    ,.link_sif_o(loader_link_sif_li)

    ,.pass_thru_data_i(loader_data_lo)
    ,.pass_thru_v_i(pass_thru_v_li)
    ,.pass_thru_ready_o(pass_thru_ready_lo)
    ,.pass_thru_out_credits_o(spmd_out_credits)
    ,.pass_thru_x_i(loader_x_cord_p)
    ,.pass_thru_y_i(loader_y_cord_p)

    ,.cycle_count_i(cycle_count)
    ,.finish_o(finish_lo)
    ,.success_o(success_lo)
    ,.timeout_o(timeout_lo)
  );

  assign pass_thru_v_li = loader_v_lo & loader_ready_li;

  bsg_manycore_spmd_loader #(
    .icache_entries_num_p(icache_entries_p)
    ,.num_rows_p(num_tiles_y_p)
    ,.num_cols_p(num_tiles_x_p)
    ,.load_rows_p(num_tiles_y_p)
    ,.load_cols_p(num_tiles_x_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.epa_addr_width_p(epa_addr_width_p)
    ,.dram_ch_num_p(num_cache_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.init_vcache_p(0)
    ,.vcache_entries_p(sets_p)
    ,.vcache_ways_p(ways_p)
  ) spmd_loader (
    .clk_i(clk)
    ,.reset_i(reset_rr)
    
    ,.data_o(loader_data_lo)
    ,.v_o(loader_v_lo)
    ,.ready_i(loader_ready_li)

    ,.my_x_i(loader_x_cord_p)
    ,.my_y_i(loader_y_cord_p)
  );    

  assign loader_ready_li = pass_thru_ready_lo & (|spmd_out_credits);

endmodule
