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

  localparam int wh_cord_markers_pos_lp[1:0] = '{wh_cord_width_p, 0};


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
  wh_link_sif_s [S:N][E:P] rtr_wh_link_sif_li, rtr_wh_link_sif_lo;
  wh_link_sif_s concentrated_link_li, concentrated_link_lo;

  // inject coordinates;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_li;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_li;
  for (genvar i = 0; i < num_tiles_x_p; i++) begin
    assign global_x_li[i] = x_cord_width_p'(i); // Leftmost column, x=0;
    assign global_y_li[i] = y_cord_width_p'(2); // Io router y coordinate;
  end

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

    ,.global_x_i(global_x_li)
    ,.global_y_i(global_y_li)

    // stubbed ports;
    ,.mc_link_sif_i('0)
    ,.mc_link_sif_o()
    ,.mc_barrier_link_i('0)
    ,.mc_barrier_link_o()
    ,.svc_ver_link_i('0)
    ,.svc_ver_link_o()
    ,.global_x_o()
    ,.global_y_o()
    ,.hor_reset_o()
    ,.ver_reset_o()
  );


  // Wormhole memory banks;
  localparam longint unsigned mem_size_lp = (2**30); // size in bytes (1GB each)

  for (genvar i = N; i <= S; i++) begin

    assign rtr_wh_link_sif_li[i][W] = wh_link_sif_lo[i][E];
    assign wh_link_sif_li[i][E] = rtr_wh_link_sif_lo[i][W];

    bsg_wormhole_router #(
      .flit_width_p(wh_flit_width_p)
      ,.dims_p(1)
      ,.cord_markers_pos_p(wh_cord_markers_pos_lp)
      ,.len_width_p(wh_len_width_p)
    ) wh_rtr (
      .clk_i(core_clk)
      ,.reset_i(reset)

      ,.link_i(rtr_wh_link_sif_li[i])
      ,.link_o(rtr_wh_link_sif_lo[i])

      ,.my_cord_i({{wh_cord_width_p-1{1'b1}}, 1'b0})
    );

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

      ,.wh_link_sif_i(rtr_wh_link_sif_lo[i][E])
      ,.wh_link_sif_o(rtr_wh_link_sif_li[i][E])
    );

    // tieoff;
    assign wh_link_sif_li[i][W] = '0;
  end

  bsg_wormhole_concentrator #(
    .flit_width_p(wh_flit_width_p)
    ,.len_width_p(wh_len_width_p)
    ,.cid_width_p(1)
    ,.cord_width_p(wh_cord_width_p)
    ,.num_in_p(2)
  ) wh_ctr (
     .clk_i(core_clk)
    ,.reset_i(reset)

    ,.links_i({rtr_wh_link_sif_lo[S][P], rtr_wh_link_sif_lo[N][P]})
    ,.links_o({rtr_wh_link_sif_li[S][P], rtr_wh_link_sif_li[N][P]})

    ,.concentrated_link_i(concentrated_link_li)
    ,.concentrated_link_o(concentrated_link_lo)
  );


  bsg_nonsynth_wormhole_test_uncached_io #(
    .vcache_data_width_p(vcache_data_width_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.num_vcaches_p(num_tiles_x_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)
    ,.wh_len_width_p(wh_len_width_p)
    ,.mem_size_p((2**(32-1-`BSG_SAFE_CLOG2(num_tiles_x_p))))
    ,.no_concentration_p(0)
  ) test_io (
    .clk_i(core_clk)
    ,.reset_i(reset)

    ,.wh_link_sif_i(concentrated_link_lo)
    ,.wh_link_sif_o(concentrated_link_li)
  );


  // SPMD LOADER;
  // Convert REV IO->MC Credit-valid to make it compatible with bsg_manycore_endpoint_standard inside io complex;
  bsg_manycore_link_sif_s io_link_converted_lo, io_link_converted_li;
  // FWD MC -> IO;
  assign io_link_converted_lo.fwd.data = io_link_sif_lo[E].fwd.data;
  assign io_link_converted_lo.fwd.v    = io_link_sif_lo[E].fwd.v;
  assign io_link_sif_li[E].fwd.ready_and_rev = io_link_converted_li.fwd.ready_and_rev;

  // REV IO -> MC;
  logic fifo_yumi;
  bsg_fifo_1r1w_small #(
    .width_p(`bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p))
    ,.els_p(3)
  ) rev_fifo0 (
    .clk_i(core_clk)
    ,.reset_i(reset)

    ,.v_i(io_link_converted_li.rev.v)
    ,.data_i(io_link_converted_li.rev.data)
    ,.ready_param_o()
  
    ,.v_o(io_link_sif_li[E].rev.v)
    ,.data_o(io_link_sif_li[E].rev.data)
    ,.yumi_i(fifo_yumi)
  );
  assign fifo_yumi = io_link_sif_lo[E].rev.ready_and_rev & io_link_sif_li[E].rev.v;

  bsg_dff_reset #(
    .width_p(1)
    ,.reset_val_p(0)
  ) cr_dff0 (
    .clk_i(core_clk)
    ,.reset_i(reset)
    ,.data_i(fifo_yumi)
    ,.data_o(io_link_converted_lo.rev.ready_and_rev)
  );

  // FWD IO -> MC;
  assign io_link_sif_li[E].fwd.data = io_link_converted_li.fwd.data;
  assign io_link_sif_li[E].fwd.v    = io_link_converted_li.fwd.v;
  assign io_link_converted_lo.fwd.ready_and_rev = io_link_sif_lo[E].fwd.ready_and_rev;
  // REV MC -> IO;
  assign io_link_converted_lo.rev.data = io_link_sif_lo[E].rev.data;
  assign io_link_converted_lo.rev.v    = io_link_sif_lo[E].rev.v;
  assign io_link_sif_li[E].rev.ready_and_rev = io_link_converted_li.rev.ready_and_rev;


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
    ,.io_link_sif_i(io_link_converted_lo)
    ,.io_link_sif_o(io_link_converted_li)
    ,.print_stat_v_o()
    ,.print_stat_tag_o()
    ,.loader_done_o()
  );

  assign io_link_sif_li[W] = '0; // tieoff;



endmodule
