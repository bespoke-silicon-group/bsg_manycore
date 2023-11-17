module bsg_nonsynth_manycore_packet_printer #(
                                      // maximum number of outstanding words
                                       freeze_init_p=1'b1
                                      , x_cord_width_p ="inv"
                                      , y_cord_width_p ="inv"
                                      , addr_width_p   ="inv"
                                      , data_width_p   ="inv"
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
    );

   logic                              pkt_v, pkt_yumi;
   logic [data_width_p-1:0     ]      pkt_data;
   logic [addr_width_p-1:0     ]      pkt_addr;
   logic [(data_width_p>>3)-1:0]      pkt_mask;

   logic                              out_v_li;


   bsg_manycore_endpoint_standard #(.x_cord_width_p    (x_cord_width_p)
                                    ,.y_cord_width_p   (y_cord_width_p)
                                    ,.fifo_els_p       (2)                          // since this module does not queue data
                                    ,.freeze_init_p    (freeze_init_p)              // input fifo is small
                                    ,.max_out_credits_p(2)                          // not sending data, keep it small
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
      ,.out_packet_i ()
      ,.out_ready_o  ()
      ,.out_credits_o()

      ,.my_x_i
      ,.my_y_i

      ,.freeze_r_o()
      );

   // not transmitting anything
   assign out_v_li = 1'b0;

   // accept all data
   assign pkt_yumi = pkt_v;

   always @(negedge clk_i)
     if (pkt_v)
       begin
          $display("## bsg_nonsynth_manycore_packet_print received addr=0h%x, data=%x, at x,y=%d,%d"
                   ,pkt_addr,pkt_data,my_x_i,my_y_i);
          if (pkt_data == 32'hCAFE_C0DE)
            begin
               $display("## bsg_nonsynth_manycore_packet_print received CAFE_CODE packet, exiting");
               $finish;
            end
       end

endmodule
