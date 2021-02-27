/**
 *    bsg_manycore_tile_vcache_array.v
 *  
 *    This module instantiates vcaches and associated ruche buffers.
 */



module bsg_manycore_tile_vcache_array
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"

    // Number of tiles in a pod
    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    
    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    // Number of tiles in a subarray 
    , parameter subarray_num_tiles_x_p="inv"

    , parameter vcache_addr_width_p ="inv"
    , parameter vcache_data_width_p ="inv"
    , parameter vcache_ways_p="inv"
    , parameter vcache_sets_p="inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_dma_data_width_p="inv"

    , parameter wh_ruche_factor_p="inv"
    , parameter wh_cid_width_p="inv"
    , parameter wh_flit_width_p="inv"
    , parameter wh_len_width_p="inv"
    , parameter wh_cord_width_p="inv"

    //, parameter reset_depth_p = 3

    , parameter manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter wh_link_sif_width_lp = 
      `bsg_ready_and_link_sif_width(wh_flit_width_p)
  )
  (
    input clk_i
    , input [subarray_num_tiles_x_p-1:0] reset_i
    , output logic [subarray_num_tiles_x_p-1:0] reset_o

    , input  [E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [E:W][wh_ruche_factor_p-1:0][wh_link_sif_width_lp-1:0] wh_link_sif_o  
    
    , input  [S:N][subarray_num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][subarray_num_tiles_x_p-1:0][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // coord id
    , input [subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    , input [subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
    , output [subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_o
    , output [subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_o


    // wormhole dest cord
    , input [subarray_num_tiles_x_p-1:0] wh_dest_east_not_west_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p, wh_link_sif_s);

  bsg_manycore_link_sif_s [subarray_num_tiles_x_p-1:0][S:N] ver_link_sif_li;
  bsg_manycore_link_sif_s [subarray_num_tiles_x_p-1:0][S:N] ver_link_sif_lo;
  wh_link_sif_s [subarray_num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] wh_link_sif_li;
  wh_link_sif_s [subarray_num_tiles_x_p-1:0][wh_ruche_factor_p-1:0][E:W] wh_link_sif_lo;




  // instantiate vcaches.
  for (genvar i = 0; i < subarray_num_tiles_x_p; i++) begin: vc_x
    bsg_manycore_tile_vcache #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
  
      ,.vcache_addr_width_p(vcache_addr_width_p)
      ,.vcache_data_width_p(vcache_data_width_p)
      ,.vcache_ways_p(vcache_ways_p)
      ,.vcache_sets_p(vcache_sets_p)
      ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
      ,.vcache_dma_data_width_p(vcache_dma_data_width_p)

      ,.wh_ruche_factor_p(wh_ruche_factor_p)
      ,.wh_cid_width_p(wh_cid_width_p)
      ,.wh_flit_width_p(wh_flit_width_p)
      ,.wh_len_width_p(wh_len_width_p)
      ,.wh_cord_width_p(wh_cord_width_p)
    ) vc (
      .clk_i(clk_i)
      ,.reset_i(reset_i[i])
      ,.reset_o(reset_o[i])

      ,.wh_link_sif_i(wh_link_sif_li[i])
      ,.wh_link_sif_o(wh_link_sif_lo[i])

      ,.ver_link_sif_i(ver_link_sif_li[i])
      ,.ver_link_sif_o(ver_link_sif_lo[i])

      ,.global_x_i(global_x_i[i])
      ,.global_y_i(global_y_i[i])

      ,.global_x_o(global_x_o[i])
      ,.global_y_o(global_y_o[i])

      ,.wh_dest_east_not_west_i(wh_dest_east_not_west_i[i])
    );
  end


  
  // connect ver link
  for (genvar i = 0; i < subarray_num_tiles_x_p; i++) begin
    // north
    assign ver_link_sif_o[N][i] = ver_link_sif_lo[i][N];
    assign ver_link_sif_li[i][N] = ver_link_sif_i[N][i];
    // south
    assign ver_link_sif_o[S][i] = ver_link_sif_lo[i][S];
    assign ver_link_sif_li[i][S] = ver_link_sif_i[S][i];
  end

  // connect wh ruche link
  for (genvar c = 0; c < subarray_num_tiles_x_p; c++) begin: rc
    for (genvar l = 0; l < wh_ruche_factor_p; l++) begin: rl // ruche stage
      if (c == subarray_num_tiles_x_p-1) begin: cl
        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) rb_w (
          .i(wh_link_sif_i[E][l])
          ,.o(wh_link_sif_li[c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E])
        );

        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) rb_e (
          .i(wh_link_sif_lo[c][l][E])
          ,.o(wh_link_sif_o[E][(l+1) % wh_ruche_factor_p])
        );
      end
      else begin: cn
        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) rb_w (
          .i(wh_link_sif_lo[c+1][l][W])
          ,.o(wh_link_sif_li[c][(l+wh_ruche_factor_p-1) % wh_ruche_factor_p][E])
        );

        bsg_ruche_buffer #(
          .width_p(wh_link_sif_width_lp)
          ,.ruche_factor_p(wh_ruche_factor_p)
          ,.ruche_stage_p(l)
          ,.harden_p(1)
        ) rb_e (
          .i(wh_link_sif_lo[c][l][E])
          ,.o(wh_link_sif_li[c+1][(l+1) % wh_ruche_factor_p][W])
        );

      end
    end
  end


  // connect edge ruche links
  for (genvar l = 0; l < wh_ruche_factor_p; l++) begin
    //  west
    assign wh_link_sif_o[W][l] = wh_link_sif_lo[0][l][W];
    assign wh_link_sif_li[0][l][W] = wh_link_sif_i[W][l];
    //  east
    //assign wh_link_sif_o[E][l] = wh_link_sif_lo[num_tiles_x_p-1][l][E];
    //assign wh_link_sif_li[num_tiles_x_p-1][l][E] = wh_link_sif_i[E][l];
  end 



endmodule
