// Bind to bsg_manycore_link_to_cache;

`include "bsg_manycore_defines.svh"
`include "bsg_defines.sv"


module vc_fwd_trace
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(link_addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , localparam link_sif_width_lp=
      `bsg_manycore_link_sif_width(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

  )
  (
    input clk_i
    , input reset_i
    , input [link_sif_width_lp-1:0] link_sif_i
    , input [link_sif_width_lp-1:0] link_sif_o
    , input [31:0] global_ctr_i
  );




  // Cast link;
  `declare_bsg_manycore_link_sif_s(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s link_sif_in;
  bsg_manycore_link_sif_s link_sif_out;
  assign link_sif_in = link_sif_i;
  assign link_sif_out = link_sif_o;

  // cast packet;
  `declare_bsg_manycore_packet_s(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_packet_s packet;
  assign packet = link_sif_in.fwd.data;


  always @ (posedge clk_i) begin
    if (reset_i == 1'b0) begin
      if (link_sif_in.fwd.v &&
          link_sif_out.fwd.ready_and_rev &&
          (packet.src_x_cord >= num_tiles_x_p) &&
          (packet.src_y_cord >= num_tiles_y_p) &&
          (packet.src_x_cord < 2*num_tiles_x_p) &&
          (packet.src_y_cord < 2*num_tiles_y_p)) begin
        
  
        $display("vc_fwd,%0d,%0d,%0d,%0d,%0d",
          global_ctr_i,
          packet.src_x_cord,
          packet.src_y_cord,
          packet.x_cord,
          packet.y_cord
        );
      end
    end
  end


endmodule
