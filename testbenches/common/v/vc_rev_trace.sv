// Bind to bsg_manycore_link_to_cache;

`include "bsg_manycore_defines.svh"
`include "bsg_defines.sv"



module vc_rev_trace
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(link_addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , localparam return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [return_packet_width_lp-1:0] return_packet_li
    , input return_packet_v_li
    , input return_packet_ready_lo

    , input [31:0] global_ctr_i
  );

  // cast return packet;
  `declare_bsg_manycore_packet_s(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_return_packet_s return_packet;
  assign return_packet = return_packet_li;

  import "DPI-C" context function
    void dpi_vc_rev_trace(input int ctr, input int tile_x, input int tile_y,
                            input int vc_x, input int vc_y);

  always @ (posedge clk_i) begin
    if (reset_i == 1'b0) begin
      if (return_packet_v_li &&
          return_packet_ready_lo &&
          (return_packet.x_cord >= num_tiles_x_p) &&
          (return_packet.y_cord >= num_tiles_y_p) &&
          (return_packet.x_cord < 2*num_tiles_x_p) &&
          (return_packet.y_cord < 2*num_tiles_y_p)) begin
        
        dpi_vc_rev_trace(global_ctr_i,
                          return_packet.x_cord, return_packet.y_cord,
                          return_packet.src_x_cord, return_packet.src_y_cord);
/*
        $display("vc_rev,%0d,%0d,%0d,%0d,%0d",
          global_ctr_i,
          return_packet.src_x_cord,
          return_packet.src_y_cord,
          return_packet.x_cord,
          return_packet.y_cord
        );
*/
      end
    end
  end


endmodule
