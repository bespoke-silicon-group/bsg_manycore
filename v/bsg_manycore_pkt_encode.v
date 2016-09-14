`include "bsg_manycore_addr.vh"
`include "bsg_manycore_packet.vh"

module bsg_manycore_pkt_encode
  #(
    x_cord_width_p   = -1 
    , y_cord_width_p = -1
    , data_width_p   = -1
    , addr_width_p   = -1
    , packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , debug_p=0
    )
   (
    input clk_i // for debug only
    ,input v_i
    ,input [addr_width_p-1:0] addr_i
    ,input [data_width_p-1:0] data_i
    ,input [(data_width_p>>3)-1:0] mask_i
    ,input we_i
    ,output v_o
    ,output [packet_width_lp-1:0] data_o
    );

   `declare_bsg_manycore_addr_s(addr_width_p,x_cord_width_p,y_cord_width_p);

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s pkt;
   addr_decode_s addr_decode;

   assign addr_decode = addr_i;
   assign data_o = pkt;

   assign pkt.op     = addr_decode.addr[$size(addr_decode.addr)-1] ? 2'b10 : 2'b01;
   assign pkt.op_ex  = mask_i;

   // remote top bit of address
   assign pkt.addr   = addr_width_p ' (addr_decode.addr[$size(addr_decode.addr)-2:0]);

   assign pkt.data   = data_i;
   assign pkt.x_cord = addr_decode.x_cord;
   assign pkt.y_cord = addr_decode.y_cord;

   assign v_o = addr_decode.remote & we_i & v_i;

   // synopsys translate_off
   if (debug_p)
   always @(negedge clk_i)
     if (v_i)
       $display("%m encode pkt addr_i=%x data_i=%x mask_i=%x we_i=%x v_o=%x, data_o=%x, remote=%x",
                addr_i, data_i, mask_i, we_i, v_o, data_o, addr_decode.remote, $bits(addr_decode_s));

   always_ff @(negedge clk_i)
     begin
        if (addr_decode.remote & ~we_i & v_i)
          begin
             $error("%m load to remote address %x", addr_i);
             $finish();
          end
/*        if (addr_decode.remote & we_i & v_i & (|addr_i[1:0]))
          begin
             $error ("%m store to remote unaligned address %x", addr_i);
          end*/
     end
   // synopsys translate_on

endmodule
