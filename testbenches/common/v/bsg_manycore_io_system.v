
//
// Paul Gao 06/2019
//
//

`include "bsg_manycore_packet.vh"

module bsg_manycore_io_system

  import bsg_noc_pkg::Dirs
       , bsg_noc_pkg::P  // proc (local node)
       , bsg_noc_pkg::W  // west
       , bsg_noc_pkg::E  // east
       , bsg_noc_pkg::N  // north
       , bsg_noc_pkg::S; // south
  
  // wormhole routing matrix
  import bsg_wormhole_router_pkg::*;

 #(
 
  /*********************** Manycore params ***********************/
   
  // Manycore configuration parameters, should match real Manycore tiles
   parameter mc_addr_width_p    = "inv"
  ,parameter mc_data_width_p    = "inv"
  ,parameter mc_load_id_width_p = "inv"
  ,parameter mc_x_cord_width_p  = "inv"
  ,parameter mc_y_cord_width_p  = "inv"
  
  ,parameter mc_num_tiles_x_p         = "inv"
  ,parameter mc_block_size_in_words_p = "inv"
  
  ,localparam mc_byte_offset_width_lp = `BSG_SAFE_CLOG2(mc_data_width_p>>3)
  ,localparam mc_cache_addr_width_lp  = mc_addr_width_p-1+mc_byte_offset_width_lp
  
  ,localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(mc_cache_addr_width_lp)
  ,localparam bsg_cache_dma_return_pkt_width_lp = `bsg_cache_dma_return_pkt_width
  ,localparam bsg_manycore_link_sif_width_lp    = `bsg_manycore_link_sif_width(mc_addr_width_p,mc_data_width_p,mc_x_cord_width_p,mc_y_cord_width_p,mc_load_id_width_p)
  
  
  /*********************** Fundamental params ***********************/
  
  
  // In this testbench the number of traffics is 2 (fwd and rev traffic)
  ,parameter num_network_p = 2
  
  // How many streams of traffic are merged in channel tunnel
  // We have fwd and rew networks, plus cache miss traffics
  ,parameter ct_num_in_p = num_network_p + 1
  
  // Tag bits are for channel_tunnel_wormhole to mux and demux packets
  // If we are merging m traffics in channel tunnel, then tag bits shoule 
  // be $clog2(m+1), where the "+1" is for credit returning packet.
  ,parameter tag_width_p = $clog2(ct_num_in_p+1)
  
  // bsg_link data width
  // MUST be multiple of (2*channel_width_p*num_channels_p) 
  ,parameter link_width_p = 34
  
  
  /*********************** Wormhole network params ***********************/
  
  // Wormhole flit width is narrower than link data width
  ,parameter flit_width_p = link_width_p - tag_width_p
  
  // We do 1D routing here
  ,parameter dims_p = 1
  
  // This is the wormhole router coordinate marker
  //
  // Example of 1D routing: marker_p = '{b, a}
  // x_cord = marker_p[b-1:a], cord_width = b-a.
  //
  // Example of 2D routing: marker_p = '{c, b, a}
  // x_cord = marker_p[b-1:a], x_cord_width = b-a.
  // y_cord = marker_p[c-1:b], y_cord_width = c-b.
  //                             cord_width = c-a.
  //
  // Coordinate passed into each module is represented by cord_width'(cord).
  // Child module use dims_p and cord_marker_pos_p to extract hidden information.
  //
  ,parameter int cord_markers_pos_p[dims_p:0] = '{4, 0}
  
  // Routing matrix that chooses which routing directions are enabled
  // Must use StrictX for 1D routing
  // StrictX directions: P->W, P->E, P->P, W->E, W->P, E->W, E->P
  //
  ,parameter dirs_p = dims_p*2+1
  ,parameter bit [1:0][dirs_p-1:0][dirs_p-1:0] routing_matrix_p = StrictX
  
  // How many bits are used to represent wormhole packet length
  // Length is represented by number of payload flits in each packet
  // len_width should be determined by max possiblt packet length
  //
  // In this testbench, max possible number of payload flit is 2 (manycore req)
  // Max possible total flits is (max_payload_flit+1)
  // Then len_width = `BSG_SAFE_CLOG2(max_payload_flit+1)
  //
  ,parameter len_width_p = `BSG_SAFE_CLOG2(3)
  
  // cache miss wormhole packet has separate settings
  ,parameter int cache_dma_cord_markers_pos_p[dims_p:0] = '{4, 0}
  ,parameter cache_dma_len_width_p = `BSG_SAFE_CLOG2(mc_block_size_in_words_p+2)
  
  // This localparam should be defined in each module that handles wormhole
  ,localparam cord_width_lp = cord_markers_pos_p[dims_p]
  ,localparam cache_dma_cord_width_lp = cache_dma_cord_markers_pos_p[dims_p]
  
  /*********************** Channel Tunnel params ***********************/
  
  // Number of available credits. There is a receive buffer (size equal to num of credits) 
  // on receiver side, when data dequeue from buffer, it returns credit to sender. 
  // If sender runs out of credit, it stalls.
  //
  // There is a round-trip delay between sender and receiver for credit returning
  // Must have large enough amount of credit to prevent stalling
  //
  ,parameter ct_remote_credits_p = 64
  
  // How often does channel tunnel return credits
  // If parameter is set to m, then channel tunnel will return credit to sender
  // after receiving 2^m wormhole flits.
  //
  // Generally we don't want to send credit too often (wasteful of IO bandwidth)
  // Receiving a quarter of packets before return credit is reasonable
  //
  ,parameter ct_credit_decimation_p    = ct_remote_credits_p/4
  
  // Smaller decimation means returning credit more frequently
  // Need to get smallest reasonable lg_decimation to prevent stalling
  ,parameter ct_lg_credit_decimation_p = $clog2(ct_credit_decimation_p/2+1)
  
  // Whether to use single 1rw memory as input buffer
  // Pseudo large fifo saves 1.7x hardware, but read / write bandwidth is halved
  // In this application we use pseudo fifo, because channel tunnel is not bottle-neck
  //
  // Proof of correctness:
  // Assume we run IO at frequency f_io, physical IO channel width is w_ch, number
  // of physical IO channels is num_ch, channel tunnel data width is w_ct, channel tunnel
  // run at frequency f_ct. In order to use pseudo large fifo without sacrificing 
  // performance, we should have:
  //
  //    f_ct >= f_io * (w_ch * num_ch / w_ct)
  //
  // For this application, it becomes f_ct >= 0.5*f_io, which is true most of the time.
  //
  ,parameter ct_use_pseudo_large_fifo_p = 1
  
  
  /*********************** DRR link params ***********************/
  
  // Physical IO link configuration
  ,parameter channel_width_p = 8
  
  // How many physical IO link channels do we have for each bsg_link
  ,parameter num_channels_p = 1
  
  // DDR Link buffer size
  // 6 should be good for 500MHz, increase if channel stalls waiting for token
  ,parameter lg_fifo_depth_p = 6
  
  // This is for token credit return on IO channel
  // Do not change
  ,parameter lg_credit_to_token_decimation_p = 3
  
  ,parameter use_extra_data_bit_p = 1
  
  )
  
  (// On ASIC
  // Clock and reset
   input asic_mc_clk_i
  ,input asic_mc_reset_i
  // Manycore link
  ,input  [bsg_manycore_link_sif_width_lp-1:0] asic_mc_link_i
  ,output [bsg_manycore_link_sif_width_lp-1:0] asic_mc_link_o
  // Cache DMA links
  ,input        [mc_num_tiles_x_p-1:0][bsg_cache_dma_pkt_width_lp-1:0] asic_dma_pkt_i
  ,input        [mc_num_tiles_x_p-1:0]                                 asic_dma_pkt_v_i
  ,output logic [mc_num_tiles_x_p-1:0]                                 asic_dma_pkt_yumi_o
  
  ,input        [mc_num_tiles_x_p-1:0][mc_data_width_p-1:0]            asic_dma_data_i
  ,input        [mc_num_tiles_x_p-1:0]                                 asic_dma_data_v_i
  ,output logic [mc_num_tiles_x_p-1:0]                                 asic_dma_data_yumi_o
  
  ,output logic [mc_num_tiles_x_p-1:0][bsg_cache_dma_return_pkt_width_lp-1:0] 
                                                                asic_dma_return_pkt_o
  ,output logic [mc_num_tiles_x_p-1:0]                          asic_dma_return_pkt_v_o
  ,input        [mc_num_tiles_x_p-1:0]                          asic_dma_return_pkt_ready_i

  ,output logic [mc_num_tiles_x_p-1:0][mc_data_width_p-1:0]            asic_dma_data_o
  ,output logic [mc_num_tiles_x_p-1:0]                                 asic_dma_data_v_o
  ,input        [mc_num_tiles_x_p-1:0]                                 asic_dma_data_ready_i


  
  // On FPGA
  // Clock and reset
  ,input fpga_mc_clk_i
  ,input fpga_mc_reset_i
  // Manycore link
  ,input  [bsg_manycore_link_sif_width_lp-1:0] fpga_mc_link_i
  ,output [bsg_manycore_link_sif_width_lp-1:0] fpga_mc_link_o
  // Cache DMA links         
  ,output logic [mc_num_tiles_x_p-1:0][bsg_cache_dma_pkt_width_lp-1:0] fpga_dma_pkt_o
  ,output logic [mc_num_tiles_x_p-1:0]                                 fpga_dma_pkt_v_o
  ,input        [mc_num_tiles_x_p-1:0]                                 fpga_dma_pkt_yumi_i

  ,output logic [mc_num_tiles_x_p-1:0][mc_data_width_p-1:0]            fpga_dma_data_o
  ,output logic [mc_num_tiles_x_p-1:0]                                 fpga_dma_data_v_o
  ,input        [mc_num_tiles_x_p-1:0]                                 fpga_dma_data_yumi_i

  ,input        [mc_num_tiles_x_p-1:0][mc_data_width_p-1:0]            fpga_dma_data_i
  ,input        [mc_num_tiles_x_p-1:0]                                 fpga_dma_data_v_i
  ,output logic [mc_num_tiles_x_p-1:0]                                 fpga_dma_data_ready_o
  );
  
  // Loopback test specific parameters
  localparam out_node_cord = 3;
  localparam in_node_cord  = 2;
  
  `declare_bsg_ready_and_link_sif_s(flit_width_p,bsg_ready_and_link_sif_s);

  // Router clock and reset
  logic router_clk_0, router_clk_1;
  logic router_reset_0, router_reset_1;
  
  // Link upstream and downstream core reset
  logic core_upstream_downstream_reset_0, core_upstream_downstream_reset_1;
  
  // Link upstream io clock and reset
  logic io_upstream_clk_0, io_upstream_clk_1;
  logic io_upstream_reset_0, io_upstream_reset_1;
  
  // Link upstream token async reset
  logic token_reset_0, token_reset_1;
  
  // Link downstream io reset
  logic [num_channels_p-1:0] io_downstream_reset_0, io_downstream_reset_1;

  bsg_ready_and_link_sif_s [mc_num_tiles_x_p-1:0][dirs_p-1:0] out_cache_dma_router_link_li;
  bsg_ready_and_link_sif_s [mc_num_tiles_x_p-1:0][dirs_p-1:0] out_cache_dma_router_link_lo;
  
  bsg_ready_and_link_sif_s [num_network_p-1:0] out_node_link_li;
  bsg_ready_and_link_sif_s [num_network_p-1:0] out_node_link_lo;
  
  bsg_ready_and_link_sif_s [num_network_p-1:0][dirs_p-1:0] out_router_link_li;
  bsg_ready_and_link_sif_s [num_network_p-1:0][dirs_p-1:0] out_router_link_lo;
  
  logic [ct_num_in_p-1:0] out_ct_fifo_valid_lo, out_ct_fifo_yumi_li;
  logic [ct_num_in_p-1:0] out_ct_fifo_valid_li, out_ct_fifo_yumi_lo;
  logic [ct_num_in_p-1:0][flit_width_p-1:0] out_ct_fifo_data_lo, out_ct_fifo_data_li;
  
  logic out_ct_valid_lo, out_ct_ready_li; 
  logic out_ct_valid_li, out_ct_yumi_lo;
  logic [link_width_p-1:0] out_ct_data_lo, out_ct_data_li;
  
  logic [num_channels_p-1:0] edge_clk_0, edge_valid_0, edge_token_0;
  logic [num_channels_p-1:0][channel_width_p-1:0] edge_data_0;
  
  logic [num_channels_p-1:0] edge_clk_1, edge_valid_1, edge_token_1;
  logic [num_channels_p-1:0][channel_width_p-1:0] edge_data_1;
  
  logic in_ct_valid_lo, in_ct_ready_li;
  logic in_ct_valid_li, in_ct_yumi_lo;
  logic [link_width_p-1:0] in_ct_data_li, in_ct_data_lo;
  
  logic [ct_num_in_p-1:0] in_ct_fifo_valid_lo, in_ct_fifo_yumi_li;
  logic [ct_num_in_p-1:0] in_ct_fifo_valid_li, in_ct_fifo_yumi_lo;
  logic [ct_num_in_p-1:0][flit_width_p-1:0] in_ct_fifo_data_lo, in_ct_fifo_data_li;
  
  bsg_ready_and_link_sif_s [num_network_p-1:0][dirs_p-1:0] in_router_link_li;
  bsg_ready_and_link_sif_s [num_network_p-1:0][dirs_p-1:0] in_router_link_lo;  
  
  bsg_ready_and_link_sif_s [num_network_p-1:0] in_node_link_li;
  bsg_ready_and_link_sif_s [num_network_p-1:0] in_node_link_lo;

  bsg_ready_and_link_sif_s [dirs_p-1:0] in_cache_dma_router_link_li;
  bsg_ready_and_link_sif_s [dirs_p-1:0] in_cache_dma_router_link_lo;

  
  genvar i;
  
  for (i = 0; i < mc_num_tiles_x_p; i++)
    begin: adapters
      localparam my_id_lp = {1'b1, `BSG_SAFE_CLOG2(mc_num_tiles_x_p)'(i)};
    
      bsg_cache_dma_async_to_wormhole
     #(.cache_addr_width_p   (mc_cache_addr_width_lp)
      ,.data_width_p         (mc_data_width_p)
      ,.block_size_in_words_p(mc_block_size_in_words_p)
      ,.flit_width_p         (flit_width_p)
      ,.dims_p               (dims_p)
      ,.cord_markers_pos_p   (cache_dma_cord_markers_pos_p)
      ,.len_width_p          (cache_dma_len_width_p)
      ) dma_to_wh
      (.dma_clk_i(asic_mc_clk_i)
      ,.dma_reset_i(asic_mc_reset_i)
                 
      ,.dma_pkt_i(asic_dma_pkt_i[i])
      ,.dma_pkt_v_i(asic_dma_pkt_v_i[i])
      ,.dma_pkt_yumi_o(asic_dma_pkt_yumi_o[i])

      ,.dma_data_i(asic_dma_data_i[i])
      ,.dma_data_v_i(asic_dma_data_v_i[i])
      ,.dma_data_yumi_o(asic_dma_data_yumi_o[i])

      ,.dma_return_pkt_o(asic_dma_return_pkt_o[i])
      ,.dma_return_pkt_v_o(asic_dma_return_pkt_v_o[i])
      ,.dma_return_pkt_ready_i(asic_dma_return_pkt_ready_i[i])

      ,.dma_data_o(asic_dma_data_o[i])
      ,.dma_data_v_o(asic_dma_data_v_o[i])
      ,.dma_data_ready_i(asic_dma_data_ready_i[i])
      
      ,.dma_my_cord_i(cache_dma_cord_width_lp'(my_id_lp))
      ,.dma_dest_cord_i(cache_dma_cord_width_lp'(0))
      
      ,.wh_clk_i(router_clk_0)
      ,.wh_reset_i(router_reset_0)

      ,.wh_link_i(out_cache_dma_router_link_lo[i][P])
      ,.wh_link_o(out_cache_dma_router_link_li[i][P])
      );
      
      bsg_wormhole_router_generalized
     #(.flit_width_p      (flit_width_p)
      ,.dims_p            (dims_p)
      ,.cord_markers_pos_p(cache_dma_cord_markers_pos_p)
      ,.routing_matrix_p  (routing_matrix_p)
      ,.len_width_p       (cache_dma_len_width_p)
      )
      router
      (.clk_i    (router_clk_0)
      ,.reset_i  (router_reset_0)
      ,.my_cord_i(cache_dma_cord_width_lp'(my_id_lp))
      ,.link_i   (out_cache_dma_router_link_li[i])
      ,.link_o   (out_cache_dma_router_link_lo[i])
      );
      
      // Link to next router
      if (i != mc_num_tiles_x_p-1)
        begin
          assign out_cache_dma_router_link_li [i]  [E] = out_cache_dma_router_link_lo [i+1][W];
          assign out_cache_dma_router_link_li [i+1][W] = out_cache_dma_router_link_lo [i]  [E];
        end
    end
    
  // Stub east side of router chain
  assign out_cache_dma_router_link_li[mc_num_tiles_x_p-1][E].v             = 1'b0;
  assign out_cache_dma_router_link_li[mc_num_tiles_x_p-1][E].ready_and_rev = 1'b1;
  
  // Connect to channel tunnel
  bsg_two_fifo
 #(.width_p(flit_width_p))
  out_cache_dma_fifo
  (.clk_i  (router_clk_0  )
  ,.reset_i(router_reset_0)
  ,.ready_o(out_cache_dma_router_link_li[0][W].ready_and_rev)
  ,.data_i (out_cache_dma_router_link_lo[0][W].data         )
  ,.v_i    (out_cache_dma_router_link_lo[0][W].v            )
  ,.v_o    (out_ct_fifo_valid_lo[num_network_p])
  ,.data_o (out_ct_fifo_data_lo [num_network_p])
  ,.yumi_i (out_ct_fifo_yumi_li [num_network_p])
  );
  
  assign out_cache_dma_router_link_li[0][W].v = out_ct_fifo_valid_li  [num_network_p];
  assign out_cache_dma_router_link_li[0][W].data = out_ct_fifo_data_li[num_network_p];
  assign out_ct_fifo_yumi_lo[num_network_p] = out_cache_dma_router_link_li[0][W].v
                                            & out_cache_dma_router_link_lo[0][W].ready_and_rev;


  bsg_manycore_link_async_to_wormhole
 #(.addr_width_p      (mc_addr_width_p)
  ,.data_width_p      (mc_data_width_p)
  ,.load_id_width_p   (mc_load_id_width_p)
  ,.x_cord_width_p    (mc_x_cord_width_p)
  ,.y_cord_width_p    (mc_y_cord_width_p)
  ,.flit_width_p      (flit_width_p)
  ,.dims_p            (dims_p)
  ,.cord_markers_pos_p(cord_markers_pos_p)
  ,.len_width_p       (len_width_p)
  ) out_adapter
  (.mc_clk_i  (asic_mc_clk_i)
  ,.mc_reset_i(asic_mc_reset_i)
   
  ,.mc_links_sif_i     (asic_mc_link_i)
  ,.mc_links_sif_o     (asic_mc_link_o)
   
  ,.wh_clk_i           (router_clk_0)
  ,.wh_reset_i         (router_reset_0)

  ,.mc_dest_cord_i     (cord_width_lp'(in_node_cord))
  
  ,.wh_link_i          (out_node_link_li)
  ,.wh_link_o          (out_node_link_lo)
  );
  
  
  for (i = 0; i < num_network_p; i++) 
  begin: r0
  
    bsg_wormhole_router_generalized
   #(.flit_width_p      (flit_width_p)
    ,.dims_p            (dims_p)
    ,.cord_markers_pos_p(cord_markers_pos_p)
    ,.routing_matrix_p  (routing_matrix_p)
    ,.len_width_p       (len_width_p)
    )
    router_0
    (.clk_i    (router_clk_0)
	,.reset_i  (router_reset_0)
	,.my_cord_i(cord_width_lp'(out_node_cord))
	,.link_i   (out_router_link_li[i])
	,.link_o   (out_router_link_lo[i])
	);

    assign out_node_link_li[i] = out_router_link_lo[i][P];
    assign out_router_link_li[i][P] = out_node_link_lo[i];
    
    // Stub
    assign out_router_link_li[i][E].v             = 1'b0;
    assign out_router_link_li[i][E].ready_and_rev = 1'b1;
    
    // Must add a fifo here, convert yumi_o to ready_o
    bsg_two_fifo
   #(.width_p(flit_width_p))
    out_ct_fifo
    (.clk_i  (router_clk_0  )
    ,.reset_i(router_reset_0)
    ,.ready_o(out_router_link_li[i][W].ready_and_rev)
    ,.data_i (out_router_link_lo[i][W].data         )
    ,.v_i    (out_router_link_lo[i][W].v            )
    ,.v_o    (out_ct_fifo_valid_lo[i])
    ,.data_o (out_ct_fifo_data_lo[i] )
    ,.yumi_i (out_ct_fifo_yumi_li[i] )
    );
    
    assign out_router_link_li [i][W].v    = out_ct_fifo_valid_li[i];
    assign out_router_link_li [i][W].data = out_ct_fifo_data_li [i];
    assign out_ct_fifo_yumi_lo[i]         = out_router_link_li  [i][W].v 
                                          & out_router_link_lo  [i][W].ready_and_rev;
  end

  bsg_channel_tunnel 
 #(.width_p                (flit_width_p)
  ,.num_in_p               (ct_num_in_p)
  ,.remote_credits_p       (ct_remote_credits_p)
  ,.use_pseudo_large_fifo_p(ct_use_pseudo_large_fifo_p)
  ,.lg_credit_decimation_p (ct_lg_credit_decimation_p)
  )
  out_ct
  (.clk_i  (router_clk_0)
  ,.reset_i(router_reset_0)

  // incoming multiplexed data
  ,.multi_data_i(out_ct_data_li)
  ,.multi_v_i   (out_ct_valid_li)
  ,.multi_yumi_o(out_ct_yumi_lo)

  // outgoing multiplexed data
  ,.multi_data_o(out_ct_data_lo)
  ,.multi_v_o   (out_ct_valid_lo)
  ,.multi_yumi_i(out_ct_ready_li & out_ct_valid_lo)

  // incoming demultiplexed data
  ,.data_i(out_ct_fifo_data_lo)
  ,.v_i   (out_ct_fifo_valid_lo)
  ,.yumi_o(out_ct_fifo_yumi_li)

  // outgoing demultiplexed data
  ,.data_o(out_ct_fifo_data_li)
  ,.v_o   (out_ct_fifo_valid_li)
  ,.yumi_i(out_ct_fifo_yumi_lo)
  );
  
  bsg_link_ddr_upstream
 #(.width_p        (link_width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p (num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.use_extra_data_bit_p(use_extra_data_bit_p)
  ) link_upstream_0
  (.core_clk_i         (router_clk_0)
  ,.io_clk_i           (io_upstream_clk_0)
  ,.core_link_reset_i  (core_upstream_downstream_reset_0)
  ,.io_link_reset_i    (io_upstream_reset_0)
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
 #(.width_p        (link_width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p (num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.use_extra_data_bit_p(use_extra_data_bit_p)
  ) link_downstream_0
  (.core_clk_i       (router_clk_0)
  ,.core_link_reset_i(core_upstream_downstream_reset_0)
  ,.io_link_reset_i  (io_downstream_reset_0)
  
  ,.core_data_o   (out_ct_data_li)
  ,.core_valid_o  (out_ct_valid_li)
  ,.core_yumi_i   (out_ct_yumi_lo)

  ,.io_clk_i      (edge_clk_1)
  ,.io_data_i     (edge_data_1)
  ,.io_valid_i    (edge_valid_1)
  ,.core_token_r_o(edge_token_1)
  );
  
  
  bsg_link_ddr_upstream
 #(.width_p        (link_width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p (num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.use_extra_data_bit_p(use_extra_data_bit_p)
  ) link_upstream_1
  (.core_clk_i         (router_clk_1)
  ,.io_clk_i           (io_upstream_clk_1)
  ,.core_link_reset_i  (core_upstream_downstream_reset_1)
  ,.io_link_reset_i    (io_upstream_reset_1)
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
 #(.width_p        (link_width_p)
  ,.channel_width_p(channel_width_p)
  ,.num_channels_p (num_channels_p)
  ,.lg_fifo_depth_p(lg_fifo_depth_p)
  ,.lg_credit_to_token_decimation_p(lg_credit_to_token_decimation_p)
  ,.use_extra_data_bit_p(use_extra_data_bit_p)
  ) link_downstream_1
  (.core_clk_i       (router_clk_1)
  ,.core_link_reset_i(core_upstream_downstream_reset_1)
  ,.io_link_reset_i  (io_downstream_reset_1)
  
  ,.core_data_o   (in_ct_data_li)
  ,.core_valid_o  (in_ct_valid_li)
  ,.core_yumi_i   (in_ct_yumi_lo)
  
  ,.io_clk_i      (edge_clk_0)
  ,.io_data_i     (edge_data_0)
  ,.io_valid_i    (edge_valid_0)
  ,.core_token_r_o(edge_token_0)
  );

  bsg_channel_tunnel 
 #(.width_p                (flit_width_p)
  ,.num_in_p               (ct_num_in_p)
  ,.remote_credits_p       (ct_remote_credits_p)
  ,.use_pseudo_large_fifo_p(ct_use_pseudo_large_fifo_p)
  ,.lg_credit_decimation_p (ct_lg_credit_decimation_p)
  )
  in_ct
  (.clk_i  (router_clk_1)
  ,.reset_i(router_reset_1)

  // incoming multiplexed data
  ,.multi_data_i(in_ct_data_li)
  ,.multi_v_i   (in_ct_valid_li)
  ,.multi_yumi_o(in_ct_yumi_lo)

  // outgoing multiplexed data
  ,.multi_data_o(in_ct_data_lo)
  ,.multi_v_o   (in_ct_valid_lo)
  ,.multi_yumi_i(in_ct_ready_li & in_ct_valid_lo)

  // incoming demultiplexed data
  ,.data_i(in_ct_fifo_data_lo)
  ,.v_i   (in_ct_fifo_valid_lo)
  ,.yumi_o(in_ct_fifo_yumi_li)

  // outgoing demultiplexed data
  ,.data_o(in_ct_fifo_data_li)
  ,.v_o   (in_ct_fifo_valid_li)
  ,.yumi_i(in_ct_fifo_yumi_lo)
  );
  
  for (i = 0; i < num_network_p; i++) 
  begin: r1
  
    bsg_wormhole_router_generalized
   #(.flit_width_p      (flit_width_p)
    ,.dims_p            (dims_p)
    ,.cord_markers_pos_p(cord_markers_pos_p)
    ,.routing_matrix_p  (routing_matrix_p)
    ,.len_width_p       (len_width_p)
    ) 
    router_1
    (.clk_i    (router_clk_1)
	,.reset_i  (router_reset_1)
	,.my_cord_i(cord_width_lp'(in_node_cord))
	,.link_i   (in_router_link_li[i])
	,.link_o   (in_router_link_lo[i])
	);
    
    assign in_node_link_li[i] = in_router_link_lo[i][P];
    assign in_router_link_li[i][P] = in_node_link_lo[i];
    
    // Stub
    assign in_router_link_li[i][W].v             = 1'b0;
    assign in_router_link_li[i][W].ready_and_rev = 1'b1;
    
    // Must add a fifo here, convert yumi_o to ready_o
    bsg_two_fifo
   #(.width_p(flit_width_p))
    in_ct_fifo
    (.clk_i  (router_clk_1  )
    ,.reset_i(router_reset_1)
    ,.ready_o(in_router_link_li[i][E].ready_and_rev)
    ,.data_i (in_router_link_lo[i][E].data         )
    ,.v_i    (in_router_link_lo[i][E].v            )
    ,.v_o    (in_ct_fifo_valid_lo[i])
    ,.data_o (in_ct_fifo_data_lo[i] )
    ,.yumi_i (in_ct_fifo_yumi_li[i] )
    );
    
    assign in_router_link_li [i][E].v    = in_ct_fifo_valid_li[i];
    assign in_router_link_li [i][E].data = in_ct_fifo_data_li [i];
    assign in_ct_fifo_yumi_lo[i]         = in_router_link_li  [i][E].v 
                                         & in_router_link_lo  [i][E].ready_and_rev;
  end


  bsg_manycore_link_async_to_wormhole
 #(.addr_width_p      (mc_addr_width_p)
  ,.data_width_p      (mc_data_width_p)
  ,.load_id_width_p   (mc_load_id_width_p)
  ,.x_cord_width_p    (mc_x_cord_width_p)
  ,.y_cord_width_p    (mc_y_cord_width_p)
  ,.flit_width_p      (flit_width_p)
  ,.dims_p            (dims_p)
  ,.cord_markers_pos_p(cord_markers_pos_p)
  ,.len_width_p       (len_width_p)
  ) in_adapter
  (.mc_clk_i  (fpga_mc_clk_i)
  ,.mc_reset_i(fpga_mc_reset_i)
   
  ,.mc_links_sif_i     (fpga_mc_link_i)
  ,.mc_links_sif_o     (fpga_mc_link_o)
   
  ,.wh_clk_i           (router_clk_1)
  ,.wh_reset_i         (router_reset_1)
  
  ,.mc_dest_cord_i     (cord_width_lp'(out_node_cord))
  
  ,.wh_link_i          (in_node_link_li)
  ,.wh_link_o          (in_node_link_lo)
  );
  
  
  // Connect to channel tunnel
  bsg_two_fifo
 #(.width_p(flit_width_p))
  in_cache_dma_fifo
  (.clk_i  (router_clk_1  )
  ,.reset_i(router_reset_1)
  ,.ready_o(in_cache_dma_router_link_li[E].ready_and_rev)
  ,.data_i (in_cache_dma_router_link_lo[E].data         )
  ,.v_i    (in_cache_dma_router_link_lo[E].v            )
  ,.v_o    (in_ct_fifo_valid_lo[num_network_p])
  ,.data_o (in_ct_fifo_data_lo [num_network_p])
  ,.yumi_i (in_ct_fifo_yumi_li [num_network_p])
  );
  
  assign in_cache_dma_router_link_li[E].v = in_ct_fifo_valid_li  [num_network_p];
  assign in_cache_dma_router_link_li[E].data = in_ct_fifo_data_li[num_network_p];
  assign in_ct_fifo_yumi_lo[num_network_p] = in_cache_dma_router_link_li[E].v
                                           & in_cache_dma_router_link_lo[E].ready_and_rev;
  

  bsg_wormhole_router_generalized
 #(.flit_width_p      (flit_width_p)
  ,.dims_p            (dims_p)
  ,.cord_markers_pos_p(cache_dma_cord_markers_pos_p)
  ,.routing_matrix_p  (routing_matrix_p)
  ,.len_width_p       (cache_dma_len_width_p)
  )
  in_dma_router
  (.clk_i    (router_clk_1)
  ,.reset_i  (router_reset_1)
  ,.my_cord_i(cache_dma_cord_width_lp'(0))
  ,.link_i   (in_cache_dma_router_link_li)
  ,.link_o   (in_cache_dma_router_link_lo)
  );
  
  // Stub west side of router chain
  assign in_cache_dma_router_link_li[W].v             = 1'b0;
  assign in_cache_dma_router_link_li[W].ready_and_rev = 1'b1;
        
  bsg_wormhole_async_to_cache_dma
 #(.cache_addr_width_p   (mc_cache_addr_width_lp)
  ,.data_width_p         (mc_data_width_p)
  ,.block_size_in_words_p(mc_block_size_in_words_p)
  ,.num_cache_p          (mc_num_tiles_x_p)
  ,.flit_width_p         (flit_width_p)
  ,.dims_p               (dims_p)
  ,.cord_markers_pos_p   (cache_dma_cord_markers_pos_p)
  ,.len_width_p          (cache_dma_len_width_p)
  ) wh_to_dma
  (.dma_clk_i       (fpga_mc_clk_i)
  ,.dma_reset_i     (fpga_mc_reset_i)

  ,.dma_pkt_o       (fpga_dma_pkt_o)
  ,.dma_pkt_v_o     (fpga_dma_pkt_v_o)
  ,.dma_pkt_yumi_i  (fpga_dma_pkt_yumi_i)

  ,.dma_data_i      (fpga_dma_data_i)
  ,.dma_data_v_i    (fpga_dma_data_v_i)
  ,.dma_data_ready_o(fpga_dma_data_ready_o)

  ,.dma_data_o      (fpga_dma_data_o)
  ,.dma_data_v_o    (fpga_dma_data_v_o)
  ,.dma_data_yumi_i (fpga_dma_data_yumi_i)
  
  ,.dma_my_cord_i   (cache_dma_cord_width_lp'(0))

  ,.wh_clk_i        (router_clk_1)
  ,.wh_reset_i      (router_reset_1)

  ,.wh_link_i       (in_cache_dma_router_link_lo[P])
  ,.wh_link_o       (in_cache_dma_router_link_li[P])
  );



  // Simulation of Clock
  always #8 router_clk_0 = ~router_clk_0;
  always #8 router_clk_1 = ~router_clk_1;

  always #4 io_upstream_clk_0 = ~io_upstream_clk_0;
  always #6 io_upstream_clk_1 = ~io_upstream_clk_1;
  
  integer j;
  
  initial
  begin

    $display("Start Simulation\n");
  
    // Init
    router_clk_0 = 1;
    router_clk_1 = 1;
    router_reset_0 = 1;
    router_reset_1 = 1;
   
    io_upstream_clk_0     = 1;
    io_upstream_clk_1     = 1;
    io_upstream_reset_0 = 1;
    io_upstream_reset_1 = 1;
    token_reset_0 = 0;
    token_reset_1 = 0;
    core_upstream_downstream_reset_0 = 1;
    core_upstream_downstream_reset_1 = 1;

    
    #200;
    
    // token async reset
    token_reset_0 = 1;
    token_reset_1 = 1;
    
    #200;
    
    token_reset_0 = 0;
    token_reset_1 = 0;
    
    #200;
    
    // upstream io reset
    @(posedge io_upstream_clk_0); #1;
    io_upstream_reset_0 = 0;
    @(posedge io_upstream_clk_1); #1;
    io_upstream_reset_1 = 0;
    
    #200;
    
    // Reset signals propagate to downstream after io_clk is generated
    for (j = 0; j < num_channels_p; j++)
      begin
        @(posedge edge_clk_1[j]); #1;
        io_downstream_reset_0[j] = 1;
        @(posedge edge_clk_0[j]); #1;
        io_downstream_reset_1[j] = 1;
      end
      
    #200;
    
    // downstream IO reset
    // edge clock 0 to downstream 1, edge clock 1 to downstream 0
    for (j = 0; j < num_channels_p; j++)
      begin
        @(posedge edge_clk_1[j]); #1;
        io_downstream_reset_0[j] = 0;
        @(posedge edge_clk_0[j]); #1;
        io_downstream_reset_1[j] = 0;
      end
    
    #200;
    
    // core link reset
    @(posedge router_clk_0); #1;
    core_upstream_downstream_reset_0 = 0;
    @(posedge router_clk_1); #1;
    core_upstream_downstream_reset_1 = 0;
    
    #200
   
    // router reset
    @(posedge router_clk_0); #1;
    router_reset_0 = 0;
    @(posedge router_clk_1); #1;
    router_reset_1 = 0;
    
    #200
    
    $display("\nIO System Init Done!\n");
    
  end

endmodule