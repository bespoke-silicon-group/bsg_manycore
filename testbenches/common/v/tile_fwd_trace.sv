// Bind to network tx;

`include "bsg_manycore_defines.svh"



module tile_fwd_trace
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , localparam packet_width_lp=
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
    , input out_v_o
    , input [packet_width_lp-1:0] out_packet_o
    , input [31:0] global_ctr_i
  );


  // cast packet;
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_packet_s out_packet;
  assign out_packet = out_packet_o;


  import "DPI-C" context function
    void dpi_tile_fwd_trace(input int ctr, input int tile_x, input int tile_y,
                            input int vc_x, input int vc_y);

  always @ (posedge clk_i) begin
    if (reset_i == 1'b0) begin 
      // print only vcache dest;
      if (out_v_o && ((out_packet.y_cord == num_tiles_y_p-1) || (out_packet.y_cord == 2*num_tiles_y_p)))

        dpi_tile_fwd_trace(global_ctr_i, out_packet.src_x_cord, out_packet.src_y_cord,
                                         out_packet.x_cord, out_packet.y_cord);
      
    end
  end


endmodule
