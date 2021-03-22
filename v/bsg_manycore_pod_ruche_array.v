/**
 *    bsg_manycore_pod_ruche_array.v
 *
 *    this module instantiates an array of pods and io routers on the left and right sides.
 *
 */


`include "bsg_noc_links.vh"


module bsg_manycore_pod_ruche_array
  import bsg_noc_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter ruche_factor_X_p=3  // only support 3 for now

    , parameter num_subarray_x_p=1
    , parameter num_subarray_y_p=1

    , parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter num_vcache_rows_p=1
    , parameter vcache_addr_width_p="inv"
    , parameter vcache_data_width_p="inv"
    , parameter vcache_ways_p="inv"
    , parameter vcache_sets_p="inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_size_p="inv"
    , parameter vcache_dma_data_width_p="inv"

    , parameter wh_ruche_factor_p=2 // only support 2 for now
    , parameter wh_cid_width_p="inv"
    , parameter wh_flit_width_p="inv"
    , parameter wh_cord_width_p="inv"
    , parameter wh_len_width_p="inv"

    // number of pods to instantiate
    , parameter num_pods_y_p="inv"
    , parameter num_pods_x_p="inv"

    , parameter reset_depth_p=3

    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)


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
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}
  )
  (
    input clk_i

    // vertical router links 
    , input  [S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // vcache wormhole links
    , input  [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][num_pods_y_p-1:0][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o

    // horizontal local links
    , input  [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o
    
    // horizontal ruche links
    , input  [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_o
    

    // bsg_tag interface
    // Each pod has one tag client for reset.
    , input bsg_tag_s [num_pods_y_p-1:0][num_pods_x_p-1:0] pod_tags_i
  );



  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);

  bsg_manycore_link_sif_s [num_pods_y_p-1:0][E:W][num_tiles_y_p-1:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [num_pods_y_p-1:0][E:W][num_tiles_y_p-1:0] hor_link_sif_lo;
  bsg_manycore_link_sif_s [num_pods_y_p-1:0][S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0] ver_link_sif_li;
  bsg_manycore_link_sif_s [num_pods_y_p-1:0][S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0] ver_link_sif_lo;

  bsg_manycore_ruche_x_link_sif_s [num_pods_y_p-1:0][E:W][num_tiles_y_p-1:0] ruche_link_li;  
  bsg_manycore_ruche_x_link_sif_s [num_pods_y_p-1:0][E:W][num_tiles_y_p-1:0] ruche_link_lo;  

  wh_link_sif_s [num_pods_y_p-1:0][E:W][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_li;
  wh_link_sif_s [num_pods_y_p-1:0][E:W][S:N][num_vcache_rows_p-1:0][wh_ruche_factor_p-1:0] wh_link_sif_lo;

  logic [num_pods_y_p-1:0][(num_pods_x_p*num_tiles_x_p)-1:0][x_cord_width_p-1:0] global_x_li;
  logic [num_pods_y_p-1:0][(num_pods_x_p*num_tiles_x_p)-1:0][y_cord_width_p-1:0] global_y_li;

  logic [num_pods_y_p-1:0][num_pods_x_p-1:0] reset_lo;
  logic [num_pods_y_p-1:0][num_pods_x_p-1:0][num_tiles_x_p-1:0] reset_r;

  // Instantiate pod rows
  for (genvar y = 0; y < num_pods_y_p; y++) begin: py
    for (genvar x = 0; x < num_pods_x_p; x++) begin: px
      bsg_tag_client #(
        .width_p($bits(bsg_manycore_pod_tag_payload_s))
        ,.default_p(0)
      ) btc (
        .bsg_tag_i(pod_tags_i[y][x])
        ,.recv_clk_i(clk_i)
        ,.recv_reset_i(1'b0)
        ,.recv_new_r_o()
        ,.recv_data_r_o(reset_lo[y][x])
      );
      bsg_dff_chain #(
        .width_p(num_tiles_x_p)
        ,.num_stages_p(reset_depth_p-1)
      ) reset_dff (
        .clk_i(clk_i)
        ,.data_i({num_tiles_x_p{reset_lo[y][x]}})
        ,.data_o(reset_r[y][x])
      );
    end

    bsg_manycore_pod_ruche_row #(
      .num_tiles_x_p(num_tiles_x_p)
      ,.num_tiles_y_p(num_tiles_y_p)
      ,.pod_x_cord_width_p(pod_x_cord_width_p)
      ,.pod_y_cord_width_p(pod_y_cord_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.ruche_factor_X_p(ruche_factor_X_p)
      ,.num_pods_x_p(num_pods_x_p)    
  
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

      ,.hetero_type_vec_p(hetero_type_vec_p)
    ) podrow (
      .clk_i(clk_i)
      ,.reset_i(reset_r[y])

      ,.hor_link_sif_i(hor_link_sif_li[y])
      ,.hor_link_sif_o(hor_link_sif_lo[y])
      ,.ver_link_sif_i(ver_link_sif_li[y])
      ,.ver_link_sif_o(ver_link_sif_lo[y])
      ,.ruche_link_i(ruche_link_li[y])
      ,.ruche_link_o(ruche_link_lo[y])

      ,.wh_link_sif_i(wh_link_sif_li[y])
      ,.wh_link_sif_o(wh_link_sif_lo[y])

      ,.global_x_i(global_x_li[y])
      ,.global_y_i(global_y_li[y])
    );

    // assign global_x/y
    for (genvar i = 0; i < num_tiles_x_p*num_pods_x_p; i++) begin
      assign global_x_li[y][i] = {  (pod_x_cord_width_p)'((i/num_tiles_x_p)+1), (x_subcord_width_lp)'(i%num_tiles_x_p)    };
      assign global_y_li[y][i] = {  (pod_y_cord_width_p)'(y*2), (y_subcord_width_lp)'((1<<y_subcord_width_lp)-num_vcache_rows_p)  };
    end

    // connect vertical local links to north
    if (y == 0) begin
      assign ver_link_sif_o[N] = ver_link_sif_lo[y][N];
      assign ver_link_sif_li[y][N] = ver_link_sif_i[N];
    end

    // connect vertical local_links to south
    if (y == num_pods_y_p-1) begin
      assign ver_link_sif_o[S] = ver_link_sif_lo[y][S];
      assign ver_link_sif_li[y][S] = ver_link_sif_i[S];
    end

    // connect vertical local links between pods
    if (y < num_pods_y_p-1) begin
      assign ver_link_sif_li[y+1][N] = ver_link_sif_lo[y][S];
      assign ver_link_sif_li[y][S] = ver_link_sif_lo[y+1][N];
    end


    // connect horizontal links on the side to the west
    // local
    assign hor_link_sif_o[W][y] = hor_link_sif_lo[y][W];
    assign hor_link_sif_li[y][W] = hor_link_sif_i[W][y];
    // ruche
    assign ruche_link_o[W][y] = ruche_link_lo[y][W];
    assign ruche_link_li[y][W] = ruche_link_i[W][y];

    // connect horizontal links on the side to the east
    // local
    assign hor_link_sif_o[E][y] = hor_link_sif_lo[y][E];
    assign hor_link_sif_li[y][E] = hor_link_sif_i[E][y];
    // ruche
    assign ruche_link_o[E][y] = ruche_link_lo[y][E];
    assign ruche_link_li[y][E] = ruche_link_i[E][y];

    // connect wh to the west
    assign wh_link_sif_o[W][y][N] = wh_link_sif_lo[y][W][N];
    assign wh_link_sif_li[y][W][N] = wh_link_sif_i[W][y][N];
    assign wh_link_sif_o[W][y][S] = wh_link_sif_lo[y][W][S];
    assign wh_link_sif_li[y][W][S] = wh_link_sif_i[W][y][S];

    // connect wh to the east
    assign wh_link_sif_o[E][y][N] = wh_link_sif_lo[y][E][N];
    assign wh_link_sif_li[y][E][N] = wh_link_sif_i[E][y][N];
    assign wh_link_sif_o[E][y][S] = wh_link_sif_lo[y][E][S];
    assign wh_link_sif_li[y][E][S] = wh_link_sif_i[E][y][S];
  end



endmodule
