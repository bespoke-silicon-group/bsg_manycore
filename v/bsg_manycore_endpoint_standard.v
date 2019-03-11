// Endpoint standard is the interface for any nodes that connecto the network.
//
// Orinigally designed by Michael B. Taylor <prof.taylor@gmail.com>
// Extedned by Shaolin <shawnless.xie@gmail.com> and Bandhav <bandhav@uw.edu>
//
// See folloing google doc for more information.
//
// https://docs.google.com/document/d/1-i62N72pfx2Cd_xKT3hiTuSilQnuC0ZOaSQMG8UPkto/edit?usp=sharing
//
//   node                               endpoint_standard             router
//
// -------------|     1. in_request     |-------------- |          |---------|
//              |  <------------------- |               |          |         |
//      Slave   |                       |               | link_in  |         |
//              |     2. out_response   |               |<---------|         |
//              |  -------------------> |               |          |         |
//              |                       |               |          |         |
//              |     3. out_request    |               |          |         |
//      Master  |  -------------------> |               |          |         |
//              |                       |               | link_out |         |
//              |     4. in_response    |               |--------->|         |
//              |  <------------------- |               |          |         |
//--------------                        |---------------|          |---------|
`include "bsg_manycore_packet.vh"

module bsg_manycore_endpoint_standard #( x_cord_width_p          = "inv"
                                         ,y_cord_width_p         = "inv"
                                         ,fifo_els_p             = "inv"
                                         // enable this to instantiate a fifo
                                         // to buffer returned data
                                         ,returned_fifo_p        = 0
                                         ,freeze_init_p          = 1'b1
                                         ,data_width_p           = 32
                                         ,addr_width_p           = 32
                                         ,max_out_credits_p      = "inv"
                                         ,load_id_width_p        = 5
                                         // if you are doing a streaming application then
                                         // you might want to turn this off because it is fairly normal
                                         ,warn_out_of_credits_p  = 1
                                         ,debug_p                = 0
                                         ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
                                         ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p, data_width_p, load_id_width_p)
                                         ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                                         ,num_nets_lp            = 2
                                         )
   (  input clk_i
    , input reset_i
    //--------------------------------------------------------
    // 0. signals to the router
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    //--------------------------------------------------------
    // 1. in_request signal group
    //    request comming from the network
    , output                            in_v_o
    , input                             in_yumi_i
    , output [data_width_p-1:0]         in_data_o
    , output [(data_width_p>>3)-1:0]    in_mask_o
    , output [addr_width_p-1:0]         in_addr_o
    , output                            in_we_o
      //debug only
    , output [x_cord_width_p-1:0]       in_src_x_cord_o
    , output [y_cord_width_p-1:0]       in_src_y_cord_o

    //--------------------------------------------------------
    // 2. out_response signal group
    //    responses that will send back to the network
    , input [data_width_p-1:0]              returning_data_i
    , input                                 returning_v_i

    //--------------------------------------------------------
    // 3. out_request signal group
    //    request that will send to the network
    , input                                  out_v_i
    , input  [packet_width_lp-1:0]           out_packet_i
    , output                                 out_ready_o

    //--------------------------------------------------------
    // 4. in_response signal group
    //    responses that send back from the network
    //    the node shold always be ready to recieve this response.
    , output [data_width_p-1:0]             returned_data_r_o
    , output [load_id_width_p-1:0]          returned_load_id_r_o
    , output                                returned_v_r_o
      //must be 1 if returned_v_r_o is high
    , input                                 returned_yumi_i
      //can be ignored.
    , output                                returned_fifo_full_o


    , output [$clog2(max_out_credits_p+1)-1:0] out_credits_o

     // tile coordinates
    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    );

   wire in_fifo_full;
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);

   bsg_manycore_packet_s      cgni_data;
   wire                       cgni_v;
   wire                       cgni_yumi;

   wire [return_packet_width_lp-1:0] returning_packet_li     ;
   wire                              returning_v_li        ;
   wire                              returning_ready_lo    ;
   wire                              returned_yumi_li;

   wire                              returned_credit;
   wire                              returned_credit_v_lo;
   bsg_manycore_return_packet_s      returned_packet_lo;

   bsg_manycore_endpoint #(.x_cord_width_p       (x_cord_width_p)
                           ,.y_cord_width_p      (y_cord_width_p)
                           ,.fifo_els_p          (fifo_els_p  )
                           ,.returned_fifo_p     (returned_fifo_p)
                           ,.data_width_p        (data_width_p)
                           ,.addr_width_p        (addr_width_p)
                           ,.load_id_width_p     (load_id_width_p)
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
      ,.returned_credit_v_r_o        ( returned_credit_v_lo    )
      ,.returned_fifo_full_o         ( returned_fifo_full_o  )
      ,.returned_yumi_i              ( returned_yumi_li      )

      ,.returning_data_i    ( returning_packet_li  )
      ,.returning_v_i       ( returning_v_li       )
      ,.returning_ready_o   ( returning_ready_lo   )

      ,.in_fifo_full_o( in_fifo_full )
      );

   assign returned_credit = returned_credit_v_lo & returned_yumi_li;

   // ----------------------------------------------------------------------------------------
   // Handle incoming request packets
   // ----------------------------------------------------------------------------------------
   //singals between FIFO to swap_ctrl
   wire in_yumi_lo, in_v_li;

   wire [data_width_p-1:0]          in_data_lo  =cgni_data.payload;
   wire [addr_width_p-1:0]          in_addr_lo  =cgni_data.addr;
   wire[(data_width_p>>3)-1:0]      in_mask_lo  =cgni_data.op_ex;

   wire pkt_remote_store   = cgni_v & (cgni_data.op == `ePacketOp_remote_store  );
   wire pkt_remote_load    = cgni_v & (cgni_data.op == `ePacketOp_remote_load   );
   wire pkt_remote_swap_aq = cgni_v & (cgni_data.op == `ePacketOp_remote_swap_aq);
   wire pkt_remote_swap_rl = cgni_v & (cgni_data.op == `ePacketOp_remote_swap_rl);
   
   // dequeue only if
   // 1. The outside is ready (they want to yumi the singal),
   // 2. The returning path is ready
   wire   rc_fifo_ready_lo, rc_fifo_v_lo, rc_fifo_yumi_li;

   assign cgni_yumi = in_yumi_lo  & (returning_ready_lo & rc_fifo_ready_lo );
   assign in_v_li   = cgni_v      & (returning_ready_lo & rc_fifo_ready_lo );


   wire [data_width_p-1:0]  comb_returning_data_lo  ;
   wire                     comb_returning_v_lo     ;
   bsg_manycore_lock_ctrl         #(      .data_width_p   (data_width_p   )
                                         ,.addr_width_p   (addr_width_p   )
                                         ,.x_cord_width_p (x_cord_width_p )
                                         ,.y_cord_width_p (y_cord_width_p )
                                         ,.max_out_credits_p ( max_out_credits_p )
                                         ,.debug_p        ( 1'b0          )
                                    ) lock_ctrl
   ( .clk_i
    ,.reset_i

     // local endpoint incoming data interface
    ,.in_v_i     (in_v_li        )
    ,.in_yumi_o  (in_yumi_lo     )
    ,.in_data_i  (in_data_lo     )
    ,.in_mask_i  (in_mask_lo     )
    ,.in_addr_i  (in_addr_lo     )
    ,.in_we_i    (pkt_remote_store)

    ,.in_swap_aq_i (pkt_remote_swap_aq )
    ,.in_swap_rl_i (pkt_remote_swap_rl )
    ,.in_x_cord_i  (cgni_data.src_x_cord )
    ,.in_y_cord_i  (cgni_data.src_y_cord )

    // combined  incoming data interface
    ,.comb_v_o      (in_v_o         )
    ,.comb_yumi_i   (in_yumi_i      )
    ,.comb_data_o   (in_data_o      )
    ,.comb_mask_o   (in_mask_o      )
    ,.comb_addr_o   (in_addr_o      )
    ,.comb_we_o     (in_we_o        )
    ,.comb_x_cord_o (in_src_x_cord_o)
    ,.comb_y_cord_o (in_src_y_cord_o)

    // The memory read value
    ,.returning_data_i
    ,.returning_v_i

    // The output read value
    ,.comb_returning_data_o    ( comb_returning_data_lo     )
    ,.comb_returning_v_o       ( comb_returning_v_lo        )


    );
   //we hide the request if the returning path is not ready

   // ----------------------------------------------------------------------------------------
   // Handle outgoing credit packet
   // ----------------------------------------------------------------------------------------
   typedef struct packed {
      logic [`return_packet_type_width-1:0]     pkt_type;
      logic [(y_cord_width_p)-1:0]              y_cord;
      logic [(x_cord_width_p)-1:0]              x_cord;
      logic [(load_id_width_p)-1:0]             load_id;
   } returning_credit_info;

   returning_credit_info  rc_fifo_li, rc_fifo_lo;

   wire req_returning_data =pkt_remote_load | pkt_remote_swap_aq;

   assign rc_fifo_li   ='{ pkt_type: ( req_returning_data) ?`ePacketType_data :`ePacketType_credit
                          ,y_cord  : cgni_data.src_y_cord
                          ,x_cord  : cgni_data.src_x_cord
                          ,load_id : cgni_data.payload.load_info_s.load_id
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

    //there is 1 cycle delay between the "RC_FIFO is not full" and "returning data
    //valid". Even in current cycle the "RC_FIFO is not full" and we yumi
    //a incoming request. In next cycle the "RC_FIFO maybe full" and we can
    //not receive the returning data.
    // THUS WE NEED A HOLD MODULE TO HOLD THE RETURNING DATA
    wire [data_width_p-1:0]     holded_returning_data_lo;
    wire                        holded_returning_v_lo   ;

    bsg_1hold #( .data_width_p( data_width_p) ) returning_hold (
        .clk_i      ( clk_i                 )
       ,.v_i        ( comb_returning_v_lo   )
       ,.data_i     ( comb_returning_data_lo)

       ,.v_o        ( holded_returning_v_lo     )
       ,.data_o     ( holded_returning_data_lo  )

       ,.hold_i     ( (~returning_ready_lo) & holded_returning_v_lo )
    );

