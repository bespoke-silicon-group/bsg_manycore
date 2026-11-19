`include "bsg_manycore_defines.svh"

`ifndef BSG_TEST_RUCHE_FACTOR_Y
`define BSG_TEST_RUCHE_FACTOR_Y 3
`endif
`ifndef BSG_TEST_BARRIER_RUCHE_FACTOR_Y
`define BSG_TEST_BARRIER_RUCHE_FACTOR_Y `BSG_TEST_RUCHE_FACTOR_Y
`endif
`ifndef BSG_TEST_SUBARRAY_X
`define BSG_TEST_SUBARRAY_X 2
`endif
`ifndef BSG_TEST_SUBARRAY_Y
`define BSG_TEST_SUBARRAY_Y 2
`endif

module test_bsg_manycore_pod_ruche
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter ruche_factor_Y_p=`BSG_TEST_RUCHE_FACTOR_Y
    , barrier_ruche_factor_Y_p=`BSG_TEST_BARRIER_RUCHE_FACTOR_Y);

  localparam addr_width_p=28, data_width_p=32;
  localparam x_cord_width_p=5, y_cord_width_p=7;
  localparam cols_lp=2, rows_lp=4;
  localparam sub_x_lp=`BSG_TEST_SUBARRAY_X, sub_y_lp=`BSG_TEST_SUBARRAY_Y;
  localparam tile_x_lp=cols_lp/sub_x_lp, tile_y_lp=rows_lp/sub_y_lp;
  localparam barrier_dirs_lp=(ruche_factor_Y_p > 0) ? 9 : 7;
  localparam x_lp=5'd8, y_lp=7'd32;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(32,wh_link_sif_s);

  bit clk=0;
  always #5 clk=~clk;
  bit reset=1;
  bsg_manycore_link_sif_s [rows_lp-1:0][cols_lp-1:0] proc_in, proc_out;
  bsg_manycore_link_sif_s [S:N][cols_lp-1:0] cache_in, cache_out, edge_in, edge_out;
  bsg_manycore_link_sif_s [E:W][rows_lp-1:0] hor_in, hor_out;
  bsg_manycore_ruche_x_link_sif_s [E:W][rows_lp-1:0][1:0] hor_ruche_in;
  wh_link_sif_s [E:W][1:0] wh_in;
  logic [rows_lp-1:0][cols_lp-1:0][barrier_dirs_lp-1:0] barrier_src;
  logic [rows_lp-1:0][cols_lp-1:0][`BSG_SAFE_CLOG2(barrier_dirs_lp+1)-1:0] barrier_dest;
  logic [rows_lp-1:0][cols_lp-1:0] barrier_data, barrier_done;
  logic [rows_lp-1:0][cols_lp-1:0][S:N] y_fwd_valid, y_rev_valid;
  logic [S:N][cols_lp-1:0] cache_y_rev_valid;
  logic saw_y_fwd, saw_y_rev;
  logic [cols_lp-1:0][x_cord_width_p-1:0] global_x;
  logic [cols_lp-1:0][y_cord_width_p-1:0] global_y;

  bsg_manycore_pod_ruche #(
    .num_tiles_x_p(cols_lp)
    ,.num_tiles_y_p(rows_lp)
    ,.pod_x_cord_width_p(4)
    ,.pod_y_cord_width_p(5)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.num_subarray_x_p(sub_x_lp)
    ,.num_subarray_y_p(sub_y_lp)
    ,.dmem_size_p(1024)
    ,.icache_entries_p(1024)
    ,.icache_tag_width_p(12)
    ,.icache_block_size_in_words_p(4)
    ,.vcache_addr_width_p(29)
    ,.vcache_data_width_p(data_width_p)
    ,.vcache_ways_p(2)
    ,.vcache_sets_p(4)
    ,.vcache_block_size_in_words_p(8)
    ,.vcache_size_p(256)
    ,.vcache_dma_data_width_p(32)
    ,.vcache_word_tracking_p(1)
    ,.ipoly_hashing_p(0)
    ,.ruche_factor_X_p(2)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
    ,.barrier_ruche_factor_X_p(2)
    ,.barrier_ruche_factor_Y_p(barrier_ruche_factor_Y_p)
    ,.wh_ruche_factor_p(2)
    ,.wh_cid_width_p(2)
    ,.wh_flit_width_p(32)
    ,.wh_cord_width_p(x_cord_width_p)
    ,.wh_len_width_p(4)
  ) dut (
    .clk_i(clk)
    ,.reset_i({cols_lp{reset}})
    ,.hor_link_sif_i(hor_in)
    ,.hor_link_sif_o(hor_out)
    ,.ver_link_sif_i(edge_in)
    ,.ver_link_sif_o(edge_out)
    ,.ruche_link_i(hor_ruche_in)
    ,.ruche_link_o()
    ,.hor_barrier_link_i('0)
    ,.hor_barrier_link_o()
    ,.hor_barrier_ruche_link_i('0)
    ,.hor_barrier_ruche_link_o()
    ,.north_wh_link_sif_i(wh_in)
    ,.north_wh_link_sif_o()
    ,.south_wh_link_sif_i(wh_in)
    ,.south_wh_link_sif_o()
    ,.global_x_i(global_x)
    ,.global_y_i(global_y)
  );

  for (genvar r=0; r<rows_lp; r++) begin: row
    for (genvar c=0; c<cols_lp; c++) begin: col
      localparam sy_lp=r/tile_y_lp, sx_lp=c/tile_x_lp;
      localparam ty_lp=r%tile_y_lp, tx_lp=c%tile_x_lp;
      assign proc_out[r][c]=dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.proc_link_sif_lo;
      assign barrier_done[r][c]=dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.barr_data_lo[0];
      initial begin
        force dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.proc_link_sif_li=proc_in[r][c];
        force dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.proc.h.z.endp.bme.bme.link_sif_in='0;
        force dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.barr_src_r_li=barrier_src[r][c];
        force dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.barr_dest_r_li=barrier_dest[r][c];
        force dut.mc_y[sy_lp].mc_x[sx_lp].mc.y[ty_lp].x[tx_lp].tile.barr_data_li[0]=barrier_data[r][c];
      end
      for (genvar d=N; d<=S; d++) begin: direction
        assign y_fwd_valid[r][c][d]=dut.mc_y[sy_lp].mc_x[sx_lp].mc.ver_ruche_link_out[ty_lp][tx_lp][0][d].fwd.v;
        assign y_rev_valid[r][c][d]=dut.mc_y[sy_lp].mc_x[sx_lp].mc.ver_ruche_link_out[ty_lp][tx_lp][0][d].rev.v;
      end
    end
  end

  for (genvar c=0; c<cols_lp; c++) begin: cache_col
    localparam sx_lp=c/tile_x_lp, tx_lp=c%tile_x_lp;
    assign cache_out[N][c]=dut.north_vc_x[sx_lp].north_vc_row.vc_x[tx_lp].vc.proc_link_sif_lo;
    assign cache_out[S][c]=dut.south_vc_x[sx_lp].south_vc_row.vc_x[tx_lp].vc.proc_link_sif_lo;
    assign cache_y_rev_valid[N][c]=dut.north_vc_x[sx_lp].north_vc_row.vc_x[tx_lp].vc.ruche_link_lo[0][S].rev.v;
    assign cache_y_rev_valid[S][c]=dut.south_vc_x[sx_lp].south_vc_row.vc_x[tx_lp].vc.ruche_link_lo[0][N].rev.v;
    initial begin
      force dut.north_vc_x[sx_lp].north_vc_row.vc_x[tx_lp].vc.proc_link_sif_li=cache_in[N][c];
      force dut.south_vc_x[sx_lp].south_vc_row.vc_x[tx_lp].vc.proc_link_sif_li=cache_in[S][c];
      force dut.north_vc_x[sx_lp].north_vc_row.vc_x[tx_lp].vc.link_to_cache.bme.link_sif_in='0;
      force dut.south_vc_x[sx_lp].south_vc_row.vc_x[tx_lp].vc.link_to_cache.bme.link_sif_in='0;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      saw_y_fwd <= 0;
      saw_y_rev <= 0;
    end
    else begin
      saw_y_fwd <= saw_y_fwd | (|y_fwd_valid);
      saw_y_rev <= saw_y_rev | (|y_rev_valid) | (|cache_y_rev_valid);
    end
  end

  task automatic reset_pod;
    reset=1;
    proc_in='0;
    cache_in='0;
    edge_in='0;
    hor_in='0;
    hor_ruche_in='0;
    wh_in='0;
    barrier_src='0;
    barrier_dest='0;
    barrier_data='0;
    for (int c=0; c<cols_lp; c++) begin
      global_x[c]=x_cord_width_p'(x_lp+c);
      global_y[c]=y_cord_width_p'(y_lp-1);
      for (int d=N; d<=S; d++) begin
        cache_in[d][c].fwd.ready_and_rev=1;
        cache_in[d][c].rev.ready_and_rev=1;
        edge_in[d][c].fwd.ready_and_rev=1;
        edge_in[d][c].rev.ready_and_rev=1;
      end
      for (int r=0; r<rows_lp; r++) begin
        proc_in[r][c].fwd.ready_and_rev=1;
        proc_in[r][c].rev.ready_and_rev=1;
        barrier_dest[r][c]=barrier_dirs_lp;
      end
    end
    for (int d=W; d<=E; d++) begin
      wh_in[d][1]='1;
      for (int r=0; r<rows_lp; r++) begin
        hor_ruche_in[d][r][1]='1;
        hor_in[d][r].fwd.ready_and_rev=1;
        hor_in[d][r].rev.ready_and_rev=1;
      end
    end
    repeat (rows_lp+5) @(negedge clk);
    reset=0;
    repeat (rows_lp+5) @(negedge clk);
  endtask

  task automatic check_cache_roundtrip(input int side);
    bsg_manycore_packet_s packet;
    bsg_manycore_return_packet_s response;
    int from_row;
    from_row=(side == N) ? rows_lp-1 : 0;
    reset_pod();
    packet='0;
    packet.addr=28'h1234567;
    packet.payload.data=32'h89abcdef;
    packet.src_x_cord=x_lp;
    packet.src_y_cord=y_cord_width_p'(y_lp+from_row);
    packet.x_cord=x_cord_width_p'(x_lp+1);
    packet.y_cord=(side == N) ? y_cord_width_p'(y_lp-1) : y_cord_width_p'(y_lp+rows_lp);
    cache_in[side][1].fwd.ready_and_rev=0;
    proc_in[from_row][0].fwd.data=packet;
    proc_in[from_row][0].fwd.v=1;
    @(negedge clk);
    proc_in[from_row][0].fwd.v=0;
    for (int cycle=0; cycle<40 && !cache_out[side][1].fwd.v; cycle++)
      @(negedge clk);
    repeat (3) begin
      assert (cache_out[side][1].fwd.v && cache_out[side][1].fwd.data === packet)
        else $fatal(1,"Pod request to cache side %0d lost or corrupted",side);
      @(negedge clk);
    end
    cache_in[side][1].fwd.ready_and_rev=1;
    @(negedge clk);
    assert (!cache_out[side][1].fwd.v) else $fatal(1,"Cache request did not drain");
    response='0;
    response.data=32'hfedcba98;
    response.reg_id=5'd13;
    response.x_cord=packet.src_x_cord;
    response.y_cord=packet.src_y_cord;
    proc_in[from_row][0].rev.ready_and_rev=0;
    cache_in[side][1].rev.data=response;
    cache_in[side][1].rev.v=1;
    do @(posedge clk); while (!cache_out[side][1].rev.ready_and_rev);
    @(negedge clk);
    cache_in[side][1].rev.v=0;
    for (int cycle=0; cycle<40 && !proc_out[from_row][0].rev.v; cycle++)
      @(negedge clk);
    repeat (3) begin
      assert (proc_out[from_row][0].rev.v && proc_out[from_row][0].rev.data === response)
        else $fatal(1,"Pod cache side %0d response lost destination X/Y",side);
      @(negedge clk);
    end
    proc_in[from_row][0].rev.ready_and_rev=1;
    @(negedge clk);
    assert (!proc_out[from_row][0].rev.v) else $fatal(1,"Cache response did not drain");
    if (ruche_factor_Y_p > 0)
      assert (saw_y_fwd && saw_y_rev) else $fatal(1,"Cache traffic bypassed Y ruche");
  endtask

  task automatic check_barrier;
    reset_pod();
    barrier_src[0][0][0]=1;
    barrier_dest[0][0]=barrier_dirs_lp-1;
    barrier_src[barrier_ruche_factor_Y_p][0][0]=1;
    barrier_src[barrier_ruche_factor_Y_p][0][barrier_dirs_lp-2]=1;
    barrier_dest[barrier_ruche_factor_Y_p][0]=barrier_dirs_lp;
    for (int sense=1; sense>=0; sense--) begin
      barrier_data[0][0]=1'(sense);
      repeat (12) @(negedge clk);
      assert (barrier_done[0][0] === !1'(sense))
        else $fatal(1,"Pod Y barrier completed before remote arrival");
      barrier_data[barrier_ruche_factor_Y_p][0]=1'(sense);
      repeat (12) @(negedge clk);
      assert (barrier_done[0][0] === 1'(sense)
              && barrier_done[barrier_ruche_factor_Y_p][0] === 1'(sense))
        else $fatal(1,"Pod Y barrier failed across subarrays");
    end
  endtask

  // No test packet targets a neighboring pod or a horizontal boundary.
  always @(negedge clk) begin
    if (!reset) begin
      for (int d=N; d<=S; d++)
        for (int c=0; c<cols_lp; c++)
          assert (!edge_out[d][c].fwd.v && !edge_out[d][c].rev.v)
            else $fatal(1,"Pod traffic escaped through the external local Y port");
    end
  end

  initial begin
    check_cache_roundtrip(N);
    check_cache_roundtrip(S);
    if (ruche_factor_Y_p > 0)
      check_barrier();
    $display("PASS: pod Y=%0d barrier Y=%0d subarrays=%0dx%0d N/S cache roundtrips and barrier",
             ruche_factor_Y_p,barrier_ruche_factor_Y_p,sub_x_lp,sub_y_lp);
    $finish;
  end

  initial begin
    #30000;
    $fatal(1,"Pod Y wiring test timed out");
  end
endmodule
