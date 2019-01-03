//====================================================================
// bsg_manycore_ram_model.v
// 11/14/2018, shawnless.xie@gmail.com
//====================================================================
// This module serves a generic 1rw ram module that can connect to bsg_manycore
// directly.
`include "bsg_manycore_packet.vh"

module bsg_manycore_ram_model#( x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32

                            ,addr_width_p           = 26 
                            ,load_id_width_p        = 5
                            ,els_p                  = 1024 //els_p must <= 2**addr_width_p
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p,load_id_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
                           )
   (  input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    );

    localparam  mem_addr_width_lp = $clog2(els_p);
    ////////////////////////////////////////////////////////////////
    // instantiate the endpoint standard

    logic                             in_yumi_li        ;
    logic                             returning_v_r     ;
    logic[data_width_p-1:0]           read_data_r       ;

    logic                               in_v_lo                 ;
    logic[data_width_p-1:0]             in_data_lo              ;
    logic[((data_width_p)>>3)-1:0]      in_mask_lo              ;
    logic[addr_width_p-1:0]             in_addr_lo              ;
    logic                               in_we_lo                ;
    bsg_manycore_endpoint_standard  #(
                              .x_cord_width_p        ( x_cord_width_p    )
                             ,.y_cord_width_p        ( y_cord_width_p    )
                             ,.fifo_els_p            ( 4                 )
                             ,.data_width_p          ( data_width_p      )
                             ,.addr_width_p          ( addr_width_p      )
                             ,.load_id_width_p       ( load_id_width_p   )
                             ,.max_out_credits_p     ( 16                )
                        )ram_endpoint

   ( .clk_i
    ,.reset_i

    // mesh network
    ,.link_sif_i
    ,.link_sif_o
    ,.my_x_i
    ,.my_y_i

    // local incoming data interface
    ,.in_v_o         ( in_v_lo              )
    ,.in_yumi_i      ( in_yumi_li           )
    ,.in_data_o      ( in_data_lo           )
    ,.in_mask_o      ( in_mask_lo           ) 
    ,.in_addr_o      ( in_addr_lo           )
    ,.in_we_o        ( in_we_lo             )
    ,.in_src_x_cord_o(                      )
    ,.in_src_y_cord_o(                      )

    // The memory read value
    ,.returning_data_i  ( read_data_r   )
    ,.returning_v_i     ( returning_v_r )

    // local outgoing data interface (does not include credits)
    // Tied up all the outgoing signals
    ,.out_v_i           ( 1'b0                          )
    ,.out_packet_i      ( packet_width_lp'(0)           )
    ,.out_ready_o       (                               )
   // local returned data interface
   // Like the memory interface, processor should always ready be to
   // handle the returned data
    ,.returned_data_r_o     (                )
    ,.returned_load_id_r_o  (                )
    ,.returned_v_r_o        (                )

    ,.out_credits_o     (               )
    );


    bsg_mem_1rw_sync_mask_write_byte #( .els_p          (   els_p               )
                                       ,.data_width_p   (   data_width_p        )
                                      )mem
    ( .clk_i
     ,.reset_i

     ,.v_i                (in_v_lo        )
     ,.w_i                (in_we_lo       )

     ,.addr_i             (in_addr_lo[0+:mem_addr_width_lp] )
     ,.data_i             (in_data_lo     )
     ,.write_mask_i       (in_mask_lo     )

     ,.data_o             (read_data_r    )
    );
    ////////////////////////////////////////////////////////////////
    // assign the signals to endpoint
    assign  in_yumi_li  =       in_v_lo   ;     //we can always handle the reqeust

    always_ff@(posedge clk_i)
        if( reset_i ) returning_v_r <= 1'b0;
        else          returning_v_r <= in_yumi_li;
        
    //synopsys translate_off
    always_ff@(negedge clk_i) begin
        if( | in_addr_lo[addr_width_p-1: mem_addr_width_lp] ) begin
                $error("Address exceed the memory range: in_addr =%h (words), mem range:%x, %m", in_addr_lo, els_p);
                $finish();
        end
    end
    //synopsys translate_on
endmodule
