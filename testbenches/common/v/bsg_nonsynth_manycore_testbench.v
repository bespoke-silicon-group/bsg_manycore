/**
 *    bsg_nonsynth_manycore_testbench.v
 *
 */


module bsg_nonsynth_manycore_testbench
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;

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

    , parameter bsg_dram_size_p ="inv" // in word
    , parameter reset_depth_p = 3

    , parameter enable_vcore_profiling_p=0
    , parameter enable_router_profiling_p=0
    , parameter enable_cache_profiling_p=0

    , parameter host_x_cord_p=0
    , parameter host_y_cord_p=0

    , parameter axi_id_width_p   = "inv"
    , parameter axi_addr_width_p = "inv"
    , parameter axi_data_width_p = "inv"
    , parameter axi_burst_len_p  = "inv"

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

    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_addr_width_p-1:0]mem_axi_araddr
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*2-1:0]mem_axi_arburst
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*4-1:0]mem_axi_arcache
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_id_width_p-1:0]mem_axi_arid
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*8-1:0]mem_axi_arlen
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*1-1:0]mem_axi_arlock
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*3-1:0]mem_axi_arprot
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*4-1:0]mem_axi_arqos
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_arready
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*4-1:0]mem_axi_arregion
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*3-1:0]mem_axi_arsize
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_arvalid

    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_addr_width_p-1:0]mem_axi_awaddr
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*2-1:0]mem_axi_awburst
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*4-1:0]mem_axi_awcache
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_id_width_p-1:0]mem_axi_awid
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*8-1:0]mem_axi_awlen
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*1-1:0]mem_axi_awlock
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*3-1:0]mem_axi_awprot
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*4-1:0]mem_axi_awqos
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_awready
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*4-1:0]mem_axi_awregion
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*3-1:0]mem_axi_awsize
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_awvalid

    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_id_width_p-1:0]mem_axi_bid
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_bready
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*2-1:0]mem_axi_bresp
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_bvalid

    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_data_width_p-1:0]mem_axi_rdata
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_id_width_p-1:0]mem_axi_rid
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_rlast
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_rready
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*2-1:0]mem_axi_rresp
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_rvalid

    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*axi_data_width_p-1:0]mem_axi_wdata
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_wlast
    , input  [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_wready
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p*(axi_data_width_p>>3)-1:0]mem_axi_wstrb
    , output [2*num_pods_y_p*2*num_vcache_rows_p*wh_ruche_factor_p-1:0]mem_axi_wvalid
  );



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
    `ifndef SYNTHESIS
    ,.hetero_type_vec_p(hetero_type_vec_p)
    `endif
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

  // SPMD LOADER
  logic print_stat_v;
  logic [data_width_p-1:0] print_stat_tag;
  bsg_nonsynth_manycore_io_complex #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.io_x_cord_p(host_x_cord_p)
    ,.io_y_cord_p(host_y_cord_p)
  ) io (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.io_link_sif_i(io_link_sif_lo[0][P])
    ,.io_link_sif_o(io_link_sif_li[0][P])
    ,.print_stat_v_o(print_stat_v)
    ,.print_stat_tag_o(print_stat_tag)
    ,.loader_done_o()
  );




  //                              //
  // Configurable Memory System   //
  //                              //

    // in bytes
    // north + south row of vcache
    localparam longint unsigned mem_size_lp = (2**30)*num_pods_x_p/wh_ruche_factor_p/num_vcache_rows_p/2;
    localparam num_vcaches_per_test_mem_lp = (num_tiles_x_p*num_pods_x_p)/wh_ruche_factor_p/2;

    parameter axi_sel_width_p = 4;
    parameter dma_addr_width_p = axi_addr_width_p - axi_sel_width_p;
    localparam lg_mem_size_lp = `BSG_SAFE_CLOG2(mem_size_lp);
    localparam lg_num_vcaches_lp = `BSG_SAFE_CLOG2(num_vcaches_per_test_mem_lp);
    localparam lg_wh_ruche_factor_lp = `BSG_SAFE_CLOG2(wh_ruche_factor_p);

    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_addr_width_p-1:0]s_axi_araddr;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][1:0]s_axi_arburst;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][3:0]s_axi_arcache;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_id_width_p-1:0]s_axi_arid;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][7:0]s_axi_arlen;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][0:0]s_axi_arlock;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][2:0]s_axi_arprot;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][3:0]s_axi_arqos;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_arready;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][3:0]s_axi_arregion;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][2:0]s_axi_arsize;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_arvalid;

    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_addr_width_p-1:0]s_axi_awaddr;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][1:0]s_axi_awburst;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][3:0]s_axi_awcache;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_id_width_p-1:0]s_axi_awid;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][7:0]s_axi_awlen;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][0:0]s_axi_awlock;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][2:0]s_axi_awprot;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][3:0]s_axi_awqos;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_awready;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][3:0]s_axi_awregion;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][2:0]s_axi_awsize;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_awvalid;

    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_id_width_p-1:0]s_axi_bid;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_bready;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][1:0]s_axi_bresp;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_bvalid;

    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_data_width_p-1:0]s_axi_rdata;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_id_width_p-1:0]s_axi_rid;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_rlast;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_rready;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][1:0]s_axi_rresp;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_rvalid;

    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][axi_data_width_p-1:0]s_axi_wdata;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_wlast;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_wready;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][(axi_data_width_p>>3)-1:0]s_axi_wstrb;
    wire [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0]s_axi_wvalid;

    assign mem_axi_araddr   = s_axi_araddr    ;
    assign mem_axi_arburst  = s_axi_arburst   ;
    assign mem_axi_arcache  = s_axi_arcache   ;
    assign mem_axi_arid     = s_axi_arid      ;
    assign mem_axi_arlen    = s_axi_arlen     ;
    assign mem_axi_arlock   = s_axi_arlock    ;
    assign mem_axi_arprot   = s_axi_arprot    ;
    assign mem_axi_arqos    = s_axi_arqos     ;
    assign s_axi_arready    = mem_axi_arready ;
    assign mem_axi_arregion = s_axi_arregion  ;
    assign mem_axi_arsize   = s_axi_arsize    ;
    assign mem_axi_arvalid  = s_axi_arvalid   ;

    assign mem_axi_awaddr   = s_axi_awaddr    ;
    assign mem_axi_awburst  = s_axi_awburst   ;
    assign mem_axi_awcache  = s_axi_awcache   ;
    assign mem_axi_awid     = s_axi_awid      ;
    assign mem_axi_awlen    = s_axi_awlen     ;
    assign mem_axi_awlock   = s_axi_awlock    ;
    assign mem_axi_awprot   = s_axi_awprot    ;
    assign mem_axi_awqos    = s_axi_awqos     ;
    assign s_axi_awready    = mem_axi_awready ;
    assign mem_axi_awregion = s_axi_awregion  ;
    assign mem_axi_awsize   = s_axi_awsize    ;
    assign mem_axi_awvalid  = s_axi_awvalid   ;

    assign s_axi_bid        = mem_axi_bid     ;
    assign mem_axi_bready   = s_axi_bready    ;
    assign s_axi_bresp      = mem_axi_bresp   ;
    assign s_axi_bvalid     = mem_axi_bvalid  ;

    assign s_axi_rdata      = mem_axi_rdata   ;
    assign s_axi_rid        = mem_axi_rid     ;
    assign s_axi_rlast      = mem_axi_rlast   ;
    assign mem_axi_rready   = s_axi_rready    ;
    assign s_axi_rresp      = mem_axi_rresp   ;
    assign s_axi_rvalid     = mem_axi_rvalid  ;

    assign mem_axi_wdata    = s_axi_wdata     ;
    assign mem_axi_wlast    = s_axi_wlast     ;
    assign s_axi_wready     = mem_axi_wready  ;
    assign mem_axi_wstrb    = s_axi_wstrb     ;
    assign mem_axi_wvalid   = s_axi_wvalid    ;

    for (genvar i = W; i <= E; i++) begin: hs                           // horizontal side
      for (genvar j = 0; j < num_pods_y_p; j++) begin: py               // pod y
        for (genvar k = N; k <= S; k++) begin: vs                       // vertical side
          for (genvar v = 0; v < num_vcache_rows_p; v++) begin: vr      // vcache row
            for (genvar r = 0; r < wh_ruche_factor_p; r++) begin: rf    // ruching

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

              ,.axi_awid_o      (s_axi_awid   [i][j][k][v][r])
              ,.axi_awaddr_o    (s_axi_awaddr [i][j][k][v][r])
              ,.axi_awlen_o     (s_axi_awlen  [i][j][k][v][r])
              ,.axi_awsize_o    (s_axi_awsize [i][j][k][v][r])
              ,.axi_awburst_o   (s_axi_awburst[i][j][k][v][r])
              ,.axi_awcache_o   (s_axi_awcache[i][j][k][v][r])
              ,.axi_awprot_o    (s_axi_awprot [i][j][k][v][r])
              ,.axi_awlock_o    (s_axi_awlock [i][j][k][v][r])
              ,.axi_awvalid_o   (s_axi_awvalid[i][j][k][v][r])
              ,.axi_awready_i   (s_axi_awready[i][j][k][v][r])

              ,.axi_wdata_o     (s_axi_wdata  [i][j][k][v][r])
              ,.axi_wstrb_o     (s_axi_wstrb  [i][j][k][v][r])
              ,.axi_wlast_o     (s_axi_wlast  [i][j][k][v][r])
              ,.axi_wvalid_o    (s_axi_wvalid [i][j][k][v][r])
              ,.axi_wready_i    (s_axi_wready [i][j][k][v][r])

              ,.axi_bid_i       (s_axi_bid    [i][j][k][v][r])
              ,.axi_bresp_i     (s_axi_bresp  [i][j][k][v][r])
              ,.axi_bvalid_i    (s_axi_bvalid [i][j][k][v][r])
              ,.axi_bready_o    (s_axi_bready [i][j][k][v][r])

              ,.axi_arid_o      (s_axi_arid   [i][j][k][v][r])
              ,.axi_araddr_o    (s_axi_araddr [i][j][k][v][r])
              ,.axi_arlen_o     (s_axi_arlen  [i][j][k][v][r])
              ,.axi_arsize_o    (s_axi_arsize [i][j][k][v][r])
              ,.axi_arburst_o   (s_axi_arburst[i][j][k][v][r])
              ,.axi_arcache_o   (s_axi_arcache[i][j][k][v][r])
              ,.axi_arprot_o    (s_axi_arprot [i][j][k][v][r])
              ,.axi_arlock_o    (s_axi_arlock [i][j][k][v][r])
              ,.axi_arvalid_o   (s_axi_arvalid[i][j][k][v][r])
              ,.axi_arready_i   (s_axi_arready[i][j][k][v][r])

              ,.axi_rid_i       (s_axi_rid    [i][j][k][v][r])
              ,.axi_rdata_i     (s_axi_rdata  [i][j][k][v][r])
              ,.axi_rresp_i     (s_axi_rresp  [i][j][k][v][r])
              ,.axi_rlast_i     (s_axi_rlast  [i][j][k][v][r])
              ,.axi_rvalid_i    (s_axi_rvalid [i][j][k][v][r])
              ,.axi_rready_o    (s_axi_rready [i][j][k][v][r])
              );

            end
          end
        end
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



endmodule
