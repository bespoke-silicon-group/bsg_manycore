/**
 *    bsg_manycore_top_crossbar.v
 *
 */

`include "bsg_manycore_defines.svh"

module bsg_manycore_top_crossbar
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(dmem_size_p)
    , parameter `BSG_INV_PARAM(icache_entries_p)
    , parameter `BSG_INV_PARAM(icache_tag_width_p)
    
    , parameter `BSG_INV_PARAM(vcache_size_p)
    , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , parameter `BSG_INV_PARAM(vcache_sets_p)

    , parameter int num_tiles_x_p=-1
    , parameter int num_tiles_y_p=-1

    , parameter `BSG_INV_PARAM(addr_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)

    , parameter y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p+2)
    , parameter x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)

    , parameter num_in_x_lp = num_tiles_x_p
    , parameter num_in_y_lp = num_tiles_y_p+2
    , parameter num_in_lp = (num_in_x_lp*num_in_y_lp)

    , parameter link_sif_width_lp = 
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)

    , parameter reset_depth_p = 3

    , parameter fwd_fifo_els_p = 32
    , parameter rev_fifo_els_p = 32
  )
  (
    input clk_i
    , input reset_i

    , input [S:N][num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_o

    , input [num_tiles_x_p-1:0][link_sif_width_lp-1:0] io_link_sif_i
    , output [num_tiles_x_p-1:0][link_sif_width_lp-1:0] io_link_sif_o
  );

  // reset_r
  logic reset_r;
  bsg_dff_chain #(
    .width_p(1)
    ,.num_stages_p(reset_depth_p)
  ) dff_reset (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );

  // Crossbar Network
  typedef int fifo_els_arr_t[num_in_lp-1:0];

  function logic [num_in_lp-1:0] get_fwd_use_credits();
    logic [num_in_lp-1:0] retval;
    for (int i = 0; i < 2; i++) begin
      for (int j = 0; j < num_in_x_lp; j++) begin
        retval[(i*num_in_x_lp)+j] = 1'b0;
      end
    end

    for (int i = num_in_y_lp-1; i < num_in_y_lp; i++) begin
      for (int j = 0; j < num_in_x_lp; j++) begin
        retval[(i*num_in_x_lp)+j] = 1'b0;
      end
    end

    // vanilla core uses credit interface for fwd P-port.
    for (int i = 2; i < num_in_y_lp-1; i++) begin
      for (int j = 0; j < num_in_x_lp; j++) begin
        retval[(i*num_in_x_lp)+j] = 1'b1;
      end
    end
    return retval;
  endfunction

  function fifo_els_arr_t get_fwd_fifo_els();
    fifo_els_arr_t retval;

    for (int i = 0; i < num_in_y_lp; i++) begin
      for (int j = 0; j < num_in_x_lp; j++) begin
        retval[(i*num_in_x_lp)+j] = fwd_fifo_els_p;
      end
    end

    return retval;
  endfunction

  function logic [num_in_lp-1:0] get_rev_use_credits();
    logic [num_in_lp-1:0] retval;
    for (int i = 0; i < num_in_y_lp; i++) begin
      for (int j = 0; j < num_in_x_lp; j++) begin
        retval[(i*num_in_x_lp)+j] = 1'b0;
      end
    end
    return retval;
  endfunction

  function fifo_els_arr_t get_rev_fifo_els();
    fifo_els_arr_t retval;

    for (int i = 0; i < num_in_y_lp; i++) begin
      for (int j = 0; j < num_in_x_lp; j++) begin
        retval[(i*num_in_x_lp)+j] = rev_fifo_els_p;
      end
    end

    return retval;
  endfunction

  localparam int fwd_fifo_els_lp[num_in_lp-1:0] = get_fwd_fifo_els();

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);
  bsg_manycore_link_sif_s [num_in_y_lp-1:0][num_in_x_lp-1:0] link_in;
  bsg_manycore_link_sif_s [num_in_y_lp-1:0][num_in_x_lp-1:0] link_out;

  bsg_manycore_crossbar #(
    .num_in_x_p(num_in_x_lp)
    ,.num_in_y_p(num_in_y_lp)

    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)

    ,.fwd_use_credits_p(get_fwd_use_credits())
    ,.fwd_fifo_els_p(get_fwd_fifo_els())
    ,.rev_use_credits_p(get_rev_use_credits())
    ,.rev_fifo_els_p(get_rev_fifo_els())
  ) network (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    
    ,.links_sif_i(link_in)
    ,.links_sif_o(link_out)
  );


  // connect vertical and IO
  for (genvar i = 0; i < num_tiles_x_p; i++) begin
    assign ver_link_sif_o[N][i] = link_out[0][i]; 
    assign link_in[0][i] = ver_link_sif_i[N][i];

    assign ver_link_sif_o[S][i] = link_out[num_tiles_y_p+2-1][i];
    assign link_in[num_tiles_y_p+2-1][i] = ver_link_sif_i[S][i];

    assign io_link_sif_o[i] = link_out[1][i];
    assign link_in[1][i] = io_link_sif_i[i];
  end

  // Instantiate Vanilla Cores
  for (genvar i = 1; i < num_tiles_y_p; i++) begin: y
    for (genvar j = 0; j < num_tiles_x_p; j++) begin: x
      bsg_manycore_proc_vanilla #(
        .x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
        ,.data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)

        ,.icache_tag_width_p(icache_tag_width_p)
        ,.icache_entries_p(icache_entries_p)

        ,.dmem_size_p(dmem_size_p)
        ,.vcache_size_p(vcache_size_p)
        ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
        ,.vcache_sets_p(vcache_sets_p)

        ,.num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)

        ,.fwd_fifo_els_p(fwd_fifo_els_lp[num_tiles_x_p*2])

        ,.debug_p(0)
      ) proc (
        .clk_i(clk_i)
        ,.reset_i(reset_r)
      
        ,.link_sif_i(link_out[i+1][j])
        ,.link_sif_o(link_in[i+1][j])

        ,.my_x_i((x_cord_width_lp)'(j))
        ,.my_y_i((y_cord_width_lp)'(i+1))
      );

    end
  end




endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_top_crossbar)
