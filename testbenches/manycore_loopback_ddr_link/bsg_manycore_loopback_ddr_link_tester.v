
//
// Paul Gao 06/2019
//
// This is a tester for wormhole network and bsg_link.
// Two manycore loopback nodes send out packets, then receive the looped back packets.
// Correctness are checked automatically.
//
//

`timescale 1ps/1ps
`include "bsg_manycore_packet.vh"

module bsg_manycore_loopback_ddr_link_tester

  import bsg_noc_pkg::Dirs
       , bsg_noc_pkg::P  // proc (local node)
       , bsg_noc_pkg::W  // west
       , bsg_noc_pkg::E  // east
       , bsg_noc_pkg::N  // north
       , bsg_noc_pkg::S; // south

 #(// Manycore configuration parameters, should match real Manycore tiles
   parameter mc_addr_width_p = 10
  ,parameter mc_data_width_p = 40
  ,parameter mc_load_id_width_p = 5
  ,parameter mc_x_cord_width_p = 5
  ,parameter mc_y_cord_width_p = 5
  
  // Loopback test node configuration
  ,parameter mc_node_num_channels_p = 7
  
  // How many wormhole packet flits for request and response
  // If ratio=n, then total packet length is n*width_p
  // 
  // Calculation of proper ratios (same for req and resp)
  // If the payload packet width is m, then:
  // (m+x_cord_width_p+y_cord_width_p+len_width_p+reserved_width_p)
  // must be smaller than or equal to (ratio*width_p)
  //
  // Increase these two ratios if adapter complains
  ,parameter req_ratio_p = 3
  ,parameter resp_ratio_p = 2
  
  // How many streams of traffic are merged in channel tunnel
  // In this testbench the number of traffics is 2 (req and resp traffic)
  ,parameter ct_num_in_p = 2
  
  // Wormhole packet configuration
  // Width of each wormhole flit
  // MUST be multiple of (2*channel_width_p*num_channels_p) 
  ,parameter width_p = 32
  
  // How many bits are needed for x-y coordinate
  // Always set to non-zero numbers
  ,parameter x_cord_width_p = 2
  ,parameter y_cord_width_p = 2
  
  // How many bits are used to represent packet length
  // If ratio is n, then length number is (n-1)
  // Should be $clog2(ratio-1+1)
  //
  // In this testbench, only 2 types of packets (req and resp)
  // Only consider the longest one
  ,parameter len_width_p = $clog2(`BSG_MAX(req_ratio_p, resp_ratio_p)-1+1)
  
  // This parameter is the property of wormhole network
  // The reserved bits are for channel_tunnel_wormhole to mux and demux packets
  // If we are merging m traffics in channel tunnel, then reserved bits needed
  // is $clog2(m+1), where the "+1" is for credit returning packet.
  ,parameter reserved_width_p = $clog2(ct_num_in_p+1)
  
  // Physical IO link configuration
  ,parameter channel_width_p = 8
  
  // How many physical IO link channels do we have for each bsg_link
  ,parameter num_channels_p = 2
  
  // DDR Link buffer size
  // 6 should be good for 500MHz, increase if channel stalls waiting for token
  ,parameter lg_fifo_depth_p = 6
  
  // This is for token credit return on IO channel
  // Do not change
  ,parameter lg_credit_to_token_decimation_p = 3
  
  // Channel tunnel configuration
  // Size of channel tunnel buffer (hardened memory)
  // There is a round-trip delay between sender and receiver for credit return
  // Must have large enough buffer to prevent stalling
  // Since credit counting is on header-flit, we need to consider the shortest possible packet
  // Suggested value is (96/`BSG_MIN(req_ratio, resp_ratio)) or larger
  ,parameter remote_credits_p = 48
  
  // Max possible number of wormhole payload flits going into channel tunnel
  // Each wormhole packet has 1 header flit and (m-1) payload flits
  ,parameter ct_max_payload_flits_p = `BSG_MAX(req_ratio_p, resp_ratio_p)-1
  
  // How often does channel tunnel return credits
  // If parameter is set to m, then channel tunnel will return credit to sender
  // after receiving 2^m wormhole packets (regardless of how many payload flits they have).
  //
  // Generally we don't want to send credit too often (wasteful of IO bandwidth)
  // Receiving a quarter of packets before return credit is reasonable
  // We may set lg_decimation to $clog2(remote_credits_p>>2) when remote_credits_p is power
  // of 2, otherwise set to ($clog2(remote_credits_p>>2)-1).
  ,parameter ct_lg_credit_decimation_p = 3
  )
  
  ();
  
  `declare_bsg_manycore_link_sif_s (mc_addr_width_p,mc_data_width_p,mc_x_cord_width_p,mc_y_cord_width_p,mc_load_id_width_p);
  `declare_bsg_ready_and_link_sif_s(width_p,bsg_ready_and_link_sif_s);
  
  // Clocks and control signals
  logic mc_clk_0, mc_clk_1;
  logic node_reset_0, node_reset_1, mc_reset_0, mc_reset_1;
  logic clk_0, clk_1, reset_0, reset_1;
  logic clk_2x_0, clk_2x_1;
  logic token_reset_0, token_reset_1;
  logic [num_channels_p-1:0] io_reset_0, io_reset_1;
  logic core_link_reset_0, core_link_reset_1;
  logic core_reset_0, core_reset_1;
  logic node_en_0, node_en_1, mc_en_0, mc_en_1;
  logic mc_error_0, mc_error_1;
  logic [31:0] sent_0, received_0, sent_1, received_1;
  
  bsg_manycore_link_sif_s out_mc_node_li;
  bsg_manycore_link_sif_s out_mc_node_lo;
  
  bsg_ready_and_link_sif_s [1:0] out_node_link_li;
  bsg_ready_and_link_sif_s [1:0] out_node_link_lo;
  
  bsg_ready_and_link_sif_s [1:0][2:0] out_router_link_li;
  bsg_ready_and_link_sif_s [1:0][2:0] out_router_link_lo;
  
  bsg_ready_and_link_sif_s [1:0] out_demux_link_li;
  bsg_ready_and_link_sif_s [1:0] out_demux_link_lo;
  
  logic out_ct_valid_lo, out_ct_ready_li;
  logic [width_p-1:0] out_ct_data_lo;
  
  logic out_ct_valid_li, out_ct_ready_lo;
  logic [width_p-1:0] out_ct_data_li;
  
  logic [num_channels_p-1:0] edge_clk_0, edge_valid_0, edge_token_0;
  logic [num_channels_p-1:0][channel_width_p-1:0] edge_data_0;
  
  logic [num_channels_p-1:0] edge_clk_1, edge_valid_1, edge_token_1;
  logic [num_channels_p-1:0][channel_width_p-1:0] edge_data_1;
  
  logic in_ct_valid_li, in_ct_ready_lo;
  logic [width_p-1:0] in_ct_data_li;
  
  logic in_ct_valid_lo, in_ct_ready_li;
  logic [width_p-1:0] in_ct_data_lo;
  
  bsg_ready_and_link_sif_s [1:0] in_demux_link_li;
  bsg_ready_and_link_sif_s [1:0] in_demux_link_lo;
  
  bsg_ready_and_link_sif_s [1:0][2:0] in_router_link_li;
  bsg_ready_and_link_sif_s [1:0][2:0] in_router_link_lo;
  
  bsg_ready_and_link_sif_s [1:0] in_node_link_li;
  bsg_ready_and_link_sif_s [1:0] in_node_link_lo;
  
  bsg_manycore_link_sif_s in_mc_node_li;
  bsg_manycore_link_sif_s in_mc_node_lo;
  
  genvar i;
  

  bsg_manycore_loopback_test_node
 #(.num_channels_p(mc_node_num_channels_p)
  ,.channel_width_p(channel_width_p)
  ,.addr_width_p(mc_addr_width_p)
  ,.data_width_p(mc_data_width_p)
  ,.load_id_width_p(mc_load_id_width_p)
  ,.x_cord_width_p(mc_x_cord_width_p)
  ,.y_cord_width_p(mc_y_cord_width_p)
  ) out_mc_node
  (.clk_i  (mc_clk_0)
  ,.reset_i(mc_reset_0)
  ,.en_i   (mc_en_0)
  
  ,.error_o   (mc_error_0)
  ,.sent_o    (sent_0)
  ,.received_o(received_0)

  ,.links_sif_i(out_mc_node_li)
  ,.links_sif_o(out_mc_node_lo)
  );


  bsg_manycore_link_async_to_wormhole
 #(.addr_width_p(mc_addr_width_p)
  ,.data_width_p(mc_data_width_p)
  ,.load_id_width_p(mc_load_id_width_p)
  ,.x_cord_width_p(mc_x_cord_width_p)
  ,.y_cord_width_p(mc_y_cord_width_p)
  ,.wormhole_req_ratio_p(req_ratio_p)
  ,.wormhole_resp_ratio_p(resp_ratio_p)
  ,.wormhole_width_p(width_p)
  ,.wormhole_x_cord_width_p(x_cord_width_p)
  ,.wormhole_y_cord_width_p(y_cord_width_p)
  ,.wormhole_len_width_p(len_width_p)
  ,.wormhole_reserved_width_p(reserved_width_p)
  ) out_adapter
  (.manycore_clk_i  (mc_clk_0)
  ,.manycore_reset_o(mc_reset_0)
  ,.manycore_en_o   (mc_en_0)
   
  ,.links_sif_i(out_mc_node_lo)
  ,.links_sif_o(out_mc_node_li)
   
  ,.clk_i   (clk_0)
  ,.reset_i (core_reset_0)
  ,.manycore_reset_i(node_reset_0)
  ,.manycore_en_i   (node_en_0)

  ,.dest_x_i((x_cord_width_p)'(3))
  ,.dest_y_i((y_cord_width_p)'(0))
  
  ,.link_i(out_node_link_li)
  ,.link_o(out_node_link_lo)
  );
  
  
  for (i = 0; i < ct_num_in_p; i++) 
  begin: r0

    bsg_wormhole_router
   #(.width_p(width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.len_width_p(len_width_p)
    ,.reserved_width_p(reserved_width_p)
    ,.enable_2d_routing_p(0)
    ,.stub_in_p(3'b010)
    ,.stub_out_p(3'b010)
    ) router_0
    (.clk_i  (clk_0)
    ,.reset_i(core_reset_0)
    // Configuration
    ,.my_x_i((x_cord_width_p)'(2))
    ,.my_y_i((y_cord_width_p)'(0))
    // Traffics
    ,.link_i(out_router_link_li[i])
    ,.link_o(out_router_link_lo[i])
    );
    
    
    assign out_node_link_li[i] = out_router_link_lo[i][P];
    assign out_router_link_li[i][P] = out_node_link_lo[i];
    
    assign out_demux_link_li[i] = out_router_link_lo[i][E];
    assign out_router_link_li[i][E] = out_demux_link_lo[i];
    
  end
  
  
  bsg_channel_tunnel_wormhole
 #(.width_p(width_p)
  ,.x_cord_width_p(x_cord_width_p)
  ,.y_cord_width_p(y_cord_width_p)
  ,.len_width_p(len_width_p)
  ,.reserved_width_p(reserved_width_p)
  ,.num_in_p(ct_num_in_p)
  ,.remote_credits_p(remote_credits_p)
  ,.max_payload_flits_p(ct_max_payload_flits_p)
  ,.lg_credit_decimation_p(ct_lg_credit_decimation_p)
  ) out_ct
  (.clk_i  (clk_0)
  ,.reset_i(core_reset_0)
  
  // incoming multiplexed data
  ,.multi_data_i (out_ct_data_li)
  ,.multi_v_i    (out_ct_valid_li)
  ,.multi_ready_o(out_ct_ready_lo)

  // outgoing multiplexed data
  ,.multi_data_o(out_ct_data_lo)
  ,.multi_v_o   (out_ct_valid_lo)
  ,.multi_yumi_i(out_ct_ready_li&out_ct_valid_lo)

  // demultiplexed data
  ,.link_i(out_demux_link_li)
  ,.link_o(out_demux_link_lo)
  );
  
  
  bsg_link_ddr_upstream
 #(.width_p(width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p(num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ) link_upstream_0
  (.core_clk_i         (clk_0)
  ,.io_clk_i           (clk_2x_0)
  ,.core_link_reset_i  (core_link_reset_0)
  ,.io_link_reset_i    (reset_0)
  ,.async_token_reset_i(token_reset_0)
  
  ,.core_data_i (out_ct_data_lo)
  ,.core_valid_i(out_ct_valid_lo)
  ,.core_ready_o(out_ct_ready_li)

  ,.io_clk_r_o  (edge_clk_0)
  ,.io_data_r_o (edge_data_0)
  ,.io_valid_r_o(edge_valid_0)
  ,.token_clk_i (edge_token_0)
  );
  
  
  bsg_link_ddr_downstream
 #(.width_p(width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p(num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ) link_downstream_0
  (.core_clk_i(clk_0)
  ,.core_link_reset_i(core_link_reset_0)
  ,.io_link_reset_i(io_reset_0)
  
  ,.core_data_o   (out_ct_data_li)
  ,.core_valid_o  (out_ct_valid_li)
  ,.core_yumi_i   (out_ct_valid_li&out_ct_ready_lo)

  ,.io_clk_i      (edge_clk_1)
  ,.io_data_i     (edge_data_1)
  ,.io_valid_i    (edge_valid_1)
  ,.core_token_r_o(edge_token_1)
  );
  
  
  bsg_link_ddr_upstream
 #(.width_p(width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p(num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ) link_upstream_1
  (.core_clk_i         (clk_1)
  ,.io_clk_i           (clk_2x_1)
  ,.core_link_reset_i  (core_link_reset_1)
  ,.io_link_reset_i    (reset_1)
  ,.async_token_reset_i(token_reset_1)
  
  ,.core_data_i (in_ct_data_lo)
  ,.core_valid_i(in_ct_valid_lo)
  ,.core_ready_o(in_ct_ready_li)

  ,.io_clk_r_o  (edge_clk_1)
  ,.io_data_r_o (edge_data_1)
  ,.io_valid_r_o(edge_valid_1)
  ,.token_clk_i (edge_token_1)
  );
  
  
  bsg_link_ddr_downstream
 #(.width_p(width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p(num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ) link_downstream_1
  (.core_clk_i(clk_1)
  ,.core_link_reset_i(core_link_reset_1)
  ,.io_link_reset_i(io_reset_1)
  
  ,.core_data_o   (in_ct_data_li)
  ,.core_valid_o  (in_ct_valid_li)
  ,.core_yumi_i   (in_ct_valid_li&in_ct_ready_lo)
  
  ,.io_clk_i      (edge_clk_0)
  ,.io_data_i     (edge_data_0)
  ,.io_valid_i    (edge_valid_0)
  ,.core_token_r_o(edge_token_0)
  );


  bsg_channel_tunnel_wormhole
 #(.width_p(width_p)
  ,.x_cord_width_p(x_cord_width_p)
  ,.y_cord_width_p(y_cord_width_p)
  ,.len_width_p(len_width_p)
  ,.reserved_width_p(reserved_width_p)
  ,.num_in_p(ct_num_in_p)
  ,.remote_credits_p(remote_credits_p)
  ,.max_payload_flits_p(ct_max_payload_flits_p)
  ,.lg_credit_decimation_p(ct_lg_credit_decimation_p)
  ) in_ct
  (.clk_i  (clk_1)
  ,.reset_i(core_reset_1)
  
  // incoming multiplexed data
  ,.multi_data_i (in_ct_data_li)
  ,.multi_v_i    (in_ct_valid_li)
  ,.multi_ready_o(in_ct_ready_lo)

  // outgoing multiplexed data
  ,.multi_data_o(in_ct_data_lo)
  ,.multi_v_o   (in_ct_valid_lo)
  ,.multi_yumi_i(in_ct_ready_li&in_ct_valid_lo)

  // demultiplexed data
  ,.link_i(in_demux_link_li)
  ,.link_o(in_demux_link_lo)
  );
  
  
  for (i = 0; i < ct_num_in_p; i++) 
  begin: r1
  
    bsg_wormhole_router
   #(.width_p(width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.len_width_p(len_width_p)
    ,.reserved_width_p(reserved_width_p)
    ,.enable_2d_routing_p(0)
    ,.stub_in_p(3'b100)
    ,.stub_out_p(3'b100)
    ) router_1
    (.clk_i  (clk_1)
    ,.reset_i(core_reset_1)
    // Configuration
    ,.my_x_i((x_cord_width_p)'(3))
    ,.my_y_i((y_cord_width_p)'(0))
    // Traffics
    ,.link_i(in_router_link_li[i])
    ,.link_o(in_router_link_lo[i])
    );
    
    assign in_node_link_li[i] = in_router_link_lo[i][P];
    assign in_router_link_li[i][P] = in_node_link_lo[i];
    
    assign in_demux_link_li[i] = in_router_link_lo[i][W];
    assign in_router_link_li[i][W] = in_demux_link_lo[i];
    
  end


  bsg_manycore_link_async_to_wormhole
 #(.addr_width_p(mc_addr_width_p)
  ,.data_width_p(mc_data_width_p)
  ,.load_id_width_p(mc_load_id_width_p)
  ,.x_cord_width_p(mc_x_cord_width_p)
  ,.y_cord_width_p(mc_y_cord_width_p)
  ,.wormhole_req_ratio_p(req_ratio_p)
  ,.wormhole_resp_ratio_p(resp_ratio_p)
  ,.wormhole_width_p(width_p)
  ,.wormhole_x_cord_width_p(x_cord_width_p)
  ,.wormhole_y_cord_width_p(y_cord_width_p)
  ,.wormhole_len_width_p(len_width_p)
  ,.wormhole_reserved_width_p(reserved_width_p)
  ) in_adapter
  (.manycore_clk_i  (mc_clk_1)
  ,.manycore_reset_o(mc_reset_1)
  ,.manycore_en_o   (mc_en_1)
   
  ,.links_sif_i(in_mc_node_lo)
  ,.links_sif_o(in_mc_node_li)
   
  ,.clk_i  (clk_1)
  ,.reset_i(core_reset_1)
  ,.manycore_reset_i(node_reset_1)
  ,.manycore_en_i   (node_en_1)

  ,.dest_x_i((x_cord_width_p)'(2))
  ,.dest_y_i((y_cord_width_p)'(0))
  
  ,.link_i(in_node_link_li)
  ,.link_o(in_node_link_lo)
  );
  
  
  bsg_manycore_loopback_test_node
 #(.num_channels_p(mc_node_num_channels_p)
  ,.channel_width_p(channel_width_p)
  ,.addr_width_p(mc_addr_width_p)
  ,.data_width_p(mc_data_width_p)
  ,.load_id_width_p(mc_load_id_width_p)
  ,.x_cord_width_p(mc_x_cord_width_p)
  ,.y_cord_width_p(mc_y_cord_width_p)
  ) in_mc_node
  (.clk_i  (mc_clk_1)
  ,.reset_i(mc_reset_1)
  ,.en_i   (mc_en_1)
  
  ,.error_o   (mc_error_1)
  ,.sent_o    (sent_1)
  ,.received_o(received_1)

  ,.links_sif_i(in_mc_node_li)
  ,.links_sif_o(in_mc_node_lo)
  );
  


  // Simulation of Clock
  always #3 clk_0    = ~clk_0;
  always #3 clk_1    = ~clk_1;
  always #2 clk_2x_0 = ~clk_2x_0;
  always #3 clk_2x_1 = ~clk_2x_1;
  always #4 mc_clk_0 = ~mc_clk_0;
  always #4 mc_clk_1 = ~mc_clk_1;
  
  
  integer j;
  
  initial 
  begin

    $display("Start Simulation\n");
  
    // Init
    clk_0 = 1;
    clk_1 = 1;
    clk_2x_0 = 1;
    clk_2x_1 = 1;
    mc_clk_0 = 1;
    mc_clk_1 = 1;
    reset_0 = 1;
    reset_1 = 1;
    token_reset_0 = 0;
    token_reset_1 = 0;
    io_reset_0 = '1;
    io_reset_1 = '1;
    core_link_reset_0 = 1;
    core_link_reset_1 = 1;
    core_reset_0 = 1;
    core_reset_1 = 1;
    node_reset_0 = 1;
    node_reset_1 = 1;
    node_en_0 = 0;
    node_en_1 = 0;
    
    #1000;
    
    // token async reset
    token_reset_0 = 1;
    token_reset_1 = 1;
    
    #1000;
    
    token_reset_0 = 0;
    token_reset_1 = 0;
    
    #1000;
    
    // upstream io reset
    @(posedge clk_2x_0); #1;
    reset_0 = 0;
    @(posedge clk_2x_1); #1;
    reset_1 = 0;
    
    #1000;
    
    // downstream IO reset
    // edge clock 0 to downstream 1, edge clock 1 to downstream 0
    for (j = 0; j < num_channels_p; j++)
      begin
        @(posedge edge_clk_1[j]); #1;
        io_reset_0[j] = 0;
        @(posedge edge_clk_0[j]); #1;
        io_reset_1[j] = 0;
      end
    
    #1000;
    
    // core link reset
    @(posedge clk_0); #1;
    core_link_reset_0 = 0;
    @(posedge clk_1); #1;
    core_link_reset_1 = 0;
    
    #1000
    
    // chip reset
    @(posedge clk_0); #1;
    core_reset_0 = 0;
    @(posedge clk_1); #1;
    core_reset_1 = 0;
    
    #1000
    
    // node reset
    @(posedge clk_0); #1;
    node_reset_0 = 0;
    @(posedge clk_1); #1;
    node_reset_1 = 0;
    
    #1000
    
    // node enable
    @(posedge clk_0); #1;
    node_en_0 = 1;
    @(posedge clk_1); #1;
    node_en_1 = 1;
    
    #50000
    
    // node disable
    @(posedge clk_0); #1;
    node_en_0 = 0;
    @(posedge clk_1); #1;
    node_en_1 = 0;
    
    #5000
    
    
    assert(mc_error_0 == 0)
    else 
      begin
        $error("\nFAIL... Error in loopback node 0\n");
        $finish;
      end
    
    assert(mc_error_1 == 0)
    else 
      begin
        $error("\nFAIL... Error in loopback node 1\n");
        $finish;
      end
    
    assert(sent_0 == received_0)
    else 
      begin
        $error("\nFAIL... Loopback node 0 sent %d packets but received only %d\n", sent_0, received_0);
        $finish;
      end
    
    assert(sent_1 == received_1)
    else 
      begin
        $error("\nFAIL... Loopback node 1 sent %d packets but received only %d\n", sent_1, received_1);
        $finish;
      end
    
    $display("\nPASS!\n");
    $display("Loopback node 0 sent and received %d packets\n", sent_0);
    $display("Loopback node 1 sent and received %d packets\n", sent_1);
    $finish;
    
  end

endmodule