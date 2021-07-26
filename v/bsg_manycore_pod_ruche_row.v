/**
 *    bsg_manycore_pod_ruche_row.v
 *
 */


`include "bsg_manycore_defines.vh"

module bsg_manycore_pod_ruche_row
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , parameter ruche_factor_X_p=3  // only support 3 for now
    , parameter barrier_ruche_factor_X_p=3
    , parameter num_subarray_x_p=1
    , parameter num_subarray_y_p=1

    , `BSG_INV_PARAM(dmem_size_p)
    , `BSG_INV_PARAM(icache_entries_p)
    , `BSG_INV_PARAM(icache_tag_width_p)

    , parameter num_vcache_rows_p=1
    , `BSG_INV_PARAM(vcache_addr_width_p)
    , `BSG_INV_PARAM(vcache_data_width_p)
    , `BSG_INV_PARAM(vcache_ways_p)
    , `BSG_INV_PARAM(vcache_sets_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_size_p)
    , `BSG_INV_PARAM(vcache_dma_data_width_p)

    , parameter wh_ruche_factor_p=2 // only support 2 for now
    , `BSG_INV_PARAM(wh_cid_width_p)
    , `BSG_INV_PARAM(wh_flit_width_p)
    , `BSG_INV_PARAM(wh_cord_width_p)
    , `BSG_INV_PARAM(wh_len_width_p)

    // number of pods to instantiate
    , `BSG_INV_PARAM(num_pods_x_p)

    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    // subarray num clk ports
    , parameter num_clk_ports_p=1 

    , parameter manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)
    , parameter ruche_x_link_sif_width_lp = 
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    // This is used to define heterogeneous arrays. Each index defines
    // the type of an X/Y coordinate in the array. This is a vector of
    // num_tiles_x_p*num_tiles_y_p ints; type "0" is the
    // default. See bsg_manycore_hetero_socket.v for more types.
    `ifndef SYNTHESIS
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}
    `endif
  )
  (
    input clk_i
    , input [num_pods_x_p-1:0][num_tiles_x_p-1:0] reset_i
    
    // vertical router links 
    , input  [S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // vcache wormhole links
    , input  [E:W][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o

    // horizontal local links
    , input  [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o

    // horizontal ruche links
    , input  [E:W][num_tiles_y_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_tiles_y_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_o

    // global coordinates
    , input [num_pods_x_p-1:0][num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    , input [num_pods_x_p-1:0][num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);



  // Instantiate pods
  bsg_manycore_link_sif_s [num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0] hor_link_sif_lo;
  bsg_manycore_link_sif_s [num_pods_x_p-1:0][S:N][num_tiles_x_p-1:0] ver_link_sif_li;
  bsg_manycore_link_sif_s [num_pods_x_p-1:0][S:N][num_tiles_x_p-1:0] ver_link_sif_lo;
  bsg_manycore_ruche_x_link_sif_s [num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0] ruche_link_li;  
  bsg_manycore_ruche_x_link_sif_s [num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0] ruche_link_lo;  
  wh_link_sif_s [num_pods_x_p-1:0][S:N][E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_li;
  wh_link_sif_s [num_pods_x_p-1:0][S:N][E:W][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_lo;
  logic [num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0] hor_barrier_link_li, hor_barrier_link_lo;
  logic [num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0][barrier_ruche_factor_X_p-1:0] barrier_ruche_link_li, barrier_ruche_link_lo;

  for (genvar x = 0; x < num_pods_x_p; x++) begin: px

    bsg_manycore_pod_ruche #(
      .num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)
      ,.pod_x_cord_width_p(pod_x_cord_width_p)
      ,.pod_y_cord_width_p(pod_y_cord_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.ruche_factor_X_p(ruche_factor_X_p)
      ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
      
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

        `ifndef SYNTHESIS
      ,.hetero_type_vec_p(hetero_type_vec_p)
        `endif

      ,.num_clk_ports_p(num_clk_ports_p)
    ) pod (
      .clk_i(clk_i)
      ,.reset_i(reset_i[x])

      ,.hor_link_sif_i(hor_link_sif_li[x])
      ,.hor_link_sif_o(hor_link_sif_lo[x])
      ,.ver_link_sif_i(ver_link_sif_li[x])
      ,.ver_link_sif_o(ver_link_sif_lo[x])
      ,.ruche_link_i(ruche_link_li[x])
      ,.ruche_link_o(ruche_link_lo[x])
      ,.hor_barrier_link_i(hor_barrier_link_li[x])
      ,.hor_barrier_link_o(hor_barrier_link_lo[x])
      ,.barrier_ruche_link_i(barrier_ruche_link_li[x])
      ,.barrier_ruche_link_o(barrier_ruche_link_lo[x])

      ,.north_wh_link_sif_i(wh_link_sif_li[x][N])
      ,.north_wh_link_sif_o(wh_link_sif_lo[x][N])
      ,.south_wh_link_sif_i(wh_link_sif_li[x][S])
      ,.south_wh_link_sif_o(wh_link_sif_lo[x][S])

      ,.global_x_i(global_x_i[x])
      ,.global_y_i(global_y_i[x])
    );


    // connect vertical local links to north
    assign ver_link_sif_o[N][x] = ver_link_sif_lo[x][N];
    assign ver_link_sif_li[x][N] = ver_link_sif_i[N][x];

    // connect vertical local_links to south
    assign ver_link_sif_o[S][x] = ver_link_sif_lo[x][S];
    assign ver_link_sif_li[x][S] = ver_link_sif_i[S][x];

    // connect horizontal local links between pods
    if (x < num_pods_x_p-1) begin
      // hor local
      assign hor_link_sif_li[x][E] = hor_link_sif_lo[x+1][W];
      assign hor_link_sif_li[x+1][W] = hor_link_sif_lo[x][E];
      // barrier hor
      assign hor_barrier_link_li[x][E] = hor_barrier_link_lo[x+1][W];
      assign hor_barrier_link_li[x+1][W] = hor_barrier_link_lo[x][E];
      // barrier ruche
      assign barrier_ruche_link_li[x][E] = barrier_ruche_link_lo[x+1][W];
      assign barrier_ruche_link_li[x+1][W] = barrier_ruche_link_lo[x][E];
    end

    // connect horizontal links on the side to the west
    if (x == 0) begin
      // local
      assign hor_link_sif_o[W] = hor_link_sif_lo[x][W];
      assign hor_link_sif_li[x][W] = hor_link_sif_i[W];
    end

    // connect horizontal links on the side to the east
    if (x == num_pods_x_p-1) begin
      // local
      assign hor_link_sif_o[E] = hor_link_sif_lo[x][E];
      assign hor_link_sif_li[x][E] = hor_link_sif_i[E];
    end

    // connect ruche links between pods
    if (x < num_pods_x_p-1) begin
      // manycore
      assign ruche_link_li[x][E] = ruche_link_lo[x+1][W];
      assign ruche_link_li[x+1][W] = ruche_link_lo[x][E];

      // vcache wh
      for (genvar m = N; m <= S; m++) begin
        assign wh_link_sif_li[x][m][E] = wh_link_sif_lo[x+1][m][W];
        assign wh_link_sif_li[x+1][m][W] = wh_link_sif_lo[x][m][E];
      end
    end
  end



  // hard-coded for ruche factor = 3
  for (genvar y = 0; y < num_tiles_y_p; y++) begin: ry
    // connect manycore ruche to west
    assign ruche_link_li[0][W][y][1] = ruche_link_i[W][y];
    assign ruche_link_o[W][y] = ruche_link_lo[0][W][y][1];

    // tieoff west manycore ruche
    assign ruche_link_li[0][W][y][0] = '0; // tieoff
    assign ruche_link_li[0][W][y][2] = '1; // tieoff

    // connect manycore ruche to east
    assign ruche_link_li[num_pods_x_p-1][E][y][0] = ruche_link_i[E][y];
    assign ruche_link_o[E][y] = ruche_link_lo[num_pods_x_p-1][E][y][0];

    // tieoff east manycore ruche
    assign ruche_link_li[num_pods_x_p-1][E][y][1] = '1;
    assign ruche_link_li[num_pods_x_p-1][E][y][2] = '0;
  end

  // connect wormhole ruche links to the outside
  // (hardcoded for wh ruche factor 2)
  // For north vcaches, the vcache row orders are reversed, so that the inner vcache layers appear at index 0.
  for (genvar j = 0; j < num_vcache_rows_p; j++) begin
    for (genvar r = 0; r < wh_ruche_factor_p; r++) begin
    // north VC row
    // west out
    assign wh_link_sif_o[W][N][j][r] = wh_link_sif_lo[0][N][W][num_vcache_rows_p-1-j][r];
    // west in
    assign wh_link_sif_li[0][N][W][num_vcache_rows_p-1-j][r] =  wh_link_sif_i[W][N][j][r];
    // east out
    assign wh_link_sif_o[E][N][j][r] =  wh_link_sif_lo[num_pods_x_p-1][N][E][num_vcache_rows_p-1-j][r];
    // east in
    assign wh_link_sif_li[num_pods_x_p-1][N][E][num_vcache_rows_p-1-j][r] =  wh_link_sif_i[E][N][j][r];

    // south VC row
    // west out
    assign wh_link_sif_o[W][S][j][r] =  wh_link_sif_lo[0][S][W][j][r];
    // west in
    assign wh_link_sif_li[0][S][W][j][r] =  wh_link_sif_i[W][S][j][r];
    // east out
    assign wh_link_sif_o[E][S][j][r] =  wh_link_sif_lo[num_pods_x_p-1][S][E][j][r];
    // east in
    assign wh_link_sif_li[num_pods_x_p-1][S][E][j][r] =  wh_link_sif_i[E][S][j][r];
    end
  end

  // Tieoff barrier links
  // (Hardcoded for ruche factor of 3 for now)
  for (genvar y = 0; y < num_tiles_y_p; y++) begin
    // local
    assign hor_barrier_link_li[0][W][y] = 1'b0;
    assign hor_barrier_link_li[num_pods_x_p-1][E][y] = 1'b0;
    // ruche
    assign barrier_ruche_link_li[0][W][y][0] = 1'b0;
    assign barrier_ruche_link_li[0][W][y][1] = 1'b0;
    assign barrier_ruche_link_li[0][W][y][2] = 1'b1;
    assign barrier_ruche_link_li[num_pods_x_p-1][E][y][0] = 1'b0;
    assign barrier_ruche_link_li[num_pods_x_p-1][E][y][1] = 1'b1;
    assign barrier_ruche_link_li[num_pods_x_p-1][E][y][2] = 1'b0;
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_pod_ruche_row)
