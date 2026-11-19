`include "bsg_manycore_defines.svh"

module test_bsg_manycore_tile_vcache_ruche
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter ruche_factor_Y_p=3);

  localparam addr_width_p=28, data_width_p=32;
  localparam x_cord_width_p=5, y_cord_width_p=7;
  localparam x_lp=5'd9, y_lp=7'd32;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_ruche_y_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_ready_and_link_sif_s(32,wh_link_sif_s);

  bit clk=0;
  always #5 clk=~clk;
  bit reset=1;
  bsg_manycore_link_sif_s [S:N] ver_in, ver_out;
  bsg_manycore_ruche_y_link_sif_s [ruche_factor_Y_p-1:0][S:N] ruche_in, ruche_out;
  wh_link_sif_s [1:0][E:W] wh_in, wh_out;
  bsg_manycore_link_sif_s proc_in, proc_out;

  bsg_manycore_tile_vcache_ruche #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_tiles_y_p(8)
    ,.ruche_factor_Y_p(ruche_factor_Y_p)
    ,.vcache_addr_width_p(29)
    ,.vcache_data_width_p(data_width_p)
    ,.vcache_ways_p(2)
    ,.vcache_sets_p(4)
    ,.vcache_block_size_in_words_p(8)
    ,.vcache_dma_data_width_p(32)
    ,.vcache_word_tracking_p(1)
    ,.icache_block_size_in_words_p(4)
    ,.wh_ruche_factor_p(2)
    ,.wh_cid_width_p(2)
    ,.wh_flit_width_p(32)
    ,.wh_len_width_p(4)
    ,.wh_cord_width_p(x_cord_width_p)
  ) dut (
    .clk_i(clk)
    ,.reset_i(reset)
    ,.reset_o()
    ,.wh_link_sif_i(wh_in)
    ,.wh_link_sif_o(wh_out)
    ,.ver_link_sif_i(ver_in)
    ,.ver_link_sif_o(ver_out)
    ,.ver_ruche_link_i(ruche_in)
    ,.ver_ruche_link_o(ruche_out)
    ,.global_x_i(x_lp)
    ,.global_y_i(y_lp)
    ,.global_x_o()
    ,.global_y_o()
  );
  assign proc_out = dut.proc_link_sif_lo;

  task automatic reset_tile;
    reset=1;
    ver_in='0;
    ruche_in='0;
    wh_in='0;
    proc_in='0;
    for (int d=N; d<=S; d++) begin
      ver_in[d].fwd.ready_and_rev=1;
      ver_in[d].rev.ready_and_rev=1;
      ruche_in[0][d].fwd.ready_and_rev=1;
      ruche_in[0][d].rev.ready_and_rev=1;
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
    ruche_in[0][to_side].fwd.ready_and_rev=0;
    if (local_input) begin
      ver_in[from_side].fwd.data=packet;
      ver_in[from_side].fwd.v=1;
      do @(posedge clk); while (!ver_out[from_side].fwd.ready_and_rev);
      @(negedge clk);
      ver_in[from_side].fwd.v=0;
    end
    else begin
      ruche_in[0][from_side].fwd.data=packet >> x_cord_width_p;
      ruche_in[0][from_side].fwd.v=1;
      do @(posedge clk); while (!ruche_out[0][from_side].fwd.ready_and_rev);
      @(negedge clk);
      ruche_in[0][from_side].fwd.v=0;
    end
    for (int cycles=0; cycles<20; cycles++) begin
      if (transit ? ruche_out[0][to_side].fwd.v : proc_out.fwd.v)
        break;
      @(negedge clk);
    end
    repeat (3) begin
      if (transit) begin
        assert (ruche_out[0][to_side].fwd.v &&
                ruche_out[0][to_side].fwd.data === (packet >> x_cord_width_p))
          else $fatal(1,"Forward Y ruche routing/compression failed");
      end
      else begin
        assert (proc_out.fwd.v && proc_out.fwd.data === packet)
          else $fatal(1,"Forward destination X reconstruction failed");
      end
      @(negedge clk);
    end
    proc_in.fwd.ready_and_rev=1;
    ruche_in[0][to_side].fwd.ready_and_rev=1;
    @(negedge clk);
    assert (!(transit ? ruche_out[0][to_side].fwd.v : proc_out.fwd.v))
      else $fatal(1,"Forward packet did not drain after releasing backpressure");
  endtask

  task automatic check_reverse(input int to_side);
    bsg_manycore_return_packet_s packet;
    packet='0;
    packet.data=32'hfedcba98;
    packet.reg_id=5'd13;
    packet.x_cord=5'd17;
    packet.y_cord= (to_side == N)
      ? y_cord_width_p'(y_lp-ruche_factor_Y_p-1)
      : y_cord_width_p'(y_lp+ruche_factor_Y_p+1);
    reset_tile();
    ruche_in[0][to_side].rev.ready_and_rev=0;
    proc_in.rev.data=packet;
    proc_in.rev.v=1;
    do @(posedge clk); while (!proc_out.rev.ready_and_rev);
    @(negedge clk);
    proc_in.rev.v=0;
    for (int cycles=0; cycles<20 && !ruche_out[0][to_side].rev.v; cycles++)
      @(negedge clk);
    repeat (3) begin
      assert (ruche_out[0][to_side].rev.v &&
              ruche_out[0][to_side].rev.data === packet)
        else $fatal(1,"Reverse Y ruche routing lost packet or destination X");
      @(negedge clk);
    end
    ruche_in[0][to_side].rev.ready_and_rev=1;
    @(negedge clk);
    assert (!ruche_out[0][to_side].rev.v)
      else $fatal(1,"Reverse packet did not drain after releasing backpressure");
  endtask

  task automatic check_reverse_ingress(input int from_side);
    bsg_manycore_return_packet_s packet;
    int to_side;
    to_side=(from_side == N) ? S : N;
    packet='0;
    packet.data=32'h1234abcd;
    packet.reg_id=5'd7;
    packet.x_cord=5'd17;
    packet.y_cord=y_cord_width_p'(y_lp+((to_side == S) ? 1 : -1));
    reset_tile();
    ver_in[to_side].rev.ready_and_rev=0;
    ruche_in[0][from_side].rev.data=packet;
    ruche_in[0][from_side].rev.v=1;
    do @(posedge clk); while (!ruche_out[0][from_side].rev.ready_and_rev);
    @(negedge clk);
    ruche_in[0][from_side].rev.v=0;
    for (int cycles=0; cycles<20 && !ver_out[to_side].rev.v; cycles++)
      @(negedge clk);
    repeat (3) begin
      assert (ver_out[to_side].rev.v && ver_out[to_side].rev.data === packet)
        else $fatal(1,"Incoming reverse Y ruche packet was corrupted");
      @(negedge clk);
    end
    ver_in[to_side].rev.ready_and_rev=1;
    @(negedge clk);
    assert (!ver_out[to_side].rev.v)
      else $fatal(1,"Incoming reverse packet did not drain");
  endtask

  initial begin
    // Isolate routing from cache responses so packet fields and stalls are controlled.
    force dut.proc_link_sif_li=proc_in;
    reset_tile();
    assert ($bits(ruche_in[0][N]) == $bits(ver_in[N])-x_cord_width_p)
      else $fatal(1,"Incorrect compressed Y link width");
    for (int trial=0; trial<8; trial++) begin
      for (int i=1; i<ruche_factor_Y_p; i++) begin
        for (int d=N; d<=S; d++) begin
          for (int b=0; b<$bits(bsg_manycore_ruche_y_link_sif_s); b++)
            ruche_in[i][d][b]=1'($urandom);
        end
      end
      wh_in[1][W]={$urandom,$urandom};
      wh_in[1][E]={$urandom,$urandom};
      #1;
      for (int i=1; i<ruche_factor_Y_p; i++) begin
        assert (ruche_out[i][N] === ruche_in[i][S] && ruche_out[i][S] === ruche_in[i][N])
          else $fatal(1,"Y ruche feedthrough failed");
      end
      assert (wh_out[1][E] === wh_in[1][W] && wh_out[1][W] === wh_in[1][E])
        else $fatal(1,"Wormhole feedthrough changed");
    end
    @(negedge clk);
    check_forward(N,0,0);
    check_forward(S,0,0);
    check_forward(N,0,1);
    check_forward(S,0,1);
    check_forward(N,1,1);
    check_forward(S,1,1);
    check_forward(N,1,0);
    check_forward(S,1,0);
    check_reverse(N);
    check_reverse(S);
    check_reverse_ingress(N);
    check_reverse_ingress(S);
    $display("PASS: vcache Y ruche factor %0d routing, compression, stalls, and feedthrough",ruche_factor_Y_p);
    $finish;
  end

  initial begin
    #20000;
    $fatal(1,"Y ruche test timed out");
  end
endmodule
