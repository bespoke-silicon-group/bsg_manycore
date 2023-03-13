/**
 *    bsg_manycore_xbar.v
 */


`include "bsg_manycore_defines.vh"


module bsg_manycore_xbar
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(host_x_cord_p)
    , `BSG_INV_PARAM(host_y_cord_p)

    , `BSG_INV_PARAM(fwd_fifo_els_p)
    , `BSG_INV_PARAM(rev_fifo_els_p)
    , localparam link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  ( 
    input clk_i
    , input reset_i

    , input        [link_sif_width_lp-1:0] host_link_i
    , output logic [link_sif_width_lp-1:0] host_link_o
    
    , input        [num_tiles_y_p-1:0][num_tiles_x_p-1:0][link_sif_width_lp-1:0] core_link_sif_i
    , output logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][link_sif_width_lp-1:0] core_link_sif_o

    , input        [1:0][num_tiles_x_p-1:0][link_sif_width_lp-1:0] vc_link_sif_i
    , output logic [1:0][num_tiles_x_p-1:0][link_sif_width_lp-1:0] vc_link_sif_o
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s host_link_in, host_link_out;
  assign host_link_in = host_link_i;
  assign host_link_o = host_link_out;

  bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0] core_link_in, core_link_out;
  assign core_link_in = core_link_sif_i; 
  assign core_link_sif_o = core_link_out;

  bsg_manycore_link_sif_s [1:0][num_tiles_x_p-1:0] vc_link_in, vc_link_out;
  assign vc_link_in  = vc_link_sif_i;
  assign vc_link_sif_o  = vc_link_out;

  localparam num_src_lp = 1+(num_tiles_x_p*num_tiles_y_p);
  localparam num_dst_lp = 1+(num_tiles_x_p*num_tiles_y_p)+(2*num_tiles_x_p);

  localparam vc_base_idx_lp = 1+(num_tiles_x_p*num_tiles_y_p);

  //// FWD network;
  logic [num_src_lp-1:0][num_dst_lp-1:0] fwd_fanout_v_lo;
  bsg_manycore_packet_s [num_src_lp-1:0][num_dst_lp-1:0] fwd_fanout_packet_lo;
  logic [num_src_lp-1:0][num_dst_lp-1:0] fwd_fanout_yumi_li;

  // Host FWD fanout;
  bsg_manycore_xbar_fanout #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(x_cord_width_p)
    ,.host_x_cord_p(host_x_cord_p)
    ,.host_y_cord_p(host_y_cord_p)
    ,.fwd_not_rev_p(1)
    ,.fifo_els_p(fwd_fifo_els_p)
    ,.use_credits_p(0)
  ) host_fwd_fanout (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(host_link_in.fwd.v)
    ,.packet_i(host_link_in.fwd.data)
    ,.credit_or_ready_o(host_link_out.fwd.ready_and_rev)
  
    ,.v_o(fwd_fanout_v_lo[0])
    ,.packet_o(fwd_fanout_packet_lo[0])
    ,.yumi_i(fwd_fanout_yumi_li[0])
  );

  // Core fwd fanout;
  for (genvar r = 0; r < num_tiles_y_p; r++) begin: tile_y
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: tile_x
      bsg_manycore_xbar_fanout #(
        .num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.host_x_cord_p(host_x_cord_p)
        ,.host_y_cord_p(host_y_cord_p)
        ,.fwd_not_rev_p(1)
        ,.input_fifo_els_p(fwd_fifo_els_p)
        ,.fifo_els_p(fwd_fifo_els_p)
        ,.use_credits_p(1)
      ) core_fwd_fanout (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(core_link_in[r][c].fwd.v)
        ,.packet_i(core_link_in[r][c].fwd.data)
        ,.credit_or_ready_o(core_link_out[r][c].fwd.ready_and_rev)
  
        ,.v_o(fwd_fanout_v_lo[1+c+(r*num_tiles_x_p)])
        ,.packet_o(fwd_fanout_packet_lo[1+(c+(r*num_tiles_x_p))])
        ,.yumi_i(fwd_fanout_yumi_li[1+(c+(r*num_tiles_x_p))])
      );
    end
  end

  
  // transposed fwd fanout
  logic [num_dst_lp-1:0][num_src_lp-1:0] fwd_fanout_v_lo_tp;
  bsg_manycore_packet_s [num_dst_lp-1:0][num_src_lp-1:0] fwd_fanout_packet_lo_tp;
  logic [num_dst_lp-1:0][num_src_lp-1:0] fwd_fanout_yumi_li_tp;
  
  for (genvar d = 0; d < num_dst_lp; d++) begin
    for (genvar s = 0; s < num_src_lp; s++) begin
      assign fwd_fanout_v_lo_tp[d][s] = fwd_fanout_v_lo[s][d];
      assign fwd_fanout_packet_lo_tp[d][s] = fwd_fanout_packet_lo[s][d];
      assign fwd_fanout_yumi_li[s][d] = fwd_fanout_yumi_li_tp[d][s];
    end
  end
  

  // Host FWD fanin 
  bsg_manycore_xbar_fanin #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.fwd_not_rev_p(1)
  ) host_fwd_fanin (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(fwd_fanout_v_lo_tp[0])
    ,.packet_i(fwd_fanout_packet_lo_tp[0])
    ,.yumi_o(fwd_fanout_yumi_li_tp[0])

    ,.v_o(host_link_out.fwd.v)
    ,.packet_o(host_link_out.fwd.data)
    ,.ready_i(host_link_in.fwd.ready_and_rev)
  );


  // Core FWD fanin 
  for (genvar r = 0; r < num_tiles_y_p; r++) begin
    for (genvar c = 0; c < num_tiles_x_p; c++) begin
      bsg_manycore_xbar_fanin #(
        .num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.fwd_not_rev_p(1)
      ) core_fwd_fanin (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(fwd_fanout_v_lo_tp[1+c+(r*num_tiles_x_p)])
        ,.packet_i(fwd_fanout_packet_lo_tp[1+c+(r*num_tiles_x_p)])
        ,.yumi_o(fwd_fanout_yumi_li_tp[1+c+(r*num_tiles_x_p)])

        ,.v_o(core_link_out[r][c].fwd.v)
        ,.packet_o(core_link_out[r][c].fwd.data)
        ,.ready_i(core_link_in[r][c].fwd.ready_and_rev)
      );
    end
  end

  // vcache FWD fanin 
  for (genvar r = 0; r <= 1; r++) begin
    for (genvar c = 0; c < num_tiles_x_p; c++) begin
      bsg_manycore_xbar_fanin #(
        .num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.fwd_not_rev_p(1)
      ) vc_fwd_fanin (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(fwd_fanout_v_lo_tp[vc_base_idx_lp+c+(r*num_tiles_x_p)])
        ,.packet_i(fwd_fanout_packet_lo_tp[vc_base_idx_lp+c+(r*num_tiles_x_p)])
        ,.yumi_o(fwd_fanout_yumi_li_tp[vc_base_idx_lp+c+(r*num_tiles_x_p)])

        ,.v_o(vc_link_out[r][c].fwd.v)
        ,.packet_o(vc_link_out[r][c].fwd.data)
        ,.ready_i(vc_link_in[r][c].fwd.ready_and_rev)
      );
    end
  end


  //// REV network;
  logic [num_dst_lp-1:0][num_src_lp-1:0] rev_fanout_v_lo;
  bsg_manycore_return_packet_s [num_dst_lp-1:0][num_src_lp-1:0] rev_fanout_packet_lo;
  logic [num_dst_lp-1:0][num_src_lp-1:0] rev_fanout_yumi_li;

  // Host REV fanout;
  bsg_manycore_xbar_fanout #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(x_cord_width_p)
    ,.host_x_cord_p(host_x_cord_p)
    ,.host_y_cord_p(host_y_cord_p)
    ,.fwd_not_rev_p(0)
    ,.fifo_els_p(rev_fifo_els_p)
    ,.use_credits_p(0)
  ) host_rev_fanout (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(host_link_in.rev.v)
    ,.packet_i(host_link_in.rev.data)
    ,.credit_or_ready_o(host_link_out.rev.ready_and_rev)
  
    ,.v_o(rev_fanout_v_lo[0])
    ,.packet_o(rev_fanout_packet_lo[0])
    ,.yumi_i(rev_fanout_yumi_li[0])
  );

  // Tile REV fanout;
  for (genvar r = 0; r < num_tiles_y_p; r++) begin
    for (genvar c = 0; c < num_tiles_x_p; c++) begin
      bsg_manycore_xbar_fanout #(
        .num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.host_x_cord_p(host_x_cord_p)
        ,.host_y_cord_p(host_y_cord_p)
        ,.fwd_not_rev_p(0)
        ,.input_fifo_els_p(rev_fifo_els_p)
        ,.fifo_els_p(rev_fifo_els_p)
        ,.use_credits_p(1)
      ) core_rev_fanout (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(core_link_in[r][c].rev.v)
        ,.packet_i(core_link_in[r][c].rev.data)
        ,.credit_or_ready_o(core_link_out[r][c].rev.ready_and_rev)
  
        ,.v_o(rev_fanout_v_lo[1+c+(r*num_tiles_x_p)])
        ,.packet_o(rev_fanout_packet_lo[1+(c+(r*num_tiles_x_p))])
        ,.yumi_i(rev_fanout_yumi_li[1+(c+(r*num_tiles_x_p))])
      );
    end
  end

  // Vcache REV fanout;
  for (genvar r = 0; r <= 1; r++) begin
    for (genvar c = 0; c < num_tiles_x_p; c++) begin
      bsg_manycore_xbar_fanout #(
        .num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.host_x_cord_p(host_x_cord_p)
        ,.host_y_cord_p(host_y_cord_p)
        ,.fwd_not_rev_p(0)
        ,.fifo_els_p(rev_fifo_els_p)
        ,.use_credits_p(0)
      ) vc_rev_fanout (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(vc_link_in[r][c].rev.v)
        ,.packet_i(vc_link_in[r][c].rev.data)
        ,.credit_or_ready_o(vc_link_out[r][c].rev.ready_and_rev)
  
        ,.v_o(rev_fanout_v_lo[vc_base_idx_lp+c+(r*num_tiles_x_p)])
        ,.packet_o(rev_fanout_packet_lo[vc_base_idx_lp+(c+(r*num_tiles_x_p))])
        ,.yumi_i(rev_fanout_yumi_li[vc_base_idx_lp+(c+(r*num_tiles_x_p))])
      );
    end
  end

  // transpose rev fanout;
  logic [num_src_lp-1:0][num_dst_lp-1:0] rev_fanout_v_lo_tp;
  bsg_manycore_return_packet_s [num_src_lp-1:0][num_dst_lp-1:0] rev_fanout_packet_lo_tp;
  logic [num_src_lp-1:0][num_dst_lp-1:0] rev_fanout_yumi_li_tp;
  
  for (genvar d = 0; d < num_dst_lp; d++) begin
    for (genvar s = 0; s < num_src_lp; s++) begin
      assign rev_fanout_v_lo_tp[s][d] = rev_fanout_v_lo[d][s];
      assign rev_fanout_packet_lo_tp[s][d] = rev_fanout_packet_lo[d][s];
      assign rev_fanout_yumi_li[d][s] = rev_fanout_yumi_li_tp[s][d];
    end
  end

  // host rev fanin;
  bsg_manycore_xbar_fanin #(
    .num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.fwd_not_rev_p(0)
  ) host_rev_fanin (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(rev_fanout_v_lo_tp[0])
    ,.packet_i(rev_fanout_packet_lo_tp[0])
    ,.yumi_o(rev_fanout_yumi_li_tp[0])

    ,.v_o(host_link_out.rev.v)
    ,.packet_o(host_link_out.rev.data)
    ,.ready_i(host_link_in.rev.ready_and_rev)
  );

  // tile rev fanin;
  for (genvar r = 0; r < num_tiles_y_p; r++) begin
    for (genvar c = 0; c < num_tiles_x_p; c++) begin
      bsg_manycore_xbar_fanin #(
        .num_tiles_x_p(num_tiles_x_p)
        ,.num_tiles_y_p(num_tiles_y_p)
        ,.y_cord_width_p(y_cord_width_p)
        ,.x_cord_width_p(x_cord_width_p)
        ,.addr_width_p(addr_width_p)
        ,.data_width_p(data_width_p)
        ,.fwd_not_rev_p(0)
      ) core_rev_fanin (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(rev_fanout_v_lo_tp[1+c+(r*num_tiles_x_p)])
        ,.packet_i(rev_fanout_packet_lo_tp[1+c+(r*num_tiles_x_p)])
        ,.yumi_o(rev_fanout_yumi_li_tp[1+c+(r*num_tiles_x_p)])

        ,.v_o(core_link_out[r][c].rev.v)
        ,.packet_o(core_link_out[r][c].rev.data)
        ,.ready_i(core_link_in[r][c].rev.ready_and_rev)
      );
    end
  end

endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_xbar)
