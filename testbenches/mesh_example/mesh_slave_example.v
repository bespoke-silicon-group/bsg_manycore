//====================================================================
// mesh_slave_example.v
// 04/10/2018, shawnless.xie@gmail.com
//====================================================================
// This module connects a standard memory to the mesh network
`include "bsg_manycore_packet.vh"

module mesh_slave_example #( x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32
                            ,addr_width_p           = 32
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                           )
   (  input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    );


    ////////////////////////////////////////////////////////////////
    // A behavior memory with 1 rw port
    // *_lo signals mean 'local output'

    //valid request
    logic                               in_v_lo                 ;

    logic[data_width_p-1:0]             mem [addr_width_p]      ;
    logic[data_width_p-1:0]             in_data_lo              ;
    logic[addr_width_p-1:0]             in_addr_lo              ;
    logic                               in_we_lo                ;
    // write
    always@( posedge clk_i)
        if( in_we_lo & in_v_lo )
                mem[ in_addr_lo ] <=  in_data_lo;

    // read
    logic[data_width_p-1:0]             read_data_r             ;
    always@( posedge clk_i)
        if( ~in_we_lo & in_v_lo)
                read_data_r <= mem[ in_addr_lo ] ;

    ////////////////////////////////////////////////////////////////
    // instantiate the endpoint standard

    logic                             in_yumi_li        ;
    logic                             returning_v_r     ;
    bsg_manycore_endpoint_standard  #(
                             .x_cord_width_p        ( x_cord_width_p    )
                             .y_cord_width_p        ( y_cord_width_p    )
                             .fifo_els_p            ( 4                 )
                             .data_width_p          ( 32                )
                             .addr_width_p          ( 20                )
                             .max_out_credits_p     ( 16                )
                        )endpoint_example

   ( .clk_i
    ,.reset_i

    // mesh network
    ,.link_sif_i
    ,.link_sif_o
    ,.my_x_i
    ,.my_y_i

    // local incoming data interface
    ,.in_v_o     ( in_v_lo              )
    ,.in_yumi_i  ( in_yumi_li           )
    ,.in_data_o  ( in_data_lo           )
    ,.in_mask_o  ( in_mask_lo           )
    ,.in_addr_o  ( in_addr_lo           )

    // The memory read value
    ,.returning_data_i  ( read_data_r   )
    ,.returning_v_i     ( returning_v_r )

    // local outgoing data interface (does not include credits)
    // Tied up all the outgoing signals
    ,.out_v_i           ( 'b0          )
    ,.out_packet_i      ( 'b0          )
    ,.out_ready_o       ( 'b1          )
   // local returned data interface
   // Like the memory interface, processor should always ready be to
   // handle the returned data
    ,.returned_data_r_o(                )
    ,.returned_v_r_o   (                )


    ,.out_credits_o     (               )
    ,.freeze_r_o        (               )
    ,.reverse_arb_pr_o  (               )
    );

    ////////////////////////////////////////////////////////////////
    // assign the signals to endpoint
    assign  in_yumi_li  =       in_v_lo         //we can always handle the reqeust

    //the returning data is only avaliable when it is a read request
    always_ff@(posedge clk_i)
        if( reset_i ) returning_v_r <= 1'b0;
        else          returning_v_r <= (in_yumi_li & ~in_we_lo);

endmodule
