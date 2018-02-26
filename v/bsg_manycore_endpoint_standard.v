`include "bsg_manycore_packet.vh"

module bsg_manycore_endpoint_standard #( x_cord_width_p          = "inv"
                                         ,y_cord_width_p         = "inv"
                                         ,fifo_els_p             = "inv"
                                         ,freeze_init_p          = 1'b1
                                         ,data_width_p           = 32
                                         ,addr_width_p           = 32
                                         ,max_out_credits_p = "inv"
                                         // if you are doing a streaming application then
                                         // you might want to turn this off because it is fairly normal
                                         ,warn_out_of_credits_p  = 1
                                         ,debug_p                = 0
                                         ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                         ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p, data_width_p)
                                         ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                         ,num_nets_lp            = 2
                                         )
   (input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    // local incoming data interface
    , output                         in_v_o
    , input                          in_yumi_i
    , output [data_width_p-1:0]      in_data_o
    , output [(data_width_p>>3)-1:0] in_mask_o
    , output [addr_width_p-1:0]      in_addr_o
    , output                         in_we_o

    // local outgoing data interface (does not include credits)
    , input                                  out_v_i
    , input  [packet_width_lp-1:0]           out_packet_i
    , output                                 out_ready_o

    // local returned data interface
    // Like the memory interface, processor should always ready be to handle the returned data
    , output [data_width_p-1:0]             returned_data_r_o
    , output                                returned_v_r_o

    // The memory read value
    , input [data_width_p-1:0]              returning_data_i
    , input                                 returning_v_i

    , output [$clog2(max_out_credits_p+1)-1:0] out_credits_o

     // tile coordinates
    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    // whether module is frozen or not
    , output freeze_r_o
    // reverse the arbiter priority
    , output reverse_arb_pr_o
    );

   wire in_fifo_full;
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s      cgni_data;
   wire                       cgni_v;
   wire                       cgni_yumi;

   wire [return_packet_width_lp-1:0] returning_packet_li     ;
   wire                              returning_v_li        ;
   wire                              returning_ready_lo    ;

   wire                              returned_credit_lo   ;
   bsg_manycore_return_packet_s      returned_packet_lo   ;

   bsg_manycore_endpoint #(.x_cord_width_p (x_cord_width_p)
                           ,.y_cord_width_p(y_cord_width_p)
                           ,.fifo_els_p    (fifo_els_p  )
                           ,.data_width_p  (data_width_p)
                           ,.addr_width_p  (addr_width_p)
                           ) bme
     (.clk_i
      ,.reset_i
      ,.link_sif_i
      ,.link_sif_o

      ,.fifo_data_o(cgni_data)
      ,.fifo_v_o   (cgni_v)
      ,.fifo_yumi_i(cgni_yumi)

      ,.out_packet_i
      ,.out_v_i
      ,.out_ready_o

      ,.returned_packet_r_o          ( returned_packet_lo    )
      ,.returned_credit_v_r_o        ( returned_credit_lo    )

      ,.returning_data_i    ( returning_packet_li  )
      ,.returning_v_i       ( returning_v_li       )
      ,.returning_ready_o   ( returning_ready_lo   )

      ,.in_fifo_full_o( in_fifo_full )
      );


   // ----------------------------------------------------------------------------------------
   // Handle incoming request packets
   // ----------------------------------------------------------------------------------------
   logic  pkt_freeze, pkt_remote_store, pkt_remote_load, pkt_unfreeze, pkt_arb_cfg, pkt_unknown;


   bsg_manycore_pkt_decode #(.x_cord_width_p (x_cord_width_p)
                             ,.y_cord_width_p(y_cord_width_p)
                             ,.data_width_p  (data_width_p )
                             ,.addr_width_p  (addr_width_p )
                             ) pkt_decode
     (.v_i                 (cgni_v)
      ,.data_i             (cgni_data)

      ,.pkt_remote_store_o (pkt_remote_store)
      ,.pkt_remote_load_o  (pkt_remote_load)
      ,.pkt_freeze_o       (pkt_freeze)
      ,.pkt_unfreeze_o     (pkt_unfreeze)
      ,.pkt_arb_cfg_o      (pkt_arb_cfg)
      ,.pkt_unknown_o      (pkt_unknown)

      ,.data_o             (in_data_o)  // "
      ,.addr_o             (in_addr_o)  // "
      ,.mask_o             (in_mask_o)  // "
      );
   // dequeue only if
   // 1. The outside is ready (they want to yumi the singal),
   //    or the packet is configure operation
   // 2. The returning path is ready (which means the returning credit fifo is
   //    not full
   wire   rc_fifo_ready_lo, rc_fifo_v_lo, rc_fifo_yumi_li;
   assign cgni_yumi = (in_yumi_i  | pkt_freeze | pkt_unfreeze | pkt_arb_cfg ) & rc_fifo_ready_lo;

   //we hide the request if the returning path is not ready
   assign in_v_o    = (pkt_remote_store | pkt_remote_load) & rc_fifo_ready_lo  ;
   assign in_we_o   = pkt_remote_store                      ;

   // ----------------------------------------------------------------------------------------
   // Handle outgoing credit packet
   // ----------------------------------------------------------------------------------------
   typedef struct packed {
      logic [`return_packet_type_width-1:0]     pkt_type;
      logic [(y_cord_width_p)-1:0]                y_cord;
      logic [(x_cord_width_p)-1:0]                x_cord;
   } returning_credit_info;

   returning_credit_info  rc_fifo_li, rc_fifo_lo;

   assign rc_fifo_li   ='{ pkt_type: pkt_remote_load ?`ePacketType_data :`ePacketType_credit
                          ,y_cord  : cgni_data.src_y_cord
                          ,x_cord  : cgni_data.src_x_cord
                        };


   bsg_two_fifo #(.width_p($bits(returning_credit_info)) ) return_credit_fifo
   ( .clk_i
    ,.reset_i

    // input side
    ,.ready_o (rc_fifo_ready_lo)// early
    ,.data_i  (rc_fifo_li      )// late
    ,.v_i     (cgni_yumi       )// late

    // output side
    ,.v_o     (rc_fifo_v_lo    )// early
    ,.data_o  (rc_fifo_lo      )// early
    ,.yumi_i  (rc_fifo_yumi_li )// late
    );

    wire   is_store_return =  rc_fifo_lo.pkt_type == `ePacketType_credit ;
    wire   load_store_ready=  is_store_return
                            | ( (~is_store_return) & returning_v_i )    ;

    assign rc_fifo_yumi_li =  rc_fifo_v_lo & returning_ready_lo & load_store_ready;

    assign returning_v_li           =  rc_fifo_v_lo & load_store_ready;
    assign returning_packet_li      = { rc_fifo_lo.pkt_type
                                      , returning_data_i
                                      , rc_fifo_lo.y_cord
                                      , rc_fifo_lo.x_cord
                                      };
   // ----------------------------------------------------------------------------------------
   // Handle returned credit & data
   // ----------------------------------------------------------------------------------------
   wire launching_out       = out_v_i & out_ready_o ;

   bsg_counter_up_down #(.max_val_p  (max_out_credits_p)
                         ,.init_val_p(max_out_credits_p)
                         ) out_credit_ctr
     (.clk_i
      ,.reset_i
      ,.down_i   (launching_out)  // launch remote store
      ,.up_i     (returned_credit_lo      )  // receive credit back
      ,.count_o(out_credits_o  )
      );

   assign returned_data_r_o     =   returned_packet_lo.data     ;
   assign returned_v_r_o        =   returned_credit_lo
                                 & ( returned_packet_lo.pkt_type == `ePacketType_data ) ;
   // ----------------------------------------------------------------------------------------
   // Handle the control registers
   // ----------------------------------------------------------------------------------------
   // create freeze gate
   logic  freeze_r;
   assign freeze_r_o = freeze_r;

   always_ff @(posedge clk_i)
     if (reset_i)
       freeze_r <= freeze_init_p;
     else
       if (pkt_freeze | pkt_unfreeze)
         begin
