/**
 *    bsg_manycore_tile_compute_array_ruche.v
 *
 *  A compute tile with 2D mesh router with half ruche x.
 *  
 */


module bsg_manycore_tile_compute_array_ruche
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W,E,N,S }
  #(parameter dmem_size_p = "inv" // number of words in DMEM
    , parameter icache_entries_p = "inv" // in words
    , parameter icache_tag_width_p = "inv"

    , parameter vcache_size_p = "inv" // capacity per vcache in words
    , parameter vcache_block_size_in_words_p ="inv"
    , parameter vcache_sets_p = "inv"

    // change the default values from "inv" back to -1
    // since num_tiles_x_p and num_tiles_y_p will be used to define the size of 2D array
    // hetero_type_vec_p, they should be int by default to avoid tool crash during
    // synthesis (DC versions at least up to 2018.06)
    , parameter int num_tiles_x_p = -1
    , parameter int num_tiles_y_p = -1

    // This is used to define heterogeneous arrays. Each index defines
    // the type of an X/Y coordinate in the array. This is a vector of
    // num_tiles_x_p*num_tiles_y_p ints; type "0" is the
    // default. See bsg_manycore_hetero_socket.v for more types.
    , parameter int hetero_type_vec_p [0:(num_tiles_y_p*num_tiles_x_p) - 1]  = '{default:0}

    // this is the addr width on the manycore network packet (word addr).
    // also known as endpoint physical address (EPA).
    , parameter addr_width_p = "inv"
    , parameter data_width_p = "inv" // 32

    // default ruche factor
    , parameter ruche_factor_X_p=3

    // global coordinate width
    // global_x/y_i
    // pod_*cord_width_p  and *_subcord_width_lp should sum up to *_cord_width_p.
    , parameter y_cord_width_p = -1
    , parameter x_cord_width_p = -1
    // pod coordinate width
    // pod_x/y_i
    , parameter pod_y_cord_width_p = -1
    , parameter pod_x_cord_width_p = -1
    // coordinate within a pod
    // my_x/y_i
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)
    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)

    
    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    // The number of registers between the reset_i port and the reset sinks
    // Must be >= 1
    , parameter reset_depth_p = 3

    // enable debugging
    , parameter debug_p = 0
  )
  (
    input clk_i
    , input [S:N] reset_i   // the top-half of the array reset is driven by north reset pin, and the bot-half by south reset.

    // horizontal -- {E,W}
    , input [E:W][num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_o

    // vertical -- {S,N}
    , input [S:N][num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_o

    // ruche link
    , input [E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][num_tiles_y_p-1:0][ruche_factor_X_p-1:0][ruche_x_link_sif_width_lp-1:0] ruche_link_o

    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i
  );

  // synopsys translate_off
  initial begin
    assert ((num_tiles_x_p > 0) && (num_tiles_y_p > 0))
      else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
    $display("## ----------------------------------------------------------------");
    $display("## MANYCORE HETERO TYPE CONFIGURATIONS");
    $display("## ----------------------------------------------------------------");
    for (integer i=0; i < num_tiles_y_p; i++) begin
      $write("## ");
      for(integer j=0; j < num_tiles_x_p; j++) begin
        $write("%0d,", hetero_type_vec_p[i * num_tiles_x_p + j]);
      end
      $write("\n");
    end
    $display("## ----------------------------------------------------------------");
  end
  // synopsys translate_on



  // Pipeline the reset. The bsg_manycore_tile has a single pipeline register
  // on reset already, so we only want to pipeline reset_depth_p-1 times.
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0] tile_reset_r;
  
  for (genvar i = N; i <= S; i++) begin: rdff
    bsg_dff_chain #(
      .width_p(num_tiles_x_p*num_tiles_y_p/2)
      ,.num_stages_p(reset_depth_p-1)
    ) tile_reset (
      .clk_i(clk_i)
      ,.data_i({(num_tiles_x_p*num_tiles_y_p/2){reset_i[i]}})
      ,.data_o(tile_reset_r[(i-N)*(num_tiles_y_p/2)+:(num_tiles_y_p/2)])
    );
  end
  

  // Instantiate tiles.
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_in;
  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_out;
 
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][ruche_factor_X_p-1:0][E:W] ruche_link_in;   
  bsg_manycore_ruche_x_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][ruche_factor_X_p-1:0][E:W] ruche_link_out;
 

  for (genvar r = 0; r < num_tiles_y_p; r++) begin: y
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: x
      bsg_manycore_tile_compute_ruche #(
        .dmem_size_p(dmem_size_p)
        ,.vcache_size_p(vcache_size_p)
        ,.icache_entries_p(icache_entries_p)
        ,.icache_tag_width_p(icache_tag_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.pod_x_cord_width_p(pod_x_cord_width_p)
        ,.pod_y_cord_width_p(pod_y_cord_width_p)
        ,.data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.hetero_type_p(hetero_type_vec_p[(r* num_tiles_x_p)+c])
        ,.debug_p(debug_p)
        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)
        ,.ruche_factor_X_p(ruche_factor_X_p)
      ) tile (
        .clk_i(clk_i)
        ,.reset_i(tile_reset_r[r][c])

        ,.link_i(link_in[r][c])
        ,.link_o(link_out[r][c])

        ,.ruche_link_i(ruche_link_in[r][c])
        ,.ruche_link_o(ruche_link_out[r][c])

        ,.my_x_i(x_subcord_width_lp'(c))
        ,.my_y_i(y_subcord_width_lp'(r))

        ,.pod_x_i(pod_x_i)
        ,.pod_y_i(pod_y_i)
      );
    end
  end

  // stitch together all of the tiles into a mesh
  bsg_mesh_stitch #(
    .width_p(link_sif_width_lp)
    ,.x_max_p(num_tiles_x_p)
    ,.y_max_p(num_tiles_y_p)
  ) link (
    .outs_i(link_out)
    ,.ins_o(link_in)
    ,.hor_i(hor_link_sif_i)
    ,.hor_o(hor_link_sif_o)
    ,.ver_i(ver_link_sif_i)
    ,.ver_o(ver_link_sif_o)
  );


  // stitch ruche links
  for (genvar r = 0; r < num_tiles_y_p; r++) begin: rr
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: rc
      for (genvar l = 0; l < ruche_factor_X_p; l++) begin: rl    // ruche stage
        if (c == num_tiles_x_p-1) begin: cl
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
  for (genvar r = 0; r < num_tiles_y_p; r++) begin: er
    for (genvar l = 0; l < ruche_factor_X_p; l++) begin: el
      // west
      assign ruche_link_o[W][r][l] = ruche_link_out[r][0][l][W];
      assign ruche_link_in[r][0][l][W] = ruche_link_i[W][r][l];
      // east
      //assign ruche_link_o[E][r][l] = ruche_link_out[r][num_tiles_x_p-1][l][E];
      //assign ruche_link_in[r][num_tiles_x_p-1][l][E] = ruche_link_i[E][r][l];
    end
  end


endmodule
