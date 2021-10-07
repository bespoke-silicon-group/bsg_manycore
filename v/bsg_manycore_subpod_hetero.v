
`include "bsg_defines.v"

module bsg_manycore_subpod_hetero
 import bsg_chip_pkg::*;
 #(// Hetero socket parameters
   parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
   , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
   , parameter `BSG_INV_PARAM(dmem_size_p)
   , parameter `BSG_INV_PARAM(vcache_size_p)
   , parameter `BSG_INV_PARAM(icache_entries_p)
   , parameter `BSG_INV_PARAM(icache_tag_width_p)
   , parameter `BSG_INV_PARAM(hetero_type_p)
   , parameter `BSG_INV_PARAM(num_tiles_x_p)
   , parameter `BSG_INV_PARAM(num_tiles_y_p)
   , parameter `BSG_INV_PARAM(num_vcache_rows_p)
   , parameter `BSG_INV_PARAM(vcache_block_size_in_words_p)
   , parameter `BSG_INV_PARAM(vcache_sets_p)
   , parameter `BSG_INV_PARAM(fwd_fifo_els_p)
   , parameter `BSG_INV_PARAM(rev_fifo_els_p)
   , parameter `BSG_INV_PARAM(links_p)
   , parameter `BSG_INV_PARAM(debug_p)

   // Tag parameters
   , parameter `BSG_INV_PARAM(tag_els_p)
   , parameter `BSG_INV_PARAM(tag_local_els_p)
   , parameter `BSG_INV_PARAM(tag_max_payload_width_p)

   // Clock generator parameters
   , parameter `BSG_INV_PARAM(clk_gen_p)
   , parameter `BSG_INV_PARAM(clk_gen_ds_width_p)
   , parameter `BSG_INV_PARAM(clk_gen_num_adgs_p)
   )
  (input                                           ext_clk_i

   , input                                         tag_clk_i
   , input                                         tag_data_i
   , input [`BSG_SAFE_CLOG2(tag_els_p)-1:0]        tag_node_id_offset_i

   , output logic [links_p-1:0]                    fwd_link_clk_o
   , output logic [links_p-1:0][fwd_width_lp-1:0]  fwd_link_data_o
   , output logic [links_p-1:0]                    fwd_link_v_o
   , input [links_p-1:0]                           fwd_link_token_i

   , input [links_p-1:0]                           fwd_link_clk_i
   , input [links_p-1:0][fwd_width_lp-1:0]         fwd_link_data_i
   , input [links_p-1:0]                           fwd_link_v_i
   , output logic [links_p-1:0]                    fwd_link_token_o

   , output logic [links_p-1:0]                    rev_link_clk_o
   , output logic [links_p-1:0][rev_width_lp-1:0]  rev_link_data_o
   , output logic [links_p-1:0]                    rev_link_v_o
   , input [links_p-1:0]                           rev_link_token_i

   , input [links_p-1:0]                           rev_link_clk_i
   , input [links_p-1:0][rev_width_lp-1:0]         rev_link_data_i
   , input [links_p-1:0]                           rev_link_v_i
   , output logic [links_p-1:0]                    rev_link_token_o
   );

  `define BSG_TAG_CLIENT_UNSYNC(tag_line_mp, signal_mp, width_mp) \
    logic [width_mp-1:0] signal_mp;                        \
    bsg_tag_client_unsync #(.width_p(width_mp))            \
    btc_``signal_mp``                                      \
     (.bsg_tag_i(tag_line_mp)                              \
      ,.data_async_r_o(signal_mp)                          \
      )
  
  `define BSG_TAG_CLIENT_SYNC(tag_line_mp, signal_mp, width_mp, recv_clk_mp) \
    logic [width_mp-1:0] signal_mp;                        \
    bsg_tag_client #(.width_p(width_mp))                   \
    btc_``signal_mp``                                      \
     (.bsg_tag_i(tag_line_mp)                              \
      ,.recv_clk_i(recv_clk_mp)                            \
      ,.recv_new_r_o()                                     \
      ,.recv_data_r_o(signal_mp)                           \
      )

  typedef struct packed {
    bsg_tag_s global_x_cord;
    bsg_tag_s global_y_cord;
    bsg_tag_s sdr_disable;
    bsg_chip_sdr_tag_lines_s sdr;
    bsg_chip_clk_gen_tag_lines_s clk_gen;
    bsg_tag_s core_reset;
  } bsg_manycore_subpod_tag_lines_s;

  bsg_manycore_subpod_tag_lines_s tag_lines_lo;
  bsg_tag_master_decentralized #(
    .els_p(tag_els_p)
    ,.local_els_p(tag_local_els_p)
    ,.lg_width_p(`BSG_WIDTH(tag_max_payload_width_p))
  ) btm (
    .clk_i(tag_clk_i)
    ,.data_i(tag_data_i)
    ,.node_id_offset_i(tag_node_id_offset_i)
    ,.clients_o(tag_lines_lo)
  );

  logic core_clk_lo;
  if (clk_gen_p == 1) begin : clkgen
    // Clock Gen Tag Clients
    `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.clk_gen.sel, clk_gen_sel_li, 2);
    `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.clk_gen.async_reset, clk_gen_async_reset_li, 1);

    bsg_clk_gen #(
      .downsample_width_p(clk_gen_ds_width_p)
      ,.num_adgs_p(clk_gen_num_adgs_p)
      ,.version_p(2)
    ) clk_gen (
      .bsg_osc_tag_i(tag_lines_lo.clk_gen.osc)
      ,.bsg_osc_trigger_tag_i(tag_lines_lo.clk_gen.osc_trigger)
      ,.bsg_ds_tag_i(tag_lines_lo.clk_gen.ds)
      ,.async_osc_reset_i(clk_gen_async_reset_li)
      ,.ext_clk_i(ext_clk_i)
      ,.select_i(clk_gen_sel_li)
      ,.clk_o(core_clk_lo)
    );
  end else begin : no_clkgen
    assign core_clk_lo = ext_clk_i;
  end

  // SDR Tag Clients
  `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.sdr.token_reset, sdr_token_reset_li, 1);
  `BSG_TAG_CLIENT_SYNC(tag_lines_lo.sdr.downstream_reset, sdr_downstream_reset_li, 1, core_clk_lo);
  `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.sdr.downlink_reset, sdr_downlink_reset_li, 1);
  `BSG_TAG_CLIENT_SYNC(tag_lines_lo.sdr.uplink_reset, sdr_uplink_reset_li, 1, core_clk_lo);
  `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.sdr_disable, sdr_disable_lo, 1);

  assign async_link_o_disable_o = sdr_disable_lo;
  assign async_link_i_disable_o = sdr_disable_lo;

  // Core Tag Clients
  `BSG_TAG_CLIENT_SYNC(tag_lines_lo.core_reset, core_reset_lo, 1, core_clk_lo);
  `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.global_x_cord, global_x_cord_li, x_cord_width_p);
  `BSG_TAG_CLIENT_UNSYNC(tag_lines_lo.global_y_cord, global_y_cord_li, y_cord_width_p);
  localparam x_subcord_width_lp = x_cord_width_p - pod_x_cord_width_p;
  localparam y_subcord_width_lp = y_cord_width_p - pod_y_cord_width_p;

  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

  for (genvar i = 0; i < links_p; i++) begin : links
    bsg_manycore_link_sif_s [links_p-1:0] ep_link_sif_li, ep_link_sif_lo;
    bsg_manycore_link_resp_credit_to_ready_and_handshake #(
      .addr_width_p(hb_addr_width_gp)
      ,.data_width_p(hb_data_width_gp)
      ,.x_cord_width_p(hb_x_cord_width_gp)
      ,.y_cord_width_p(hb_y_cord_width_gp)
    ) rev_c2r (
      .clk_i(core_clk_lo)
      ,.reset_i(core_reset_lo)

      ,.credit_link_sif_i(proc_link_sif_lo[i])
      ,.credit_link_sif_o(proc_link_sif_li[i])

      ,.ready_and_link_sif_i(ep_link_sif_li)
      ,.ready_and_link_sif_o(ep_link_sif_lo)
    );

    bsg_link_sdr #(
      .width_p(fwd_width_lp)
      ,.lg_fifo_depth_p(sdr_lg_fifo_depth_gp)
      ,.lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_gp)
    ) fwd_sdr (
      .core_clk_i(core_clk_lo)
      ,.core_uplink_reset_i(sdr_uplink_reset_li)
      ,.core_downstream_reset_i(sdr_downstream_reset_li)
      ,.async_downlink_reset_i(sdr_downlink_reset_li)
      ,.async_token_reset_i(sdr_token_reset_li)

      ,.core_data_i(ep_link_sif_lo.fwd.data)
      ,.core_v_i(ep_link_sif_lo.fwd.v)
      ,.core_ready_o(ep_link_sif_li.fwd.ready_and_rev)

      ,.core_data_o(ep_link_sif_li.fwd.data)
      ,.core_v_o(ep_link_sif_li.fwd.v)
      ,.core_yumi_i(ep_link_sif_li.fwd.v & ep_link_sif_lo.fwd.ready_and_rev)

      ,.link_clk_o(fwd_link_clk_o[i])
      ,.link_data_o(fwd_link_data_o[i])
      ,.link_v_o(fwd_link_v_o[i])
      ,.link_token_i(fwd_link_token_i[i])

      ,.link_clk_i(fwd_link_clk_i[i])
      ,.link_data_i(fwd_link_data_i[i])
      ,.link_v_i(fwd_link_v_i[i])
      ,.link_token_o(fwd_link_token_o[i])
    );

    bsg_link_sdr #(
      .width_p(rev_width_lp)
      ,.lg_fifo_depth_p(sdr_lg_fifo_depth_gp)
      ,.lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_gp)
    ) rev_sdr (
      .core_clk_i(core_clk_lo)
      ,.core_uplink_reset_i(sdr_uplink_reset_li)
      ,.core_downstream_reset_i(sdr_downstream_reset_li)
      ,.async_downlink_reset_i(sdr_downlink_reset_li)
      ,.async_token_reset_i(sdr_token_reset_li)

      ,.core_data_i(ep_link_sif_lo.rev.data)
      ,.core_v_i(ep_link_sif_lo.rev.v)
      ,.core_ready_o(ep_link_sif_li.rev.ready_and_rev)

      ,.core_data_o(ep_link_sif_li.rev.data)
      ,.core_v_o(ep_link_sif_li.rev.v)
      ,.core_yumi_i(ep_link_sif_li.rev.v & ep_link_sif_lo.rev.ready_and_rev)

      ,.link_clk_o(rev_link_clk_o[i])
      ,.link_data_o(rev_link_data_o[i])
      ,.link_v_o(rev_link_v_o[i])
      ,.link_token_i(rev_link_token_i[i])

      ,.link_clk_i(rev_link_clk_i[i])
      ,.link_data_i(rev_link_data_i[i])
      ,.link_v_i(rev_link_v_i[i])
      ,.link_token_o(rev_link_token_o[i])
    );
  end

  bsg_manycore_hetero_socket #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.vcache_size_p(vcache_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.hetero_type_p(hetero_type_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_p)
    ,.rev_fifo_els_p(rev_fifo_els_p)
    ,.links_p(links_p)
    ,.debug_p(debug_p)
  ) proc (
    .clk_i(core_clk_lo)
    ,.reset_i(core_reset_lo)

    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)

    ,.pod_x_i(global_x_cord_li[x_subcord_width_lp+:pod_x_cord_width_p])
    ,.pod_y_i(global_y_cord_li[y_subcord_width_lp+:pod_y_cord_width_p])

    ,.my_x_i(global_x_cord_li[0+:x_subcord_width_lp])
    ,.my_y_i(global_y_cord_li[0+:y_subcord_width_lp])
  );

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_subpod_hetero)

