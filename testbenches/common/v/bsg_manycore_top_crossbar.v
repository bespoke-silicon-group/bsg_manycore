/**
 *    bsg_manycore_top_crossbar.v
 *
 */



module bsg_manycore_top_crossbar
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"
    
    , parameter vcache_size_p="inv"
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_sets_p="inv"

    , parameter int num_tiles_x_p=-1
    , parameter int num_tiles_y_p=-1

    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"

    , parameter y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p+2)
    , parameter x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)

    , parameter link_sif_width_lp = 
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)

    , parameter reset_depth_p = 5
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
  logic [reset_depth_p-1:0] reset_r;
  always_ff @ (posedge clk_i) begin
    for (integer k = 1; k < reset_depth_p; k++) begin
      reset_r[k] <= (k == 1)
        ? reset_i
        : reset_r[k-1];
    end
  end


  // Crossbar Network
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);
  bsg_manycore_link_sif_s [(num_tiles_y_p+2)-1:0][num_tiles_x_p-1:0] link_in;
  bsg_manycore_link_sif_s [(num_tiles_y_p+2)-1:0][num_tiles_x_p-1:0] link_out;
  logic [(num_tiles_y_p+2)-1:0][num_tiles_x_p-1:0] links_credit_lo;

  bsg_manycore_crossbar #(
    .num_in_x_p(num_tiles_x_p)
    ,.num_in_y_p(num_tiles_y_p+2)

    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)
  ) network (
    .clk_i(clk_i)
    ,.reset_i(reset_r[reset_depth_p-2])
    
    ,.links_sif_i(link_in)
    ,.links_sif_o(link_out)

    ,.links_credit_o(links_credit_lo)
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
  for (genvar i = 2; i <= num_tiles_y_p; i++) begin: py
    for (genvar j = 0; j < num_tiles_x_p; j++) begin: px
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

        ,.debug_p(0)
      ) proc (
        .clk_i(clk_i)
        ,.reset_i(reset_r[reset_depth_p-1])
      
        ,.link_sif_i(link_out[i][j])
        ,.link_sif_o(link_in[i][j])

        ,.link_credit_i(links_credit_lo[i][j])
        
        ,.my_x_i((x_cord_width_lp)'(j))
        ,.my_y_i((y_cord_width_lp)'(i))
      );

    end
  end




endmodule
