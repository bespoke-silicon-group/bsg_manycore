`include "bsg_manycore_defines.svh"
`include "block_mem_defines.vh"

module bsg_manycore_tile_block_mem
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  import block_mem_pkg::*;
  #(parameter `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(mem_size_in_words_p) // total block mem size;

    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(icache_block_size_in_words_p)
  
    , localparam mem_addr_width_lp = `BSG_SAFE_CLOG2(mem_size_in_words_p)+2 // byte addr;
    , y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)
    , x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
    , output logic reset_o

    , input  [S:N][manycore_link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][manycore_link_sif_width_lp-1:0] ver_link_sif_o

    // manycore cord
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i

    , output logic [x_cord_width_p-1:0] global_x_o
    , output logic [y_cord_width_p-1:0] global_y_o
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);


  // reset dff
  logic reset_r;
  bsg_dff #(
    .width_p(1)
  ) reset_dff (
    .clk_i(clk_i)
    ,.data_i(reset_i)
    ,.data_o(reset_r)
  );

  assign reset_o = reset_r;


  // feedthrough coordinate bits
  logic [x_cord_width_p-1:0] global_x_r;
  logic [y_cord_width_p-1:0] global_y_r;

  bsg_dff #(
    .width_p(x_cord_width_p)
  ) x_dff (
    .clk_i(clk_i)
    ,.data_i(global_x_i)
    ,.data_o(global_x_r)
  );

  bsg_dff #(
    .width_p(y_cord_width_p)
  ) y_dff (
    .clk_i(clk_i)
    ,.data_i(global_y_i)
    ,.data_o(global_y_r)
  );

  assign global_x_o = global_x_r;
  assign global_y_o = y_cord_width_p'(global_y_r+1);


  // mesh router
  // vcache connects to P
  bsg_manycore_link_sif_s [S:W] link_sif_li, link_sif_lo;
  bsg_manycore_link_sif_s proc_link_sif_li, proc_link_sif_lo;
  
  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    // Because vcaches do not initiate packets, and there are no clients on the same Row,
    // horizontal manycore links are unnecessary.
    ,.stub_p(4'b0011) // stub E and W
    ,.rev_use_credits_p(5'b00001)
  ) rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.links_sif_i(link_sif_li)
    ,.links_sif_o(link_sif_lo)

    ,.proc_link_sif_i(proc_link_sif_li)
    ,.proc_link_sif_o(proc_link_sif_lo)

    ,.global_x_i(global_x_r)
    ,.global_y_i(global_y_r)
  );


  // connect north and south links;
  assign ver_link_sif_o[S] = link_sif_lo[S];
  assign link_sif_li[S] = ver_link_sif_i[S];
  assign ver_link_sif_o[N] = link_sif_lo[N];
  assign link_sif_li[N] = ver_link_sif_i[N];


  // link_to_block_mem;
  `declare_block_mem_pkt_s(mem_addr_width_lp,data_width_p);
  logic block_mem_v_lo;
  block_mem_pkt_s block_mem_pkt_lo;
  logic [data_width_p-1:0] block_mem_data_li;
  

  bsg_manycore_link_to_block_mem #(
    .link_addr_width_p(addr_width_p) // word_addr
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
  
    ,.mem_size_in_words_p(mem_size_in_words_p)
    ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
  ) link_to_bmem (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    // manycore side;
    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)

    // to block mem;
    ,.pkt_o(block_mem_pkt_lo)
    ,.v_o(block_mem_v_lo)
    ,.data_i(block_mem_data_li)
  
    ,.global_x_i(global_x_r)
    ,.global_y_i(global_y_r)
  );  


  // block_mem;
  bsg_manycore_block_mem #(
    .mem_size_in_words_p(mem_size_in_words_p)
    ,.data_width_p(data_width_p)
  ) bmem (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pkt_i(block_mem_pkt_lo)
    ,.v_i(block_mem_v_lo)
    ,.data_o(block_mem_data_li)
  );


endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_tile_block_mem)