//    wire   is_store_return =  rc_fifo_lo.pkt_type == `ePacketType_credit ;
//    wire   load_store_ready=  is_store_return
//                            | ( (~is_store_return) & holded_returning_v_lo )    ;
    wire   load_store_ready = holded_returning_v_lo;

    assign rc_fifo_yumi_li =  rc_fifo_v_lo & returning_ready_lo & load_store_ready;

    assign returning_v_li           =  rc_fifo_v_lo & load_store_ready;

    bsg_manycore_return_packet_s      returning_pkt_cast;
    assign returning_pkt_cast       = '{ pkt_type        : rc_fifo_lo.pkt_type
                                       , data            : holded_returning_data_lo
                                       , y_cord          : rc_fifo_lo.y_cord
                                       , x_cord          : rc_fifo_lo.x_cord
                                       , load_id         : rc_fifo_lo.load_id
                                       };
    assign returning_packet_li      = returning_pkt_cast;
   // ----------------------------------------------------------------------------------------
   // Handle returned credit & data
   // ----------------------------------------------------------------------------------------
   wire launching_out       = out_v_i & out_ready_o ;

   bsg_counter_up_down #( .max_val_p  (max_out_credits_p)
                         ,.init_val_p(max_out_credits_p)
                         ,.max_step_p(1)
                         ) out_credit_ctr
     (.clk_i
      ,.reset_i
      ,.down_i  (launching_out) // launch remote store
      ,.up_i    (returned_credit) // receive credit back
      ,.count_o (out_credits_o)
      );

   assign returned_data_r_o     = returned_packet_lo.data     ;
   assign returned_load_id_r_o  = returned_packet_lo.load_id  ;
   assign returned_v_r_o        = returned_credit_v_lo
                                    & (returned_packet_lo.pkt_type == `ePacketType_data);
   assign returned_yumi_li      = returned_yumi_i 
                                    | (returned_credit_v_lo 
                                        & ~(returned_packet_lo.pkt_type == `ePacketType_data)
                                      );
  // *************************************************
   // ** checks
   //
   // everything below here is only for checking
   //

