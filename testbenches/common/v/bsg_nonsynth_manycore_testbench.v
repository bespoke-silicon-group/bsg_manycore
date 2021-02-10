/**
 *    bsg_nonsynth_manycore_testbench.v
 *
 */


module bsg_nonsynth_manycore_testbench
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_manycore_mem_cfg_pkg::*;
  #(parameter num_pods_x_p  = "inv"
    , parameter num_pods_y_p  = "inv"
    , parameter num_tiles_x_p = "inv"
    , parameter num_tiles_y_p = "inv"
    , parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"
    , parameter pod_x_cord_width_p = "inv"
    , parameter pod_y_cord_width_p = "inv"
    , parameter addr_width_p = "inv"
    , parameter data_width_p = "inv"
    , parameter dmem_size_p = "inv"
    , parameter icache_entries_p = "inv"
    , parameter icache_tag_width_p = "inv"
    , parameter ruche_factor_X_p  = "inv"

    , parameter vcache_data_width_p = "inv"
    , parameter vcache_sets_p = "inv"
    , parameter vcache_ways_p = "inv"
    , parameter vcache_block_size_in_words_p = "inv" // in words
    , parameter vcache_dma_data_width_p = "inv" // in bits
    , parameter vcache_size_p = "inv" // in words
    , parameter vcache_addr_width_p="inv" // byte addr

    , parameter wh_flit_width_p = "inv"
    , parameter wh_ruche_factor_p = 2
    , parameter wh_cid_width_p = "inv"
    , parameter wh_len_width_p = "inv"
    , parameter wh_cord_width_p = "inv"

    , parameter bsg_manycore_mem_cfg_e bsg_manycore_mem_cfg_p = e_vcache_test_mem
    , parameter bsg_dram_size_p ="inv" // in word
    , parameter reset_depth_p = 3

    , parameter enable_vcore_profiling_p=0
    , parameter enable_router_profiling_p=0
    , parameter enable_cache_profiling_p=0

    , parameter cache_bank_addr_width_lp = `BSG_SAFE_CLOG2(bsg_dram_size_p/(2*num_tiles_x_p)*4) // byte addr
    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    // This is used to define heterogeneous arrays. Each index defines
    // the type of an X/Y coordinate in the array. This is a vector of
    // num_tiles_x_p*num_tiles_y_p ints; type "0" is the
    // default. See bsg_manycore_hetero_socket.v for more types.
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}
  )
  (
    input clk_i
    , input reset_i

    , output tag_done_o
    
    , input  [link_sif_width_lp-1:0] io_link_sif_i
    , output [link_sif_width_lp-1:0] io_link_sif_o
  );


  // print machine settings
  initial begin
    $display("MACHINE SETTINGS:");
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X                 = %d", num_tiles_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_Y                 = %d", num_tiles_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_SET               = %d", vcache_sets_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_WAY               = %d", vcache_ways_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS  = %d", vcache_block_size_in_words_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MAX_EPA_WIDTH            = %d", addr_width_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_MEM_CFG                  = %s", bsg_manycore_mem_cfg_p.name());
    $display("[INFO][TESTBENCH] BSG_MACHINE_RUCHE_FACTOR_X           = %d", ruche_factor_X_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_ORIGIN_X_CORD            = %d", `BSG_MACHINE_ORIGIN_X_CORD);
    $display("[INFO][TESTBENCH] BSG_MACHINE_ORIGIN_Y_CORD            = %d", `BSG_MACHINE_ORIGIN_Y_CORD);
  end


  // BSG TAG MASTER
  logic tag_done_lo;
  bsg_tag_s [num_pods_y_p-1:0][num_pods_x_p-1:0][S:N] pod_tags_lo;
  bsg_tag_s [num_pods_x_p-1:0] io_tags_lo;

  bsg_nonsynth_manycore_tag_master #(
    .num_pods_x_p(num_pods_x_p)
    ,.num_pods_y_p(num_pods_y_p)
    ,.wh_cord_width_p(wh_cord_width_p)
  ) mtm (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.tag_done_o(tag_done_lo)
    ,.pod_tags_o(pod_tags_lo)
    ,.io_tags_o(io_tags_lo)
  );   
  
  assign tag_done_o = tag_done_lo;

  // deassert reset when tag programming is done.
  wire reset = ~tag_done_lo;
  logic reset_r;
  bsg_dff_chain #(
    .width_p(1)
    ,.num_stages_p(reset_depth_p)
  ) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset)
    ,.data_o(reset_r)
  );


  // instantiate manycore
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0] io_link_sif_li;
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0] io_link_sif_lo;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0] wh_unconc_link_sif_li;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0] wh_unconc_link_sif_lo;
  bsg_manycore_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] hor_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_factor_X_p-1:0] ruche_link_li;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_factor_X_p-1:0] ruche_link_lo;

  bsg_manycore_pod_ruche_array #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.ruche_factor_X_p(ruche_factor_X_p)

    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)

    ,.vcache_addr_width_p(vcache_addr_width_p)
    ,.vcache_data_width_p(vcache_data_width_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_dma_data_width_p(vcache_dma_data_width_p)

    ,.wh_ruche_factor_p(wh_ruche_factor_p)
    ,.wh_cid_width_p(wh_cid_width_p)
    ,.wh_flit_width_p(wh_flit_width_p)
    ,.wh_cord_width_p(wh_cord_width_p)
    ,.wh_len_width_p(wh_len_width_p)

    ,.num_pods_y_p(num_pods_y_p)
    ,.num_pods_x_p(num_pods_x_p)

    ,.reset_depth_p(reset_depth_p)
    ,.hetero_type_vec_p(hetero_type_vec_p)
  ) DUT (
    .clk_i(clk_i)

    ,.io_link_sif_i(io_link_sif_li)
    ,.io_link_sif_o(io_link_sif_lo)

    ,.wh_link_sif_i(wh_unconc_link_sif_li)
    ,.wh_link_sif_o(wh_unconc_link_sif_lo)

    ,.hor_link_sif_i(hor_link_sif_li)
    ,.hor_link_sif_o(hor_link_sif_lo)

    ,.ruche_link_i(ruche_link_li)
    ,.ruche_link_o(ruche_link_lo)


    ,.pod_tags_i(pod_tags_lo) 
    ,.io_tags_i(io_tags_lo)
  );


  // Host link connection
  // connects to P-port of (x,y)=(0,1)
  assign io_link_sif_li[0] = io_link_sif_i;
  assign io_link_sif_o = io_link_sif_lo[0]; 


  // instantiate wormhole concentrators
  wh_link_sif_s [E:W][num_pods_y_p-1:0] wh_link_sif_li;
  wh_link_sif_s [E:W][num_pods_y_p-1:0] wh_link_sif_lo;

  for (genvar i = W; i <= E; i++) begin: conc_s
    for (genvar j = 0; j < num_pods_y_p; j++) begin: conc_y
      bsg_wormhole_concentrator #(
        .flit_width_p(wh_flit_width_p)
        ,.len_width_p(wh_len_width_p)
        ,.cid_width_p(wh_cid_width_p)
        ,.cord_width_p(wh_cord_width_p)
        ,.num_in_p(2*wh_ruche_factor_p)
      ) conc0 (
        .clk_i(clk_i)
        ,.reset_i(reset_r)
      
        ,.links_i(wh_unconc_link_sif_lo[i][j])
        ,.links_o(wh_unconc_link_sif_li[i][j])

        ,.concentrated_link_i(wh_link_sif_li[i][j])
        ,.concentrated_link_o(wh_link_sif_lo[i][j])
      );
    end
  end


  //                              //
  // Configurable Memory System   //
  //                              //
  localparam logic [e_max_val-1:0] mem_cfg_lp = (1 << bsg_manycore_mem_cfg_p);

  if (mem_cfg_lp[e_vcache_test_mem]) begin
    // in bytes
    // north + south row of vcache
    localparam longint unsigned mem_size_lp = (num_pods_x_p == 1)
      ? 1*(2**30)
      : 2*(2**30)*(num_pods_x_p/2);

    for (genvar i = W; i <= E; i++) begin
      for (genvar j = 0; j < num_pods_y_p; j++) begin
        bsg_nonsynth_wormhole_test_mem #(
          .vcache_data_width_p(vcache_data_width_p)
          ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
          ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
          ,.num_vcaches_p(num_tiles_x_p*num_pods_x_p) // north + south row of vcache
          ,.wh_cid_width_p(wh_cid_width_p)
          ,.wh_flit_width_p(wh_flit_width_p)
          ,.wh_cord_width_p(wh_cord_width_p)
          ,.wh_len_width_p(wh_len_width_p)
          ,.wh_ruche_factor_p(wh_ruche_factor_p)
          ,.mem_size_p(mem_size_lp)
        ) test_mem (
          .clk_i(clk_i)
          ,.reset_i(reset_r)
          ,.wh_link_sif_i(wh_link_sif_lo[i][j])
          ,.wh_link_sif_o(wh_link_sif_li[i][j])
        );
      end
    end

  end
  else if (mem_cfg_lp[e_vcache_hbm2]) begin
    

    `define dram_pkg bsg_dramsim3_hbm2_8gb_x128_pkg
    parameter hbm2_data_width_p = `dram_pkg::data_width_p;
    parameter hbm2_channel_addr_width_p = `dram_pkg::channel_addr_width_p;
    parameter hbm2_num_channels_p = `dram_pkg::num_channels_p;

    // north + south row of vcache
    parameter num_vcaches_per_link_lp = num_tiles_x_p*num_pods_x_p; // # of vcaches connected to each concentrated link.
    parameter num_wh_links_lp = (num_pods_y_p*2);
    parameter num_vcaches_per_channel_lp = 16;
    parameter num_total_channels_lp = (num_wh_links_lp*num_vcaches_per_link_lp)/num_vcaches_per_channel_lp;
    parameter num_dram_lp = `BSG_CDIV(num_total_channels_lp,hbm2_num_channels_p);


    // WH to cache dma
    `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p);
    bsg_cache_dma_pkt_s [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_pkt_lo;
    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_pkt_v_lo;
    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_pkt_yumi_li;

    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_li;
    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_data_v_li;
    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_data_ready_lo;

    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_lo;
    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_data_v_lo;
    logic [num_wh_links_lp*num_vcaches_per_link_lp-1:0] dma_data_yumi_li;


    for (genvar i = 0; i < num_pods_y_p; i++) begin
      bsg_manycore_vcache_wh_to_cache_dma #(
        .wh_flit_width_p(wh_flit_width_p)
        ,.wh_cid_width_p(wh_cid_width_p)
        ,.wh_len_width_p(wh_len_width_p)
        ,.wh_cord_width_p(wh_cord_width_p)
        ,.wh_ruche_factor_p(wh_ruche_factor_p)

        ,.num_vcaches_p(num_vcaches_per_link_lp)
        ,.vcache_addr_width_p(vcache_addr_width_p)
        ,.vcache_data_width_p(vcache_data_width_p)
        ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ) wh_to_dma (
        .clk_i(clk_i)
        ,.reset_i(reset_r)
    
        ,.wh_link_sif_i(wh_link_sif_lo[W][i])
        ,.wh_link_sif_o(wh_link_sif_li[W][i])

        ,.dma_pkt_o         (dma_pkt_lo[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
        ,.dma_pkt_v_o       (dma_pkt_v_lo[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
        ,.dma_pkt_yumi_i    (dma_pkt_yumi_li[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])

        ,.dma_data_i        (dma_data_li[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
        ,.dma_data_v_i      (dma_data_v_li[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
        ,.dma_data_ready_o  (dma_data_ready_lo[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])

        ,.dma_data_o        (dma_data_lo[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
        ,.dma_data_v_o      (dma_data_v_lo[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
        ,.dma_data_yumi_i   (dma_data_yumi_li[num_vcaches_per_link_lp*i+:num_vcaches_per_link_lp])
      );
    end

    for (genvar i = 0; i < num_pods_y_p; i++) begin
      bsg_manycore_vcache_wh_to_cache_dma #(
        .wh_flit_width_p(wh_flit_width_p)
        ,.wh_cid_width_p(wh_cid_width_p)
        ,.wh_len_width_p(wh_len_width_p)
        ,.wh_cord_width_p(wh_cord_width_p)
        ,.wh_ruche_factor_p(wh_ruche_factor_p)

        ,.num_vcaches_p(num_vcaches_per_link_lp)
        ,.vcache_addr_width_p(vcache_addr_width_p)
        ,.vcache_data_width_p(vcache_data_width_p)
        ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ) wh_to_dma (
        .clk_i(clk_i)
        ,.reset_i(reset_r)
    
        ,.wh_link_sif_i(wh_link_sif_lo[E][i])
        ,.wh_link_sif_o(wh_link_sif_li[E][i])

        ,.dma_pkt_o         (dma_pkt_lo[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
        ,.dma_pkt_v_o       (dma_pkt_v_lo[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
        ,.dma_pkt_yumi_i    (dma_pkt_yumi_li[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])

        ,.dma_data_i        (dma_data_li[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
        ,.dma_data_v_i      (dma_data_v_li[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
        ,.dma_data_ready_o  (dma_data_ready_lo[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])

        ,.dma_data_o        (dma_data_lo[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
        ,.dma_data_v_o      (dma_data_v_lo[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
        ,.dma_data_yumi_i   (dma_data_yumi_li[num_vcaches_per_link_lp*((num_pods_y_p)+i)+:num_vcaches_per_link_lp])
      );
    end


    // DRAMSIM3
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_v_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_write_not_read_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][hbm2_channel_addr_width_p-1:0] dramsim3_ch_addr_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_yumi_lo;

    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][hbm2_data_width_p-1:0] dramsim3_data_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_data_v_li;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_data_yumi_lo;

    logic [(num_dram_lp*hbm2_num_channels_p)-1:0][hbm2_data_width_p-1:0] dramsim3_data_lo;
    logic [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_data_v_lo;
    `dram_pkg::dram_ch_addr_s [(num_dram_lp*hbm2_num_channels_p)-1:0] dramsim3_read_done_ch_addr_lo;
    
    for (genvar i = 0; i < num_dram_lp; i++) begin
      bsg_nonsynth_dramsim3 #(
        .channel_addr_width_p (hbm2_channel_addr_width_p)
        ,.data_width_p        (hbm2_data_width_p)
        ,.num_channels_p      (hbm2_num_channels_p)
        ,.num_columns_p       (`dram_pkg::num_columns_p)
        ,.num_rows_p          (`dram_pkg::num_rows_p)
        ,.num_ba_p            (`dram_pkg::num_ba_p)
        ,.num_bg_p            (`dram_pkg::num_bg_p)
        ,.num_ranks_p         (`dram_pkg::num_ranks_p)
        ,.address_mapping_p   (`dram_pkg::address_mapping_p)
        ,.size_in_bits_p      (`dram_pkg::size_in_bits_p)
        ,.config_p            (`dram_pkg::config_p)
        ,.init_mem_p          (1)
        ,.base_id_p           (i*hbm2_num_channels_p)
      ) hbm0 (
        .clk_i(clk_i)
        ,.reset_i(reset_r)
      
        ,.v_i                 (dramsim3_v_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.write_not_read_i    (dramsim3_write_not_read_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.ch_addr_i           (dramsim3_ch_addr_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.mask_i              ('1)
        ,.yumi_o              (dramsim3_yumi_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])

        ,.data_v_i            (dramsim3_data_v_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.data_i              (dramsim3_data_li[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.data_yumi_o         (dramsim3_data_yumi_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])

        ,.data_v_o            (dramsim3_data_v_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.data_o              (dramsim3_data_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])
        ,.read_done_ch_addr_o (dramsim3_read_done_ch_addr_lo[hbm2_num_channels_p*i+:hbm2_num_channels_p])

        ,.write_done_o        ()
        ,.write_done_ch_addr_o()
      );
    end



    // cache DMA to DRAMSIM3
    typedef struct packed {
      logic [1:0] bg;
      logic [1:0] ba;
      logic [14:0] ro;
      logic [5:0] co;
      logic [4:0] byte_offset;
    } dram_ch_addr_s; 

    dram_ch_addr_s [num_total_channels_lp-1:0] test_dram_ch_addr_lo;
    logic [num_total_channels_lp-1:0][hbm2_channel_addr_width_p-1:0] test_dram_ch_addr_li;

    for (genvar i = 0; i < num_total_channels_lp; i++) begin

      bsg_cache_to_test_dram #(
        .num_cache_p(num_vcaches_per_channel_lp)
        ,.addr_width_p(vcache_addr_width_p)
        ,.data_width_p(vcache_data_width_p)
        ,.block_size_in_words_p(vcache_block_size_in_words_p)
        ,.cache_bank_addr_width_p(cache_bank_addr_width_lp)
        ,.dma_data_width_p(vcache_dma_data_width_p)
      
        ,.dram_channel_addr_width_p(hbm2_channel_addr_width_p)
        ,.dram_data_width_p(hbm2_data_width_p)
      ) cache_to_tram (
        .core_clk_i           (clk_i)
        ,.core_reset_i        (reset_r)

        ,.dma_pkt_i           (dma_pkt_lo[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])
        ,.dma_pkt_v_i         (dma_pkt_v_lo[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])
        ,.dma_pkt_yumi_o      (dma_pkt_yumi_li[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])

        ,.dma_data_o          (dma_data_li[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])
        ,.dma_data_v_o        (dma_data_v_li[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])
        ,.dma_data_ready_i    (dma_data_ready_lo[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])

        ,.dma_data_i          (dma_data_lo[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])
        ,.dma_data_v_i        (dma_data_v_lo[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])
        ,.dma_data_yumi_o     (dma_data_yumi_li[i*num_vcaches_per_channel_lp+:num_vcaches_per_channel_lp])


        ,.dram_clk_i              (clk_i)
        ,.dram_reset_i            (reset_r)
    
        ,.dram_req_v_o            (dramsim3_v_li[i])
        ,.dram_write_not_read_o   (dramsim3_write_not_read_li[i])
        ,.dram_ch_addr_o          (test_dram_ch_addr_lo[i])
        ,.dram_req_yumi_i         (dramsim3_yumi_lo[i])

        ,.dram_data_v_o           (dramsim3_data_v_li[i])
        ,.dram_data_o             (dramsim3_data_li[i])
        ,.dram_data_yumi_i        (dramsim3_data_yumi_lo[i])

        ,.dram_data_v_i           (dramsim3_data_v_lo[i])
        ,.dram_data_i             (dramsim3_data_lo[i])
        ,.dram_ch_addr_i          (test_dram_ch_addr_li[i])
      );

      assign dramsim3_ch_addr_li[i] = {
        test_dram_ch_addr_lo[i].ro,
        test_dram_ch_addr_lo[i].bg,
        test_dram_ch_addr_lo[i].ba,
        test_dram_ch_addr_lo[i].co,
        test_dram_ch_addr_lo[i].byte_offset
      };

      assign test_dram_ch_addr_li[i] = {
        dramsim3_read_done_ch_addr_lo[i].bg,
        dramsim3_read_done_ch_addr_lo[i].ba,
        dramsim3_read_done_ch_addr_lo[i].ro,
        dramsim3_read_done_ch_addr_lo[i].co,
        dramsim3_read_done_ch_addr_lo[i].byte_offset
      };
    end
  end



  // IO TIE OFFS
  for (genvar i = 1; i < num_pods_x_p*num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) io_n_tieoff (
      .clk_i(clk_i)
      ,.reset_i(reset_r)
      ,.link_sif_i(io_link_sif_lo[i])
      ,.link_sif_o(io_link_sif_li[i])
    );
  end


  // HOR TIEOFF (local link)
  for (genvar i = W; i <= E; i++) begin
    for (genvar j = 0; j < num_pods_y_p; j++) begin
      for (genvar k = 0; k < num_tiles_y_p; k++) begin
        bsg_manycore_link_sif_tieoff #(
          .addr_width_p(addr_width_p)
          ,.data_width_p(data_width_p)
          ,.x_cord_width_p(x_cord_width_p)
          ,.y_cord_width_p(y_cord_width_p)
        ) hor_tieoff (
          .clk_i(clk_i)
          ,.reset_i(reset_r)
          ,.link_sif_i(hor_link_sif_lo[i][j][k])
          ,.link_sif_o(hor_link_sif_li[i][j][k])
        );
      end
    end
  end


  // RUCHE LINK TIEOFF (west)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      for (genvar l = 0; l < ruche_factor_X_p; l++) begin
        bsg_manycore_ruche_x_link_sif_tieoff #(
          .addr_width_p(addr_width_p)
          ,.data_width_p(data_width_p)
          ,.x_cord_width_p(x_cord_width_p)
          ,.y_cord_width_p(y_cord_width_p)
          ,.ruche_stage_p(l)
          ,.ruche_factor_X_p(ruche_factor_X_p)
          ,.west_not_east_p(1)
        ) rw_tieoff (
          .clk_i(clk_i)
          ,.reset_i(reset_r)
          ,.ruche_link_i(ruche_link_lo[W][j][k][l])
          ,.ruche_link_o(ruche_link_li[W][j][k][l])
        );
      end
    end
  end

  // RUCHE LINK TIEOFF (east)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      for (genvar l = 0; l < ruche_factor_X_p; l++) begin
        bsg_manycore_ruche_x_link_sif_tieoff #(
          .addr_width_p(addr_width_p)
          ,.data_width_p(data_width_p)
          ,.x_cord_width_p(x_cord_width_p)
          ,.y_cord_width_p(y_cord_width_p)
          ,.ruche_stage_p(l)
          ,.ruche_factor_X_p(ruche_factor_X_p)
          ,.west_not_east_p(0)
        ) re_tieoff (
          .clk_i(clk_i)
          ,.reset_i(reset_r)
          ,.ruche_link_i(ruche_link_lo[E][j][k][l])
          ,.ruche_link_o(ruche_link_li[E][j][k][l])
        );
      end
    end
  end
  

if (enable_vcore_profiling_p) begin
  // vanilla core profiler
   bind vanilla_core vanilla_core_profiler #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.data_width_p(data_width_p)
    ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
    ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
  ) vcore_prof (
    .*
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
  ); 

  bind network_tx remote_load_trace #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
    ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
  ) rlt (
    .*
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
  );

end

if (enable_cache_profiling_p) begin
  bind bsg_cache vcache_profiler #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.header_print_p("py[0].px[0].pod.north_vc_row.vc_x[0]")
    ,.ways_p(ways_p)
  ) vcache_prof (
    // everything else
    .*
    // bsg_cache_miss
    ,.chosen_way_n(miss.chosen_way_n)
    // from testbench
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
  );
end

if (enable_router_profiling_p) begin
  bind bsg_mesh_router router_profiler #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.dims_p(dims_p)
    ,.XY_order_p(XY_order_p)
    ,.origin_x_cord_p(`BSG_MACHINE_ORIGIN_X_CORD)
    ,.origin_y_cord_p(`BSG_MACHINE_ORIGIN_Y_CORD)
  ) rp0 (
    .*
    ,.global_ctr_i($root.`HOST_MODULE_PATH.global_ctr)
    ,.trace_en_i($root.`HOST_MODULE_PATH.trace_en)
    ,.print_stat_v_i($root.`HOST_MODULE_PATH.print_stat_v)
    ,.print_stat_tag_i($root.`HOST_MODULE_PATH.print_stat_tag)
  );
end


endmodule
