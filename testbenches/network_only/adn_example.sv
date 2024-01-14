
`ifndef bsg_tiles_X
`error bsg_tiles_X must be defined; pass it in through the makefile
`endif

`ifndef bsg_tiles_Y
`error bsg_tiles_Y must be defined; pass it in through the makefile
`endif

module adn_example
  (input clk_i
   ,input reset_i
   );

   localparam debug_lp=0;
   localparam num_tiles_x_lp  = `bsg_tiles_X;
   localparam num_tiles_y_lp  = `bsg_tiles_Y;
   localparam data_width_lp   = 32;
   localparam addr_width_lp   = 20;
   localparam lg_node_x_lp    = `BSG_SAFE_CLOG2(num_tiles_x_lp);
   localparam lg_node_y_lp    = `BSG_SAFE_CLOG2(num_tiles_y_lp + 1);
   localparam endpoint_credits_lp = 8;

   `declare_bsg_manycore_link_sif_s(addr_width_lp, data_width_lp, lg_node_x_lp, lg_node_y_lp);

   bsg_manycore_link_sif_s [num_tiles_y_lp-1:0][num_tiles_x_lp-1:0] proc_link_sif_li;
   bsg_manycore_link_sif_s [num_tiles_y_lp-1:0][num_tiles_x_lp-1:0] proc_link_sif_lo;

   bsg_manycore_link_sif_s [S:N][num_tiles_x_lp-1:0] ver_link_li, ver_link_lo;
   bsg_manycore_link_sif_s [E:W][num_tiles_y_lp-1:0] hor_link_li, hor_link_lo;

   bsg_manycore_mesh
     #(
      .data_width_p (data_width_lp)
      ,.addr_width_p (addr_width_lp)
      ,.num_tiles_x_p(num_tiles_x_lp)
      ,.num_tiles_y_p(num_tiles_y_lp)

      ,.stub_w_p     ({num_tiles_y_lp{1'b1}})
      ,.stub_e_p     ({num_tiles_y_lp{1'b1}})
      ,.stub_n_p     ({num_tiles_x_lp{1'b1}})

      // only south side X=0 and 1 is unstubbed
      // NOTE: to add more I/O devices you will have unstub the ports
      //       to remove them, you will have stub them

      ,.stub_s_p     ({ { (num_tiles_x_lp-2) {1'b1} }
                        , 2'b00
                      })
      ,.debug_p(1'b0)
      ) UUT
       ( .clk_i   (clk_i)
         ,.reset_i (reset_i)

         ,.hor_link_sif_i(hor_link_li)
         ,.hor_link_sif_o(hor_link_lo)

         ,.ver_link_sif_i(ver_link_li)
         ,.ver_link_sif_o(ver_link_lo)

         ,.proc_link_sif_i(proc_link_sif_li)
         ,.proc_link_sif_o(proc_link_sif_lo)
         );

   localparam packet_width_lp   = `bsg_manycore_packet_width(addr_width_lp,data_width_lp,lg_node_x_lp,lg_node_y_lp);

   // NOTE: you have to update this to match the trace length in the rom file
   localparam rom_words_lp      = 16;

   localparam rom_addr_width_lp = `BSG_SAFE_CLOG2(rom_words_lp);

   logic [packet_width_lp-1:0]   rom_data_lo;
   logic [rom_addr_width_lp-1:0] rom_addr_li;

   // I/O DEVICES HERE
   //
   // add south side links; usually these are I/O devices
   // (be sure to unstub any ports you use, and to stub out ports you don't use
   //  above in the stub_s_p parameter of bsg_manycore_mesh )
   //

   wire                          done_o;

   // attach to SOUTH side below tile X=0 e.g. (Y,X)=(1,0)
   bsg_manycore_packet_streamer
     #(.max_out_credits_p(endpoint_credits_lp)
       ,.rom_words_p(rom_words_lp)
       ,.freeze_init_p(0) // start transmitting at reset
       ,.x_cord_width_p(lg_node_x_lp)
       ,.y_cord_width_p(lg_node_y_lp)
       ,.addr_width_p(addr_width_lp)
       ,.data_width_p(data_width_lp)
       ) ps
       (.clk_i
        ,.reset_i
        ,.link_sif_i(ver_link_lo[S][0] )
        ,.link_sif_o(ver_link_li[S][0] )
        ,.my_x_i(lg_node_x_lp ' (0)              )  // at x=0,y=y_max
        ,.my_y_i(lg_node_y_lp ' (num_tiles_y_lp) )
        ,.rom_addr_o(rom_addr_li)
        ,.rom_data_i(rom_data_lo)
        ,.done_o()
        );

   bsg_rom_gen_adn #(.width_p      (packet_width_lp)
                     ,.addr_width_p(rom_addr_width_lp)
                     ) rom
     (.addr_i (rom_addr_li)
      ,.data_o(rom_data_lo)
      );

  // put a packet printer on SOUTH side below tile X=1 e.g. (Y,X)=(1,1)
   bsg_nonsynth_manycore_packet_printer
     #(.x_cord_width_p(lg_node_x_lp)
       ,.y_cord_width_p(lg_node_y_lp)
       ,.data_width_p(data_width_lp)
       ,.addr_width_p(addr_width_lp)
       ) pp
       (.clk_i
        ,.reset_i
        ,.link_sif_i(ver_link_lo[S][1])
        ,.link_sif_o(ver_link_li[S][1])
        ,.my_x_i(lg_node_x_lp ' (1))
        ,.my_y_i(lg_node_y_lp ' (num_tiles_y_lp))
        );

   // ACCELERATORS HERE
   //
   // add proc links below; these are usually accelerators
   // in this example we just fill it with the same "forward packet"
   // accelerator

   genvar                                               r,c;

   for (c = 0; c < num_tiles_x_lp; c++)
     begin: x
     for (r = 0; r < num_tiles_y_lp; r++)
       begin: y
          bsg_manycore_accel_default #(.x_cord_width_p  (lg_node_x_lp )
                                       ,.y_cord_width_p  (lg_node_y_lp )
                                       ,.data_width_p     (data_width_lp)
                                       ,.addr_width_p     (addr_width_lp)
                                       ,.debug_p          (debug_lp     )
                                       ,.max_out_credits_p(endpoint_credits_lp)
                                       ,.proc_fifo_els_p  (endpoint_credits_lp)
                                       // start them out unfrozen
                                       ,.freeze_init_p    (0)
                                       ) a
          (.clk_i
           ,.reset_i
           ,.link_sif_i(proc_link_sif_lo[r][c])
           ,.link_sif_o(proc_link_sif_li[r][c])

           ,.my_x_i (lg_node_x_lp ' (c))
           ,.my_y_i (lg_node_y_lp ' (r))
           ,.freeze_o()
           );
       end
     end
endmodule