// synopsys translate_off
            $display("## freeze_r <= %x (%m)",pkt_freeze);
// synopsys translate_on
            freeze_r <= pkt_freeze;
         end
   //the arbiter configuation gate
   logic arb_cfg_r ;

   always_ff @(posedge clk_i)
   if( reset_i )            arb_cfg_r <= 1'b1;
   else if( pkt_arb_cfg ) begin
    // synopsys translate_off
     $display("## arb_cfg_r <= %b (%m)", in_data_o[0]);
    // synopsys translate_on
      arb_cfg_r <= in_data_o[0];
   end

   assign reverse_arb_pr_o = arb_cfg_r & in_fifo_full ;
   // *************************************************
   // ** checks
   //
   // everything below here is only for checking
   //

// synopsys translate_off
   if (debug_p)
   always_ff @(negedge clk_i)
     begin
        if (returned_credit_lo)
          $display("## return packet received by (x,y)=%x,%x",my_x_i,my_y_i);
     end

   always_ff @(negedge clk_i)
     if (~reset_i & pkt_unknown & cgni_v)
       begin
          $write("## UNKNOWN packet: %b PACKET_WIDTH=%d; (%m)  ",cgni_data,$bits(bsg_manycore_packet_s));
          `write_bsg_manycore_packet_s(cgni_data);
          $write("\n");
	  $finish();
       end

   if (debug_p)
     always_ff @(negedge clk_i)
       if (out_v_i)
         $display("## attempting remote store send of data %x, ready_i = %x (%m)",out_packet_i,out_ready_o);

   if (debug_p)
     always_ff @(negedge clk_i)
       if (in_v_o & ~freeze_r)
         $display("## received remote store request of data %x, addr %x, mask %b (%m)",
                  in_data_o, in_addr_o, in_mask_o);

   if (debug_p)
     always_ff @(negedge clk_i)
       if (cgni_v & ~freeze_r)
         $display("## data %x avail on cgni (cgni_yumi=%x,in_v=%x, in_addr=%x, in_data=%x, in_yumi=%x) (%m)"
                  ,cgni_data,cgni_yumi,in_v_o,in_addr_o, in_data_o, in_yumi_i);

   // this is not an error, but it is extremely surprising
   // and merits investigation


   logic out_of_credits_warned = 0;

  if (warn_out_of_credits_p)
   always @(negedge clk_i)
     begin
        if ( ~(reset_i) & ~out_of_credits_warned)
        assert (out_credits_o === 'X || out_credits_o > 0) else
          begin
             $display("## out of remote store credits(=%d) x,y=%d,%d displaying only once (%m)",out_credits_o,my_x_i,my_y_i);
             $display("##   (this may be a performance problem; or normal behavior)");
             out_of_credits_warned = 1;
          end
     end

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
   bsg_manycore_link_sif_s link_sif_i_cast;
   assign link_sif_i_cast = link_sif_i;

   bsg_manycore_return_packet_s return_packet;
   assign return_packet = link_sif_i_cast.rev.data;

   logic reset_i_r ;
   always_ff @(posedge clk_i)  reset_i_r <= reset_i;

   always_ff @(negedge clk_i)
     assert ( (reset_i_r!==0) | ~link_sif_i_cast.rev.v | ({return_packet.y_cord, return_packet.x_cord} == {my_y_i, my_x_i}))
       else begin
         $error("## errant credit packet v=%b for YX=%d,%d landed at YX=%d,%d (%m)"
                ,link_sif_i_cast.rev.v
                ,link_sif_i_cast.rev.data[x_cord_width_p+:y_cord_width_p]
                ,link_sif_i_cast.rev.data[0+:x_cord_width_p]
                ,my_y_i,my_x_i);
        $finish();
       end

// synopsys translate_on

endmodule


