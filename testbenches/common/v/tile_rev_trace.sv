// bind to bsg_manycore_endpoint
`include "bsg_manycore_defines.svh"
`include "bsg_defines.sv"

module tile_rev_trace
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    ,`BSG_INV_PARAM(data_width_p)
    ,`BSG_INV_PARAM(x_cord_width_p)
    ,`BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

  )
  (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , input [link_sif_width_lp-1:0] link_sif_o

    , input [31:0] global_ctr_i
  );


  // cast link;
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s link_sif_in, link_sif_out;
  assign link_sif_in = link_sif_i;
  assign link_sif_out = link_sif_o;


  // cast packet;
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_return_packet_s return_packet;
  assign return_packet = link_sif_in.rev.data;


  import "DPI-C" context function
    void dpi_tile_rev_trace(input int ctr, input int tile_x, input int tile_y,
                            input int vc_x, input int vc_y);


  always @ (posedge clk_i) begin
    if (reset_i == 1'b0) begin
      if (link_sif_in.rev.v &&
          link_sif_out.rev.ready_and_rev &&
          (return_packet.x_cord >= num_tiles_x_p) &&
          (return_packet.y_cord >= num_tiles_y_p) &&
          (return_packet.x_cord < 2*num_tiles_x_p) &&
          (return_packet.y_cord < 2*num_tiles_y_p) &&
          ((return_packet.src_y_cord == num_tiles_y_p-1) || (return_packet.src_y_cord == num_tiles_y_p*2))
        ) begin
        
        dpi_tile_rev_trace(global_ctr_i,
                          return_packet.x_cord, return_packet.y_cord,
                          return_packet.src_x_cord, return_packet.src_y_cord);
 /*
        $display("tile_rev,%0d,%0d,%0d,%0d,%0d",
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
