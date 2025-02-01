/**
 *    bsg_miniblade_pod.sv
 */

`include "bsg_manycore_defines.svh"


module bsg_miniblade_pod
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
  
    , `BSG_INV_PARAM(dmem_size_p)
    , `BSG_INV_PARAM(icache_entries_p )
    , `BSG_INV_PARAM(icache_tag_width_p )
    , `BSG_INV_PARAM(icache_block_size_in_words_p )
    , `BSG_INV_PARAM(pod_x_cord_width_p )
    , `BSG_INV_PARAM(pod_y_cord_width_p )


    , `BSG_INV_PARAM(vcache_size_p)
    , `BSG_INV_PARAM(vcache_addr_width_p)
    , `BSG_INV_PARAM(vcache_data_width_p)
    , `BSG_INV_PARAM(vcache_ways_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_dma_data_width_p)
    , `BSG_INV_PARAM(vcache_word_tracking_p)
    , `BSG_INV_PARAM(ipoly_hashing_p)


    // wormhole concentrator id;
    // north vc = 1'b0;
    // south vc = 1'b1;
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)


    , parameter tag_els_p=1024
    , parameter tag_local_els_p=1
    , parameter tag_lg_width_p=4
    , localparam lg_tag_els_lp=`BSG_SAFE_CLOG2(tag_els_p)

    , localparam link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , localparam wh_link_sif_width_lp=
      `bsg_ready_and_link_sif_width(wh_flit_width_p)

  )
  (
    // core_clk;
    input clk_i
   
    // reset_o tieoff;
    , output hor_reset_o 
    , output [num_tiles_x_p-1:0] ver_reset_o 
    // bsg_tag interface;
    , input tag_clk_i
    , input tag_data_i
    , input [lg_tag_els_lp-1:0] node_id_offset_i

    // IO router links - horizontal;
    // west - tieoff;
    // east - connect to noc block (corner - proc);
    , input  [E:W][link_sif_width_lp-1:0] io_link_sif_i
    , output [E:W][link_sif_width_lp-1:0] io_link_sif_o

    // connect to VC wormhole link;
    // west - tieoff;
    // east - connect to noc block;
    , input  [E:W][wh_link_sif_width_lp-1:0] north_wh_link_sif_i
    , output [E:W][wh_link_sif_width_lp-1:0] north_wh_link_sif_o
    , input  [E:W][wh_link_sif_width_lp-1:0] south_wh_link_sif_i
    , output [E:W][wh_link_sif_width_lp-1:0] south_wh_link_sif_o

    // connect to MC links;
    , input  [E:W][num_tiles_y_p-1:0][link_sif_width_lp-1:0] mc_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][link_sif_width_lp-1:0] mc_link_sif_o
    , input  [E:W][num_tiles_y_p-1:0] mc_barrier_link_i
    , output [E:W][num_tiles_y_p-1:0] mc_barrier_link_o

    // south VC vertical link; (for tieoff)
    , input  [num_tiles_x_p-1:0][link_sif_width_lp-1:0] svc_ver_link_i
    , output [num_tiles_x_p-1:0][link_sif_width_lp-1:0] svc_ver_link_o

    // coordinates (connect to south VC);
    // For tie off;
    , output [num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_o
    , output [num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_o
  );


  // manycore link;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  // wh link;
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p,wh_link_sif_s);



  // io router corner;
  logic [num_tiles_x_p-1:0][1:0] io_reset_lo; // 0 = south; 1 = west;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0]  io_global_y_lo, io_global_y_li;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0]  io_global_x_lo, io_global_x_li;

  bsg_manycore_link_sif_s  io_corner_hor_link_sif_li, io_corner_hor_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0]      io_ver_link_sif_li, io_ver_link_sif_lo;

  bsg_miniblade_tile_io_router_corner #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)

    ,.tag_els_p(tag_els_p)
    ,.tag_local_els_p(tag_local_els_p)
    ,.tag_lg_width_p(tag_lg_width_p)
  ) io_corner (
    .clk_i(clk_i)

    ,.tag_clk_i(tag_clk_i)
    ,.tag_data_i(tag_data_i)
    ,.node_id_offset_i(node_id_offset_i)

    ,.reset_o(io_reset_lo[num_tiles_x_p-1])

    // west;
    ,.hor_link_sif_i(io_corner_hor_link_sif_li)
    ,.hor_link_sif_o(io_corner_hor_link_sif_lo)

    // south;
    ,.ver_link_sif_i(io_ver_link_sif_li[num_tiles_x_p-1])
    ,.ver_link_sif_o(io_ver_link_sif_lo[num_tiles_x_p-1])

    // proc;
    ,.proc_link_sif_i(io_link_sif_i[E])
    ,.proc_link_sif_o(io_link_sif_o[E])

    ,.global_x_i(io_global_x_li[num_tiles_x_p-1])
    ,.global_y_i(io_global_y_li[num_tiles_x_p-1])
    ,.global_x_o(io_global_x_lo[num_tiles_x_p-1])
    ,.global_y_o(io_global_y_lo[num_tiles_x_p-1])
  );


  // io router array;
  logic [num_tiles_x_p-2:0] io_rtr_reset_li;
  bsg_manycore_link_sif_s [num_tiles_x_p-2:0][E:W] io_rtr_hor_link_sif_li, io_rtr_hor_link_sif_lo;
  logic [num_tiles_x_p-2:0][x_cord_width_p-1:0] io_rtr_global_x_li, io_rtr_global_x_lo;
  logic [num_tiles_x_p-2:0][y_cord_width_p-1:0] io_rtr_global_y_li, io_rtr_global_y_lo;

  for (genvar i = 0; i < num_tiles_x_p-1; i++) begin: ior
    bsg_miniblade_tile_io_router #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
    ) io_rtr (
      .clk_i(clk_i)
      ,.reset_i(io_rtr_reset_li[i])
      ,.reset_o(io_reset_lo[i])

      ,.hor_link_sif_i(io_rtr_hor_link_sif_li[i])
      ,.hor_link_sif_o(io_rtr_hor_link_sif_lo[i])

      ,.ver_link_sif_i(io_ver_link_sif_li[i])
      ,.ver_link_sif_o(io_ver_link_sif_lo[i])

      ,.global_x_i(io_global_x_li[i])
      ,.global_y_i(io_global_y_li[i])
      ,.global_x_o(io_global_x_lo[i])
      ,.global_y_o(io_global_y_lo[i])
    );

    // connect reset;
    assign io_rtr_reset_li[i] = io_reset_lo[i+1][1];

    // connect east;
    if (num_tiles_x_p-2 == i) begin
      assign io_rtr_hor_link_sif_li[i][E] = io_corner_hor_link_sif_lo;
      assign io_corner_hor_link_sif_li = io_rtr_hor_link_sif_lo[i][E];
    end
    else begin
      assign io_rtr_hor_link_sif_li[i][E] = io_rtr_hor_link_sif_lo[i+1][W];
    end

    // connect west;
    if (i == 0) begin
      assign io_rtr_hor_link_sif_li[i][W] = io_link_sif_i[W];
      assign io_link_sif_o[W] = io_rtr_hor_link_sif_lo[i][W];
    end
    else begin
      assign io_rtr_hor_link_sif_li[i][W] = io_rtr_hor_link_sif_lo[i-1][E];
    end
  end

  assign hor_reset_o = io_reset_lo[0][1];

  // Inject IO coordinates;
  for (genvar c = 0; c < num_tiles_x_p; c++) begin
    assign io_global_x_li[c] = x_cord_width_p'(c);
    assign io_global_y_li[c] = y_cord_width_p'(2); // IO y coordinate = 2;
  end


  //// TILE ports;
  // north vc array;
  logic [num_tiles_x_p-1:0] nvc_reset_li, nvc_reset_lo;
  wh_link_sif_s [num_tiles_x_p-1:0][E:W] nvc_wh_link_sif_li, nvc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:N] nvc_ver_link_sif_li, nvc_ver_link_sif_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] nvc_global_x_li, nvc_global_x_lo;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] nvc_global_y_li, nvc_global_y_lo;

  // mc array
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0] mc_reset_li, mc_reset_lo;
  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] mc_link_li, mc_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] barrier_link_li, barrier_link_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][x_cord_width_p-1:0] mc_global_x_li, mc_global_x_lo;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][y_cord_width_p-1:0] mc_global_y_li, mc_global_y_lo;

  // south vc array;
  logic [num_tiles_x_p-1:0] svc_reset_li, svc_reset_lo;
  wh_link_sif_s [num_tiles_x_p-1:0][E:W] svc_wh_link_sif_li, svc_wh_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0][S:N] svc_ver_link_sif_li, svc_ver_link_sif_lo;
  logic [num_tiles_x_p-1:0][x_cord_width_p-1:0] svc_global_x_li;
  logic [num_tiles_x_p-1:0][y_cord_width_p-1:0] svc_global_y_li;


  // Instantiate north vc array;
  for (genvar c = 0; c < num_tiles_x_p; c++) begin: nvc
    bsg_miniblade_tile_vcache #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)

      ,.num_tiles_y_p(num_tiles_y_p)
     
      ,.icache_block_size_in_words_p(icache_block_size_in_words_p) 
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) vc (
      .clk_i(clk_i)
      ,.reset_i(nvc_reset_li[c])
      ,.reset_o(nvc_reset_lo[c])

      ,.wh_link_sif_i(nvc_wh_link_sif_li[c])
      ,.wh_link_sif_o(nvc_wh_link_sif_lo[c])
      
      ,.ver_link_sif_i(nvc_ver_link_sif_li[c])
      ,.ver_link_sif_o(nvc_ver_link_sif_lo[c])

      ,.global_x_i(nvc_global_x_li[c])
      ,.global_y_i(nvc_global_y_li[c])
      ,.global_x_o(nvc_global_x_lo[c])
      ,.global_y_o(nvc_global_y_lo[c])
    );

    // connect north;
    assign nvc_reset_li[c] = io_reset_lo[c][0];
    assign nvc_global_x_li[c] = io_global_x_lo[c];
    assign nvc_global_y_li[c] = io_global_y_lo[c];
    assign nvc_ver_link_sif_li[c][N] = io_ver_link_sif_lo[c];
    assign io_ver_link_sif_li[c] = nvc_ver_link_sif_lo[c][N];
   
    // connect south;
    assign nvc_ver_link_sif_li[c][S] = mc_link_lo[0][c][N];
   
    // connect west;
    if (c == 0) begin
      assign nvc_wh_link_sif_li[c][W] = north_wh_link_sif_i[W];
      assign north_wh_link_sif_o[W] = nvc_wh_link_sif_lo[c][W];
    end
    else begin
      assign nvc_wh_link_sif_li[c][W] = nvc_wh_link_sif_lo[c-1][E];
    end

    // connect east;
    if (c == num_tiles_x_p-1) begin
      assign nvc_wh_link_sif_li[c][E] = north_wh_link_sif_i[E];
      assign north_wh_link_sif_o[E] = nvc_wh_link_sif_lo[c][E];
    end
    else begin
      assign nvc_wh_link_sif_li[c][E] = nvc_wh_link_sif_lo[c+1][W];
    end
  end


  // Instantiate manycore mesh array;
  for (genvar r = 0; r < num_tiles_y_p; r++) begin: y
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: x
      bsg_miniblade_tile_compute_mesh #(
        .dmem_size_p(dmem_size_p)
        ,.vcache_size_p (vcache_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)
        ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.ipoly_hashing_p(ipoly_hashing_p)
      ) tile (
        .clk_i(clk_i)
        ,.reset_i(mc_reset_li[r][c])
        ,.reset_o(mc_reset_lo[r][c])

        ,.link_i(mc_link_li[r][c])
        ,.link_o(mc_link_lo[r][c])
    
        ,.barrier_link_i(barrier_link_li[r][c])
        ,.barrier_link_o(barrier_link_lo[r][c])

        ,.global_x_i(mc_global_x_li[r][c])
        ,.global_y_i(mc_global_y_li[r][c])
        ,.global_x_o(mc_global_x_lo[r][c])
        ,.global_y_o(mc_global_y_lo[r][c])
      );

      // connect reset, coordinates;
      if (r == 0) begin
        assign mc_reset_li[r][c] = nvc_reset_lo[c];
        assign mc_global_x_li[r][c] = nvc_global_x_lo[c];
        assign mc_global_y_li[r][c] = nvc_global_y_lo[c];
      end
      else begin
        assign mc_reset_li[r][c] = mc_reset_lo[r-1][c];
        assign mc_global_x_li[r][c] = mc_global_x_lo[r-1][c];
        assign mc_global_y_li[r][c] = mc_global_y_lo[r-1][c];
      end

      // connect north;
      if (r == 0) begin
        assign mc_link_li[r][c][N] = nvc_ver_link_sif_lo[c][S];
        assign barrier_link_li[r][c][N] = 1'b0; // tieoff;
      end
      else begin
        assign mc_link_li[r][c][N] = mc_link_lo[r-1][c][S];
        assign barrier_link_li[r][c][N] = barrier_link_lo[r-1][c][S];
      end

      // connect south;
      if (r == num_tiles_y_p-1) begin
        assign mc_link_li[r][c][S] = svc_ver_link_sif_lo[c][N];
        assign barrier_link_li[r][c][S] = 1'b0; // tieoff;
      end
      else begin
        assign mc_link_li[r][c][S] = mc_link_lo[r+1][c][N];
        assign barrier_link_li[r][c][S] = barrier_link_lo[r+1][c][N];
      end

      // connect west;
      if (c == 0) begin
        assign mc_link_li[r][c][W] = mc_link_sif_i[W][r];
        assign mc_link_sif_o[W][r] = mc_link_lo[r][c][W];
        assign barrier_link_li[r][c][W] = mc_barrier_link_i[W][r];
        assign mc_barrier_link_o[W][r] = barrier_link_lo[r][c][W];
      end
      else begin
        assign mc_link_li[r][c][W] = mc_link_lo[r][c-1][E];
        assign barrier_link_li[r][c][W] = barrier_link_lo[r][c-1][E];
      end


      // connect east;
      if (c == num_tiles_x_p-1) begin
        assign mc_link_li[r][c][E] = mc_link_sif_i[E][r];
        assign mc_link_sif_o[E][r] = mc_link_lo[r][c][E];
        assign barrier_link_li[r][c][E] = mc_barrier_link_i[E][r];
        assign mc_barrier_link_o[E][r] = barrier_link_lo[r][c][E];
      end
      else begin
        assign mc_link_li[r][c][E] = mc_link_lo[r][c+1][W];
        assign barrier_link_li[r][c][E] = barrier_link_lo[r][c+1][W];
      end


    end
  end

  // Instantiate south vc array;
  for (genvar c = 0; c < num_tiles_x_p; c++) begin: svc
    bsg_miniblade_tile_vcache #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)

      ,.num_tiles_y_p(num_tiles_y_p)
      
      ,.icache_block_size_in_words_p(icache_block_size_in_words_p) 
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)
      ,.vcache_word_tracking_p(vcache_word_tracking_p)

      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) vc (
      .clk_i(clk_i)
      ,.reset_i(svc_reset_li[c])
      ,.reset_o(svc_reset_lo[c])

      ,.wh_link_sif_i(svc_wh_link_sif_li[c])
      ,.wh_link_sif_o(svc_wh_link_sif_lo[c])
      
      ,.ver_link_sif_i(svc_ver_link_sif_li[c])
      ,.ver_link_sif_o(svc_ver_link_sif_lo[c])

      ,.global_x_i(svc_global_x_li[c])
      ,.global_y_i(svc_global_y_li[c])
      ,.global_x_o(global_x_o[c])
      ,.global_y_o(global_y_o[c])
    );


    // coordinate, reset;
    assign svc_reset_li[c] = mc_reset_lo[num_tiles_y_p-1][c];
    assign svc_global_x_li[c] = mc_global_x_lo[num_tiles_y_p-1][c];
    assign svc_global_y_li[c] = mc_global_y_lo[num_tiles_y_p-1][c];
    assign ver_reset_o[c] = svc_reset_lo[c];

    // connect north;
    assign svc_ver_link_sif_li[c][N] = mc_link_lo[num_tiles_y_p-1][c][S];
   
    // connect south;
    assign svc_ver_link_sif_li[c][S] = svc_ver_link_i[c];
    assign svc_ver_link_o[c] = svc_ver_link_sif_lo[c][S];
   
    // connect west;
    if (c == 0) begin
      assign svc_wh_link_sif_li[c][W] = south_wh_link_sif_i[W];
      assign south_wh_link_sif_o[W] = svc_wh_link_sif_lo[c][W];
    end
    else begin
      assign svc_wh_link_sif_li[c][W] = svc_wh_link_sif_lo[c-1][E];
    end

    // connect east;
    if (c == num_tiles_x_p-1) begin
      assign svc_wh_link_sif_li[c][E] = south_wh_link_sif_i[E];
      assign south_wh_link_sif_o[E] = svc_wh_link_sif_lo[c][E];
    end
    else begin
      assign svc_wh_link_sif_li[c][E] = svc_wh_link_sif_lo[c+1][W];
    end

  end



endmodule
