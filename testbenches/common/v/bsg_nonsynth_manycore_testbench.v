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

    , parameter num_subarray_x_p = "inv"
    , parameter num_subarray_y_p = "inv"

    , parameter num_vcache_rows_p = "inv"
    , parameter vcache_data_width_p = "inv"
    , parameter vcache_sets_p = "inv"
    , parameter vcache_ways_p = "inv"
    , parameter vcache_block_size_in_words_p = "inv" // in words
    , parameter vcache_dma_data_width_p = "inv" // in bits
    , parameter vcache_size_p = "inv" // in words
    , parameter vcache_addr_width_p="inv" // byte addr
    , parameter num_vcaches_per_channel_p = "inv"

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

    , parameter cache_bank_addr_width_lp = `BSG_SAFE_CLOG2(bsg_dram_size_p/(2*num_tiles_x_p*num_vcache_rows_p)*4) // byte addr
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
    $display("[INFO][TESTBENCH] BSG_MACHINE_SUBARRAY_X               = %d", num_subarray_x_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_SUBARRAY_Y               = %d", num_subarray_y_p);
    $display("[INFO][TESTBENCH] BSG_MACHINE_ORIGIN_X_CORD            = %d", `BSG_MACHINE_ORIGIN_X_CORD);
    $display("[INFO][TESTBENCH] BSG_MACHINE_ORIGIN_Y_CORD            = %d", `BSG_MACHINE_ORIGIN_Y_CORD);
    $display("[INFO][TESTBENCH] BSG_MACHINE_NUM_VCACHE_ROWS          = %d", num_vcache_rows_p);
    $display("[INFO][TESTBENCH] enable_vcore_profiling_p             = %d", enable_vcore_profiling_p);
    $display("[INFO][TESTBENCH] enable_router_profiling_p            = %d", enable_router_profiling_p);
    $display("[INFO][TESTBENCH] enable_cache_profiling_p             = %d", enable_cache_profiling_p);
  end


  // BSG TAG MASTER
  logic tag_done_lo;
  bsg_tag_s [num_pods_y_p-1:0][num_pods_x_p-1:0] pod_tags_lo;

  bsg_nonsynth_manycore_tag_master #(
    .num_pods_x_p(num_pods_x_p)
    ,.num_pods_y_p(num_pods_y_p)
    ,.wh_cord_width_p(wh_cord_width_p)
  ) mtm (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.tag_done_o(tag_done_lo)
    ,.pod_tags_o(pod_tags_lo)
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
  bsg_manycore_link_sif_s [S:N][(num_pods_x_p*num_tiles_x_p)-1:0] ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][(num_pods_x_p*num_tiles_x_p)-1:0] ver_link_sif_lo;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_li;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_lo;
  bsg_manycore_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] hor_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] ruche_link_li;
  bsg_manycore_ruche_x_link_sif_s [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0] ruche_link_lo;

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

    ,.num_subarray_x_p(num_subarray_x_p)
    ,.num_subarray_y_p(num_subarray_y_p)

    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)

    ,.num_vcache_rows_p(num_vcache_rows_p)
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

    ,.ver_link_sif_i(ver_link_sif_li)
    ,.ver_link_sif_o(ver_link_sif_lo)

    ,.wh_link_sif_i(wh_link_sif_li)
    ,.wh_link_sif_o(wh_link_sif_lo)

    ,.hor_link_sif_i(hor_link_sif_li)
    ,.hor_link_sif_o(hor_link_sif_lo)

    ,.ruche_link_i(ruche_link_li)
    ,.ruche_link_o(ruche_link_lo)

    ,.pod_tags_i(pod_tags_lo) 
  );

  // Invert WH ruche links
  // hardcoded for ruche factor = 2
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] buffered_wh_link_sif_li;
  wh_link_sif_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] buffered_wh_link_sif_lo;
  for (genvar i = W; i <= E; i++) begin
    for (genvar j = 0; j < num_pods_y_p; j++) begin
      for (genvar k = N; k <= S; k++) begin
        for (genvar v = 0; v < num_vcache_rows_p; v++) begin
          for (genvar r = 0; r < wh_ruche_factor_p; r++) begin
            if (r == 0) begin
              assign wh_link_sif_li[i][j][k][v][r] = buffered_wh_link_sif_li[i][j][k][v][r];
              assign buffered_wh_link_sif_lo[i][j][k][v][r] = wh_link_sif_lo[i][j][k][v][r];
            end
            else begin
              assign wh_link_sif_li[i][j][k][v][r] = ~buffered_wh_link_sif_li[i][j][k][v][r];
              assign buffered_wh_link_sif_lo[i][j][k][v][r] = ~wh_link_sif_lo[i][j][k][v][r];
            end
          end
        end
      end
    end
  end

  // IO ROUTER
  localparam rev_use_credits_lp = 5'b00001;
  localparam int rev_fifo_els_lp[4:0] = '{2,2,2,2,3};
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:P] io_link_sif_li;
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:P] io_link_sif_lo;

  for (genvar x = 0; x < num_pods_x_p*num_tiles_x_p; x++) begin: io_rtr_x
    bsg_manycore_mesh_node #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.stub_p(4'b0100) // stub north
      ,.rev_use_credits_p(rev_use_credits_lp)
      ,.rev_fifo_els_p(rev_fifo_els_lp)
    ) io_rtr (
      .clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.links_sif_i(io_link_sif_li[x][S:W])
      ,.links_sif_o(io_link_sif_lo[x][S:W])

      ,.proc_link_sif_i(io_link_sif_li[x][P])
      ,.proc_link_sif_o(io_link_sif_lo[x][P])

      ,.global_x_i(x_cord_width_p'(num_tiles_x_p+x))
      ,.global_y_i(y_cord_width_p'(0))
    );

    // connect to pod array
    assign ver_link_sif_li[N][x] = io_link_sif_lo[x][S];
    assign io_link_sif_li[x][S] = ver_link_sif_lo[N][x];

    // connect between io rtr
    if (x < (num_pods_x_p*num_tiles_x_p)-1) begin
      assign io_link_sif_li[x][E] = io_link_sif_lo[x+1][W];
      assign io_link_sif_li[x+1][W] = io_link_sif_lo[x][E];
    end
  end



  // Host link connection
  assign io_link_sif_li[0][P] = io_link_sif_i;
  assign io_link_sif_o = io_link_sif_lo[0][P];




  //                              //
  // Configurable Memory System   //
  //                              //
  localparam logic [e_max_val-1:0] mem_cfg_lp = (1 << bsg_manycore_mem_cfg_p);

  if (mem_cfg_lp[e_vcache_test_mem]) begin: test_mem
    // in bytes
    // north + south row of vcache
    localparam longint unsigned mem_size_lp = (2**30)*num_pods_x_p/wh_ruche_factor_p/num_vcache_rows_p/2;
    localparam num_vcaches_per_test_mem_lp = (num_tiles_x_p*num_pods_x_p)/wh_ruche_factor_p/2;

    for (genvar i = W; i <= E; i++) begin: hs                           // horizontal side
      for (genvar j = 0; j < num_pods_y_p; j++) begin: py               // pod y
        for (genvar k = N; k <= S; k++) begin: vs                       // vertical side
          for (genvar v = 0; v < num_vcache_rows_p; v++) begin: vr      // vcache row
            for (genvar r = 0; r < wh_ruche_factor_p; r++) begin: rf    // ruching
/*
              bsg_nonsynth_wormhole_test_mem #(
                .vcache_data_width_p(vcache_data_width_p)
                ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
                ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
                ,.num_vcaches_p(num_vcaches_per_test_mem_lp)
                ,.wh_cid_width_p(wh_cid_width_p)
                ,.wh_flit_width_p(wh_flit_width_p)
                ,.wh_cord_width_p(wh_cord_width_p)
                ,.wh_len_width_p(wh_len_width_p)
                ,.wh_ruche_factor_p(wh_ruche_factor_p)
                ,.no_concentration_p(1)
                ,.mem_size_p(mem_size_lp)
              ) test_mem (
                .clk_i(clk_i)
                ,.reset_i(reset_r)

                ,.wh_link_sif_i(buffered_wh_link_sif_lo[i][j][k][v][r])
                ,.wh_link_sif_o(buffered_wh_link_sif_li[i][j][k][v][r])
              );
*/

              parameter axi_id_width_p   = 1;
              parameter axi_addr_width_p = 34;
              parameter axi_data_width_p = 256;
              parameter axi_burst_len_p  = 1;

              parameter axi_sel_width_p = 4;
              parameter dma_addr_width_p = axi_addr_width_p - axi_sel_width_p;
              localparam lg_mem_size_lp = `BSG_SAFE_CLOG2(mem_size_lp);
              localparam lg_num_vcaches_lp = `BSG_SAFE_CLOG2(num_vcaches_per_test_mem_lp);
              localparam lg_wh_ruche_factor_lp = `BSG_SAFE_CLOG2(wh_ruche_factor_p);

              // WH to cache dma
              `declare_bsg_cache_dma_pkt_s(dma_addr_width_p);
              bsg_cache_dma_pkt_s                 dma_pkt_lo;
              bsg_cache_dma_pkt_s                 dma_pkt_remap_lo;
              logic                               dma_pkt_v_lo;
              logic                               dma_pkt_yumi_li;

              logic [vcache_dma_data_width_p-1:0] dma_data_li;
              logic                               dma_data_v_li;
              logic                               dma_data_ready_lo;

              logic [vcache_dma_data_width_p-1:0] dma_data_lo;
              logic                               dma_data_v_lo;
              logic                               dma_data_yumi_li;

              logic [wh_cord_width_p-1:0]         dma_src_cord_lo;

              assign dma_pkt_remap_lo.write_not_read = dma_pkt_lo.write_not_read;
              assign dma_pkt_remap_lo.addr = {'0,
                dma_src_cord_lo[lg_wh_ruche_factor_lp+:lg_num_vcaches_lp],
                dma_pkt_lo.addr[0+:lg_mem_size_lp-lg_num_vcaches_lp]
              };

              bsg_wormhole_to_cache_dma_fanout
             #(.num_dma_p       (1)
              ,.dma_addr_width_p(dma_addr_width_p)
              ,.dma_burst_len_p (vcache_block_size_in_words_p*vcache_data_width_p/vcache_dma_data_width_p)
              ,.wh_flit_width_p (wh_flit_width_p)
              ,.wh_cid_width_p  (wh_cid_width_p)
              ,.wh_len_width_p  (wh_len_width_p)
              ,.wh_cord_width_p (wh_cord_width_p)
              ,.dma_data_width_p(vcache_dma_data_width_p)
              ) wh_to_dma
              (.clk_i  (clk_i)
              ,.reset_i(reset_r)

              ,.wh_link_sif_i     (buffered_wh_link_sif_lo[i][j][k][v][r])
              ,.wh_dma_id_i       ('0)
              ,.wh_link_sif_o     (buffered_wh_link_sif_li[i][j][k][v][r])

              ,.dma_pkt_o            (dma_pkt_lo)
              ,.dma_src_cord_o       (dma_src_cord_lo)
              ,.dma_pkt_v_o          (dma_pkt_v_lo)
              ,.dma_pkt_yumi_i       (dma_pkt_yumi_li)

              ,.dma_data_i           (dma_data_li)
              ,.dma_data_v_i         (dma_data_v_li)
              ,.dma_data_ready_and_o (dma_data_ready_lo)

              ,.dma_data_o           (dma_data_lo)
              ,.dma_data_v_o         (dma_data_v_lo)
              ,.dma_data_yumi_i      (dma_data_yumi_li)
              );

              wire [axi_addr_width_p-1:0]s_axi_araddr;
              wire [1:0]s_axi_arburst;
              wire [3:0]s_axi_arcache;
              wire [axi_id_width_p-1:0]s_axi_arid;
              wire [7:0]s_axi_arlen;
              wire [0:0]s_axi_arlock;
              wire [2:0]s_axi_arprot;
              wire [3:0]s_axi_arqos;
              wire s_axi_arready;
              wire [3:0]s_axi_arregion;
              wire [2:0]s_axi_arsize;
              wire s_axi_arvalid;

              wire [axi_addr_width_p-1:0]s_axi_awaddr;
              wire [1:0]s_axi_awburst;
              wire [3:0]s_axi_awcache;
              wire [axi_id_width_p-1:0]s_axi_awid;
              wire [7:0]s_axi_awlen;
              wire [0:0]s_axi_awlock;
              wire [2:0]s_axi_awprot;
              wire [3:0]s_axi_awqos;
              wire s_axi_awready;
              wire [3:0]s_axi_awregion;
              wire [2:0]s_axi_awsize;
              wire s_axi_awvalid;

              wire [axi_id_width_p-1:0]s_axi_bid;
              wire s_axi_bready;
              wire [1:0]s_axi_bresp;
              wire s_axi_bvalid;

              wire [axi_data_width_p-1:0]s_axi_rdata;
              wire [axi_id_width_p-1:0]s_axi_rid;
              wire s_axi_rlast;
              wire s_axi_rready;
              wire [1:0]s_axi_rresp;
              wire s_axi_rvalid;

              wire [axi_data_width_p-1:0]s_axi_wdata;
              wire s_axi_wlast;
              wire s_axi_wready;
              wire [(axi_data_width_p>>3)-1:0]s_axi_wstrb;
              wire s_axi_wvalid;

              // s_axi port
              // not supported
              assign s_axi_arqos    = '0;
              assign s_axi_arregion = '0;
              assign s_axi_awqos    = '0;
              assign s_axi_awregion = '0;

              bsg_cache_to_axi
             #(.addr_width_p         (dma_addr_width_p)
              ,.block_size_in_words_p(vcache_block_size_in_words_p)
              ,.data_width_p         (vcache_dma_data_width_p)
              ,.num_cache_p          (1)
              ,.axi_id_width_p       (axi_id_width_p)
              ,.axi_addr_width_p     (axi_addr_width_p)
              ,.axi_data_width_p     (axi_data_width_p)
              ,.axi_burst_len_p      (axi_burst_len_p)
              ) dma_to_axi
              (.clk_i  (clk_i)
              ,.reset_i(reset_r)

              ,.dma_pkt_i       (dma_pkt_remap_lo)
              ,.dma_pkt_v_i     (dma_pkt_v_lo)
              ,.dma_pkt_yumi_o  (dma_pkt_yumi_li)

              ,.dma_data_o      (dma_data_li)
              ,.dma_data_v_o    (dma_data_v_li)
              ,.dma_data_ready_i(dma_data_ready_lo)

              ,.dma_data_i      (dma_data_lo)
              ,.dma_data_v_i    (dma_data_v_lo)
              ,.dma_data_yumi_o (dma_data_yumi_li)

              ,.axi_awid_o      (s_axi_awid)
              ,.axi_awaddr_o    (s_axi_awaddr)
              ,.axi_awlen_o     (s_axi_awlen)
              ,.axi_awsize_o    (s_axi_awsize)
              ,.axi_awburst_o   (s_axi_awburst)
              ,.axi_awcache_o   (s_axi_awcache)
              ,.axi_awprot_o    (s_axi_awprot)
              ,.axi_awlock_o    (s_axi_awlock)
              ,.axi_awvalid_o   (s_axi_awvalid)
              ,.axi_awready_i   (s_axi_awready)

              ,.axi_wdata_o     (s_axi_wdata)
              ,.axi_wstrb_o     (s_axi_wstrb)
              ,.axi_wlast_o     (s_axi_wlast)
              ,.axi_wvalid_o    (s_axi_wvalid)
              ,.axi_wready_i    (s_axi_wready)

              ,.axi_bid_i       (s_axi_bid)
              ,.axi_bresp_i     (s_axi_bresp)
              ,.axi_bvalid_i    (s_axi_bvalid)
              ,.axi_bready_o    (s_axi_bready)

              ,.axi_arid_o      (s_axi_arid)
              ,.axi_araddr_o    (s_axi_araddr)
              ,.axi_arlen_o     (s_axi_arlen)
              ,.axi_arsize_o    (s_axi_arsize)
              ,.axi_arburst_o   (s_axi_arburst)
              ,.axi_arcache_o   (s_axi_arcache)
              ,.axi_arprot_o    (s_axi_arprot)
              ,.axi_arlock_o    (s_axi_arlock)
              ,.axi_arvalid_o   (s_axi_arvalid)
              ,.axi_arready_i   (s_axi_arready)

              ,.axi_rid_i       (s_axi_rid)
              ,.axi_rdata_i     (s_axi_rdata)
              ,.axi_rresp_i     (s_axi_rresp)
              ,.axi_rlast_i     (s_axi_rlast)
              ,.axi_rvalid_i    (s_axi_rvalid)
              ,.axi_rready_o    (s_axi_rready)
              );

              bsg_nonsynth_manycore_axi_mem
             #(.axi_id_width_p     (axi_id_width_p)
              ,.axi_addr_width_p   (axi_addr_width_p)
              ,.axi_data_width_p   (axi_data_width_p)
              ,.axi_burst_len_p    (axi_burst_len_p)
              ,.mem_els_p          (mem_size_lp/(axi_data_width_p/8))
              ,.bsg_dram_included_p(1)
              ) axi_mem
              (.clk_i  (clk_i)
              ,.reset_i(reset_r)

              ,.axi_awid_i   (s_axi_awid)
              ,.axi_awaddr_i ({(axi_sel_width_p)'(0), s_axi_awaddr[dma_addr_width_p-1:0]})
              ,.axi_awvalid_i(s_axi_awvalid)
              ,.axi_awready_o(s_axi_awready)

              ,.axi_wdata_i  (s_axi_wdata)
              ,.axi_wstrb_i  (s_axi_wstrb)
              ,.axi_wlast_i  (s_axi_wlast)
              ,.axi_wvalid_i (s_axi_wvalid)
              ,.axi_wready_o (s_axi_wready)

              ,.axi_bid_o    (s_axi_bid)
              ,.axi_bresp_o  (s_axi_bresp)
              ,.axi_bvalid_o (s_axi_bvalid)
              ,.axi_bready_i (s_axi_bready)

              ,.axi_arid_i   (s_axi_arid)
              ,.axi_araddr_i ({(axi_sel_width_p)'(0), s_axi_araddr[dma_addr_width_p-1:0]})
              ,.axi_arvalid_i(s_axi_arvalid)
              ,.axi_arready_o(s_axi_arready)

              ,.axi_rid_o    (s_axi_rid)
              ,.axi_rdata_o  (s_axi_rdata)
              ,.axi_rresp_o  (s_axi_rresp)
              ,.axi_rlast_o  (s_axi_rlast)
              ,.axi_rvalid_o (s_axi_rvalid)
              ,.axi_rready_i (s_axi_rready)
              );

            end
          end
        end
      end
    end

  end
  else if (mem_cfg_lp[e_vcache_hbm2]) begin: hbm2
    

    `define dram_pkg `BSG_MACHINE_DRAMSIM3_PKG
    parameter hbm2_data_width_p = `dram_pkg::data_width_p;
    parameter hbm2_channel_addr_width_p = `dram_pkg::channel_addr_width_p;
    parameter hbm2_num_channels_p = `dram_pkg::num_channels_p;
      
    parameter num_total_vcaches_lp = (num_pods_x_p*num_pods_y_p*2*num_tiles_x_p*num_vcache_rows_p);
    parameter lg_num_total_vcaches_lp = `BSG_SAFE_CLOG2(num_total_vcaches_lp);
    parameter num_vcaches_per_link_lp = (num_tiles_x_p*num_pods_x_p)/wh_ruche_factor_p/2; // # of vcaches attached to each link

    parameter num_total_channels_lp = num_total_vcaches_lp/num_vcaches_per_channel_p;
    parameter num_dram_lp = `BSG_CDIV(num_total_channels_lp,hbm2_num_channels_p);


    // WH to cache dma
    `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p);
    bsg_cache_dma_pkt_s [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_v_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_pkt_yumi_li;

    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_li;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_v_li;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_ready_lo;

    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0][vcache_dma_data_width_p-1:0] dma_data_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_v_lo;
    logic [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][num_vcaches_per_link_lp-1:0] dma_data_yumi_li;


    for (genvar i = W; i <= E; i++) begin: hs
      for (genvar j = 0; j < num_pods_y_p; j++) begin: py
        for (genvar k = N; k <= S; k++) begin: py
          for (genvar n = 0; n < num_vcache_rows_p; n++) begin: row
            for (genvar r = 0; r < wh_ruche_factor_p; r++) begin: rf
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

                ,.no_concentration_p(1)
                ,.num_pods_x_p(num_pods_x_p)
                ,.pod_start_x_p(1)
                ,.num_tiles_x_p(num_tiles_x_p)
              ) wh_to_dma (
                .clk_i(clk_i)
                ,.reset_i(reset_r)
    
                ,.wh_link_sif_i     (buffered_wh_link_sif_lo[i][j][k][n][r])
                ,.wh_link_sif_o     (buffered_wh_link_sif_li[i][j][k][n][r])

                ,.dma_pkt_o         (dma_pkt_lo[i][j][k][n][r])
                ,.dma_pkt_v_o       (dma_pkt_v_lo[i][j][k][n][r])
                ,.dma_pkt_yumi_i    (dma_pkt_yumi_li[i][j][k][n][r])

                ,.dma_data_i        (dma_data_li[i][j][k][n][r])
                ,.dma_data_v_i      (dma_data_v_li[i][j][k][n][r])
                ,.dma_data_ready_o  (dma_data_ready_lo[i][j][k][n][r])

                ,.dma_data_o        (dma_data_lo[i][j][k][n][r])
                ,.dma_data_v_o      (dma_data_v_lo[i][j][k][n][r])
                ,.dma_data_yumi_i   (dma_data_yumi_li[i][j][k][n][r])
              );
            end
          end
        end
      end
    end


    // cache DMA to DRAMSIM3
    // assign vcache DMA to correct HBM2 channel / bank
    bsg_cache_dma_pkt_s [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_pkt_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_pkt_v_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_pkt_yumi_li;

    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0][vcache_dma_data_width_p-1:0] remapped_dma_data_li;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_v_li;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_ready_lo;

    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0][vcache_dma_data_width_p-1:0] remapped_dma_data_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_v_lo;
    logic [num_total_channels_lp-1:0][num_vcaches_per_channel_p-1:0] remapped_dma_data_yumi_li;


    vcache_dma_to_dram_channel_map #(
      .num_pods_y_p(num_pods_y_p)
      ,.num_pods_x_p(num_pods_x_p)
      ,.num_tiles_x_p(num_tiles_x_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)

      ,.num_vcache_rows_p(num_vcache_rows_p)
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
    ) dma_map (
      // unmapped
      .dma_pkt_i                    (dma_pkt_lo)
      ,.dma_pkt_v_i                 (dma_pkt_v_lo)
      ,.dma_pkt_yumi_o              (dma_pkt_yumi_li)

      ,.dma_data_o                  (dma_data_li)
      ,.dma_data_v_o                (dma_data_v_li)
      ,.dma_data_ready_i            (dma_data_ready_lo)

      ,.dma_data_i                  (dma_data_lo)
      ,.dma_data_v_i                (dma_data_v_lo)
      ,.dma_data_yumi_o             (dma_data_yumi_li)

      // remapped
      ,.remapped_dma_pkt_o          (remapped_dma_pkt_lo)
      ,.remapped_dma_pkt_v_o        (remapped_dma_pkt_v_lo)
      ,.remapped_dma_pkt_yumi_i     (remapped_dma_pkt_yumi_li)
      
      ,.remapped_dma_data_i         (remapped_dma_data_li)
      ,.remapped_dma_data_v_i       (remapped_dma_data_v_li)
      ,.remapped_dma_data_ready_o   (remapped_dma_data_ready_lo)

      ,.remapped_dma_data_o         (remapped_dma_data_lo)
      ,.remapped_dma_data_v_o       (remapped_dma_data_v_lo)
      ,.remapped_dma_data_yumi_i    (remapped_dma_data_yumi_li)
    );
        

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
        .clk_i                (clk_i)
        ,.reset_i             (reset_r)
      
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

        ,.print_stat_v_i      ($root.`HOST_MODULE_PATH.print_stat_v)
        ,.print_stat_tag_i    ($root.`HOST_MODULE_PATH.print_stat_tag)

        ,.write_done_o        ()
        ,.write_done_ch_addr_o()
      );
    end


    // cache to test dram
    // This is the address format coming out of cache dma.
    typedef struct packed {
      logic [$clog2(`dram_pkg::num_ba_p)-1:0] ba;
      logic [$clog2(`dram_pkg::num_bg_p)-1:0] bg;
      logic [$clog2(`dram_pkg::num_rows_p)-1:0] ro;
      logic [$clog2(`dram_pkg::num_columns_p)-1:0] co;
      logic [$clog2(`dram_pkg::data_width_p>>3)-1:0] byte_offset;
    } dram_ch_addr_s; 

    dram_ch_addr_s [num_total_channels_lp-1:0] test_dram_ch_addr_lo;
    logic [num_total_channels_lp-1:0][hbm2_channel_addr_width_p-1:0] test_dram_ch_addr_li;

    for (genvar i = 0; i < num_total_channels_lp; i++) begin

      bsg_cache_to_test_dram #(
        .num_cache_p(num_vcaches_per_channel_p)
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

        ,.dma_pkt_i           (remapped_dma_pkt_lo[i])
        ,.dma_pkt_v_i         (remapped_dma_pkt_v_lo[i])
        ,.dma_pkt_yumi_o      (remapped_dma_pkt_yumi_li[i])

        ,.dma_data_o          (remapped_dma_data_li[i])
        ,.dma_data_v_o        (remapped_dma_data_v_li[i])
        ,.dma_data_ready_i    (remapped_dma_data_ready_lo[i])

        ,.dma_data_i          (remapped_dma_data_lo[i])
        ,.dma_data_v_i        (remapped_dma_data_v_lo[i])
        ,.dma_data_yumi_o     (remapped_dma_data_yumi_li[i])


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

      // manycore to dramsim3 address hashing
      // dramsim3 uses ro-bg-ba-co-bo as address map, so we are changing the mapping here.
      assign dramsim3_ch_addr_li[i] = {
        test_dram_ch_addr_lo[i].ro,
        test_dram_ch_addr_lo[i].bg,
        test_dram_ch_addr_lo[i].ba,
        test_dram_ch_addr_lo[i].co,
        test_dram_ch_addr_lo[i].byte_offset
      };

      // dramsim3 to manycore address hashing
      // address coming out of dramsim3 is also ro-bg-ba-co-bo, so we are changing it back to the format that cache dma uses.
      assign test_dram_ch_addr_li[i] = {
        dramsim3_read_done_ch_addr_lo[i].ba,
        dramsim3_read_done_ch_addr_lo[i].bg,
        dramsim3_read_done_ch_addr_lo[i].ro,
        dramsim3_read_done_ch_addr_lo[i].co,
        dramsim3_read_done_ch_addr_lo[i].byte_offset
      };
    end
  end













  ////                        ////
  ////      TIE OFF           ////
  ////                        ////


  // IO P tie off
  for (genvar i = 1; i < num_pods_x_p*num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) io_p_tieoff (
      .clk_i(clk_i)
      ,.reset_i(reset_r)
      ,.link_sif_i(io_link_sif_lo[i][P])
      ,.link_sif_o(io_link_sif_li[i][P])
    );
  end

  // IO west end tieoff
  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) io_w_tieoff (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_sif_i(io_link_sif_lo[0][W])
    ,.link_sif_o(io_link_sif_li[0][W])
  );

  // IO east end tieoff
  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) io_e_tieoff (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.link_sif_i(io_link_sif_lo[(num_pods_x_p*num_tiles_x_p)-1][E])
    ,.link_sif_o(io_link_sif_li[(num_pods_x_p*num_tiles_x_p)-1][E])
  );


  // SOUTH VER LINK TIE OFFS
  for (genvar i = 0; i < num_pods_x_p*num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) ver_s_tieoff (
      .clk_i(clk_i)
      ,.reset_i(reset_r)
      ,.link_sif_i(ver_link_sif_lo[S][i])
      ,.link_sif_o(ver_link_sif_li[S][i])
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
      // hard coded for ruche factor 3
      assign ruche_link_li[W][j][k] = '0;
    end
  end

  // RUCHE LINK TIEOFF (east)
  for (genvar j = 0; j < num_pods_y_p; j++) begin
    for (genvar k = 0; k < num_tiles_y_p; k++) begin
      // hard coded for ruche factor 3
      assign ruche_link_li[E][j][k] = '0;
    end
  end
  








//                  //
//    PROFILERS     //
//                  //

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
    ,.header_print_p({`BSG_STRINGIFY(`HOST_MODULE_PATH),".testbench.DUT.py[0].podrow.px[0].pod.north_vc_x[0].north_vc_row.vc_y[0].vc_x[0].vc.cache.vcache_prof"})
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
  );
end


endmodule
