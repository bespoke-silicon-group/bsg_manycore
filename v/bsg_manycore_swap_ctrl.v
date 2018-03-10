//====================================================================
// bsg_manycore_swap_ctrl.v
// 03/03/2018, shawnless.xie@gmail.com
//====================================================================
// This module implements compare-and-swap control.
//
// 1. incoming request
//      [local mem]   <=  [ swap_ctrl ] <=  endpoint_standard
//
// 2. returning data
//      [local mem]   =>  [ swap_ctrl ] =>  endpoint_standard

module bsg_manycore_swap_ctrl         #(  data_width_p           = 32
                                         ,addr_width_p           = 32
                                         ,x_cord_width_p         = "inv"
                                         ,y_cord_width_p         = "inv"
                                         ,debug_p                = 0
                                         )
   (  input clk_i
    , input reset_i

    // local endpoint incoming data interface
    , input                         in_v_i
    , output                        in_yumi_o
    , input [data_width_p-1:0]      in_data_i
    , input [(data_width_p>>3)-1:0] in_mask_i
    , input [addr_width_p-1:0]      in_addr_i
    , input                         in_we_i

    , input                         in_swap_aq_i
    , input                         in_swap_rl_i
    , input [x_cord_width_p-1:0]    in_x_cord_i
    , input [y_cord_width_p-1:0]    in_y_cord_i

    // combined  incoming data interface
    , output                         comb_v_o
    , input                          comb_yumi_i
    , output [data_width_p-1:0]      comb_data_o
    , output [(data_width_p>>3)-1:0] comb_mask_o
    , output [addr_width_p-1:0]      comb_addr_o
    , output                         comb_we_o

    // The memory read value
    , input [data_width_p-1:0]       returning_data_i
    , input                          returning_v_i

    // The output read value
    , output [data_width_p-1:0]      comb_returning_data_o
    , output                         comb_returning_v_o


    );

    //-------------------------------------------------------------------------
    //  The interal registered data
    //-------------------------------------------------------------------------
    enum logic [1:0] {SWAP_IDLE, SWAP_LOADING, SWAP_STORING} swap_stat_r, swap_stat_n;

    logic [data_width_p-1:0]        swap_data_r;
    logic [addr_width_p-1:0]        swap_addr_r;
    logic [(data_width_p>>3)-1:0]   swap_mask_r;
    logic                           swap_lock_r;
    logic [x_cord_width_p-1:0]      swap_x_cord_r;
    logic [y_cord_width_p-1:0]      swap_y_cord_r;

    // signals for aq
    wire swap_aq_success =  in_v_i & in_swap_aq_i & comb_yumi_i
                          & (~swap_lock_r) & (swap_stat_r == SWAP_IDLE)  ;

    //on fail, will return immediately
    wire swap_aq_fail    =  in_v_i & in_swap_aq_i & swap_lock_r
                          & ( swap_stat_r == SWAP_IDLE );

    wire swap_aq_yumi    = swap_aq_success | swap_aq_fail    ;

    // signals for rl
    wire swap_match = ( swap_addr_r   == in_addr_i )
                     &( swap_x_cord_r == in_x_cord_i)
                     &( swap_y_cord_r == in_y_cord_i);

    wire swap_rl_success = in_v_i & in_swap_rl_i & comb_yumi_i
                          &( swap_lock_r & swap_match)
                          &( swap_stat_r == SWAP_IDLE)  ;

    //on fail, will return immediately
    wire swap_rl_fail    = in_v_i & in_swap_rl_i
                          & (~swap_lock_r  | (swap_lock_r & ~swap_match) )
                          & ( swap_stat_r == SWAP_IDLE );

    wire swap_rl_yumi    = swap_rl_success | swap_rl_fail;

    wire swap_yumi       = swap_aq_yumi | swap_rl_yumi            ;

    wire swap_success = swap_aq_success | swap_rl_success;

    always_ff@(posedge clk_i)
        if ( swap_success) begin
            swap_data_r     <=   in_data_i      ;
            swap_addr_r     <=   in_addr_i      ;
            swap_x_cord_r   <=   in_x_cord_i    ;
            swap_y_cord_r   <=   in_y_cord_i    ;
            swap_mask_r     <=   in_mask_i      ;
        end

    always_ff@(posedge clk_i)
        if ( reset_i)                       swap_lock_r <=   1'b0     ;
        else if (swap_aq_success )          swap_lock_r <=   1'b1     ;
        else if (swap_rl_success )          swap_lock_r <=   1'b0     ;

    //-------------------------------------------------------------------------
    //  State Machine
    //-------------------------------------------------------------------------

    always_ff@(posedge clk_i )
        if( reset_i )   swap_stat_r <= SWAP_IDLE  ;
        else            swap_stat_r <= swap_stat_n;

    always_comb begin
        case (swap_stat_r)
            SWAP_IDLE:
                if ( swap_success )                     swap_stat_n = SWAP_STORING;
                else                                    swap_stat_n = SWAP_IDLE   ;
            SWAP_STORING:
                if ( comb_yumi_i   )                    swap_stat_n = SWAP_IDLE   ;
                else                                    swap_stat_n = SWAP_STORING;
            default:
                                                        swap_stat_n = SWAP_IDLE   ;
        endcase
    end

    wire swap_store_req  =    swap_stat_r  == SWAP_STORING;
    wire swap_working    =    swap_stat_r  != SWAP_IDLE   ;

    //-------------------------------------------------------------------------
    //  The output signals
    //-------------------------------------------------------------------------

    //yumi signal to endpoint
    wire   swap_req     = in_swap_aq_i | in_swap_rl_i         ;
    //we should not present the normal reqeust if the swap is working
    wire   normal_yumi  = in_v_i & (~ swap_req )  //normal reqeust
                         &(~swap_working)         //swap is not working
                         &comb_yumi_i         ;   //memory is not busy

    assign in_yumi_o = swap_yumi | normal_yumi;

    //To local memory
    wire   swap_failing              =  swap_aq_fail  | swap_rl_fail    ;
    //NOTE: comb_v_o =1 when  SWAP_IDLE -> SWAP_LOADING, which is the load
    //      request
    assign comb_v_o     =   swap_working ?  swap_store_req :
                            swap_failing ?  1'b0
                                         :  in_v_i ;

    assign comb_data_o  =   swap_store_req  ?  swap_data_r
                                            :  in_data_i ;

    assign comb_mask_o  =   swap_working    ?  swap_mask_r
                                            :  in_mask_i ;

    assign comb_addr_o  =   swap_working    ?  swap_addr_r
                                            :  in_addr_i ;

    assign comb_we_o    =   swap_store_req  ? 1'b1 : in_we_i ;

    //returning data to endpoint
    logic                     swap_failing_r        ;
    logic [data_width_p-1:0]  swap_failing_data_r   ;

    always_ff@( posedge clk_i) begin
        swap_failing_r      <= swap_failing ;
        swap_failing_data_r <= in_data_i    ;
    end

    assign comb_returning_v_o       = swap_failing_r ?  1'b1
                                                     : returning_v_i ;

    assign comb_returning_data_o    = swap_failing_r ?  swap_failing_data_r
                                                     : returning_data_i ;

    //-------------------------------------------------------------------------
    // assertion and diagnosis
    //-------------------------------------------------------------------------
    //synopsys translate_off
    if(debug_p) begin
        always_ff@(negedge clk_i ) begin
            if( swap_aq_success ) $display("##  addr=%h : (y,x)=(%d, %d) aquire success   %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i,$time );
            if( swap_aq_fail    ) $display("##  addr=%h : (y,x)=(%d, %d) aquire fail      %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i,$time );
            if( swap_rl_success ) $display("##  addr=%h : (y,x)=(%d, %d) release success  %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i,$time );
            if( swap_rl_fail    ) $display("##  addr=%h : (y,x)=(%d, %d) release fail     %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i,$time );
        end
    end
    //synopsys translate_on
endmodule
