
`include "bsg_defines.v"

module bsg_manycore_packet_streamer #(
                                      // maximum number of outstanding words
                                       max_out_credits_p)
                                      , rom_words_p)
                                      , freeze_init_p=1'b1
                                      , `BSG_INV_PARAM(x_cord_width_p )
                                      , `BSG_INV_PARAM(y_cord_width_p )
                                      , `BSG_INV_PARAM(addr_width_p   )
                                      , `BSG_INV_PARAM(data_width_p   )
                                      , debug_p = 1
                                      , packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                      , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                      )
   (input clk_i
    , input reset_i

    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input [x_cord_width_p-1:0]   my_x_i
    , input [y_cord_width_p-1:0]   my_y_i

    // connection to the rom
    , output [`BSG_SAFE_CLOG2(rom_words_p)-1:0] rom_addr_o
    , input  [packet_width_lp-1:0]  rom_data_i
    , output done_o
    );

   logic                              pkt_v, pkt_yumi;
   logic [data_width_p-1:0     ]      pkt_data;
   logic [addr_width_p-1:0     ]      pkt_addr;
   logic [(data_width_p>>3)-1:0]      pkt_mask;

   logic                              freeze_r;

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s                        out_packet_li;
   logic                                        out_v_li;
   logic                                        out_ready_lo;
   logic [$clog2(max_out_credits_p+1)-1:0]      out_credits_lo;

   // we are not receiving data with this node, so we tie this off to
   // the input and absorb packets
   assign pkt_yumi = pkt_v;

   bsg_manycore_endpoint_standard #(.x_cord_width_p    (x_cord_width_p)
                                    ,.y_cord_width_p   (y_cord_width_p)
                                    ,.fifo_els_p       (2)                          // since this module is not receiving data
                                    ,.freeze_init_p    (freeze_init_p)              //    the input fifo small
                                    ,.max_out_credits_p(max_out_credits_p)
                                    ,.data_width_p     (data_width_p)
                                    ,.addr_width_p     (addr_width_p)
                                    ) endp
     (.clk_i
      ,.reset_i
      ,.link_sif_i
      ,.link_sif_o
      ,.in_v_o   (pkt_v)
      ,.in_yumi_i(pkt_yumi)
      ,.in_data_o(pkt_data)
      ,.in_mask_o(pkt_mask)
      ,.in_addr_o(pkt_addr)

      ,.out_v_i      (out_v_li)
      ,.out_packet_i (out_packet_li)
      ,.out_ready_o  (out_ready_lo)
      ,.out_credits_o(out_credits_lo)

      ,.my_x_i
      ,.my_y_i

      ,.freeze_r_o(freeze_r)
      );

   wire data_transferred = out_v_li & out_ready_lo;
   
   wire done_n, done_r;
   assign done_n = done_r | ((rom_addr_o == (rom_words_p-1)) & data_transferred);
   
   bsg_dff_reset #(.width_p(1), .harden_p(0)) done_reg
     (.clock_i(clk_i)
      ,.data_i(done_n)
      ,.reset_i
      ,.data_o(done_r)
      );

   assign out_v_li = (~done_r & ~freeze_r & (|out_credits_lo));
   assign out_packet_li = rom_data_i;

   bsg_counter_clear_up #(.max_val_p(rom_words_p-1)
                          ,.init_val_p(0)
                          ) bccu
   (.clk_i
    ,.reset_i
    ,.clear_i(1'b0)
    ,.up_i(data_transferred & ~done_n)
    ,.count_o(rom_addr_o)
    );

   if (debug_p)
     always @(negedge clk_i)
       begin
	  if (data_transferred)
            $display("## bsg_manycore_packet_streamer v=%b packet=%b ready=%b out_credits_lo=%b rom_addr=%b freeze=%b done_o=%b"
                     , out_v_li, out_packet_li, out_ready_lo, out_credits_lo, rom_addr_o, freeze_r, done_o);
          if (done_n & ~done_r)
	    $display("## bsg_manycore_packet_streamer finished transmission (%m)");
       end
endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_packet_streamer)