// synopsys translate_off
   if (debug_p)
   always_ff @(negedge clk_i)
     begin
        if (returned_credit)
          $display("## return packet received by (x,y)=%x,%x",my_x_i,my_y_i);
     end

//   always_ff @(negedge clk_i)
//     if (~reset_i & pkt_unknown & cgni_v)
//       begin
//          $write("## UNKNOWN packet: %b PACKET_WIDTH=%d; (%m)  ",cgni_data,$bits(bsg_manycore_packet_s));
//          `write_bsg_manycore_packet_s(cgni_data);
//          $write("\n");
//	  $finish();
//       end

   if (debug_p)
     always_ff @(negedge clk_i)
       if (out_v_i)
         $display("## attempting remote store send of data %x, ready_i = %x (%m)",out_packet_i,out_ready_o);

//   if (debug_p)
//     always_ff @(negedge clk_i)
//       if (in_v_o & ~freeze_r)
//         $display("## received remote store request of data %x, addr %x, mask %b (%m)",
//                  in_data_o, in_addr_o, in_mask_o);

//   if (debug_p)
//     always_ff @(negedge clk_i)
//       if (cgni_v & ~freeze_r)
//         $display("## data %x avail on cgni (cgni_yumi=%x,in_v=%x, in_addr=%x, in_data=%x, in_yumi=%x) (%m)"
//                  ,cgni_data,cgni_yumi,in_v_o,in_addr_o, in_data_o, in_yumi_i);

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

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);
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

   always_ff @(negedge clk_i) begin
        if( (returned_v_r_o === 1'b1) && ( returned_yumi_i != 1'b1) && returned_fifo_full_o ) begin
                $display("## Returned response will be dropped at YX=%d, %d (%m)", my_y_i, my_x_i);
                $finish();
        end
   end
        // synopsys translate_on

endmodule


