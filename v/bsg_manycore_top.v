/**
 *    bsg_manycore toplevel.
 *
 *    Instantiates bsg_manycore and tie-offs
 *
 */

`include "bsg_manycore_packet.vh"
 
module bsg_manycore_top 
  #(parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"

    , parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter dmem_size_p="inv"
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter vcache_size_p="inv"
    , parameter vcache_sets_p="inv"
    , parameter vcache_block_size_in_words_p="inv"

    , parameter extra_io_rows_p=1

    , parameter epa_byte_addr_width_p="inv"
    , parameter dram_ch_addr_width_p="inv"
    , parameter branch_trace_en_p=0

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,)
  )
  (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] s_link_sif_i
    , output logic [link_sif_width_lp-1:0] s_link_sif_o

    , input [link_sif_width_lp-1:0] io_link_sif_i
    , output logic [link_sif_width_lp-1:0] io_link_sif_o
  );


  `declare_bsg_manycore_link_sif_s(bsg_max_epa_width_p,data_width_p,
    x_cord_width_lp,y_cord_width_lp,load_id_width_p);

  bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0] ver_link_li, ver_link_lo;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_p-1:0] hor_link_li, hor_link_lo;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_li, io_link_lo;

  bsg_manycore #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)

    ,.data_width_p(data_width_p)
    ,.addr_width_p(bsg_max_epa_width_p)
    ,.load_id_width_p(load_id_width_p)

    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)

    ,.vcache_size_p(vcache_size_p)
    ,.vcache_sets_p(bsg_vcache_set_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)

    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.branch_trace_en_p(bsg_branch_trace_en_p)
  ) manycore (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.hor_link_sif_i(hor_link_li)
    ,.hor_link_sif_o(hor_link_lo)

    ,.ver_link_sif_i(ver_link_li)
    ,.ver_link_sif_o(ver_link_lo)

    ,.io_link_sif_i(io_link_li)
    ,.io_link_sif_o(io_link_lo)
  );


  // The manycore has a 2-FF pipelined reset in 16nm, therefore we need
  // to add a 2 cycle latency to all other modules.
  logic reset_r, reset_rr;

  always_ff @ (posedge clk_i) begin
    reset_r <= reset_i;
    reset_rr <= reset_r;
  end


  // tieoffs
  //
  for (genvar i = 0; i < num_tiles_y_p; i++) begin

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_w (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(hor_link_lo[W][i])
      ,.link_sif_o(hor_link_li[W][i])
    );

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_e (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(hor_link_lo[E][i])
      ,.link_sif_o(hor_link_li[E][i])
    );
  end

  for (genvar i = 0; i < num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_n (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(ver_link_lo[N][i])
      ,.link_sif_o(ver_link_li[N][i])
    );
  end

  for (genvar i = 1; i < num_tiles_x_p; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(bsg_max_epa_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) tieoff_io (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(io_link_lo[i])
      ,.link_sif_o(io_link_li[i])
    );
  end

endmodule
