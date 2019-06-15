
//
// Paul Gao 06/2019
//
// This is an adapter from wormhole network to bsg manycore link
// It assumes that wormhole network and manycore are in different clock regions, an
// asynchronous fifo is instantiated in this adapter to cross the clock domains.
//
//

`include "bsg_manycore_packet.vh"
`include "bsg_wormhole_router.vh"

`define declare_bsg_manycore_link_to_wormhole_s(load_width, hdr_struct_name, in_struct_name) \
  typedef struct packed {                                                      \
    logic [load_width-1:0]     data;                                           \
    hdr_struct_name            hdr;                                            \
  } in_struct_name

module bsg_manycore_link_async_to_wormhole

 #(// Manycore link parameters
   parameter addr_width_p="inv"
  ,parameter data_width_p="inv"
  ,parameter load_id_width_p = "inv"
  ,parameter x_cord_width_p="inv"
  ,parameter y_cord_width_p="inv"
  
  // Wormhole link parameters
  ,parameter flit_width_p                     = "inv"
  ,parameter dims_p                           = "inv"
  ,parameter int cord_markers_pos_p[dims_p:0] = "inv"
  ,parameter len_width_p                      = "inv"
  
  ,localparam num_nets_lp = 2
  ,localparam bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
  
  ,localparam cord_width_lp = cord_markers_pos_p[dims_p]
  )

  (// Manycore side
   input manycore_clk_i
  ,input manycore_reset_i
  
  // Manycore links
  ,input  [bsg_manycore_link_sif_width_lp-1:0] links_sif_i
  ,output [bsg_manycore_link_sif_width_lp-1:0] links_sif_o
  
  // Wormhole side
  ,input clk_i
  ,input reset_i
  
  // The wormhole destination IDs should either be connected to a register (whose value is
  // initialized before reset is deasserted), or set to a constant value.
  ,input [cord_width_lp-1:0] dest_cord_i

  // Wormhole links: {fwd_link, rev_link}
  ,input  [num_nets_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [num_nets_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] link_o
  );

  localparam rev_packet_index_lp = 0;
  localparam fwd_packet_index_lp = 1;
  localparam lg_fifo_depth_lp = 3;
  
  genvar i;
  
  /********************* Packet definition *********************/
  
  // Define manycore link, fwd and rev packets
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  `declare_bsg_manycore_packet_s  (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  
  // Manycore packet width
  localparam mc_fwd_width_lp = $bits(bsg_manycore_packet_s);
  localparam mc_rev_width_lp = $bits(bsg_manycore_return_packet_s);
  
  // Define wormhole fwd and rev packets
  `declare_bsg_wormhole_router_header_s(cord_width_lp, len_width_p, bsg_wormhole_hdr_s);
  
  `declare_bsg_manycore_link_to_wormhole_s(mc_fwd_width_lp, bsg_wormhole_hdr_s, fwd_wormhole_packet_s);
  `declare_bsg_manycore_link_to_wormhole_s(mc_rev_width_lp, bsg_wormhole_hdr_s, rev_wormhole_packet_s);
  
  // Wormhole packet width
  localparam wh_fwd_width_lp = $bits(fwd_wormhole_packet_s);
  localparam wh_rev_width_lp = $bits(rev_wormhole_packet_s);
  
  // Determine PISO and SIPOF convertion ratio
  localparam wh_fwd_ratio_lp = `BSG_CDIV(wh_fwd_width_lp, flit_width_p);
  localparam wh_rev_ratio_lp = `BSG_CDIV(wh_rev_width_lp, flit_width_p);
  
  // synopsys translate_off
  initial
  begin
    assert (len_width_p >= `BSG_SAFE_CLOG2(wh_fwd_ratio_lp))
    else $error("Wormhole packet len width %d is too narrow for fwd ratio %d. Please increase len width.", len_width_p, wh_fwd_ratio_lp);
    
    assert (len_width_p >= `BSG_SAFE_CLOG2(wh_rev_ratio_lp))
    else $error("Wormhole packet len width %d is too narrow for rev ratio %d. Please increase len width.", len_width_p, wh_rev_ratio_lp);
  end
  // synopsys translate_on
  
  
  /********************* Interfacing manycore link *********************/
  
  // Cast of manycore link packets
  bsg_manycore_link_sif_s links_sif_i_cast, links_sif_o_cast;
  
  assign links_sif_i_cast = links_sif_i;
  assign links_sif_o = links_sif_o_cast;
  
  // fwd and rev packets
  bsg_manycore_fwd_link_sif_s fwd_li, fwd_lo;
  bsg_manycore_rev_link_sif_s rev_li, rev_lo;
  
  // coming from manycore to adapter
  assign fwd_li = links_sif_i_cast.fwd;
  assign rev_li = links_sif_i_cast.rev;
  // going out of adapter to manycore
  assign links_sif_o_cast.fwd = fwd_lo;
  assign links_sif_o_cast.rev = rev_lo;
  
  // fwd and rev wormhole packets
  fwd_wormhole_packet_s mc_fwd_piso_data_li_cast, mc_fwd_sipof_data_lo_cast;
  rev_wormhole_packet_s mc_rev_piso_data_li_cast, mc_rev_sipof_data_lo_cast;
  
  always_comb 
  begin
    // fwd out of manycore
    mc_fwd_piso_data_li_cast.hdr.cord = dest_cord_i;
    mc_fwd_piso_data_li_cast.hdr.len  = wh_fwd_ratio_lp-1;
    mc_fwd_piso_data_li_cast.data     = fwd_li.data;
    
    // rev out of manycore
    mc_rev_piso_data_li_cast.hdr.cord = dest_cord_i;
    mc_rev_piso_data_li_cast.hdr.len  = wh_rev_ratio_lp-1;
    mc_rev_piso_data_li_cast.data     = rev_li.data;
    
    // fwd into manycore
    fwd_lo.data                       = mc_fwd_sipof_data_lo_cast.data;
    
    // rev into manycore
    rev_lo.data                       = mc_rev_sipof_data_lo_cast.data;
  end
  
  
  /********************* SIPOF and PISO *********************/
  
  // PISO and SIPOF signals
  logic [wh_fwd_ratio_lp*flit_width_p-1:0] mc_fwd_piso_data_li, mc_fwd_sipof_data_lo;
  logic [wh_rev_ratio_lp*flit_width_p-1:0] mc_rev_piso_data_li, mc_rev_sipof_data_lo;
  
  assign mc_fwd_piso_data_li       = {'0, mc_fwd_piso_data_li_cast};
  assign mc_rev_piso_data_li       = {'0, mc_rev_piso_data_li_cast};
  assign mc_fwd_sipof_data_lo_cast = mc_fwd_sipof_data_lo[wh_fwd_width_lp-1:0];
  assign mc_rev_sipof_data_lo_cast = mc_rev_sipof_data_lo[wh_rev_width_lp-1:0];
  
  // Async fifo signals
  logic [num_nets_lp-1:0] mc_async_fifo_valid_li, mc_async_fifo_yumi_lo;
  logic [num_nets_lp-1:0] mc_async_fifo_valid_lo, mc_async_fifo_ready_li;
  
  logic [num_nets_lp-1:0][flit_width_p-1:0] mc_async_fifo_data_li;
  logic [num_nets_lp-1:0][flit_width_p-1:0] mc_async_fifo_data_lo;
  
  // fwd link piso and sipof
  bsg_parallel_in_serial_out 
 #(.width_p(flit_width_p)
  ,.els_p  (wh_fwd_ratio_lp )
  ) fwd_piso
  (.clk_i  (manycore_clk_i  )
  ,.reset_i(manycore_reset_i)
  ,.valid_i(fwd_li.v            )
  ,.data_i (mc_fwd_piso_data_li )
  ,.ready_o(fwd_lo.ready_and_rev)
  ,.valid_o(mc_async_fifo_valid_li[fwd_packet_index_lp])
  ,.data_o (mc_async_fifo_data_li [fwd_packet_index_lp])
  ,.yumi_i (mc_async_fifo_yumi_lo [fwd_packet_index_lp])
  );
  
  bsg_serial_in_parallel_out_full
 #(.width_p(flit_width_p)
  ,.els_p  (wh_fwd_ratio_lp )
  ) fwd_sipof
  (.clk_i  (manycore_clk_i  )
  ,.reset_i(manycore_reset_i)
  ,.v_i    (mc_async_fifo_valid_lo[fwd_packet_index_lp])
  ,.ready_o(mc_async_fifo_ready_li[fwd_packet_index_lp])
  ,.data_i (mc_async_fifo_data_lo [fwd_packet_index_lp])
  ,.data_o (mc_fwd_sipof_data_lo           )
  ,.v_o    (fwd_lo.v                       )
  ,.yumi_i (fwd_lo.v & fwd_li.ready_and_rev)
  );
  
  // rev link piso and sipof
  bsg_parallel_in_serial_out 
 #(.width_p(flit_width_p)
  ,.els_p  (wh_rev_ratio_lp )
  ) rev_piso
  (.clk_i  (manycore_clk_i  )
  ,.reset_i(manycore_reset_i)
  ,.valid_i(rev_li.v            )
  ,.data_i (mc_rev_piso_data_li )
  ,.ready_o(rev_lo.ready_and_rev)
  ,.valid_o(mc_async_fifo_valid_li[rev_packet_index_lp])
  ,.data_o (mc_async_fifo_data_li [rev_packet_index_lp])
  ,.yumi_i (mc_async_fifo_yumi_lo [rev_packet_index_lp])
  );
  
  bsg_serial_in_parallel_out_full
 #(.width_p(flit_width_p)
  ,.els_p  (wh_rev_ratio_lp )
  ) rev_sipof
  (.clk_i  (manycore_clk_i  )
  ,.reset_i(manycore_reset_i)
  ,.v_i    (mc_async_fifo_valid_lo[rev_packet_index_lp])
  ,.ready_o(mc_async_fifo_ready_li[rev_packet_index_lp])
  ,.data_i (mc_async_fifo_data_lo [rev_packet_index_lp])
  ,.data_o (mc_rev_sipof_data_lo           )
  ,.v_o    (rev_lo.v                       )
  ,.yumi_i (rev_lo.v & rev_li.ready_and_rev)
  );
  
  
  /********************* Async fifo to wormhole link *********************/
  
  // Wormhole side signals
  logic [num_nets_lp-1:0] valid_lo, ready_li;
  logic [num_nets_lp-1:0][flit_width_p-1:0] data_lo;
  
  logic [num_nets_lp-1:0] valid_li, ready_lo;
  logic [num_nets_lp-1:0][flit_width_p-1:0] data_li;

  // Manycore side async fifo input
  logic [num_nets_lp-1:0] mc_async_fifo_full_lo;
  assign mc_async_fifo_yumi_lo = ~mc_async_fifo_full_lo & mc_async_fifo_valid_li;
  
  // Manycore side async fifo output
  logic [num_nets_lp-1:0] mc_async_fifo_deq_li;
  assign mc_async_fifo_deq_li = mc_async_fifo_ready_li & mc_async_fifo_valid_lo;
  
  // Wormhole side async fifo input
  logic [num_nets_lp-1:0] wh_async_fifo_full_lo;
  assign ready_lo = ~wh_async_fifo_full_lo;
  
  for (i = 0; i < num_nets_lp; i++) 
  begin: afifo
    // This async fifo crosses from wormhole clock to manycore clock
    bsg_async_fifo
   #(.lg_size_p(lg_fifo_depth_lp)
    ,.width_p  (flit_width_p)
    ) wh_to_mc
    (.w_clk_i  (clk_i)
    ,.w_reset_i(reset_i)
    ,.w_enq_i  (valid_li[i] & ready_lo[i])
    ,.w_data_i (data_li[i])
    ,.w_full_o (wh_async_fifo_full_lo[i])

    ,.r_clk_i  (manycore_clk_i)
    ,.r_reset_i(manycore_reset_i)
    ,.r_deq_i  (mc_async_fifo_deq_li[i])
    ,.r_data_o (mc_async_fifo_data_lo[i])
    ,.r_valid_o(mc_async_fifo_valid_lo[i])
    );
    
    // This async fifo crosses from manycore clock to wormhole clock
    bsg_async_fifo
   #(.lg_size_p(lg_fifo_depth_lp)
    ,.width_p  (flit_width_p)
    ) mc_to_wh
    (.w_clk_i  (manycore_clk_i)
    ,.w_reset_i(manycore_reset_i)
    ,.w_enq_i  (mc_async_fifo_yumi_lo[i])
    ,.w_data_i (mc_async_fifo_data_li[i])
    ,.w_full_o (mc_async_fifo_full_lo[i])

    ,.r_clk_i  (clk_i)
    ,.r_reset_i(reset_i)
    ,.r_deq_i  (valid_lo[i] & ready_li[i])
    ,.r_data_o (data_lo[i])
    ,.r_valid_o(valid_lo[i])
    );
  end
  
  
  /********************* Interfacing bsg_noc link *********************/
  
  `declare_bsg_ready_and_link_sif_s(flit_width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s [num_nets_lp-1:0] link_i_cast, link_o_cast;
  
  for (i = 0; i < num_nets_lp; i++) 
  begin: noc_cast
    assign link_i_cast[i]               = link_i[i];
    assign link_o[i]                    = link_o_cast[i];

    assign valid_li[i]                  = link_i_cast[i].v;
    assign data_li[i]                   = link_i_cast[i].data;
    assign link_o_cast[i].ready_and_rev = ready_lo[i];
    
    assign link_o_cast[i].v             = valid_lo[i];
    assign link_o_cast[i].data          = data_lo[i];
    assign ready_li[i]                  = link_i_cast[i].ready_and_rev;
  end
  
endmodule