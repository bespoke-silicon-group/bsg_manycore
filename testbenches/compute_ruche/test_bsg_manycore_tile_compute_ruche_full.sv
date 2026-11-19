`include "bsg_manycore_defines.svh"

`ifndef BSG_TEST_RUCHE_FACTOR_Y
`define BSG_TEST_RUCHE_FACTOR_Y 3
`endif
`ifndef BSG_TEST_BARRIER_RUCHE_FACTOR_Y
`define BSG_TEST_BARRIER_RUCHE_FACTOR_Y `BSG_TEST_RUCHE_FACTOR_Y
`endif

module test_bsg_manycore_tile_compute_ruche_full
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter ruche_factor_Y_p=`BSG_TEST_RUCHE_FACTOR_Y
    , barrier_ruche_factor_Y_p=`BSG_TEST_BARRIER_RUCHE_FACTOR_Y);

  localparam addr_width_p=28, data_width_p=32;
  localparam x_cord_width_p=5, y_cord_width_p=7;
  localparam x_lp=5'd9, y_lp=7'd32;
  localparam lanes_lp=`BSG_MAX(1,ruche_factor_Y_p);
  localparam barrier_dirs_lp=(ruche_factor_Y_p > 0) ? 9 : 7;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bit clk=0;
  always #5 clk=~clk;
  bit reset=1;
  bsg_manycore_link_sif_s [S:W] local_in, local_out;
  bsg_manycore_ruche_x_link_sif_s [1:0][E:W] hor_in, hor_out;
  bsg_manycore_ruche_y_link_sif_s [lanes_lp-1:0][S:N] ver_in, ver_out;
  bsg_manycore_link_sif_s proc_in, proc_out;
  logic [S:W] barrier_in, barrier_out;
  logic [1:0][E:W] hor_barrier_in, hor_barrier_out;
  logic [barrier_ruche_factor_Y_p-1:0][S:N] ver_barrier_in, ver_barrier_out;
  logic [barrier_dirs_lp-1:0] barrier_src;
  logic [`BSG_SAFE_CLOG2(barrier_dirs_lp+1)-1:0] barrier_dest;
  logic barrier_data;

  bsg_manycore_tile_compute_ruche_full #(
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
    ,.reset_i(reset)
    ,.reset_o()
    ,.link_i(local_in)
    ,.link_o(local_out)
    ,.ruche_link_i(hor_in)
    ,.ruche_link_o(hor_out)
    ,.ver_ruche_link_i(ver_in)
    ,.ver_ruche_link_o(ver_out)
    ,.barrier_link_i(barrier_in)
    ,.barrier_link_o(barrier_out)
    ,.hor_barrier_ruche_link_i(hor_barrier_in)
    ,.hor_barrier_ruche_link_o(hor_barrier_out)
    ,.ver_barrier_ruche_link_i(ver_barrier_in)
    ,.ver_barrier_ruche_link_o(ver_barrier_out)
    ,.global_x_i(x_lp)
    ,.global_y_i(y_lp)
    ,.global_x_o()
    ,.global_y_o()
  );
  assign proc_out=dut.proc_link_sif_lo;

  task automatic reset_tile;
    reset=1;
    local_in='0;
    hor_in='0;
    ver_in='0;
    proc_in='0;
    barrier_in='0;
    hor_barrier_in='0;
    ver_barrier_in='0;
    barrier_src='0;
    barrier_dest=barrier_dirs_lp;
    barrier_data=0;
    for (int d=W; d<=S; d++) begin
      local_in[d].fwd.ready_and_rev=1;
      local_in[d].rev.ready_and_rev=1;
    end
    for (int d=W; d<=E; d++) begin
      hor_in[0][d].fwd.ready_and_rev=1;
      hor_in[0][d].rev.ready_and_rev=1;
    end
    for (int d=N; d<=S; d++) begin
      ver_in[0][d].fwd.ready_and_rev=1;
      ver_in[0][d].rev.ready_and_rev=1;
    end
    proc_in.fwd.ready_and_rev=1;
    proc_in.rev.ready_and_rev=1;
    repeat (4) @(negedge clk);
    reset=0;
    repeat (3) @(negedge clk);
  endtask

  task automatic check_forward(input int from_side, input bit local_input, input bit transit);
    bsg_manycore_packet_s packet;
    int to_side;
    to_side=(from_side == N) ? S : N;
    packet='0;
    packet.addr=28'h1234567;
    packet.payload.data=32'h89abcdef;
    packet.src_x_cord=5'd17;
    packet.src_y_cord=7'd11;
    packet.x_cord=x_lp;
    packet.y_cord=transit
      ? y_cord_width_p'(y_lp+((to_side == S) ? ruche_factor_Y_p : -ruche_factor_Y_p))
      : y_lp;
    reset_tile();
    proc_in.fwd.ready_and_rev=0;
    ver_in[0][to_side].fwd.ready_and_rev=0;
    if (local_input) begin
      local_in[from_side].fwd.data=packet;
      local_in[from_side].fwd.v=1;
      do @(posedge clk); while (!local_out[from_side].fwd.ready_and_rev);
      @(negedge clk);
      local_in[from_side].fwd.v=0;
    end
    else begin
      ver_in[0][from_side].fwd.data=packet >> x_cord_width_p;
      ver_in[0][from_side].fwd.v=1;
      do @(posedge clk); while (!ver_out[0][from_side].fwd.ready_and_rev);
      @(negedge clk);
      ver_in[0][from_side].fwd.v=0;
    end
    for (int cycles=0; cycles<20; cycles++) begin
      if (transit ? ver_out[0][to_side].fwd.v : proc_out.fwd.v)
        break;
      @(negedge clk);
    end
    repeat (3) begin
      if (transit) begin
        assert (ver_out[0][to_side].fwd.v &&
                ver_out[0][to_side].fwd.data === (packet >> x_cord_width_p))
          else $fatal(1,"Forward Y routing/compression failed");
      end
      else begin
        assert (proc_out.fwd.v && proc_out.fwd.data === packet)
          else $fatal(1,"Forward destination X reconstruction failed");
      end
      @(negedge clk);
    end
    proc_in.fwd.ready_and_rev=1;
    ver_in[0][to_side].fwd.ready_and_rev=1;
    @(negedge clk);
    assert (!(transit ? ver_out[0][to_side].fwd.v : proc_out.fwd.v))
      else $fatal(1,"Forward packet did not drain");
  endtask

  task automatic check_reverse(input int side, input bit ingress);
    bsg_manycore_return_packet_s packet;
    int to_side;
    to_side=ingress ? ((side == N) ? S : N) : side;
    packet='0;
    packet.data=32'hfedcba98;
    packet.reg_id=5'd13;
    packet.x_cord=5'd17;
    packet.y_cord=y_cord_width_p'(y_lp+((to_side == S) ? 1 : -1)
                   *(ingress ? 1 : ruche_factor_Y_p+1));
    reset_tile();
    local_in[to_side].rev.ready_and_rev=0;
    ver_in[0][to_side].rev.ready_and_rev=0;
    if (ingress) begin
      ver_in[0][side].rev.data=packet;
      ver_in[0][side].rev.v=1;
      do @(posedge clk); while (!ver_out[0][side].rev.ready_and_rev);
      @(negedge clk);
      ver_in[0][side].rev.v=0;
    end
    else begin
      proc_in.rev.data=packet;
      proc_in.rev.v=1;
      @(negedge clk);
      proc_in.rev.v=0;
    end
    for (int cycles=0; cycles<20; cycles++) begin
      if (ingress ? local_out[to_side].rev.v : ver_out[0][to_side].rev.v)
        break;
      @(negedge clk);
    end
    repeat (3) begin
      assert (ingress
        ? (local_out[to_side].rev.v && local_out[to_side].rev.data === packet)
        : (ver_out[0][to_side].rev.v && ver_out[0][to_side].rev.data === packet))
        else $fatal(1,"Reverse Y routing lost packet or destination X");
      @(negedge clk);
    end
    local_in[to_side].rev.ready_and_rev=1;
    ver_in[0][to_side].rev.ready_and_rev=1;
    @(negedge clk);
    assert (!(ingress ? local_out[to_side].rev.v : ver_out[0][to_side].rev.v))
      else $fatal(1,"Reverse packet did not drain");
  endtask

  task automatic check_p_credits;
    bsg_manycore_packet_s packet;
    bsg_manycore_return_packet_s response;
    int fwd_credits, rev_credits;
    reset_tile();
    packet='0;
    packet.x_cord=x_cord_width_p'(x_lp+3);
    packet.y_cord=y_lp;
    response='0;
    response.x_cord=x_cord_width_p'(x_lp+2);
    response.y_cord=y_lp;
    hor_in[0][E].fwd.ready_and_rev=0;
    local_in[E].rev.ready_and_rev=0;
    // Both P FIFOs must accept three consecutive packets without ready.
    proc_in.fwd.data=packet;
    proc_in.rev.data=response;
    proc_in.fwd.v=1;
    proc_in.rev.v=1;
    repeat (3) @(posedge clk);
    #1;
    proc_in.fwd.v=0;
    proc_in.rev.v=0;
    @(negedge clk);
    assert (proc_out.fwd.ready_and_rev === 0 && proc_out.rev.ready_and_rev === 0)
      else $fatal(1,"P interface returned ready instead of a dequeue credit");
    assert (hor_out[0][E].fwd.v && hor_out[0][E].fwd.data ===
            `bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_p,y_cord_width_p,packet)
            && local_out[E].rev.v && local_out[E].rev.data === response)
      else $fatal(1,"X routing/compression changed");
    hor_in[0][E].fwd.ready_and_rev=1;
    local_in[E].rev.ready_and_rev=1;
    fwd_credits=0;
    rev_credits=0;
    repeat (8) begin
      @(negedge clk);
      fwd_credits+=int'(proc_out.fwd.ready_and_rev);
      rev_credits+=int'(proc_out.rev.ready_and_rev);
    end
    assert (fwd_credits == 3 && rev_credits == 3)
      else $fatal(1,"P FIFOs lost packets/credits: fwd=%0d rev=%0d",fwd_credits,rev_credits);
  endtask

  initial begin
    force dut.proc_link_sif_li=proc_in;
    force dut.proc.h.z.endp.bme.bme.link_sif_in='0;
    force dut.barr_src_r_li=barrier_src;
    force dut.barr_dest_r_li=barrier_dest;
    force dut.barr_data_li[0]=barrier_data;
    reset_tile();
    for (int trial=0; trial<8; trial++) begin
      hor_in[1]={$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
      hor_barrier_in[1]=$urandom;
      for (int i=1; i<ruche_factor_Y_p; i++)
        for (int d=N; d<=S; d++)
          for (int b=0; b<$bits(bsg_manycore_ruche_y_link_sif_s); b++)
            ver_in[i][d][b]=1'($urandom);
      for (int i=1; i<barrier_ruche_factor_Y_p; i++)
        ver_barrier_in[i]=$urandom;
      #1;
      assert (hor_out[1][E] === hor_in[1][W] && hor_out[1][W] === hor_in[1][E]
              && hor_barrier_out[1][E] === hor_barrier_in[1][W]
              && hor_barrier_out[1][W] === hor_barrier_in[1][E])
        else $fatal(1,"X feedthrough changed");
      for (int i=1; i<ruche_factor_Y_p; i++)
        assert (ver_out[i][N] === ver_in[i][S] && ver_out[i][S] === ver_in[i][N])
          else $fatal(1,"Y data feedthrough failed");
      for (int i=1; i<barrier_ruche_factor_Y_p; i++)
        assert (ver_barrier_out[i][N] === ver_barrier_in[i][S]
                && ver_barrier_out[i][S] === ver_barrier_in[i][N])
          else $fatal(1,"Y barrier feedthrough failed");
    end
    @(negedge clk);
    check_p_credits();
    if (ruche_factor_Y_p > 0) begin
      for (int d=N; d<=S; d++) begin
        check_forward(d,0,0);
        check_forward(d,0,1);
        check_forward(d,1,1);
        check_forward(d,1,0);
        check_reverse(d,0);
        check_reverse(d,1);
        reset_tile();
        barrier_src[0]=1;
        barrier_dest=(d == N) ? 7 : 8;
        for (int sense=1; sense>=0; sense--) begin
          barrier_data=1'(sense);
          repeat (3) @(negedge clk);
          assert (ver_barrier_out[0][d] === 1'(sense))
            else $fatal(1,"Barrier gather did not reach Y port");
          ver_barrier_in[0][d]=1'(sense);
          repeat (3) @(negedge clk);
          assert (dut.barr_data_lo[0] === 1'(sense))
            else $fatal(1,"Barrier broadcast did not reach P");
        end
      end
    end
    else begin
      assert (ver_out === '0 && ver_barrier_out === '0)
        else $fatal(1,"Disabled Y outputs are not tied off");
    end
    $display("PASS: compute tile Y=%0d barrier Y=%0d routing, credits, stalls, and feedthrough",
             ruche_factor_Y_p,barrier_ruche_factor_Y_p);
    $finish;
  end

  initial begin
    #30000;
    $fatal(1,"Full ruche compute tile test timed out");
  end
endmodule
