//====================================================================
// mesh_master_example.v
// 04/10/2018, shawnless.xie@gmail.com
//====================================================================
// This module read/write packets into the mesh network
`include "bsg_manycore_packet.vh"

module mesh_master_example #(x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32
                            ,addr_width_p           = 32
                            ,load_id_width_p        = 11
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p, load_id_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                           )
   (  input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    , input   [x_cord_width_p-1:0]                dest_x_i
    , input   [y_cord_width_p-1:0]                dest_y_i

    , output                                      finish_o
    );


    localparam  seq_lenght_lp   = 32;
    ////////////////////////////////////////////////////////////////
    // instantiate the endpoint standard
    ////////////////////////////////////////////////////////////////
    // declare the bsg_manycore_packet sending to the network
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);
    bsg_manycore_packet_s       out_packet_li     ;
    logic                       out_v_li          ;
    logic                       out_ready_lo      ;

    logic                       returned_v_lo     ;
    logic[data_width_p-1:0]     returned_data_lo  ;

    bsg_manycore_endpoint_standard  #(
                              .x_cord_width_p        ( x_cord_width_p    )
                             ,.y_cord_width_p        ( y_cord_width_p    )
                             ,.fifo_els_p            ( 4                 )
                             ,.data_width_p          ( data_width_p      )
                             ,.addr_width_p          ( addr_width_p      )
                             ,.load_id_width_p       ( load_id_width_p   )
                             ,.max_out_credits_p     ( 16                )
                        )endpoint_example

   ( .clk_i
    ,.reset_i

    // mesh network
    ,.link_sif_i
    ,.link_sif_o
    ,.my_x_i
    ,.my_y_i

    // local incoming data interface
    ,.in_v_o     (      )
    ,.in_yumi_i  ( 1'b0 )
    ,.in_data_o  (      )
    ,.in_mask_o  (      )
    ,.in_addr_o  (      )
    ,.in_we_o    (      )
    ,.in_src_x_cord_o(  )
    ,.in_src_y_cord_o(  )

    // The memory read value
    ,.returning_data_i  (   data_width_p'(0))
    ,.returning_v_i     (   1'b0 )

    // local outgoing data interface (does not include credits)
    // Tied up all the outgoing signals
    ,.out_v_i           ( out_v_li     )
    ,.out_packet_i      ( out_packet_li)
    ,.out_ready_o       ( out_ready_lo )
   // local returned data interface
   // Like the memory interface, processor should always ready be to
   // handle the returned data
    ,.returned_data_r_o(  returned_data_lo      )
    ,.returned_v_r_o   (  returned_v_lo         )
    ,.returned_yumi_i  (  returned_v_lo      )
    ,.returned_load_id_r_o( )
    ,.returned_fifo_full_o( )

    ,.out_credits_o     (               )
    );


    ////////////////////////////////////////////////////////////////
    // declare the state machine to control the write/send
    ////////////////////////////////////////////////////////////////

    typedef enum logic[1 :0] { eWriting=2'b00
                             , eReading=2'b01
                             , eWaiting=2'b10
                             , eFinish=2'b11
                             }eStat ;

    eStat                        stat_r, stat_n          ;
    logic  [addr_width_p-1:0]    wait_counter_r          ;
    // declare the address and data regsiter for sending
    logic  [ data_width_p-1:0]          data_r;
    logic  [ addr_width_p-1:0]          addr_r;


    wire addr_overflow = ( addr_r == addr_width_p'(seq_lenght_lp-1) )
                         & out_ready_lo ;
    wire wait_overflow = ( wait_counter_r ==addr_width_p'(seq_lenght_lp-1) )
                         & out_ready_lo ;
    //----------------
    always_comb begin
        case ( stat_r )
                eWriting :  stat_n = addr_overflow    ?  eReading : eWriting;
                eReading :  stat_n = addr_overflow    ?  eWaiting : eReading;
                eWaiting :  stat_n = wait_overflow    ?  eFinish  : eWaiting;
                default  :  stat_n = eFinish;
        endcase
    end

    always_ff@( posedge clk_i) begin
        if( reset_i )  stat_r   <= eWriting;
        else           stat_r   <= stat_n  ;
    end

    assign      finish_o = (stat_r == eFinish);

    ////////////////////////////////////////////////////////////////
    // SEND REQUEST TO THE NETWORK
    ////////////////////////////////////////////////////////////////

    // assign the valid, packet signals
    wire   eOp_n            = (stat_r == eWriting)? `ePacketOp_remote_store
                                                  : `ePacketOp_remote_load   ;
    assign out_v_li         = (stat_r == eWriting) || (stat_r == eReading)   ;
    assign out_packet_li    = '{
                                 addr           :       addr_r
                                ,op             :       eOp_n
                                ,op_ex          :       {(data_width_p>>3){1'b1}}
                                ,payload        :       data_r
                                ,src_y_cord     :       my_y_i
                                ,src_x_cord     :       my_x_i
                                ,y_cord         :       dest_y_i
                                ,x_cord         :       dest_x_i
                                };
     // control the address and data send to the network
     wire   launch_packet    = out_v_li  & out_ready_lo                 ;
     wire   incr_data        = launch_packet & ( stat_r == eWriting)   ;
     wire   incr_addr        = launch_packet                            ;

     always_ff@(posedge clk_i ) begin
        if( reset_i )        data_r <= 'b0           ;
        else if( incr_data)  data_r <=  data_r + 1   ;
     end

     wire [addr_width_p-1:0] addr_n = (stat_r == eWriting)  && (stat_n == eReading)
                                     ? addr_width_p'(0)
                                     : addr_r + 1       ;

     always_ff@(posedge clk_i ) begin
        if( reset_i )                   addr_r <= 'b0           ;
        else if( incr_addr )            addr_r <= addr_n        ;
     end

    ////////////////////////////////////////////////////////////////
    // MONITOR RETURNED PACKET FROM NETWORK
    ////////////////////////////////////////////////////////////////
    always_ff@( posedge clk_i )
        if (reset_i )                   wait_counter_r <= 0               ;
        else if( returned_v_lo )        wait_counter_r <= wait_counter_r+1;

    //synopsys translate_off
    int cycle_counter_r; //start counting when issued the first read reqeust
    always_ff@( posedge clk_i )
        if( reset_i )                   cycle_counter_r <= 0;
        else if ( stat_r == eWriting )  cycle_counter_r <= 0;
        else                            cycle_counter_r <= cycle_counter_r + 1;


    always@( negedge clk_i )
        if( reset_i !== 1'bx  && returned_v_lo )
                $display("cycle %d, returned=%h, expected=%h", cycle_counter_r
                                                             , returned_data_lo
                                                             , wait_counter_r);
    //synopsys translate_on

endmodule
