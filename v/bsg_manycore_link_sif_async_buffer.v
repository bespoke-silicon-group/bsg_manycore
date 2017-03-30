//====================================================================
// bsg_manycore_link_sif_async_buffer.v
// 02/15/2017, shawnless.xie@gmail.com
//====================================================================
//
//This module converts the bsg_manycore_link_sif signals between different 
//clock domains.

module bsg_manycore_link_sif_async_buffer 
   #(   addr_width_p  = 32
      , data_width_p  = 32
      , x_cord_width_p = "inv"
      , y_cord_width_p = "inv"
      , fifo_els_p    = 2
      , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
    )(
    //the left side signal 
    input                                       L_clk_i
   ,input                                       L_reset_i
   ,input  [bsg_manycore_link_sif_width_lp-1:0] L_link_sif_i
   ,output [bsg_manycore_link_sif_width_lp-1:0] L_link_sif_o
    //the right side signal
   ,input                                       R_clk_i
   ,input                                       R_reset_i
   ,input  [bsg_manycore_link_sif_width_lp-1:0] R_link_sif_i
   ,output [bsg_manycore_link_sif_width_lp-1:0] R_link_sif_o
   ); 
   ////////////////////////////////////////////////////////////////////////////////////////
   // Declear the cast structures. 
   localparam return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p, 
                                                                         y_cord_width_p);

   localparam packet_width_lp        = `bsg_manycore_packet_width       (addr_width_p,
                                                                         data_width_p,
                                                                         x_cord_width_p,
                                                                         y_cord_width_p);
   localparam fifo_lg_size_lp        = `BSG_SAFE_CLOG2( fifo_els_p );

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_link_sif_s L_link_sif_i_cast,  L_link_sif_o_cast ;
   bsg_manycore_link_sif_s R_link_sif_i_cast,  R_link_sif_o_cast;

   assign L_link_sif_i_cast     = L_link_sif_i;
   assign L_link_sif_o          = L_link_sif_o_cast;
   assign R_link_sif_i_cast     = R_link_sif_i;
   assign R_link_sif_o          = R_link_sif_o_cast;

   ////////////////////////////////////////////////////////////////////////////////////////
   // Covert left to right forwarding signals 
   wire                         l2r_fwd_w_enq   ;
   wire [packet_width_lp-1:0]   l2r_fwd_w_data  ;
   wire                         l2r_fwd_w_full  ;

   wire                         l2r_fwd_r_deq   ;
   wire [packet_width_lp-1:0]   l2r_fwd_r_data  ;
   wire                         l2r_fwd_r_valid ;
    bsg_async_fifo #(.lg_size_p  ( fifo_lg_size_lp )
                    ,.width_p    ( packet_width_lp ) 
                    )left2right_fwd
   (
     .w_clk_i   ( L_clk_i    )
    ,.w_reset_i ( L_reset_i  )
    // not legal to w_enq_i if w_full_o is not low.
    ,.w_enq_i   ( l2r_fwd_w_enq   )
    ,.w_data_i  ( l2r_fwd_w_data  )
    ,.w_full_o  ( l2r_fwd_w_full  )

    // not legal to r_deq_i if r_valid_o is not high.
    ,.r_clk_i   ( R_clk_i     )
    ,.r_reset_i ( R_reset_i   )
    ,.r_deq_i   ( l2r_fwd_r_deq   )
    ,.r_data_o  ( l2r_fwd_r_data  )
    ,.r_valid_o ( l2r_fwd_r_valid )
    );

    assign l2r_fwd_w_enq    =  (~ l2r_fwd_w_full ) & L_link_sif_i_cast.fwd.v     ;
    assign l2r_fwd_w_data   =                        L_link_sif_i_cast.fwd.data  ;
    assign L_link_sif_o_cast.fwd.ready_and_rev = ~l2r_fwd_w_full                 ;

    assign l2r_fwd_r_deq    =  l2r_fwd_r_valid     & R_link_sif_i_cast.fwd.ready_and_rev;
    assign R_link_sif_o_cast.fwd.v            = l2r_fwd_r_valid                 ;
    assign R_link_sif_o_cast.fwd.data         = l2r_fwd_r_data                  ;
   ////////////////////////////////////////////////////////////////////////////////////////
   // Covert right to left reverse  signals 
   wire                                 r2l_rev_w_enq   ;
   wire [return_packet_width_lp-1:0]    r2l_rev_w_data  ;
   wire                                 r2l_rev_w_full  ;

   wire                                 r2l_rev_r_deq   ;
   wire [return_packet_width_lp-1:0]    r2l_rev_r_data  ;
   wire                                 r2l_rev_r_valid ;
    bsg_async_fifo #(.lg_size_p  ( fifo_lg_size_lp          )
                    ,.width_p    ( return_packet_width_lp   )
                    )right2left_rev
   (
     .w_clk_i   ( R_clk_i    )
    ,.w_reset_i ( R_reset_i  )
    // not legal to w_enq_i if w_full_o is not low.
    ,.w_enq_i   ( r2l_rev_w_enq  )
    ,.w_data_i  ( r2l_rev_w_data )
    ,.w_full_o  ( r2l_rev_w_full )

    // not legal to r_deq_i if r_valid_o is not high.
    ,.r_clk_i   ( L_clk_i     )
    ,.r_reset_i ( L_reset_i   )
    ,.r_deq_i   ( r2l_rev_r_deq  )
    ,.r_data_o  ( r2l_rev_r_data )
    ,.r_valid_o ( r2l_rev_r_valid)
    );

    assign r2l_rev_w_enq    =  (~ r2l_rev_w_full ) & R_link_sif_i_cast.rev.v     ;
    assign r2l_rev_w_data   =                        R_link_sif_i_cast.rev.data  ;
    assign R_link_sif_o_cast.rev.ready_and_rev = ~r2l_rev_w_full                 ;

    assign r2l_rev_r_deq    =  r2l_rev_r_valid     & L_link_sif_i_cast.rev.ready_and_rev;
    assign L_link_sif_o_cast.rev.v            = r2l_rev_r_valid                 ;
    assign L_link_sif_o_cast.rev.data         = r2l_rev_r_data                  ;

   ////////////////////////////////////////////////////////////////////////////////////////
   // Covert left to right reverse signals 
   wire                                 l2r_rev_w_enq   ;
   wire [return_packet_width_lp-1:0]    l2r_rev_w_data  ;
   wire                                 l2r_rev_w_full  ;

   wire                                 l2r_rev_r_deq   ;
   wire [return_packet_width_lp-1:0]    l2r_rev_r_data  ;
   wire                                 l2r_rev_r_valid ;
    bsg_async_fifo #(.lg_size_p  ( fifo_lg_size_lp )
                    ,.width_p    ( return_packet_width_lp ) 
                    )left2right_rev
   (
     .w_clk_i   ( L_clk_i    )
    ,.w_reset_i ( L_reset_i  )
    // not legal to w_enq_i if w_full_o is not low.
    ,.w_enq_i   ( l2r_rev_w_enq   )
    ,.w_data_i  ( l2r_rev_w_data  )
    ,.w_full_o  ( l2r_rev_w_full  )

    // not legal to r_deq_i if r_valid_o is not high.
    ,.r_clk_i   ( R_clk_i     )
    ,.r_reset_i ( R_reset_i   )
    ,.r_deq_i   ( l2r_rev_r_deq   )
    ,.r_data_o  ( l2r_rev_r_data  )
    ,.r_valid_o ( l2r_rev_r_valid )
    );

    assign l2r_rev_w_enq    =  (~ l2r_rev_w_full ) & L_link_sif_i_cast.rev.v     ;
    assign l2r_rev_w_data   =                        L_link_sif_i_cast.rev.data  ;
    assign L_link_sif_o_cast.rev.ready_and_rev = ~l2r_rev_w_full                 ;

    assign l2r_rev_r_deq    =  l2r_rev_r_valid     & R_link_sif_i_cast.rev.ready_and_rev;
    assign R_link_sif_o_cast.rev.v            = l2r_rev_r_valid                 ;
    assign R_link_sif_o_cast.rev.data         = l2r_rev_r_data                  ;

   ////////////////////////////////////////////////////////////////////////////////////////
   // Covert right to left forward  signals 
   wire                                 r2l_fwd_w_enq   ;
   wire [packet_width_lp-1:0]           r2l_fwd_w_data  ;
   wire                                 r2l_fwd_w_full  ;

   wire                                 r2l_fwd_r_deq   ;
   wire [packet_width_lp-1:0]           r2l_fwd_r_data  ;
   wire                                 r2l_fwd_r_valid ;
    bsg_async_fifo #(.lg_size_p  ( fifo_lg_size_lp          )
                    ,.width_p    ( packet_width_lp          )
                    )right2left_fwd
   (
     .w_clk_i   ( R_clk_i    )
    ,.w_reset_i ( R_reset_i  )
    // not legal to w_enq_i if w_full_o is not low.
    ,.w_enq_i   ( r2l_fwd_w_enq  )
    ,.w_data_i  ( r2l_fwd_w_data )
    ,.w_full_o  ( r2l_fwd_w_full )

    // not legal to r_deq_i if r_valid_o is not high.
    ,.r_clk_i   ( L_clk_i     )
    ,.r_reset_i ( L_reset_i   )
    ,.r_deq_i   ( r2l_fwd_r_deq  )
    ,.r_data_o  ( r2l_fwd_r_data )
    ,.r_valid_o ( r2l_fwd_r_valid)
    );

    assign r2l_fwd_w_enq    =  (~ r2l_fwd_w_full ) & R_link_sif_i_cast.fwd.v     ;
    assign r2l_fwd_w_data   =                        R_link_sif_i_cast.fwd.data  ;
    assign R_link_sif_o_cast.fwd.ready_and_rev = ~r2l_fwd_w_full                 ;

    assign r2l_fwd_r_deq    =  r2l_fwd_r_valid     & L_link_sif_i_cast.fwd.ready_and_rev;
    assign L_link_sif_o_cast.fwd.v            = r2l_fwd_r_valid                 ;
    assign L_link_sif_o_cast.fwd.data         = r2l_fwd_r_data                  ;
endmodule
