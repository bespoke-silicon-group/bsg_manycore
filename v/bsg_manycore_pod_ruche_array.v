/**
 *    bsg_manycore_pod_ruche_array.v
 *
 *    this module instantiates an array of pods and io routers on the left and right sides.
 *
 */


`include "bsg_noc_links.vh"


module bsg_manycore_pod_ruche_array
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter ruche_factor_X_p="inv"

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

    , parameter wh_ruche_factor_p="inv"
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
    , input reset_i

    // IO router proc links (north and south)
    , input  [S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] io_link_sif_i
    , output [S:N][num_pods_x_p-1:0][num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] io_link_sif_o

    // concentrated wormhole links
    , input  [E:W][2*num_pods_y_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][2*num_pods_y_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o

    // horizontal local links
    , input  [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][manycore_link_sif_width_lp-1:0] hor_link_sif_o
    
    // horizontal ruche links
    , input  [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_pods_y_p-1:0][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_o
    
    , input [E:W][wh_cord_width_p-1:0] dest_wh_cord_i
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

  wh_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][wh_ruche_factor_p-1:0] north_wh_link_sif_li;
  wh_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][wh_ruche_factor_p-1:0] north_wh_link_sif_lo;
  wh_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][wh_ruche_factor_p-1:0] south_wh_link_sif_li;
  wh_link_sif_s [num_pods_y_p-1:0][num_pods_x_p-1:0][E:W][wh_ruche_factor_p-1:0] south_wh_link_sif_lo;


  // Instantiate pods
  for (genvar y = 0; y < num_pods_y_p; y++) begin: py
    for (genvar x = 0; x < num_pods_x_p; x++) begin: px

      // if num_pods_x_p = 1, all traffics go to west.
      // if greater, the left half of the pod array traffic goes to west,
      // and the right half to east.
      wire [wh_cord_width_p-1:0] dest_wh_cord = (num_pods_x_p == 1)
        ? dest_wh_cord_i[W]
        : (x < (num_pods_x_p/2)
          ? dest_wh_cord_i[W]
          : dest_wh_cord_i[E]);

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
        ,.reset_i(reset_i)

        ,.hor_link_sif_i(hor_link_sif_li[y][x])
        ,.hor_link_sif_o(hor_link_sif_lo[y][x])
    
        ,.ver_link_sif_i(ver_link_sif_li[y][x])
        ,.ver_link_sif_o(ver_link_sif_lo[y][x])

        ,.ruche_link_i(ruche_link_li[y][x])
        ,.ruche_link_o(ruche_link_lo[y][x])

        ,.north_wh_link_sif_i(north_wh_link_sif_li[y][x])
        ,.north_wh_link_sif_o(north_wh_link_sif_lo[y][x])
        ,.north_dest_wh_cord_i(dest_wh_cord)
        ,.north_vcache_pod_x_i(pod_x_cord_width_p'(x+1))
        ,.north_vcache_pod_y_i(pod_y_cord_width_p'(2*y))

        ,.south_wh_link_sif_i(south_wh_link_sif_li[y][x])
        ,.south_wh_link_sif_o(south_wh_link_sif_lo[y][x])
        ,.south_dest_wh_cord_i(dest_wh_cord)
        ,.south_vcache_pod_x_i(pod_x_cord_width_p'(x+1))
        ,.south_vcache_pod_y_i(pod_y_cord_width_p'((2*y)+2))

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



  // instantiate io router rows (north)
  logic [(num_pods_x_p*num_tiles_x_p)-1:0] north_io_reset_r;
  bsg_dff_chain #(
    .width_p(num_pods_x_p*num_tiles_x_p)
    ,.num_stages_p(reset_depth_p)
  ) north_io_reset_dff (
    .clk_i(clk_i)
    ,.data_i({(num_pods_x_p*num_tiles_x_p){reset_i}})
    ,.data_o(north_io_reset_r)
  );

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

      ,.proc_link_sif_i(io_link_sif_i[N][i/num_tiles_x_p][i%num_tiles_x_p])
      ,.proc_link_sif_o(io_link_sif_o[N][i/num_tiles_x_p][i%num_tiles_x_p])

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
  

  // instantiate io router rows (south)
  logic [(num_pods_x_p*num_tiles_x_p)-1:0] south_io_reset_r;
  bsg_dff_chain #(
    .width_p(num_pods_x_p*num_tiles_x_p)
    ,.num_stages_p(reset_depth_p)
  ) south_io_reset_dff (
    .clk_i(clk_i)
    ,.data_i({(num_pods_x_p*num_tiles_x_p){reset_i}})
    ,.data_o(south_io_reset_r)
  );


  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:W] south_io_link_sif_li;
  bsg_manycore_link_sif_s [(num_pods_x_p*num_tiles_x_p)-1:0][S:W] south_io_link_sif_lo;

  for (genvar i = 0; i < num_pods_x_p*num_tiles_x_p; i++) begin: south_io_x
    bsg_manycore_mesh_node #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.stub_p(4'b1000) // stub south
    ) io_rtr (
      .clk_i(clk_i)
      ,.reset_i(south_io_reset_r[i])

      ,.links_sif_i(south_io_link_sif_li[i])
      ,.links_sif_o(south_io_link_sif_lo[i])

      ,.proc_link_sif_i(io_link_sif_i[S][i/num_tiles_x_p][i%num_tiles_x_p])
      ,.proc_link_sif_o(io_link_sif_o[S][i/num_tiles_x_p][i%num_tiles_x_p])

      ,.global_x_i(x_cord_width_p'(num_tiles_x_p+i))
      ,.global_y_i({y_cord_width_p{1'b1}})
    );
  
    // connect north link to pods
    assign ver_link_sif_li[num_pods_y_p-1][i/num_tiles_x_p][S][i%num_tiles_x_p] = south_io_link_sif_lo[i][N];
    assign south_io_link_sif_li[i][N] = ver_link_sif_lo[num_pods_y_p-1][i/num_tiles_x_p][S][i%num_tiles_x_p];

    if (i != (num_pods_x_p*num_tiles_x_p)-1) begin
      assign south_io_link_sif_li[i+1][W] = south_io_link_sif_lo[i][E];
      assign south_io_link_sif_li[i][E] = south_io_link_sif_lo[i+1][W];
    end
  end

  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) south_io_left_tieoff (
    .clk_i(clk_i)
    ,.reset_i(south_io_reset_r[0])
    ,.link_sif_i(south_io_link_sif_lo[0][W])
    ,.link_sif_o(south_io_link_sif_li[0][W])
  );

  bsg_manycore_link_sif_tieoff #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) south_io_right_tieoff (
    .clk_i(clk_i)
    ,.reset_i(south_io_reset_r[0])
    ,.link_sif_i(south_io_link_sif_lo[(num_pods_x_p*num_tiles_x_p)-1][E])
    ,.link_sif_o(south_io_link_sif_li[(num_pods_x_p*num_tiles_x_p)-1][E])
  );



  

  // connect ruche links between pods (with ruche buffers)
  for (genvar i = 0; i < num_pods_y_p; i++) begin: rb_py
    for (genvar j = 0; j < num_pods_x_p-1; j++) begin: rb_px
      for (genvar k = 0; k < num_tiles_y_p; k++) begin: rb_y
        for (genvar l = 0; l < ruche_factor_X_p; l++) begin: rb_f

          bsg_ruche_buffer #(
            .width_p(ruche_x_link_sif_width_lp)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_w (
            .i(ruche_link_lo[i][j+1][W][k][l])
            ,.o(ruche_link_li[i][j][E][k][(l+ruche_factor_X_p-1)%ruche_factor_X_p])
          );

          bsg_ruche_buffer #(
            .width_p(ruche_x_link_sif_width_lp)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_e (
            .i(ruche_link_lo[i][j][E][k][l])
            ,.o(ruche_link_li[i][j+1][W][k][(l+1)%ruche_factor_X_p])
          );

        end
      end
    end
  end


  // connect wormhole ruche links between pods (with ruche buffers)
  for (genvar i = 0; i < num_pods_y_p; i++) begin: wrb_y
    for (genvar j = 0; j < num_pods_x_p-1; j++) begin: wrb_x
      for (genvar l = 0; l < wh_ruche_factor_p; l++) begin: wrb_f
        // north wh going west
        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) north_wrb_w (
          .i(north_wh_link_sif_lo[i][j+1][W][l])
          ,.o(north_wh_link_sif_li[i][j][E][(l+wh_ruche_factor_p-1)%wh_ruche_factor_p])
        );

        // north wh going east
        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) north_wrb_e (
          .i(north_wh_link_sif_lo[i][j][E][l])
          ,.o(north_wh_link_sif_li[i][j+1][W][(l+1)%wh_ruche_factor_p])
        );

        // south wh going west
        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) south_wrb_w (
          .i(south_wh_link_sif_lo[i][j+1][W][l])
          ,.o(south_wh_link_sif_li[i][j][E][(l+wh_ruche_factor_p-1)%wh_ruche_factor_p])
        );

        // south wh going east
        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) south_wrb_e (
          .i(south_wh_link_sif_lo[i][j][E][l])
          ,.o(south_wh_link_sif_li[i][j+1][W][(l+1)%wh_ruche_factor_p])
        );
      end
    end
  end



  // instantiate wormhole concentrators
  logic [E:W][2*num_pods_y_p-1:0] wh_conc_reset_r;
  bsg_dff_chain #(
    .width_p(4*num_pods_y_p)
    ,.num_stages_p(reset_depth_p)
  ) wh_conc_reset_dff (
    .clk_i(clk_i)
    ,.data_i({(4*num_pods_y_p){reset_i}})
    ,.data_o(wh_conc_reset_r)
  );

  wh_link_sif_s [E:W][(2*num_pods_y_p)-1:0][wh_ruche_factor_p-1:0] unconc_links_li;
  wh_link_sif_s [E:W][(2*num_pods_y_p)-1:0][wh_ruche_factor_p-1:0] unconc_links_lo;

  for (genvar i = W; i <= E; i++) begin: conc_s
    for (genvar j = 0; j < num_pods_y_p*2; j++) begin: conc_y
      bsg_wormhole_concentrator #(
        .flit_width_p(wh_flit_width_p)
        ,.len_width_p(wh_len_width_p)
        ,.cid_width_p(wh_cid_width_p)
        ,.cord_width_p(wh_cord_width_p)
        ,.num_in_p(wh_ruche_factor_p)
      ) conc0 (
        .clk_i(clk_i)
        ,.reset_i(wh_conc_reset_r[i][j])
      
        ,.links_i(unconc_links_li[i][j])
        ,.links_o(unconc_links_lo[i][j])

        ,.concentrated_link_i(wh_link_sif_i[i][j])
        ,.concentrated_link_o(wh_link_sif_o[i][j])
      );
    end
  end


  // connect wormhole ruche links to the wormhole concentrators
  // (with bsg_ruche anti_buffers)
  for (genvar i = 0; i < num_pods_y_p; i++) begin: conc_wrb_y
    for (genvar l = 0; l < wh_ruche_factor_p; l++) begin: conc_wrb_f

      // north_wh west output
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(1)
        ,.input_not_output_p(0)
        ,.harden_p(1)
      ) north_abuf_west_out (
        .i(north_wh_link_sif_lo[i][0][W][l])
        ,.o(unconc_links_li[W][2*i][(wh_ruche_factor_p-l)%wh_ruche_factor_p])
      );

      // north wh west input
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(1)
        ,.input_not_output_p(1)
        ,.harden_p(1)
      ) north_abuf_west_in (
        .i(unconc_links_lo[W][2*i][(wh_ruche_factor_p-l)%wh_ruche_factor_p])
        ,.o(north_wh_link_sif_li[i][0][W][l])
      );

      // south wh west output
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(1)
        ,.input_not_output_p(0)
        ,.harden_p(1)
      ) south_abuf_west_out (
        .i(south_wh_link_sif_lo[i][0][W][l])
        ,.o(unconc_links_li[W][(2*i)+1][(wh_ruche_factor_p-l)%wh_ruche_factor_p])
      );

      // south wh_west input
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(1)
        ,.input_not_output_p(1)
        ,.harden_p(1)
      ) south_abuf_west_in (
        .i(unconc_links_lo[W][(2*i)+1][(wh_ruche_factor_p-l)%wh_ruche_factor_p])
        ,.o(south_wh_link_sif_li[i][0][W][l])
      );

      // north_wh east output
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(0)
        ,.input_not_output_p(0)
        ,.harden_p(1)
      ) north_abuf_east_out (
        .i(north_wh_link_sif_lo[i][num_pods_x_p-1][E][l])
        ,.o(unconc_links_li[E][2*i][(wh_ruche_factor_p+((num_pods_x_p*num_tiles_x_p)-1)-l)%wh_ruche_factor_p])
      );

      // north wh east input
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(0)
        ,.input_not_output_p(1)
        ,.harden_p(1)
      ) north_abuf_east_in (
        .i(unconc_links_lo[E][2*i][(wh_ruche_factor_p+((num_pods_x_p*num_tiles_x_p)-1)-l)%wh_ruche_factor_p])
        ,.o(north_wh_link_sif_li[i][num_pods_x_p-1][E][l])
      );

      // south_wh east output
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(0)
        ,.input_not_output_p(0)
        ,.harden_p(1)
      ) south_abuf_east_out (
        .i(south_wh_link_sif_lo[i][num_pods_x_p-1][E][l])
        ,.o(unconc_links_li[E][(2*i)+1][(wh_ruche_factor_p+((num_pods_x_p*num_tiles_x_p)-1)-l)%wh_ruche_factor_p])
      );

      // south wh east input
      bsg_ruche_anti_buffer #(
        .width_p(wh_link_sif_width_lp)
        ,.ruche_factor_p(wh_ruche_factor_p)
        ,.ruche_stage_p(l)
        ,.west_not_east_p(0)
        ,.input_not_output_p(1)
        ,.harden_p(1)
      ) south_abuf_east_in (
        .i(unconc_links_lo[E][(2*i)+1][(wh_ruche_factor_p+((num_pods_x_p*num_tiles_x_p)-1)-l)%wh_ruche_factor_p])
        ,.o(south_wh_link_sif_li[i][num_pods_x_p-1][E][l])
      );

    end
  end

endmodule
