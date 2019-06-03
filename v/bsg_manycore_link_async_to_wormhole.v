
//
// Paul Gao 06/2019
//
// This is an adapter from wormhole network to bsg manycore link
// It assumes that wormhole network and manycore are in different clock regions, an
// asynchronous fifo is instantiated in this adapter to cross the clock domains.
//
//

`include "bsg_manycore_packet.vh"

module bsg_manycore_link_async_to_wormhole

 #(parameter addr_width_p="inv"
  ,parameter data_width_p="inv"
  ,parameter load_id_width_p = "inv"
  ,parameter x_cord_width_p="inv"
  ,parameter y_cord_width_p="inv"
  ,parameter wormhole_req_ratio_p = "inv"
  ,parameter wormhole_resp_ratio_p = "inv"
  ,parameter wormhole_width_p = "inv"
  ,parameter wormhole_x_cord_width_p = "inv"
  ,parameter wormhole_y_cord_width_p = "inv"
  ,parameter wormhole_len_width_p = "inv"
  ,parameter wormhole_reserved_width_p = "inv"
  ,localparam lg_fifo_depth_lp = 3
  ,localparam num_nets_lp = 2
  ,localparam bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(wormhole_width_p))
    
  (//
   // Manycore side
   //
   input manycore_clk_i
   
   // Optional reset/enable outputs
  ,output manycore_reset_o
  ,output manycore_en_o
  
  // Manycore links
  ,input [bsg_manycore_link_sif_width_lp-1:0] links_sif_i
  ,output [bsg_manycore_link_sif_width_lp-1:0] links_sif_o
  
  //
  // Wormhole side
  //
  ,input clk_i
  ,input reset_i
  
  // If the reset / enable signals for manycore is in wormhole clock domain, this adapter 
  // can forward them to manycore clock domain with integrated synchronizers.
  ,input manycore_reset_i
  ,input manycore_en_i
  
  // The wormhole destination IDs should either be connected to a register (whose value is
  // initialized before reset is deasserted), or set to a constant value.
  ,input [wormhole_x_cord_width_p-1:0] dest_x_i
  ,input [wormhole_y_cord_width_p-1:0] dest_y_i

  // Wormhole links
  ,input [num_nets_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [num_nets_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] link_o);
  
  
  genvar i;
  
  
  // Reset signals
  
  bsg_launch_sync_sync 
 #(.width_p(1))
  mc_reset_blss
  (.iclk_i(clk_i)
  ,.iclk_reset_i(1'b0)
  ,.oclk_i(manycore_clk_i)
  ,.iclk_data_i(manycore_reset_i)
  ,.iclk_data_o()
  ,.oclk_data_o(manycore_reset_o));
  
  bsg_launch_sync_sync 
 #(.width_p(1))
  mc_en_blss
  (.iclk_i(clk_i)
  ,.iclk_reset_i(1'b0)
  ,.oclk_i(manycore_clk_i)
  ,.iclk_data_i(manycore_en_i)
  ,.iclk_data_o()
  ,.oclk_data_o(manycore_en_o));
  
  
  // Interfacing bsg_noc links 

  logic [num_nets_lp-1:0] valid_o, ready_i;
  logic [num_nets_lp-1:0][wormhole_width_p-1:0] data_o;
  
  logic [num_nets_lp-1:0] valid_i, ready_o;
  logic [num_nets_lp-1:0][wormhole_width_p-1:0] data_i;
  
  `declare_bsg_ready_and_link_sif_s(wormhole_width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s [num_nets_lp-1:0] link_i_cast, link_o_cast;
  
  for (i = 0; i < num_nets_lp; i++) 
  begin
  
    assign link_i_cast[i] = link_i[i];
    assign link_o[i] = link_o_cast[i];

    assign valid_i[i] = link_i_cast[i].v;
    assign data_i[i] = link_i_cast[i].data;
    assign link_o_cast[i].ready_and_rev = ready_o[i];

    assign link_o_cast[i].v = valid_o[i];
    assign link_o_cast[i].data = data_o[i];
    assign ready_i[i] = link_i_cast[i].ready_and_rev;
  
  end
  

  // Manycore side async fifo input
  logic [num_nets_lp-1:0][wormhole_width_p-1:0] mc_data_li;
  logic [num_nets_lp-1:0] mc_enq_li, mc_valid_li;
  logic [num_nets_lp-1:0] mc_full_lo, mc_ready_lo;
  
  assign mc_ready_lo = ~mc_full_lo;
  assign mc_enq_li = mc_valid_li & mc_ready_lo;

  // Manycore side async fifo output
  logic [num_nets_lp-1:0][wormhole_width_p-1:0] mc_data_lo;
  logic [num_nets_lp-1:0] mc_valid_lo;
  logic [num_nets_lp-1:0] mc_deq_li, mc_ready_li;
  
  assign mc_deq_li = mc_ready_li & mc_valid_lo;
  
  // Wormhole side async fifo input
  logic [num_nets_lp-1:0] wh_full_lo;
  logic [num_nets_lp-1:0] wh_enq_li;
  
  assign ready_o = ~wh_full_lo;
  assign wh_enq_li = valid_i & ready_o;
  
  
  for (i = 0; i < num_nets_lp; i++) 
  begin: afifo
  
    bsg_async_fifo
   #(.lg_size_p(lg_fifo_depth_lp)
    ,.width_p(wormhole_width_p))
    wh_2_mc_fifo
    (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_enq_i(wh_enq_li[i])
    ,.w_data_i(data_i[i])
    ,.w_full_o(wh_full_lo[i])

    ,.r_clk_i(manycore_clk_i)
    ,.r_reset_i(manycore_reset_o)
    ,.r_deq_i(mc_deq_li[i])
    ,.r_data_o(mc_data_lo[i])
    ,.r_valid_o(mc_valid_lo[i]));
    
    bsg_async_fifo
   #(.lg_size_p(lg_fifo_depth_lp)
    ,.width_p(wormhole_width_p))
    mc_2_wh_fifo
    (.w_clk_i(manycore_clk_i)
    ,.w_reset_i(manycore_reset_o)
    ,.w_enq_i(mc_enq_li[i])
    ,.w_data_i(mc_data_li[i])
    ,.w_full_o(mc_full_lo[i])

    ,.r_clk_i(clk_i)
    ,.r_reset_i(reset_i)
    ,.r_deq_i(valid_o[i] & ready_i[i])
    ,.r_data_o(data_o[i])
    ,.r_valid_o(valid_o[i]));
  
  end


  // Define link packets
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  // Define req and resp packets
  `declare_bsg_manycore_packet_s  (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);

  localparam mc_req_width_lp = $bits(bsg_manycore_packet_s);
  localparam mc_resp_width_lp = $bits(bsg_manycore_return_packet_s);
  
  localparam wh_req_width_lp = wormhole_width_p*wormhole_req_ratio_p;
  localparam wh_resp_width_lp = wormhole_width_p*wormhole_resp_ratio_p;
  localparam wh_width_lp = `BSG_MAX(wh_req_width_lp, wh_resp_width_lp);
  
  localparam mc_wh_req_width_lp = `bsg_wormhole_packet_width(wormhole_reserved_width_p, wormhole_x_cord_width_p, wormhole_y_cord_width_p, wormhole_len_width_p, mc_req_width_lp);
  localparam mc_wh_resp_width_lp = `bsg_wormhole_packet_width(wormhole_reserved_width_p, wormhole_x_cord_width_p, wormhole_y_cord_width_p, wormhole_len_width_p, mc_resp_width_lp);
  
  
   // synopsys translate_off
   initial begin
     assert (mc_wh_req_width_lp <= wh_req_width_lp)
     else $error("Wormhole request packet width %d is smaller than manycore request packet width plus wormhole header width %d", wh_req_width_lp, mc_wh_req_width_lp);
     
     assert (mc_wh_resp_width_lp <= wh_resp_width_lp)
     else $error("Wormhole request packet width %d is smaller than manycore request packet width plus wormhole header width %d", wh_resp_width_lp, mc_wh_resp_width_lp);
   end
   // synopsys translate_on
  
  
  // input to piso
  logic [num_nets_lp-1:0][wh_width_lp-1:0] mc_ps_data_li;
  logic [num_nets_lp-1:0] mc_ps_valid_li;
  logic [num_nets_lp-1:0] mc_ps_ready_lo;

  // output from sipof
  logic [num_nets_lp-1:0][wh_width_lp-1:0] mc_ps_data_lo;
  logic [num_nets_lp-1:0] mc_ps_valid_lo;
  logic [num_nets_lp-1:0] mc_ps_yumi_li;
  
  
  for (i = 0; i < num_nets_lp; i++) 
  begin: ps
    
    localparam ps_width_lp = (i==0)? wh_req_width_lp : wh_resp_width_lp;
    localparam ps_els_lp = ps_width_lp / wormhole_width_p;
  
    bsg_parallel_in_serial_out 
   #(.width_p(wormhole_width_p)
    ,.els_p(ps_els_lp)
    ,.msb_first_p(1))
    piso
    (.clk_i(manycore_clk_i)
    ,.reset_i(manycore_reset_o)
    ,.valid_i(mc_ps_valid_li[i])
    ,.data_i(mc_ps_data_li[i][ps_width_lp-1:0])
    ,.ready_o(mc_ps_ready_lo[i])
    ,.valid_o(mc_valid_li[i])
    ,.data_o(mc_data_li[i])
    ,.yumi_i(mc_ready_lo[i]&mc_valid_li[i]));
    
    bsg_serial_in_parallel_out_full_buffered
   #(.width_p(wormhole_width_p)
    ,.els_p(ps_els_lp)
    ,.msb_first_p(1))
    sipof
    (.clk_i(manycore_clk_i)
    ,.reset_i(manycore_reset_o)
    ,.v_i(mc_valid_lo[i])
    ,.ready_o(mc_ready_li[i])
    ,.data_i(mc_data_lo[i])
    ,.data_o(mc_ps_data_lo[i][ps_width_lp-1:0])
    ,.v_o(mc_ps_valid_lo[i])
    ,.yumi_i(mc_ps_yumi_li[i]));  
  
  end
  
  
  // Cast of link packets
  bsg_manycore_link_sif_s links_sif_i_cast, links_sif_o_cast;

  assign links_sif_i_cast = links_sif_i;
  assign links_sif_o = links_sif_o_cast;
  
  
  // Req and Resp packets
  bsg_manycore_fwd_link_sif_s fwd_li, fwd_lo;
  bsg_manycore_rev_link_sif_s rev_li, rev_lo;

  // coming in from manycore
  assign fwd_li = links_sif_i_cast.fwd;
  assign rev_li = links_sif_i_cast.rev;

  // going out to manycore
  assign links_sif_o_cast.fwd = fwd_lo;
  assign links_sif_o_cast.rev = rev_lo;
  
  
  // Define wormhole packets
  `declare_bsg_wormhole_packet_s(wh_req_width_lp, wormhole_reserved_width_p, wormhole_x_cord_width_p, wormhole_y_cord_width_p, wormhole_len_width_p, req_wormhole_packet);
  `declare_bsg_wormhole_packet_s(wh_resp_width_lp, wormhole_reserved_width_p, wormhole_x_cord_width_p, wormhole_y_cord_width_p, wormhole_len_width_p, resp_wormhole_packet);
  
  // Cast of wormhole packets
  req_wormhole_packet mc_req_data_cast;
  resp_wormhole_packet mc_resp_data_cast;
  
  assign mc_ps_data_li[0] = mc_req_data_cast;
  assign mc_ps_data_li[1] = mc_resp_data_cast;
  
  always_comb 
  begin
  
    // req going out of manycore
    mc_ps_valid_li[0] = fwd_li.v;
    mc_req_data_cast.reserved = 0;
    mc_req_data_cast.x_cord = dest_x_i;
    mc_req_data_cast.y_cord = dest_y_i;
    mc_req_data_cast.len = wormhole_req_ratio_p-1;
    mc_req_data_cast.data = fwd_li.data;
    fwd_lo.ready_and_rev = mc_ps_ready_lo[0];

    // req coming into manycore
    fwd_lo.v = mc_ps_valid_lo[0];
    fwd_lo.data = mc_ps_data_lo[0][mc_req_width_lp-1:0];
    mc_ps_yumi_li[0] = mc_ps_valid_lo[0] & fwd_li.ready_and_rev;

    // resp going out of manycore
    mc_ps_valid_li[1] = rev_li.v;
    mc_resp_data_cast.reserved = 0;
    mc_resp_data_cast.x_cord = dest_x_i;
    mc_resp_data_cast.y_cord = dest_y_i;
    mc_resp_data_cast.len = wormhole_resp_ratio_p-1;
    mc_resp_data_cast.data = rev_li.data;
    rev_lo.ready_and_rev = mc_ps_ready_lo[1];

    // resp coming into manycore
    rev_lo.v = mc_ps_valid_lo[1];
    rev_lo.data = mc_ps_data_lo[1][mc_resp_width_lp-1:0];
    mc_ps_yumi_li[1] = mc_ps_valid_lo[1] & rev_li.ready_and_rev;
  
  end
  
  


endmodule