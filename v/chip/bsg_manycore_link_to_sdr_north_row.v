
`include "bsg_manycore_defines.vh"

module bsg_manycore_link_to_sdr_north_row
  import bsg_manycore_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , parameter `BSG_INV_PARAM(addr_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)
    , parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter fwd_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter rev_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)

    , parameter `BSG_INV_PARAM(lg_fifo_depth_p)
    , parameter `BSG_INV_PARAM(lg_credit_to_token_decimation_p)

    , parameter num_clk_ports_p=1

    , parameter tag_els_p=1024
    , parameter tag_local_els_p=1
    , parameter tag_lg_width_p=4
    , parameter tag_lg_els_lp=`BSG_SAFE_CLOG2(tag_els_p)
  )
  (
    input [num_clk_ports_p-1:0] core_clk_i
    , output [num_tiles_x_p-1:0] core_reset_ver_o
    , output [E:W]  core_reset_o

    , input  [num_tiles_x_p-1:0][x_cord_width_p-1:0] core_global_x_i
    , input  [num_tiles_x_p-1:0][y_cord_width_p-1:0] core_global_y_i
    , output [num_tiles_x_p-1:0][x_cord_width_p-1:0] core_global_x_o
    , output [num_tiles_x_p-1:0][y_cord_width_p-1:0] core_global_y_o

    ,input  [num_tiles_x_p-1:0][link_sif_width_lp-1:0] core_link_sif_i
    ,output [num_tiles_x_p-1:0][link_sif_width_lp-1:0] core_link_sif_o
  
    , input  async_uplink_reset_i
    , input  async_downlink_reset_i
    , input  async_downstream_reset_i
    , input  async_token_reset_i

    , output async_uplink_reset_o
    , output async_downlink_reset_o
    , output async_downstream_reset_o
    , output async_token_reset_o

    ,input  [num_tiles_x_p-1:0] async_fwd_link_i_disable_i
    ,input  [num_tiles_x_p-1:0] async_fwd_link_o_disable_i
    ,input  [num_tiles_x_p-1:0] async_rev_link_i_disable_i
    ,input  [num_tiles_x_p-1:0] async_rev_link_o_disable_i

    ,output [num_tiles_x_p-1:0]                   io_fwd_link_clk_o
    ,output [num_tiles_x_p-1:0][fwd_width_lp-1:0] io_fwd_link_data_o
    ,output [num_tiles_x_p-1:0]                   io_fwd_link_v_o
    ,input  [num_tiles_x_p-1:0]                   io_fwd_link_token_i

    ,input  [num_tiles_x_p-1:0]                   io_fwd_link_clk_i
    ,input  [num_tiles_x_p-1:0][fwd_width_lp-1:0] io_fwd_link_data_i
    ,input  [num_tiles_x_p-1:0]                   io_fwd_link_v_i
    ,output [num_tiles_x_p-1:0]                   io_fwd_link_token_o

    ,output [num_tiles_x_p-1:0]                   io_rev_link_clk_o
    ,output [num_tiles_x_p-1:0][rev_width_lp-1:0] io_rev_link_data_o
    ,output [num_tiles_x_p-1:0]                   io_rev_link_v_o
    ,input  [num_tiles_x_p-1:0]                   io_rev_link_token_i

    ,input  [num_tiles_x_p-1:0]                   io_rev_link_clk_i
    ,input  [num_tiles_x_p-1:0][rev_width_lp-1:0] io_rev_link_data_i
    ,input  [num_tiles_x_p-1:0]                   io_rev_link_v_i
    ,output [num_tiles_x_p-1:0]                   io_rev_link_token_o

    // bsg_tag_master
    ,input tag_clk_i
    ,input tag_data_i
    ,input [tag_lg_els_lp-1:0] node_id_offset_i
  );

  // BTM
  bsg_tag_s clients_lo;
  bsg_tag_master_decentralized #(
    .els_p(tag_els_p)
    ,.local_els_p(tag_local_els_p)
    ,.lg_width_p(tag_lg_width_p)
  ) btm0 (
    .clk_i(tag_clk_i)
    ,.data_i(tag_data_i)
    ,.node_id_offset_i(node_id_offset_i)
    ,.clients_o(clients_lo)
  );


  // BTC for core reset
  logic btc_core_reset_lo;
  bsg_tag_client #(
    .width_p(1)
  ) btc (
    .bsg_tag_i(clients_lo)
    ,.recv_clk_i(core_clk_i)
    ,.recv_new_r_o()
    ,.recv_data_r_o(btc_core_reset_lo)
  );


  logic [num_tiles_x_p-1:0]       core_reset_li;
  logic [num_tiles_x_p-1:0][1:0]  core_reset_lo;

  logic [num_tiles_x_p-1:0] async_uplink_reset_li;
  logic [num_tiles_x_p-1:0] async_downlink_reset_li;
  logic [num_tiles_x_p-1:0] async_downstream_reset_li;
  logic [num_tiles_x_p-1:0] async_token_reset_li;

  logic [num_tiles_x_p-1:0] async_uplink_reset_lo;
  logic [num_tiles_x_p-1:0] async_downlink_reset_lo;
  logic [num_tiles_x_p-1:0] async_downstream_reset_lo;
  logic [num_tiles_x_p-1:0] async_token_reset_lo;


  for (genvar x = 0; x < num_tiles_x_p; x++) begin: sdr_x
    bsg_manycore_link_to_sdr_north #(
      .lg_fifo_depth_p                  (lg_fifo_depth_p)
      ,.lg_credit_to_token_decimation_p (lg_credit_to_token_decimation_p)
      ,.x_cord_width_p                  (x_cord_width_p)
      ,.y_cord_width_p                  (y_cord_width_p)
      ,.addr_width_p                    (addr_width_p)
      ,.data_width_p                    (data_width_p)

    ) sdr_n (
      .core_clk_i                 (core_clk_i[x/(num_tiles_x_p/num_clk_ports_p)])
      ,.core_reset_i              (core_reset_li[x])
      ,.core_reset_o              (core_reset_lo[x])

      ,.core_global_x_i           (core_global_x_i[x])
      ,.core_global_y_i           (core_global_y_i[x])
      ,.core_global_x_o           (core_global_x_o[x])
      ,.core_global_y_o           (core_global_y_o[x])

      ,.core_link_sif_i           (core_link_sif_i[x])
      ,.core_link_sif_o           (core_link_sif_o[x])

      ,.async_uplink_reset_i      (async_uplink_reset_li[x])
      ,.async_downlink_reset_i    (async_downlink_reset_li[x])
      ,.async_downstream_reset_i  (async_downstream_reset_li[x])
      ,.async_token_reset_i       (async_token_reset_li[x])

      ,.async_uplink_reset_o      (async_uplink_reset_lo[x])
      ,.async_downlink_reset_o    (async_downlink_reset_lo[x])
      ,.async_downstream_reset_o  (async_downstream_reset_lo[x])
      ,.async_token_reset_o       (async_token_reset_lo[x])

      ,.async_fwd_link_i_disable_i(async_fwd_link_i_disable_i[x])
      ,.async_fwd_link_o_disable_i(async_fwd_link_o_disable_i[x])
      ,.async_rev_link_i_disable_i(async_rev_link_i_disable_i[x])
      ,.async_rev_link_o_disable_i(async_rev_link_o_disable_i[x])

      ,.io_fwd_link_clk_o         (io_fwd_link_clk_o[x])
      ,.io_fwd_link_data_o        (io_fwd_link_data_o[x])
      ,.io_fwd_link_v_o           (io_fwd_link_v_o[x])
      ,.io_fwd_link_token_i       (io_fwd_link_token_i[x])

      ,.io_fwd_link_clk_i         (io_fwd_link_clk_i[x])
      ,.io_fwd_link_data_i        (io_fwd_link_data_i[x])
      ,.io_fwd_link_v_i           (io_fwd_link_v_i[x])
      ,.io_fwd_link_token_o       (io_fwd_link_token_o[x])

      ,.io_rev_link_clk_o         (io_rev_link_clk_o[x])
      ,.io_rev_link_data_o        (io_rev_link_data_o[x])
      ,.io_rev_link_v_o           (io_rev_link_v_o[x])
      ,.io_rev_link_token_i       (io_rev_link_token_i[x])

      ,.io_rev_link_clk_i         (io_rev_link_clk_i[x])
      ,.io_rev_link_data_i        (io_rev_link_data_i[x])
      ,.io_rev_link_v_i           (io_rev_link_v_i[x])
      ,.io_rev_link_token_o       (io_rev_link_token_o[x])

    );

    if (x == 0) begin
      assign core_reset_o[W] = core_reset_lo[x][1];
      assign async_uplink_reset_li[x] = async_uplink_reset_i;
      assign async_downlink_reset_li[x] = async_downlink_reset_i;
      assign async_downstream_reset_li[x] = async_downstream_reset_i;
      assign async_token_reset_li[x] = async_token_reset_i;
    end
  
    if (x > 0) begin
      assign async_uplink_reset_li[x] = async_uplink_reset_lo[x-1];
      assign async_downlink_reset_li[x] = async_downlink_reset_lo[x-1];
      assign async_downstream_reset_li[x] = async_downstream_reset_lo[x-1];
      assign async_token_reset_li[x] = async_token_reset_lo[x-1];
    end
  
    if (x < num_tiles_x_p-1) begin
      assign core_reset_li[x] = core_reset_lo[x+1][1];
    end

    if (x == num_tiles_x_p-1) begin
      assign core_reset_li[x] = btc_core_reset_lo;
      assign async_uplink_reset_o = async_uplink_reset_lo[x];
      assign async_downlink_reset_o = async_downlink_reset_lo[x];
      assign async_downstream_reset_o = async_downstream_reset_lo[x];
      assign async_token_reset_o = async_token_reset_lo[x];
      assign core_reset_o[E] = btc_core_reset_lo;
    end

    assign core_reset_ver_o[x] = core_reset_lo[x][0];

  end


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_to_sdr_north_row)

