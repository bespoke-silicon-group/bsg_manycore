/**
 *    bsg_manycore_tile_compute_array_ruche.v
 *
 *    A compute tile with 2D mesh router with half ruche x.
 *  
 */

`include "bsg_manycore_defines.vh"

module bsg_manycore_tile_compute_array_ruche
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W,E,N,S }
  #(`BSG_INV_PARAM(dmem_size_p ) // number of words in DMEM
    , `BSG_INV_PARAM(icache_entries_p ) // in words
    , `BSG_INV_PARAM(icache_tag_width_p )
    , `BSG_INV_PARAM(icache_block_size_in_words_p)

    , `BSG_INV_PARAM(num_vcache_rows_p )
    , `BSG_INV_PARAM(vcache_size_p ) // capacity per vcache in words
    , `BSG_INV_PARAM(vcache_block_size_in_words_p )
    , `BSG_INV_PARAM(vcache_sets_p )

    // change the default values from "inv" back to -1
    // since num_tiles_x_p and num_tiles_y_p will be used to define the size of 2D array
    // hetero_type_vec_p, they should be int by default to avoid tool crash during
    // DC synthesis (versions at least up to 2018.06)

    // Number of tiles in the entire pod
    , `BSG_INV_PARAM(parameter int num_tiles_x_p)
    , `BSG_INV_PARAM(parameter int num_tiles_y_p)

    // Number of tiles in this subarray.
    , `BSG_INV_PARAM(subarray_num_tiles_x_p)
    , `BSG_INV_PARAM(subarray_num_tiles_y_p)

    // This is used to define heterogeneous arrays. Each index defines
    // the type of an X/Y coordinate in the array. This is a vector of
    // num_tiles_x_p*num_tiles_y_p ints; type "0" is the
    // default. See bsg_manycore_hetero_socket.v for more types.
    , parameter int hetero_type_vec_p [0:(subarray_num_tiles_y_p*subarray_num_tiles_x_p) - 1]  = '{default:0}

    // this is the addr width on the manycore network packet (word addr).
    // also known as endpoint physical address (EPA).
    , `BSG_INV_PARAM(addr_width_p )
    , `BSG_INV_PARAM(data_width_p ) // 32

    // default ruche factor
    , ruche_factor_X_p=3
    // barrier ruche factor
    , barrier_ruche_factor_X_p=3

    // global coordinate width
    // global_x/y_i
    // pod_*_cord_width_p  and *_subcord_width_p should sum up to *_cord_width_p.
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)

    // pod coordinate width
    // pod_x/y_i
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)

    , num_clk_ports_p=1

    // coordinate within a pod
    // my_x/y_i
    // A multiple of these modules can be instantiated within a pod as a subarray to form a larger array.
    , localparam y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)
    , x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)

    
    , link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    // The number of registers between the reset_i port and the reset sinks
    // Must be >= 1
    , parameter reset_depth_p = 3

    // enable debugging
    , debug_p = 0
  )
  (
    input [num_clk_ports_p-1:0] clk_i

    , input [subarray_num_tiles_x_p-1:0] reset_i
    , output logic [subarray_num_tiles_x_p-1:0] reset_o
  
    // horizontal -- {E,W}
    , input [E:W][subarray_num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][subarray_num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_o

    // vertical -- {S,N}
    , input [S:N][subarray_num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][subarray_num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_o

    // ruche link
    , input [E:W][subarray_num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][subarray_num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_o

    // barrier local link
    , input  [S:N][subarray_num_tiles_x_p-1:0] ver_barrier_link_i
    , output [S:N][subarray_num_tiles_x_p-1:0] ver_barrier_link_o
    , input  [E:W][subarray_num_tiles_y_p-1:0] hor_barrier_link_i
    , output [E:W][subarray_num_tiles_y_p-1:0] hor_barrier_link_o
    // barrier ruche link
    , input  [E:W][subarray_num_tiles_y_p-1:0][barrier_ruche_factor_X_p-1:0] barrier_ruche_link_i
    , output [E:W][subarray_num_tiles_y_p-1:0][barrier_ruche_factor_X_p-1:0] barrier_ruche_link_o

    // global coordinates
    , input [subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_i
    , input [subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_i
    , output [subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_o
    , output [subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_o
  );

  // synopsys translate_off
  initial begin
    assert ((subarray_num_tiles_x_p > 0) && (subarray_num_tiles_y_p > 0))
      else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
    $display("## ----------------------------------------------------------------");
    $display("## MANYCORE HETERO TYPE CONFIGURATIONS");
    $display("## ----------------------------------------------------------------");
    for (integer i=0; i < subarray_num_tiles_y_p; i++) begin
      $write("## ");
      for(integer j=0; j < subarray_num_tiles_x_p; j++) begin
        $write("%0d,", hetero_type_vec_p[i * subarray_num_tiles_x_p + j]);
      end
      $write("\n");
    end
    $display("## ----------------------------------------------------------------");
  end
  // synopsys translate_on



  

  // Instantiate tiles.
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][S:W] link_in;
  bsg_manycore_link_sif_s [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][S:W] link_out;
 
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][ruche_factor_X_p-1:0][E:W] ruche_link_in;   
  bsg_manycore_ruche_x_link_sif_s [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][ruche_factor_X_p-1:0][E:W] ruche_link_out;
 
  logic [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][x_cord_width_p-1:0] global_x_li, global_x_lo;
  logic [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][y_cord_width_p-1:0] global_y_li, global_y_lo;

  logic [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0] reset_li, reset_lo;

  logic [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][S:W] barrier_link_li, barrier_link_lo;
  logic [subarray_num_tiles_y_p-1:0][subarray_num_tiles_x_p-1:0][barrier_ruche_factor_X_p-1:0][E:W] barrier_ruche_link_li, barrier_ruche_link_lo;

  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin: y
    for (genvar c = 0; c < subarray_num_tiles_x_p; c++) begin: x
      bsg_manycore_tile_compute_ruche #(
        .dmem_size_p(dmem_size_p)
        ,.vcache_size_p(vcache_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)
        ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.hetero_type_p(hetero_type_vec_p[(r*subarray_num_tiles_x_p)+c])
        ,.debug_p(debug_p)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.num_vcache_rows_p(num_vcache_rows_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.ruche_factor_X_p(ruche_factor_X_p)
        ,.barrier_ruche_factor_X_p(barrier_ruche_factor_X_p)
      ) tile (
        .clk_i(clk_i[c/(subarray_num_tiles_x_p/num_clk_ports_p)])

        ,.reset_i(reset_li[r][c])
        ,.reset_o(reset_lo[r][c])

        ,.link_i(link_in[r][c])
        ,.link_o(link_out[r][c])

        ,.ruche_link_i(ruche_link_in[r][c])
        ,.ruche_link_o(ruche_link_out[r][c])

        ,.barrier_link_i(barrier_link_li[r][c])
        ,.barrier_link_o(barrier_link_lo[r][c])
        ,.barrier_ruche_link_i(barrier_ruche_link_li[r][c])
        ,.barrier_ruche_link_o(barrier_ruche_link_lo[r][c])

        ,.global_x_i(global_x_li[r][c])
        ,.global_y_i(global_y_li[r][c])

        ,.global_x_o(global_x_lo[r][c])
        ,.global_y_o(global_y_lo[r][c])
      );

      // connect north
      if (r == 0) begin
        assign global_x_li[r][c] = global_x_i[c];
        assign global_y_li[r][c] = global_y_i[c];

        assign reset_li[r][c] = reset_i[c];
      end

      // connect south
      if (r == subarray_num_tiles_y_p-1) begin
        assign global_x_o[c] = global_x_lo[r][c];
        assign global_y_o[c] = global_y_lo[r][c];
  
        assign reset_o[c] = reset_lo[r][c];
      end

      // connect between rows
      if (r < subarray_num_tiles_y_p-1) begin
        assign global_x_li[r+1][c] = global_x_lo[r][c];
        assign global_y_li[r+1][c] = global_y_lo[r][c];

        assign reset_li[r+1][c] = reset_lo[r][c];
      end

    end
  end


  // stitch together all of the tiles into a mesh
  logic [E:W][subarray_num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_li;
  logic [E:W][subarray_num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_lo;

  bsg_mesh_stitch #(
    .width_p(link_sif_width_lp)
    ,.x_max_p(subarray_num_tiles_x_p)
    ,.y_max_p(subarray_num_tiles_y_p)
  ) link (
    .outs_i(link_out)
    ,.ins_o(link_in)
    ,.hor_i(hor_link_sif_li)
    ,.hor_o(hor_link_sif_lo)
    ,.ver_i(ver_link_sif_i)
    ,.ver_o(ver_link_sif_o)
  );

  assign hor_link_sif_li[W] = hor_link_sif_i[W];
  assign hor_link_sif_o[W] = hor_link_sif_lo[W];
  
  
  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin: lr
    bsg_buf #(
      .width_p(link_sif_width_lp)
      ,.harden_p(1)
    ) lb_e (
      .i(hor_link_sif_lo[E][r])
      ,.o(hor_link_sif_o[E][r])
    );

    bsg_buf #(
      .width_p(link_sif_width_lp)
      ,.harden_p(1)
    ) lb_w (
      .i(hor_link_sif_i[E][r])
      ,.o(hor_link_sif_li[E][r])
    );
  end
  
  // Ruche Connection Diagram:
  // For ruche factor 3
  // https://docs.google.com/presentation/d/1MdQODg7RtSm3qP2aIDhG5b7j58DfMFEDun-4yWoRzcw/edit#slide=id.p

  // stitch ruche links
  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin: rr
    for (genvar c = 0; c < subarray_num_tiles_x_p; c++) begin: rc
      for (genvar l = 0; l < ruche_factor_X_p; l++) begin: rl    // ruche stage
        if (c == subarray_num_tiles_x_p-1) begin: cl
          bsg_ruche_buffer #(
            .width_p(ruche_x_link_sif_width_lp)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_w (
            .i(ruche_link_i[E][r][l])
            ,.o(ruche_link_in[r][c][(l+ruche_factor_X_p-1) % ruche_factor_X_p][E])
          );

          bsg_ruche_buffer #(
            .width_p(ruche_x_link_sif_width_lp)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_e (
            .i(ruche_link_out[r][c][l][E])
            ,.o(ruche_link_o[E][r][(l+1)%ruche_factor_X_p])
          );
        end
        else begin: cn
          bsg_ruche_buffer #(
            .width_p(ruche_x_link_sif_width_lp)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_w (
            .i(ruche_link_out[r][c+1][l][W])
            ,.o(ruche_link_in[r][c][(l+ruche_factor_X_p-1) % ruche_factor_X_p][E])
          );

          bsg_ruche_buffer #(
            .width_p(ruche_x_link_sif_width_lp)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) rb_e (
            .i(ruche_link_out[r][c][l][E])
            ,.o(ruche_link_in[r][c+1][(l+1)%ruche_factor_X_p][W])
          );
        end
      end
    end
  end


  // edge ruche links
  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin: er
    for (genvar l = 0; l < ruche_factor_X_p; l++) begin: el
      // west
      assign ruche_link_o[W][r][l] = ruche_link_out[r][0][l][W];
      assign ruche_link_in[r][0][l][W] = ruche_link_i[W][r][l];
    end
  end



  // stitch local barrier links
  logic [E:W][subarray_num_tiles_y_p-1:0] hor_barrier_link_li, hor_barrier_link_lo;
  bsg_mesh_stitch #(
    .width_p(1)
    ,.x_max_p(subarray_num_tiles_x_p)
    ,.y_max_p(subarray_num_tiles_y_p)
  ) barr_link (
    .outs_i(barrier_link_lo)
    ,.ins_o(barrier_link_li)
    ,.hor_i(hor_barrier_link_li)
    ,.hor_o(hor_barrier_link_lo)
    ,.ver_i(ver_barrier_link_i)
    ,.ver_o(ver_barrier_link_o)
  );

  assign hor_barrier_link_li[W] = hor_barrier_link_i[W];
  assign hor_barrier_link_o[W] = hor_barrier_link_lo[W];
  
  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin: belr
    bsg_buf #(.width_p(1),.harden_p(1)) bb_e (
      .i(hor_barrier_link_lo[E][r])
      ,.o(hor_barrier_link_o[E][r])
    );
    bsg_buf #(.width_p(1),.harden_p(1)) bb_w (
      .i(hor_barrier_link_i[E][r])
      ,.o(hor_barrier_link_li[E][r])
    );
  end

  // stitch barrier ruche link
  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin: brr
    for (genvar c = 0; c < subarray_num_tiles_x_p; c++) begin: brc
      for (genvar l = 0; l < ruche_factor_X_p; l++) begin: brl
        if (c == subarray_num_tiles_x_p-1) begin: cl
          bsg_ruche_buffer #(
            .width_p(1)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) brb_w (
            .i(barrier_ruche_link_i[E][r][l])
            ,.o(barrier_ruche_link_li[r][c][(l+ruche_factor_X_p-1) % ruche_factor_X_p][E])
          );

          bsg_ruche_buffer #(
            .width_p(1)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) brb_e (
            .i(barrier_ruche_link_lo[r][c][l][E])
            ,.o(barrier_ruche_link_o[E][r][(l+1)%ruche_factor_X_p])
          );
        end
        else begin: cn
          bsg_ruche_buffer #(
            .width_p(1)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) brb_w (
            .i(barrier_ruche_link_lo[r][c+1][l][W])
            ,.o(barrier_ruche_link_li[r][c][(l+ruche_factor_X_p-1) % ruche_factor_X_p][E])
          );

          bsg_ruche_buffer #(
            .width_p(1)
            ,.ruche_factor_p(ruche_factor_X_p)
            ,.ruche_stage_p(l)
            ,.harden_p(1)
          ) brb_e (
            .i(barrier_ruche_link_lo[r][c][l][E])
            ,.o(barrier_ruche_link_li[r][c+1][(l+1)%ruche_factor_X_p][W])
          );
        end
      end
    end
  end

  // edge barrier ruche links
  for (genvar r = 0; r < subarray_num_tiles_y_p; r++) begin
    for (genvar l = 0; l < ruche_factor_X_p; l++) begin
      // west
      assign barrier_ruche_link_o[W][r][l] = barrier_ruche_link_lo[r][0][l][W];
      assign barrier_ruche_link_li[r][0][l][W] = barrier_ruche_link_i[W][r][l];
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_tile_compute_array_ruche)
