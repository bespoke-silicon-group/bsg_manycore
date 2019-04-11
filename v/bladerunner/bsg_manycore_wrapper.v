/**
 *  bsg_manycore_wrapper.v
 */

`include "bsg_manycore_packet.vh"

module bsg_manycore_wrapper
  import bsg_noc_pkg::*;
  #(parameter addr_width_p="inv" // in words
    , parameter data_width_p="inv"

    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"

    , parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter epa_byte_addr_width_p="inv"
    , parameter dram_ch_addr_width_p="inv"
    , parameter load_id_width_p="inv"
 
    , parameter num_cache_p="inv"

    , parameter x_cord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_cord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p+2)
  
    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_cache_p-1:0][link_sif_width_lp-1:0] cache_link_sif_i
    , output logic [num_cache_p-1:0][link_sif_width_lp-1:0] cache_link_sif_o

    , output logic [num_cache_p-1:0][x_cord_width_lp-1:0] cache_x_o
    , output logic [num_cache_p-1:0][y_cord_width_lp-1:0] cache_y_o

    , input [link_sif_width_lp-1:0] loader_link_sif_i
    , output logic [link_sif_width_lp-1:0] loader_link_sif_o

    , input [link_sif_width_lp-1:0] rom_link_sif_i
    , output [link_sif_width_lp-1:0] rom_link_sif_o
  );

  // manycore
  //
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p);

  bsg_manycore_link_sif_s [E:W][num_tiles_y_p:0] hor_link_sif_li;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_p:0] hor_link_sif_lo;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] ver_link_sif_li;
  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] ver_link_sif_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_sif_li;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_sif_lo;
  
  bsg_manycore #(
    .dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p+1)

    ,.stub_n_p({num_tiles_x_p{1'b0}})
    ,.stub_e_p({num_tiles_y_p{1'b0}})
    ,.stub_w_p({num_tiles_y_p{1'b0}})
    ,.stub_s_p({num_tiles_x_p{1'b0}})

    ,.debug_p(0)
    ,.addr_width_p(addr_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.data_width_p(data_width_p)
    ,.load_id_width_p(load_id_width_p)
  ) manycore (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.hor_link_sif_i(hor_link_sif_li)
    ,.hor_link_sif_o(hor_link_sif_lo)

    ,.ver_link_sif_i(ver_link_sif_li)
    ,.ver_link_sif_o(ver_link_sif_lo)
    
    ,.io_link_sif_i(io_link_sif_li)
    ,.io_link_sif_o(io_link_sif_lo)
  );

  // connecting link_sif to outside
  //
  //  north[0] : bladerunner_rom
  //  north[-1]: loader

  //  south[0] : victim cache 0
  //  south[1] : victim cache 1
  //  ...
  //
  for (genvar i = 0; i < num_cache_p; i++) begin
    assign cache_link_sif_o[i] = ver_link_sif_lo[S][i];
    assign ver_link_sif_li[S][i] = cache_link_sif_i[i];
  end


  assign rom_link_sif_o = io_link_sif_lo[0];
  assign io_link_sif_li[0] = rom_link_sif_i;


  assign loader_link_sif_o = io_link_sif_lo[num_tiles_x_p-1];
  assign io_link_sif_li[num_tiles_x_p-1] = loader_link_sif_i;

  // x,y for cache
  //
  for (genvar i = 0; i < num_cache_p; i++) begin
    assign cache_x_o[i] = (x_cord_width_lp)'(i);
    assign cache_y_o[i] = (y_cord_width_lp)'(num_tiles_y_p+1);
  end
  

  // tie-off
  //
  for (genvar i = 0; i < num_tiles_y_p+1; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.load_id_width_p(load_id_width_p)
    ) tieoff_w (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.link_sif_i(hor_link_sif_lo[W][i])
      ,.link_sif_o(hor_link_sif_li[W][i])
    );
  end

  for (genvar i = 0; i < num_tiles_y_p+1; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.load_id_width_p(load_id_width_p)
    ) tieoff_e (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.link_sif_i(hor_link_sif_lo[E][i])
      ,.link_sif_o(hor_link_sif_li[E][i])
    );
  end

  for (genvar i = 0; i < num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.load_id_width_p(load_id_width_p)
    ) tieoff_n (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.link_sif_i(ver_link_sif_lo[N][i])
      ,.link_sif_o(ver_link_sif_li[N][i])
    );
  end

  for (genvar i = num_cache_p; i < num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.load_id_width_p(load_id_width_p)
    ) tieoff_s (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.link_sif_i(ver_link_sif_lo[S][i])
      ,.link_sif_o(ver_link_sif_li[S][i])
    );
  end

  for (genvar i = 1; i < num_tiles_x_p-1; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.load_id_width_p(load_id_width_p)
    ) tieoff_io (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.link_sif_i(io_link_sif_lo[i])
      ,.link_sif_o(io_link_sif_li[i])
    );
  end

endmodule
