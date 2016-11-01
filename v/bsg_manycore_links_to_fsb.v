
// This module acts as a converter between the interconnect
// of a manycore and the FSB interconnect.
//
// We make use of the bsg_channel_tunnel to virtualize the
// links.
//

module  bsg_manycore_links_to_fsb
   import bsg_fsb_pkg::*;
  #(parameter ring_width_p="inv"
    , parameter dest_id_p="inv"
    , parameter num_links_p="inv"
    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    // how many remote credits we have; see bsg_channel_tunnel for how to do this calculation.
    // typically this number is fairly large

    , parameter remote_credits_p="inv"

    , parameter use_pseudo_large_fifo_p = 0
    , parameter bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    )
  (input clk_i
   , input reset_i

   // manycore side: array of links

   , input  [num_links_p-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_i
   , output [num_links_p-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_o

   // FSB side

   // input channel
   , input  v_i
   , input [ring_width_p-1:0] data_i
   , output ready_o

   // output channel
   , output v_o
   , output [ring_width_p-1:0] data_o
   , input yumi_i
   );

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   // also defines return packet
   `declare_bsg_manycore_packet_s  (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_link_sif_s [num_links_p-1:0] links_sif_i_cast, links_sif_o_cast;

   assign links_sif_i_cast = links_sif_i;
   assign links_sif_o = links_sif_o_cast;

   localparam num_nets_lp = 2;
   localparam num_in_lp = num_nets_lp * num_links_p;
   localparam width_lp =  `BSG_MAX($bits(bsg_manycore_packet_s),$bits(bsg_manycore_return_packet_s));
   localparam tagged_width_lp = $clog2(num_in_lp+1) + width_lp;

   // ****
   // **** Signals for manycore link side of bsg_channel_tunnel
   // ****

   // incoming demultiplexed data
   logic [num_in_lp-1:0][width_lp-1:0] data_li;
   logic [num_in_lp-1:0]               v_li;
   logic [num_in_lp-1:0]               yumi_lo;

    // outgoing demultiplexed data
   logic [num_in_lp-1:0][width_lp-1:0] data_lo;
   logic [num_in_lp-1:0]               v_lo;
   logic [num_in_lp-1:0]               yumi_li;

   genvar i,j;

   // ****
   // **** Handle manycore link side of bsg_channel_tunnel
   // ****

   for (i = 0; i < num_links_p; i=i+1)
     begin: rof
        bsg_manycore_fwd_link_sif_s fwd_li, fwd_lo;
        bsg_manycore_rev_link_sif_s rev_li, rev_lo;

        // coming in from manycore
        assign fwd_lo = links_sif_i_cast[i].fwd;
        assign rev_lo = links_sif_i_cast[i].rev;

        // going out to manycore
        assign links_sif_o_cast[i].fwd = fwd_li;
        assign links_sif_o_cast[i].rev = rev_li;

        for (j = 0; j < num_nets_lp; j=j+1)
          begin: rof2
             localparam localwidth_lp = j ? $bits(bsg_manycore_return_packet_s) : $bits(bsg_manycore_packet_s);
             logic ready_lo;

             logic [localwidth_lp-1:0] data;

             if (j)
               begin
                  assign rev_li.ready_and_rev = ready_lo;
                  assign data = rev_lo.data;
               end
             else
               begin
                  assign fwd_li.ready_and_rev = ready_lo;
                  assign data = fwd_lo.data;
               end

             // ** place a two fifo on both channels going from manycore to outside world
             bsg_two_fifo #(.width_p(localwidth_lp)) fifo
             (.clk_i   (clk_i  )
              ,.reset_i(reset_i)

              // input
              ,.ready_o(ready_lo)
              ,.data_i (data)
              ,.v_i    (j ?              rev_lo.v             :              fwd_lo.v            )

              // output
              ,.v_o    (   v_li[i*2+j])
              ,.data_o (data_li[i*2+j][localwidth_lp-1:0])
              ,.yumi_i (yumi_lo[i*2+j])
              );

             // zero extra bits for shorter packet
             if (localwidth_lp < width_lp)
               assign data_li[i*2+j][width_lp-1:localwidth_lp] = 0;
          end // block: rof2sd

        // ** for fwd channels going from outside world to manycore
        assign fwd_li.data    = data_lo[i*2  ][$bits(bsg_manycore_packet_s)-1:0];
        assign fwd_li.v       =    v_lo[i*2  ];
        assign yumi_li[i*2] =      v_lo[i*2  ] & fwd_lo.ready_and_rev;  // v/y to v&r conversion

        // ** for rev channels going from outside world to manycore
        assign rev_li.data    = data_lo[i*2+1][$bits(bsg_manycore_return_packet_s)-1:0];
        assign rev_li.v       =    v_lo[i*2+1];
        assign yumi_li[i*2+1] =    v_lo[i*2+1] & rev_lo.ready_and_rev;  // v/y to v&r conversion
     end


   // ****
   // **** Handle FSB side of bsg_channel_tunnel
   // ****

   // incoming multiplexed data
   logic [tagged_width_lp-1:0]  multi_data_li;
   logic                        multi_v_li;
   logic                        multi_yumi_lo;

   // ** place a FIFO on FSB traffic coming in from outside world towards bsg_channel_tunnel

   bsg_two_fifo #(.width_p(tagged_width_lp)) fifo
   (.clk_i   (clk_i  )
    ,.reset_i(reset_i)

    // input
    ,.ready_o(ready_o                   )
    ,.data_i (data_i[0+:tagged_width_lp]) // note: we assume that the useful data in the packet
                                          // is in the low-order bits.
    ,.v_i    (v_i                       )

    // output
    ,.v_o    (multi_v_li)
    ,.data_o (multi_data_li)
    ,.yumi_i (multi_yumi_lo)
    );

    // outgoing multiplexed data; we need to append the packet header info to convert into data_o, of size ring_width_p
   logic [tagged_width_lp-1:0]  multi_data_lo;

   bsg_fsb_pkt_client_s out_pkt;

   // synopsys translate_off
   initial
     assert($bits(bsg_fsb_pkt_client_s)==ring_width_p)
       else $error("bsg_fsb_pkt_client_s and ring_width_p do not line up",$bits(bsg_fsb_pkt_client_s),ring_width_p);
   // synopsys translate_on

   localparam bsg_fsb_pkt_client_s_data_size_lp = $bits(bsg_fsb_pkt_client_data_t);

   assign out_pkt.destid = dest_id_p;
   assign out_pkt.cmd    = 0;
   assign out_pkt.data   = bsg_fsb_pkt_client_s_data_size_lp ' (multi_data_lo);
   assign data_o = out_pkt;

   // ****
   // **** Finally, the bsg_channel_tunnel itself
   // ****

   // we tunnel a manycore packet
   bsg_channel_tunnel #(.width_p  (width_lp )
                        ,.num_in_p(num_in_lp)
                        ,.remote_credits_p(remote_credits_p) // fixme
                        ,.use_pseudo_large_fifo_p(use_pseudo_large_fifo_p)
                        ) bct
   (.clk_i
    ,.reset_i

    // fsb side
    // in
    ,.multi_data_i (multi_data_li)
    ,.multi_v_i    (multi_v_li   )
    ,.multi_yumi_o (multi_yumi_lo)

    // out
    ,.multi_data_o (multi_data_lo)
    ,.multi_v_o    (v_o          )
    ,.multi_yumi_i (yumi_i       )

    // manycore side

    ,.data_i  (data_li)
    ,.v_i     (v_li   )
    ,.yumi_o  (yumi_lo)

    ,.data_o  (data_lo)
    ,.v_o     (v_lo   )
    ,.yumi_i  (yumi_li)
    );


endmodule



/*
   localparam addr_width_lp    = 20;
   localparam data_width_lp    = 32;

   localparam x_cord_width_lp =`BSG_SAFE_CLOG2(num_tiles_x_p);
   localparam y_cord_width_lp =`BSG_SAFE_CLOG2(num_tiles_y_p+extra_io_rows_p);

   // both E and W links will get stubbed off
   // bsg_manycore_link_sif_s [E:W][num_tiles_y_p-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_lo, hor_link_sif_li;

   // the north link portion of this will get stubbed off
   bsg_manycore_link_sif_s [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_lo, ver_link_sif_lo;

   bsg_manycore #(.bank_size_p   (bank_size_p)

                  ,.num_banks_p  (num_banks_p  )
                  ,.num_tiles_x_p(num_tiles_x_p)
                  ,.num_tiles_y_p(num_tiles_y_p)
                  ,.extra_io_rows_p(extra_io_rows_p)

                  ,.stub_w_p     ( num_tiles_y_p { 1'b1 } )
                  ,.stub_e_p     ( num_tiles_y_p { 1'b1 } )
                  ,.stub_n_p     ( num_tiles_x_p { 1'b1 } )
                  ,.stub_s_p     ( num_tiles_x_p { 1'b0 } )

                  ,.addr_width_p (addr_width_lp)
                  ,.data_width_p (data_width_lp)

               ) bmc
  (.clk_i   (clk_i  )
   ,.reset_i(reset_i)

   ,.hor_link_sif_i() // stubbed
   ,.hor_link_sif_o() // stubbed
   ,.ver_link_sif_i(ver_link_sif_li)
   ,.ver_link_sif_o(ver_link_sif_lo)
  );
  */
