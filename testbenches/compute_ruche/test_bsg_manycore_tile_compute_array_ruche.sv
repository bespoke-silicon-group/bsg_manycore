`include "bsg_manycore_defines.svh"

`ifndef BSG_TEST_RUCHE_FACTOR_Y
`define BSG_TEST_RUCHE_FACTOR_Y 3
`endif
`ifndef BSG_TEST_BARRIER_RUCHE_FACTOR_Y
`define BSG_TEST_BARRIER_RUCHE_FACTOR_Y `BSG_TEST_RUCHE_FACTOR_Y
`endif

module test_bsg_manycore_tile_compute_array_ruche
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter ruche_factor_Y_p=`BSG_TEST_RUCHE_FACTOR_Y
    , barrier_ruche_factor_Y_p=`BSG_TEST_BARRIER_RUCHE_FACTOR_Y);

  localparam addr_width_p=28, data_width_p=32;
  localparam x_cord_width_p=5, y_cord_width_p=7;
  localparam cols_lp=2;
  localparam rows_lp=`BSG_MAX(ruche_factor_Y_p,barrier_ruche_factor_Y_p)+2;
  localparam dest_row_lp=(ruche_factor_Y_p > 0) ? ruche_factor_Y_p+1 : 0;
  localparam lanes_lp=`BSG_MAX(1,ruche_factor_Y_p);
  localparam barrier_dirs_lp=(ruche_factor_Y_p > 0) ? 9 : 7;
  localparam barrier_lg_dirs_lp=`BSG_SAFE_CLOG2(barrier_dirs_lp+1);
  localparam x_lp=5'd9, y_lp=7'd32;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bit clk=0;
  always #5 clk=~clk;
  bit reset=1;
  bsg_manycore_link_sif_s [rows_lp-1:0][cols_lp-1:0] proc_in, proc_out;
  bsg_manycore_ruche_y_link_sif_s [S:N][cols_lp-1:0][lanes_lp-1:0] ver_in, ver_out;
  bsg_manycore_ruche_x_link_sif_s [E:W][rows_lp-1:0][1:0] hor_in;
  logic [S:N][cols_lp-1:0][barrier_ruche_factor_Y_p-1:0] barrier_in, barrier_out;
  logic [rows_lp-1:0][cols_lp-1:0][barrier_dirs_lp-1:0] barrier_src;
  logic [rows_lp-1:0][cols_lp-1:0][barrier_lg_dirs_lp-1:0] barrier_dest;
  logic [rows_lp-1:0][cols_lp-1:0] barrier_data, barrier_done;
  bsg_manycore_ruche_y_link_sif_s [rows_lp-1:0][cols_lp-1:0][lanes_lp-1:0][S:N] injected;
  logic [rows_lp-1:0][cols_lp-1:0][barrier_ruche_factor_Y_p-1:0][S:N] injected_barrier;
  logic [cols_lp-1:0][x_cord_width_p-1:0] global_x;
  logic [cols_lp-1:0][y_cord_width_p-1:0] global_y;
  logic saw_y_fwd, saw_y_rev;

  bsg_manycore_tile_compute_array_ruche #(
    .dmem_size_p(1024)
    ,.vcache_size_p(1024)
    ,.icache_entries_p(1024)
    ,.icache_tag_width_p(12)
    ,.icache_block_size_in_words_p(4)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(2)
    ,.pod_y_cord_width_p(4)
    ,.num_tiles_x_p(8)
    ,.num_tiles_y_p(8)
    // Only used by the processor's address mapping, which this test bypasses.
    ,.num_vcache_rows_p(2)
    ,.subarray_num_tiles_x_p(cols_lp)
    ,.subarray_num_tiles_y_p(rows_lp)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.ruche_factor_X_p(2)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
    ,.barrier_ruche_factor_X_p(2)
    ,.barrier_ruche_factor_Y_p(barrier_ruche_factor_Y_p)
    ,.vcache_block_size_in_words_p(8)
    ,.vcache_sets_p(4)
    ,.ipoly_hashing_p(0)
  ) dut (
    .clk_i(clk)
    ,.reset_i({cols_lp{reset}})
    ,.reset_o()
    ,.hor_link_sif_i('0)
    ,.hor_link_sif_o()
    ,.ver_link_sif_i('0)
    ,.ver_link_sif_o()
    ,.ruche_link_i(hor_in)
    ,.ruche_link_o()
    ,.ver_ruche_link_i(ver_in)
    ,.ver_ruche_link_o(ver_out)
    ,.ver_barrier_link_i('0)
    ,.ver_barrier_link_o()
    ,.hor_barrier_link_i('0)
    ,.hor_barrier_link_o()
    ,.hor_barrier_ruche_link_i('0)
    ,.hor_barrier_ruche_link_o()
    ,.ver_barrier_ruche_link_i(barrier_in)
    ,.ver_barrier_ruche_link_o(barrier_out)
    ,.global_x_i(global_x)
    ,.global_y_i(global_y)
    ,.global_x_o()
    ,.global_y_o()
  );

  for (genvar r=0; r<rows_lp; r++) begin: row
    for (genvar c=0; c<cols_lp; c++) begin: col
      assign proc_out[r][c]=dut.y[r].x[c].tile.proc_link_sif_lo;
      assign barrier_done[r][c]=dut.y[r].x[c].tile.barr_data_lo[0];
      initial begin
        force dut.y[r].x[c].tile.proc_link_sif_li=proc_in[r][c];
        force dut.y[r].x[c].tile.proc.h.z.endp.bme.bme.link_sif_in='0;
        force dut.y[r].x[c].tile.barr_src_r_li=barrier_src[r][c];
        force dut.y[r].x[c].tile.barr_dest_r_li=barrier_dest[r][c];
        force dut.y[r].x[c].tile.barr_data_li[0]=barrier_data[r][c];
      end
    end
  end

  if (ruche_factor_Y_p > 0) begin: monitor_y_hops
    always @(posedge clk) begin
      if (reset) begin
        saw_y_fwd <= 0;
        saw_y_rev <= 0;
      end
      else begin
        saw_y_fwd <= saw_y_fwd | dut.ver_ruche_link_out[1][1][0][S].fwd.v;
        saw_y_rev <= saw_y_rev | dut.ver_ruche_link_out[dest_row_lp][1][0][N].rev.v;
      end
    end
  end
  else begin: no_y_hops
    assign saw_y_fwd=1;
    assign saw_y_rev=1;
  end

  task automatic reset_array;
    reset=1;
    proc_in='0;
    barrier_src='0;
    barrier_dest='0;
    barrier_data='0;
    hor_in='0;
    ver_in='0;
    barrier_in='0;
    for (int c=0; c<cols_lp; c++) begin
      global_x[c]=x_cord_width_p'(x_lp+c);
      global_y[c]=y_lp;
      for (int d=N; d<=S; d++) begin
        for (int l=1; l<ruche_factor_Y_p; l++)
          ver_in[d][c][l]=((ruche_factor_Y_p % 2 == 0) ? (l % 2 != 0)
                            : ((d == N) ? (l % 2 == 0) : (l % 2 != 0))) ? '1 : '0;
        for (int l=1; l<barrier_ruche_factor_Y_p; l++)
          barrier_in[d][c][l]=(barrier_ruche_factor_Y_p % 2 == 0) ? (l % 2 != 0)
                              : ((d == N) ? (l % 2 == 0) : (l % 2 != 0));
      end
      for (int r=0; r<rows_lp; r++) begin
        proc_in[r][c].fwd.ready_and_rev=1;
        proc_in[r][c].rev.ready_and_rev=1;
        barrier_dest[r][c]=barrier_dirs_lp;
      end
    end
    for (int r=0; r<rows_lp; r++) begin
      hor_in[W][r][1]='1;
      hor_in[E][r][1]='1;
    end
    repeat (rows_lp+3) @(negedge clk);
    reset=0;
    repeat (rows_lp+3) @(negedge clk);
  endtask

  task automatic check_stitching;
    bit invert;
    logic [$bits(injected)-1:0] random_data;
    logic [$bits(injected_barrier)-1:0] random_barrier;
    logic [$bits(ver_in)-1:0] random_edge_data;
    logic [$bits(barrier_in)-1:0] random_edge_barrier;
    reset=1;
    force dut.ver_ruche_link_out=injected;
    force dut.ver_barrier_ruche_link_lo=injected_barrier;
    repeat (8) begin
      for (int b=0; b<$bits(random_data); b++) random_data[b]=1'($urandom);
      for (int b=0; b<$bits(random_barrier); b++) random_barrier[b]=1'($urandom);
      for (int b=0; b<$bits(random_edge_data); b++) random_edge_data[b]=1'($urandom);
      for (int b=0; b<$bits(random_edge_barrier); b++) random_edge_barrier[b]=1'($urandom);
      injected=random_data;
      injected_barrier=random_barrier;
      ver_in=random_edge_data;
      barrier_in=random_edge_barrier;
      #1;
      for (int c=0; c<cols_lp; c++) begin
        for (int l=0; l<ruche_factor_Y_p; l++) begin
          invert=(l == 0) ? (ruche_factor_Y_p % 2 == 0) : 1;
          assert (dut.ver_ruche_link_in[0][c][l][N] === ver_in[N][c][l]
                  && ver_out[N][c][l] === injected[0][c][l][N])
            else $fatal(1,"North data boundary wiring failed");
          assert (dut.ver_ruche_link_in[rows_lp-1][c][(l+ruche_factor_Y_p-1)%ruche_factor_Y_p][S]
                  === (invert ? ~ver_in[S][c][l] : ver_in[S][c][l])
                  && ver_out[S][c][(l+1)%ruche_factor_Y_p]
                  === (invert ? ~injected[rows_lp-1][c][l][S] : injected[rows_lp-1][c][l][S]))
            else $fatal(1,"South data boundary rotation/inversion failed");
          for (int r=0; r<rows_lp-1; r++)
            assert (dut.ver_ruche_link_in[r][c][(l+ruche_factor_Y_p-1)%ruche_factor_Y_p][S]
                    === (invert ? ~injected[r+1][c][l][N] : injected[r+1][c][l][N])
                    && dut.ver_ruche_link_in[r+1][c][(l+1)%ruche_factor_Y_p][N]
                    === (invert ? ~injected[r][c][l][S] : injected[r][c][l][S]))
              else $fatal(1,"Internal data rotation/inversion failed");
        end
        for (int l=0; l<barrier_ruche_factor_Y_p; l++) begin
          invert=(l == 0) ? (barrier_ruche_factor_Y_p % 2 == 0) : 1;
          assert (dut.ver_barrier_ruche_link_li[0][c][l][N] === barrier_in[N][c][l]
                  && barrier_out[N][c][l] === injected_barrier[0][c][l][N])
            else $fatal(1,"North barrier boundary wiring failed");
          assert (dut.ver_barrier_ruche_link_li[rows_lp-1][c][(l+barrier_ruche_factor_Y_p-1)%barrier_ruche_factor_Y_p][S]
                  === (invert ^ barrier_in[S][c][l])
                  && barrier_out[S][c][(l+1)%barrier_ruche_factor_Y_p]
                  === (invert ^ injected_barrier[rows_lp-1][c][l][S]))
            else $fatal(1,"South barrier boundary rotation/inversion failed");
          for (int r=0; r<rows_lp-1; r++)
            assert (dut.ver_barrier_ruche_link_li[r][c][(l+barrier_ruche_factor_Y_p-1)%barrier_ruche_factor_Y_p][S]
                    === (invert ^ injected_barrier[r+1][c][l][N])
                    && dut.ver_barrier_ruche_link_li[r+1][c][(l+1)%barrier_ruche_factor_Y_p][N]
                    === (invert ^ injected_barrier[r][c][l][S]))
              else $fatal(1,"Internal barrier rotation/inversion failed");
        end
      end
    end
    release dut.ver_ruche_link_out;
    release dut.ver_barrier_ruche_link_lo;
  endtask

  task automatic check_traffic;
    bsg_manycore_packet_s packet;
    bsg_manycore_return_packet_s response;
    reset_array();
    packet='0;
    packet.addr=28'h1234567;
    packet.payload.data=32'h89abcdef;
    packet.src_x_cord=x_lp;
    packet.src_y_cord=y_lp;
    packet.x_cord=x_cord_width_p'(x_lp+1);
    packet.y_cord=y_cord_width_p'(y_lp+dest_row_lp);
    proc_in[dest_row_lp][1].fwd.ready_and_rev=0;
    proc_in[0][0].fwd.data=packet;
    proc_in[0][0].fwd.v=1;
    @(negedge clk);
    proc_in[0][0].fwd.v=0;
    for (int cycle=0; cycle<30 && !proc_out[dest_row_lp][1].fwd.v; cycle++)
      @(negedge clk);
    repeat (3) begin
      assert (proc_out[dest_row_lp][1].fwd.v
              && proc_out[dest_row_lp][1].fwd.data === packet)
        else $fatal(1,"Array XY request routing or source coordinates corrupted");
      @(negedge clk);
    end
    proc_in[dest_row_lp][1].fwd.ready_and_rev=1;
    @(negedge clk);
    assert (!proc_out[dest_row_lp][1].fwd.v) else $fatal(1,"Array request did not drain");
    response='0;
    response.data=32'hfeedbeef;
    response.x_cord=x_lp;
    response.y_cord=y_lp;
    proc_in[0][0].rev.ready_and_rev=0;
    proc_in[dest_row_lp][1].rev.data=response;
    proc_in[dest_row_lp][1].rev.v=1;
    @(negedge clk);
    proc_in[dest_row_lp][1].rev.v=0;
    for (int cycle=0; cycle<30 && !proc_out[0][0].rev.v; cycle++)
      @(negedge clk);
    repeat (3) begin
      assert (proc_out[0][0].rev.v && proc_out[0][0].rev.data === response)
        else $fatal(1,"Array YX response routing or destination coordinates corrupted");
      @(negedge clk);
    end
    proc_in[0][0].rev.ready_and_rev=1;
    @(negedge clk);
    assert (!proc_out[0][0].rev.v) else $fatal(1,"Array response did not drain");
    assert (saw_y_fwd && saw_y_rev)
      else $fatal(1,"Traffic bypassed Y ruche links");
  endtask

  task automatic check_barrier;
    reset_array();
    barrier_src[0][0][0]=1;
    barrier_dest[0][0]=barrier_dirs_lp-1;
    barrier_src[barrier_ruche_factor_Y_p][0][0]=1;
    barrier_src[barrier_ruche_factor_Y_p][0][barrier_dirs_lp-2]=1;
    barrier_dest[barrier_ruche_factor_Y_p][0]=barrier_dirs_lp;
    for (int sense=1; sense>=0; sense--) begin
      barrier_data[0][0]=1'(sense);
      repeat (10) @(negedge clk);
      assert (barrier_done[0][0] === !1'(sense))
        else $fatal(1,"Barrier completed before remote arrival");
      barrier_data[barrier_ruche_factor_Y_p][0]=1'(sense);
      repeat (10) @(negedge clk);
      assert (barrier_done[0][0] === 1'(sense)
              && barrier_done[barrier_ruche_factor_Y_p][0] === 1'(sense))
        else $fatal(1,"Y ruche barrier gather/broadcast failed");
    end
  endtask

  initial begin
    reset_array();
    if (ruche_factor_Y_p > 0) begin
      check_stitching();
      check_traffic();
      check_barrier();
    end
    else begin
      check_traffic();
      assert (ver_out === '0 && barrier_out === '0)
        else $fatal(1,"Disabled array Y ports are not tied off");
    end
    $display("PASS: compute array Y=%0d barrier Y=%0d stitching, XY/YX traffic, and barrier",
             ruche_factor_Y_p,barrier_ruche_factor_Y_p);
    $finish;
  end

  initial begin
    #30000;
    $fatal(1,"Full ruche compute array test timed out");
  end
endmodule
