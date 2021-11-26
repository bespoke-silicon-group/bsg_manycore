
//
// Paul Gao 06/2019
//
// This is an adapter from wormhole network to bsg manycore link
//
// Since manycore link consists of independent fwd_link and rev_link, this module
// instantiates two bsg_ready_and_link_async_to_wormhole to handle them.
//
//

`include "bsg_defines.v"

module bsg_manycore_link_async_to_wormhole
 import bsg_manycore_pkg::*;

 #(// Manycore link parameters
   `BSG_INV_PARAM(addr_width_p)
  ,`BSG_INV_PARAM(data_width_p)
  ,`BSG_INV_PARAM(x_cord_width_p)
  ,`BSG_INV_PARAM(y_cord_width_p)
  
  // Wormhole link parameters
  ,`BSG_INV_PARAM(flit_width_p                     )
  ,dims_p                           = 2
  ,int cord_markers_pos_p[dims_p:0] = '{5, 4, 0}
  ,`BSG_INV_PARAM(len_width_p                      )

  // The number of registers between reset_i and reset sinks.
  ,mc_reset_depth_p = 3
  
  ,localparam num_nets_lp = 2
  ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  ,bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
  
  ,cord_width_lp = cord_markers_pos_p[dims_p]
  )

  (// Manycore side
   input mc_clk_i
  ,input mc_reset_i
  
  // Manycore links
  ,input  [bsg_manycore_link_sif_width_lp-1:0] mc_links_sif_i
  ,output [bsg_manycore_link_sif_width_lp-1:0] mc_links_sif_o
  
  // The wormhole destination IDs should either be connected to a register (whose value is
  // initialized before reset is deasserted), or set to a constant value.
  ,input [cord_width_lp-1:0] mc_dest_cord_i
  
  // Wormhole side
  ,input wh_clk_i
  ,input wh_reset_i

  // Wormhole links: {fwd_link, rev_link}
  ,input  [num_nets_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] wh_link_i
  ,output [num_nets_lp-1:0][bsg_ready_and_link_sif_width_lp-1:0] wh_link_o
  );

  // Packet format is {fwd_link, rev_link}
  localparam fwd_index_lp = 1;
  localparam rev_index_lp = 0;
  
  genvar i;
  
  // Define manycore link, fwd and rev packets
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  `declare_bsg_manycore_packet_s  (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  
  // Manycore packet width
  localparam manycore_fwd_packet_width_lp = $bits(bsg_manycore_packet_s);
  localparam manycore_rev_packet_width_lp = $bits(bsg_manycore_return_packet_s);
  
  // Cast of manycore link packets
  bsg_manycore_link_sif_s mc_links_sif_i_cast, mc_links_sif_o_cast;
  
  assign mc_links_sif_i_cast = mc_links_sif_i;
  assign mc_links_sif_o      = mc_links_sif_o_cast;

  // Pipeline the reset
  logic [mc_reset_depth_p:0] mc_reset_i_r;

  assign mc_reset_i_r[0] = mc_reset_i;

  genvar k;
  for (k = 1; k <= mc_reset_depth_p; k++)
    begin
      always_ff @(posedge mc_clk_i)
        begin
          mc_reset_i_r[k] <= mc_reset_i_r[k-1];
        end
    end
  
  // Fwd link
  bsg_ready_and_link_async_to_wormhole
 #(.ral_link_width_p  (manycore_fwd_packet_width_lp)
  ,.flit_width_p      (flit_width_p      )
  ,.dims_p            (dims_p            )
  ,.cord_markers_pos_p(cord_markers_pos_p)
  ,.len_width_p       (len_width_p       )
  ) fwd
  (.ral_clk_i      (mc_clk_i      )
  ,.ral_reset_i    (mc_reset_i_r[mc_reset_depth_p]    )
  ,.ral_link_i     (mc_links_sif_i_cast.fwd)
  ,.ral_link_o     (mc_links_sif_o_cast.fwd)
  ,.ral_dest_cord_i(mc_dest_cord_i)

  ,.wh_clk_i        (wh_clk_i      )
  ,.wh_reset_i      (wh_reset_i    )
  ,.wh_link_i       (wh_link_i[fwd_index_lp])
  ,.wh_link_o       (wh_link_o[fwd_index_lp])
  );
  
  // Rev link
  bsg_ready_and_link_async_to_wormhole
 #(.ral_link_width_p  (manycore_rev_packet_width_lp)
  ,.flit_width_p      (flit_width_p      )
  ,.dims_p            (dims_p            )
  ,.cord_markers_pos_p(cord_markers_pos_p)
  ,.len_width_p       (len_width_p       )
  ) rev
  (.ral_clk_i      (mc_clk_i      )
  ,.ral_reset_i    (mc_reset_i_r[mc_reset_depth_p]    )
  ,.ral_link_i     (mc_links_sif_i_cast.rev)
  ,.ral_link_o     (mc_links_sif_o_cast.rev)
  ,.ral_dest_cord_i(mc_dest_cord_i)

  ,.wh_clk_i        (wh_clk_i      )
  ,.wh_reset_i      (wh_reset_i    )
  ,.wh_link_i       (wh_link_i[rev_index_lp])
  ,.wh_link_o       (wh_link_o[rev_index_lp])
  );
  
endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_async_to_wormhole)
