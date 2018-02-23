// bsg_manycore_link_sif_tieoff
//
// this is used to tie off manycore links
//
// NB: the manycore also contains "stub_p" parameters to tie off network links.
// that one will result in lower area.
//
// However, if for physical design, we are trying to use a single replicated
// design, this would be the module to use.
//
//

module bsg_manycore_link_sif_tieoff
  #(  addr_width_p  = 32
      , data_width_p  = 32
      , x_cord_width_p = "inv"
      , y_cord_width_p = "inv"
      , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
      )
   (
    // debug only
    input clk_i
    , input reset_i

    , input [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o
    );

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_link_sif_s link_sif_i_cast, link_sif_o_cast;
   assign link_sif_i_cast = link_sif_i;
   assign link_sif_o      = link_sif_o_cast;

   wire   _unused1 = & (link_sif_i_cast.fwd.data); // mostly used; sometimes we use the return packet
   wire   _unused2 = & (link_sif_i_cast.rev.data);
   wire   _unused3 = link_sif_i_cast.rev.v;       // we ignore return packets coming in

   // we don't inject any non-return data into the array
   assign link_sif_o_cast.fwd.v         = 1'b0;
   assign link_sif_o_cast.fwd.data         = 0;

   // we will absorb incoming packets, but only if we can turn around and send back a credit
   // on return channel

   // do we have to zero this on reset; otherwise we don't come out of reset correctly?
   assign link_sif_o_cast.fwd.ready_and_rev = link_sif_i_cast.rev.ready_and_rev;  // & ~reset_i;

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_packet_s            temp;
   assign temp = link_sif_i_cast.fwd.data;

   // send a credit packet back; if they route a packet off the side of the chip
   bsg_manycore_return_packet_s     return_pkt      ;
   assign return_pkt.pkt_type          = `ePacketType_credit ;
   assign return_pkt.data              = data_width_p'(0)   ;
   assign return_pkt.y_cord            = temp.src_y_cord    ;
   assign return_pkt.x_cord            = temp.src_x_cord    ;

   assign link_sif_o_cast.rev.v        = link_sif_i_cast.fwd.v;
   assign link_sif_o_cast.rev.data     = return_pkt;

   // absorb all outgoing return packets; they will disappear into the night
   assign link_sif_o_cast.rev.ready_and_rev = 1'b1;

   // synopsys translate_off
   always_ff @(negedge clk_i)
     begin
        if (!reset_i)
          begin
             if (link_sif_i_cast.fwd.v)
               $error("%m unexpected data %x to tied off port; sending credit packet",link_sif_i_cast.fwd.data);
             if (link_sif_i_cast.rev.v)
               $error("%m unexpected return data %x to tied off port; absorbing",link_sif_i_cast.rev.data);
          end
     end
   // synopsys translate_on

endmodule // bsg_manycore_link_sif_tieoff
