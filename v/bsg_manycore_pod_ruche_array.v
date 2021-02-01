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

    , parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

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
  )
  (
    input clk_i

    // IO router proc links (north)
    , input  [(num_pods_x_p*num_tiles_x_p)-1:0][manycore_link_sif_width_lp-1:0] io_link_sif_i
    , output [(num_pods_x_p*num_tiles_x_p)-1:0][manycore_link_sif_width_lp-1:0] io_link_sif_o

    // concentrated wormhole links
    , input  [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][num_pods_y_p-1:0][S:N][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o

    // horizontal local links
    , input  [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o
    
    // horizontal ruche links
    , input  [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_o
    

    // bsg_tag interface
    // for each pod, there are two bsg_tag_clients (north and south)
    // bsg_tag_clients carry {reset, dest_wh_cord}
    , input bsg_tag_s [num_pods_y_p-1:0][num_pods_x_p-1:0][S:N] pod_tags_i

    // io rtr reset tag for each pod column
    , input bsg_tag_s [num_pods_x_p-1:0] io_tags_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);

  bsg_manycore_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0] hor_link_sif_lo;
  bsg_manycore_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][S:N][num_tiles_x_p-1:0] ver_link_sif_li;
  bsg_manycore_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][S:N][num_tiles_x_p-1:0] ver_link_sif_lo;

  bsg_manycore_ruche_x_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0] ruche_link_li;  
  bsg_manycore_ruche_x_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0] ruche_link_lo;  

  wh_link_sif_s [num_pods_y_p-1:0][S:N][num_pods_x_p-1:0][E:W][wh_ruche_factor_p-1:0] wh_link_sif_li;
  wh_link_sif_s [num_pods_y_p-1:0][S:N][num_pods_x_p-1:0][E:W][wh_ruche_factor_p-1:0] wh_link_sif_lo;


  // Instantiate pods
  for (genvar y = 0; y < num_pods_y_p; y++) begin: py
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

        ,.reset_depth_p(reset_depth_p)
      ) pod (
        .clk_i(clk_i)

        ,.hor_link_sif_i(hor_link_sif_li[y][x])
        ,.hor_link_sif_o(hor_link_sif_lo[y][x])
        ,.ver_link_sif_i(ver_link_sif_li[y][x])
        ,.ver_link_sif_o(ver_link_sif_lo[y][x])
        ,.ruche_link_i(ruche_link_li[y][x])
        ,.ruche_link_o(ruche_link_lo[y][x])

        ,.north_wh_link_sif_i(wh_link_sif_li[y][N][x])
        ,.north_wh_link_sif_o(wh_link_sif_lo[y][N][x])
        ,.north_vcache_pod_x_i(pod_x_cord_width_p'(x+1))
        ,.north_vcache_pod_y_i(pod_y_cord_width_p'(2*y))
        ,.north_bsg_tag_i(pod_tags_i[y][x][N])

        ,.south_wh_link_sif_i(wh_link_sif_li[y][S][x])
        ,.south_wh_link_sif_o(wh_link_sif_lo[y][S][x])
        ,.south_vcache_pod_x_i(pod_x_cord_width_p'(x+1))
        ,.south_vcache_pod_y_i(pod_y_cord_width_p'((2*y)+2))
        ,.south_bsg_tag_i(pod_tags_i[y][x][S])

        ,.pod_x_i(pod_x_cord_width_p'(x+1))
        ,.pod_y_i(pod_y_cord_width_p'((2*y)+1))
      );

    end
  end

  // connect vertical local links between pods
  for (genvar i = 0; i < num_pods_y_p-1; i++) begin
    for (genvar j = 0; j < num_pods_x_p; j++) begin
      assign ver_link_sif_li[i+1][j][N] = ver_link_sif_lo[i][j][S];
      assign ver_link_sif_li[i][j][S] = ver_link_sif_lo[i+1][j][N];
    end
  end

  // connect horizontal local links between pods
  for (genvar i = 0; i < num_pods_y_p; i++) begin
    for (genvar j = 0; j < num_pods_x_p-1; j++) begin
      assign hor_link_sif_li[i][j][E] = hor_link_sif_lo[i][j+1][W];
      assign hor_link_sif_li[i][j+1][W] = hor_link_sif_lo[i][j][E];
    end
  end

  // connect horizontal links on the side to the ports
  for (genvar i = 0; i < num_pods_y_p; i++) begin
    // west
    assign hor_link_sif_o[W][i] = hor_link_sif_lo[i][0][W];
    assign hor_link_sif_li[i][0][W] = hor_link_sif_i[W][i];
    // east
    assign hor_link_sif_o[E][i] = hor_link_sif_lo[i][num_pods_x_p-1][E];
    assign hor_link_sif_li[i][num_pods_x_p-1][E] = hor_link_sif_i[E][i];
  end

  // connect ruche links on the side to the ports
  for (genvar i = 0; i < num_pods_y_p; i++) begin
    // west
    assign ruche_link_o[W][i] = ruche_link_lo[i][0][W];
    assign ruche_link_li[i][0][W] = ruche_link_i[W][i];
    // east
    assign ruche_link_o[E][i] = ruche_link_lo[i][num_pods_x_p-1][E];
    assign ruche_link_li[i][num_pods_x_p-1][E] = ruche_link_i[E][i];
  end


  // io router tag_client
  logic [num_pods_x_p-1:0] io_rtr_reset;
  for (genvar i = 0; i < num_pods_x_p; i++) begin: tag_io
    bsg_tag_client #(
      .width_p(1)
      ,.default_p(0)
    ) btc_io (
      .bsg_tag_i(io_tags_i[i])
      ,.recv_clk_i(clk_i)
      ,.recv_reset_i(1'b0)
      ,.recv_new_r_o()
      ,.recv_data_r_o(io_rtr_reset[i])
    );
  end

  // instantiate io router rows (north)
  logic [(num_pods_x_p*num_tiles_x_p)-1:0] north_io_reset_r;
  for (genvar i = 0; i < num_pods_x_p; i++) begin: reset_io
    bsg_dff_chain #(
      .width_p(num_tiles_x_p)
      ,.num_stages_p(reset_depth_p)
    ) north_io_reset_dff (
      .clk_i(clk_i)
      ,.data_i({num_tiles_x_p{io_rtr_reset[i]}})
      ,.data_o(north_io_reset_r[i*num_tiles_x_p+:num_tiles_x_p])
    );
  end

  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:W] north_io_link_sif_li;
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:W] north_io_link_sif_lo;

  for (genvar i = 0; i < num_pods_x_p*num_tiles_x_p; i++) begin: north_io_x

    bsg_manycore_mesh_node #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.stub_p(4'b0100) // stub north
    ) io_rtr (
      .clk_i(clk_i)
      ,.reset_i(north_io_reset_r[i])

      ,.links_sif_i(north_io_link_sif_li[i])
      ,.links_sif_o(north_io_link_sif_lo[i])

      ,.proc_link_sif_i(io_link_sif_i[i])
      ,.proc_link_sif_o(io_link_sif_o[i])

      ,.global_x_i(x_cord_width_p'(num_tiles_x_p+i))
      ,.global_y_i(y_cord_width_p'(0))
    );
  
    // connect south link to pods
    assign ver_link_sif_li[0][i/num_tiles_x_p][N][i%num_tiles_x_p] = north_io_link_sif_lo[i][S];
    assign north_io_link_sif_li[i][S] = ver_link_sif_lo[0][i/num_tiles_x_p][N][i%num_tiles_x_p];

  
    if (i != (num_pods_x_p*num_tiles_x_p)-1) begin
      assign north_io_link_sif_li[i+1][W] = north_io_link_sif_lo[i][E];
      assign north_io_link_sif_li[i][E] = north_io_link_sif_lo[i+1][W];
    end
  end

  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) north_io_left_tieoff (
    .clk_i(clk_i)
    ,.reset_i(north_io_reset_r[0])
    ,.link_sif_i(north_io_link_sif_lo[0][W])
    ,.link_sif_o(north_io_link_sif_li[0][W])
  );

  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) north_io_right_tieoff (
    .clk_i(clk_i)
    ,.reset_i(north_io_reset_r[0])
    ,.link_sif_i(north_io_link_sif_lo[(num_pods_x_p*num_tiles_x_p)-1][E])
    ,.link_sif_o(north_io_link_sif_li[(num_pods_x_p*num_tiles_x_p)-1][E])
  );
  
  // tie off south ver links
  for (genvar i = 0; i < num_pods_x_p*num_tiles_x_p; i++) begin: stx
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
    ) south_ver_tieoff (
      .clk_i(clk_i)
      ,.reset_i(north_io_reset_r[0])
      ,.link_sif_i(ver_link_sif_lo[num_pods_y_p-1][i/num_tiles_x_p][S][i%num_tiles_x_p])
      ,.link_sif_o(ver_link_sif_li[num_pods_y_p-1][i/num_tiles_x_p][S][i%num_tiles_x_p])
    );
  end


  // connect ruche links between pods
  for (genvar i = 0; i < num_pods_y_p; i++) begin: rb_py
    for (genvar j = 0; j < num_pods_x_p-1; j++) begin: rb_px
      for (genvar k = 0; k < num_tiles_y_p; k++) begin: rb_y
        for (genvar l = 0; l < ruche_factor_X_p; l++) begin: rb_f
          assign ruche_link_li[i][j][E][k][l] = ruche_link_lo[i][j+1][W][k][l];
          assign ruche_link_li[i][j+1][W][k][l] = ruche_link_lo[i][j][E][k][l];;
        end
      end
    end
  end


  // connect wormhole ruche links between pods
  for (genvar i = 0; i < num_pods_y_p; i++) begin: wrb_y
    for (genvar m = N; m <= S; m++) begin: wrb_tb
      for (genvar j = 0; j < num_pods_x_p-1; j++) begin: wrb_x
        for (genvar l = 0; l < wh_ruche_factor_p; l++) begin: wrb_f
          assign wh_link_sif_li[i][m][j][E][l] = wh_link_sif_lo[i][m][j+1][W][l];
          assign wh_link_sif_li[i][m][j+1][W][l] = wh_link_sif_lo[i][m][j][E][l];
        end
      end
    end
  end


  // connect wormhole ruche links to the outside
  // (hardcoded for wh ruche factor 2)
  for (genvar i = 0; i < num_pods_y_p; i++) begin: wrb_out_y
    for (genvar m = N; m <= S; m++) begin: wrb_out_tb
      // west out
      assign wh_link_sif_o[W][i][m][0] =  wh_link_sif_lo[i][m][0][W][0];
      assign wh_link_sif_o[W][i][m][1] = ~wh_link_sif_lo[i][m][0][W][1];
      // west in
      assign wh_link_sif_li[i][m][0][W][0] =  wh_link_sif_i[W][i][m][0];
      assign wh_link_sif_li[i][m][0][W][1] = ~wh_link_sif_i[W][i][m][1];
      // east out
      assign wh_link_sif_o[E][i][m][0] =  wh_link_sif_lo[i][m][num_pods_x_p-1][E][0];
      assign wh_link_sif_o[E][i][m][1] = ~wh_link_sif_lo[i][m][num_pods_x_p-1][E][1];
      // east in
      assign wh_link_sif_li[i][m][num_pods_x_p-1][E][0] =  wh_link_sif_i[E][i][m][0];
      assign wh_link_sif_li[i][m][num_pods_x_p-1][E][1] = ~wh_link_sif_i[E][i][m][1];
    end
  end

endmodule
