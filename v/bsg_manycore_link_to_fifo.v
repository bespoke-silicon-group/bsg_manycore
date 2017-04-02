//====================================================================
// bsg_manycore_link_to_fifo.v
// 03/30/2017, shawnless.xie@gmail.com
//====================================================================
// This module acts as a converter that merge the bsg_manycore_link_sif
// of the manycore into a FIFO interface in the same clock domain.
//
// Pleas contact Prof Taylor for the document.
//
`include "bsg_manycore_packet.vh"

module  bsg_manycore_link_to_fifo
  #(  parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    //The output fifo width must be multiple times of data_width_p
    , parameter out_fifo_width_scale_p  = 2
    //multiple channel are merged to increase the output bandwidth
    , parameter in_channel_scale_p      = 2
    , parameter fifo_els_p              = 4

    , parameter bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter link_sif_num_lp     = in_channel_scale_p * out_fifo_width_scale_p
    , parameter out_fifo_width_lp   = data_width_p       * out_fifo_width_scale_p
    , parameter debug_lp            = 0
    )
  (

     input clk_i
   , input reset_i

   , input  [link_sif_num_lp-1:0]  [x_cord_width_p-1:0]     my_x_i
   , input  [link_sif_num_lp-1:0]  [y_cord_width_p-1:0]     my_y_i

   //input from the manycore, in the same clock domain with the FIFO
   , input  [link_sif_num_lp-1:0] [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
   , output [link_sif_num_lp-1:0] [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

   //FIFO output
   , output                             v_o
   , output [out_fifo_width_lp-1:0]     data_o
   , input                              ready_i
   );

   //local parameter definition
    localparam max_out_credits_lp =200;
    localparam packet_width_lp    = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  ///////////////////////////////////////////////////////////////////////////////////
  // instantiate the endpoint
  logic [link_sif_num_lp-1:0]                               endpoint_v    ;
  logic [link_sif_num_lp-1:0]                               endpoint_yumi ;
  logic [link_sif_num_lp-1:0] [data_width_p-1:0]            endpoint_data ;
  logic [link_sif_num_lp-1:0] [(data_width_p>>3)-1:0]       endpoint_mask ;
  logic [link_sif_num_lp-1:0] [addr_width_p-1:0]            endpoint_addr ;

  genvar i;

  for( i = 0; i < link_sif_num_lp ; i ++ ) begin : out_fifo_endpoint_gen
      bsg_manycore_endpoint_standard #(
         .x_cord_width_p     ( x_cord_width_p )
        ,.y_cord_width_p     ( y_cord_width_p )
        ,.fifo_els_p         ( fifo_els_p     )
        ,.data_width_p       ( data_width_p   )
        ,.addr_width_p       ( addr_width_p   )
        ,.max_out_credits_p  ( max_out_credits_lp)
      )out_fifo_endpoint_standard
       (
         .clk_i         ( clk_i     )
        ,.reset_i       ( reset_i   )

        // mesh network
        ,.link_sif_i    ( link_sif_i [ i ] )
        ,.link_sif_o    ( link_sif_o [ i ] )

        // local incoming data interface
        ,.in_v_o        ( endpoint_v    [ i ]   )
        ,.in_yumi_i     ( endpoint_yumi [ i ]   )
        ,.in_data_o     ( endpoint_data [ i ]   )
        ,.in_mask_o     ( endpoint_mask [ i ]   )
        ,.in_addr_o     ( endpoint_addr [ i ]   )

        // local outgoing data interface (does not include credits)
        ,.out_v_i       ( 1'b0                          )
        ,.out_packet_i  ( { packet_width_lp { 1'b0 } }  )
        ,.out_ready_o   (                               )

        // whether a credit was returned; not flow controlled
        ,.out_credits_o (                       )
        ,.freeze_r_o    (                       )
        ,.reverse_arb_pr_o(                     )

        ,.my_x_i        ( my_x_i [ i ]          )
        ,.my_y_i        ( my_y_i [ i ]          )
        );
  end
  ///////////////////////////////////////////////////////////////////////////////////
  // the relay node between asyncFIFO and merger

  //input side signal
  logic [link_sif_num_lp-1:0]                               endpoint_ready    ;

  //output side signal
  logic [link_sif_num_lp-1:0]                               endpoint_relayed_v    ;
  logic [link_sif_num_lp-1:0]                               endpoint_relayed_ready;
  logic [link_sif_num_lp-1:0] [data_width_p-1:0]            endpoint_relayed_data ;

  for( i=0; i < link_sif_num_lp ; i++ ) begin : endpoint_relay_gen
     bsg_relay_fifo# ( .width_p( data_width_p )) endpoint_relay_inst (
        .clk_i      ( clk_i                 )
       ,.reset_i    ( reset_i               )
       //input side
       ,.ready_o    ( endpoint_ready        [ i ]  )
       ,.data_i     ( endpoint_data         [ i ]  )
       ,.v_i        ( endpoint_v            [ i ]  )

       //output side
       ,.v_o        ( endpoint_relayed_v    [ i ]  )
       ,.data_o     ( endpoint_relayed_data [ i ]  )
       ,.ready_i    ( endpoint_relayed_ready[ i ]  )
     );

    assign endpoint_yumi[ i ] = endpoint_ready[ i ] & endpoint_v[ i ] ;
  end

  ///////////////////////////////////////////////////////////////////////////////////
  //merge the data into the FIFO bitwidth
  logic [in_channel_scale_p-1:0]                               merged_v    ;
  logic [in_channel_scale_p-1:0]                               merged_ready;
  logic [in_channel_scale_p-1:0] [out_fifo_width_lp-1:0]       merged_data ;

  genvar j;
  for( i = 0; i < in_channel_scale_p ; i ++ ) begin : merge_bitwidth
    assign merged_v[ i ] = &  endpoint_relayed_v  [ i*out_fifo_width_scale_p
                                                +:    out_fifo_width_scale_p ];

    for( j=0; j < out_fifo_width_scale_p ; j++) begin : merge_data_j
        assign merged_data[ i ] [ j*data_width_p  +:   data_width_p ]
             = endpoint_relayed_data[ i * out_fifo_width_scale_p + j ];
    end

    //TODO: is this OK ?
    wire tmp_ready = merged_ready[ i ] & merged_v[ i ] ;
    assign endpoint_relayed_ready[ i*out_fifo_width_scale_p
                                 +:  out_fifo_width_scale_p ] = { out_fifo_width_scale_p { tmp_ready } };


  end

  ///////////////////////////////////////////////////////////////////////////////////
  // the relay node between merger and round-robin selecter

  //output side signal
  logic [in_channel_scale_p-1:0]                               merged_relayed_v    ;
  logic [in_channel_scale_p-1:0]                               merged_relayed_yumi ;
  logic [in_channel_scale_p-1:0] [out_fifo_width_lp-1:0]       merged_relayed_data ;

  for( i=0; i < in_channel_scale_p ; i++ ) begin : merged_relay_gen
     bsg_two_fifo# ( .width_p( out_fifo_width_lp )) merged_relay_inst (
        .clk_i      ( clk_i                 )
       ,.reset_i    ( reset_i               )

       //input side
       ,.ready_o    ( merged_ready        [ i ] )
       ,.data_i     ( merged_data         [ i ] )
       ,.v_i        ( merged_v            [ i ] )

       //output side
       ,.v_o        ( merged_relayed_v    [ i ] )
       ,.data_o     ( merged_relayed_data [ i ] )
       ,.yumi_i     ( merged_relayed_yumi [ i ] )
     );
  end

  ///////////////////////////////////////////////////////////////////////////////////
  //round robin the multi-channnel input
  logic                                                        rr_v               ;
  logic [out_fifo_width_lp-1 :0]                               rr_data            ;
  logic                                                        rr_yumi            ;

  bsg_round_robin_n_to_1 #(
       .width_p         ( out_fifo_width_lp )
      ,.num_in_p        ( in_channel_scale_p)
      ,.strict_p        ( 1'b1              )
   ) outfifo_rr
   (  .clk_i    ( clk_i     )
    , .reset_i  ( reset_i   )

    // to fifos
    , .data_i   ( merged_relayed_data   )
    , .v_i      ( merged_relayed_v      )
    , .yumi_o   ( merged_relayed_yumi   )

    // to downstream
    , .v_o      ( rr_v           )
    , .data_o   ( rr_data        )
    , .tag_o    (                )
    , .yumi_i   ( rr_yumi        )
    );

  ///////////////////////////////////////////////////////////////////////////////////
  // the relay node after round-robin selecter
  wire   rr_ready;
  bsg_relay_fifo# ( .width_p( out_fifo_width_lp )) rr_relay_inst (
     .clk_i      ( clk_i                 )
    ,.reset_i    ( reset_i               )

    //input side
    ,.ready_o    ( rr_ready        )
    ,.data_i     ( rr_data         )
    ,.v_i        ( rr_v            )

    //output side
    ,.v_o        ( v_o    )
    ,.data_o     ( data_o )
    ,.ready_i    ( ready_i)
  );
 assign rr_yumi = rr_v & rr_ready ;

endmodule

