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
   , input                              yumi_i
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
  //merge the data into the FIFO bitwidth 
  logic [in_channel_scale_p-1:0]                               merged_v    ;
  logic [in_channel_scale_p-1:0]                               merged_yumi ;
  logic [in_channel_scale_p-1:0] [out_fifo_width_lp-1:0]       merged_data ;

  genvar j;
  for( i = 0; i < in_channel_scale_p ; i ++ ) begin : merge_bitwidth
    assign merged_v [i] = & endpoint_v[ i*out_fifo_width_scale_p  +:  out_fifo_width_scale_p ];  
    assign endpoint_yumi [ i*out_fifo_width_scale_p  +:  out_fifo_width_scale_p ] 
             = { out_fifo_width_scale_p { merged_yumi[ i ] } };

    for( j=0; j < out_fifo_width_scale_p ; j++) begin : merge_data_j
        assign merged_data [ i ] [ j*data_width_p +: data_width_p ] = endpoint_data[ i * j ];

    end
  end

  ///////////////////////////////////////////////////////////////////////////////////
  //round robin the multi-channnel input
  bsg_round_robin_n_to_1 #(
       .width_p         ( out_fifo_width_lp ) 
      ,.num_in_p        ( in_channel_scale_p) 
      ,.strict_p        ( 1'b1              ) 
   ) outfifo_rr 
   (  .clk_i    ( clk_i     )
    , .reset_i  ( reset_i   )

    // to fifos
    , .data_i   ( merged_data   )
    , .v_i      ( merged_v      )
    , .yumi_o   ( merged_yumi   )

    // to downstream
    , .v_o      ( v_o           ) 
    , .data_o   ( data_o        )
    , .tag_o    (               )
    , .yumi_i   ( yumi_i        )
    );

endmodule

