/**
 *  test_bsg_manycore.v
 *
 */

`include "bsg_manycore_packet.vh"

`ifndef bsg_global_X
`error bsg_global_X must be defined; pass it in through the makefile;
`endif

`ifndef bsg_global_Y
`error bsg_global_Y must be defined; pass it in through the makefile;
`endif

`define MAX_CYCLES 1000000

module test_bsg_manycore;

  import bsg_noc_pkg::*; // {P=0, W, E, N, S}

  localparam int bsg_hetero_type_vec_lp [0:`bsg_global_Y-1][0:`bsg_global_X-1] = '{`bsg_hetero_type_vec};
  localparam cycle_time_lp = 20; // clock period
  localparam max_cycles_lp = `MAX_CYCLES;

  localparam num_tiles_x_lp = `bsg_global_X;
  localparam num_tiles_y_lp = `bsg_global_Y;
  localparam extra_io_rows_lp = 1;

  localparam lg_node_x_lp = `BSG_SAFE_CLOG2(num_tiles_x_lp);
  localparam lg_node_y_lp = `BSG_SAFE_CLOG2(num_tiles_y_lp + extra_io_rows_lp);

  localparam data_width_lp = 32;
  localparam addr_width_lp = 32-2-1-lg_node_x_lp+1;
  localparam load_id_width_lp = 12;

  localparam dmem_size_lp = 1024;
  localparam icache_entries_num_lp = 1024;
  localparam icache_tag_width_lp = 12;
  localparam epa_byte_addr_width_lp = 18;
  localparam dram_ch_addr_width_lp =  32-2-1-lg_node_x_lp; // 2MB;

  localparam debug_lp = 0;


  // clock and reset generation
  //
  wire clk;
  wire reset;

  bsg_nonsynth_clock_gen #(
    .cycle_time_p(cycle_time_lp)
  ) clock_gen (
    .o(clk)
  );

  bsg_nonsynth_reset_gen #(
    .num_clocks_p(1)
    ,.reset_cycles_lo_p(1)
    ,.reset_cycles_hi_p(10)
  ) reset_gen (
    .clk_i(clk)
    ,.async_reset_o(reset)
  );

  // The manycore has a 2-FF pipelined reset in 16nm, therefore we need
  // to add a 2 cycle latency to all other modules.
  logic reset_r, reset_rr;

  always_ff @ (posedge clk) begin
    reset_r <= reset;
    reset_rr <= reset_r;
  end


  `declare_bsg_manycore_link_sif_s(addr_width_lp,data_width_lp,
    lg_node_x_lp,lg_node_y_lp,load_id_width_lp);

  bsg_manycore_link_sif_s [S:N][num_tiles_x_lp-1:0] ver_link_li, ver_link_lo;
  bsg_manycore_link_sif_s [E:W][num_tiles_y_lp-1:0] hor_link_li, hor_link_lo;
  bsg_manycore_link_sif_s [num_tiles_x_lp-1:0] io_link_li, io_link_lo;

  bsg_manycore #(
    .dmem_size_p(dmem_size_lp)
    ,.icache_entries_p(icache_entries_num_lp)
    ,.icache_tag_width_p(icache_tag_width_lp)
    ,.data_width_p(data_width_lp)
    ,.addr_width_p(addr_width_lp)
    ,.load_id_width_p(load_id_width_lp)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_lp)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_lp )
    ,.dram_ch_start_col_p (1'b0)
    ,.num_tiles_x_p(num_tiles_x_lp)
    ,.num_tiles_y_p(num_tiles_y_lp)
    ,.extra_io_rows_p(extra_io_rows_lp)
    ,.hetero_type_vec_p(bsg_hetero_type_vec_lp)
    ,.stub_w_p({num_tiles_y_lp{1'b0}})
    ,.stub_e_p({num_tiles_y_lp{1'b0}})
    ,.stub_n_p({num_tiles_x_lp{1'b0}})
    ,.stub_s_p({num_tiles_x_lp{1'b0}})
    ,.debug_p(debug_lp)
  ) UUT (
    .clk_i(clk)
    ,.reset_i (reset)

    ,.hor_link_sif_i(hor_link_li)
    ,.hor_link_sif_o(hor_link_lo)

    ,.ver_link_sif_i(ver_link_li)
    ,.ver_link_sif_o(ver_link_lo)

    ,.io_link_sif_i(io_link_li)
    ,.io_link_sif_o(io_link_lo)
  );
  
  // tie off
  //
  for (genvar i = 0; i < num_tiles_y_lp; i++) begin

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_lp)
      ,.data_width_p(data_width_lp)
      ,.load_id_width_p(load_id_width_lp)
      ,.x_cord_width_p(lg_node_x_lp)
      ,.y_cord_width_p(lg_node_y_lp)
    ) tieoff_w (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(hor_link_lo[W][i])
      ,.link_sif_o(hor_link_li[W][i])
    );

    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_lp)
      ,.data_width_p(data_width_lp)
      ,.load_id_width_p(load_id_width_lp)
      ,.x_cord_width_p(lg_node_x_lp)
      ,.y_cord_width_p(lg_node_y_lp)
    ) tieoff_e (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(hor_link_lo[E][i])
      ,.link_sif_o(hor_link_li[E][i])
    );
  end


  for (genvar i = 0; i < num_tiles_x_lp; i++) begin
    bsg_manycore_link_sif_tieoff #(
      .addr_width_p(addr_width_lp)
      ,.data_width_p(data_width_lp)
      ,.load_id_width_p(load_id_width_lp)
      ,.x_cord_width_p(lg_node_x_lp)
      ,.y_cord_width_p(lg_node_y_lp)
    ) tieoff_n (
      .clk_i(clk)
      ,.reset_i(reset_rr)
      ,.link_sif_i(ver_link_lo[N][i])
      ,.link_sif_o(ver_link_li[N][i])
    );
  end

  // instantiate the loader and moniter
  //
  logic finish_lo;

  bsg_nonsynth_manycore_io_complex #(
    .icache_entries_num_p(icache_entries_num_lp)
    ,.addr_width_p(addr_width_lp)
    ,.load_id_width_p(load_id_width_lp)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_lp)
    ,.dram_ch_addr_width_p( dram_ch_addr_width_lp)
    ,.data_width_p(data_width_lp)
    ,.extra_io_rows_p ( extra_io_rows_lp )
	  ,.max_cycles_p(max_cycles_lp)
    ,.num_tiles_x_p(num_tiles_x_lp)
    ,.num_tiles_y_p(num_tiles_y_lp)
    ,.include_vcache_p(`enable_vcache)
  ) io(
    .clk_i(clk)
    ,.reset_i(reset_rr)
    ,.ver_link_sif_i(ver_link_lo[S])
    ,.ver_link_sif_o(ver_link_li[S])
    ,.io_link_sif_i(io_link_lo)
    ,.io_link_sif_o(io_link_li)
    ,.finish_lo(finish_lo)
    ,.success_lo()
    ,.timeout_lo()
  );

  // vanilla core tracer
  //
  if (1) begin
    bind bsg_manycore_proc_vanilla bsg_manycore_proc_vanilla_trace #(
      .x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.icache_tag_width_p(icache_tag_width_p)
      ,.icache_entries_p(icache_entries_p)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.dmem_size_p(dmem_size_p)
    ) vanilla_tracer (
      .*
    );
  end


endmodule


