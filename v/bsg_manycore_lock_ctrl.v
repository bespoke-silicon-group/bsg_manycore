//====================================================================
// bsg_manycore_lock_ctrl.v
// 03/02/2019, shawnless.xie@gmail.com
//====================================================================
// This module implements the lock command, which reuses the swap.aq 
// and swap.rl RISC-V instruction pairs to implement the mutex primitive
//
//--------------------------------------------------------------------
// mutex lock : swap.aq rd, x0, addr
//              Treated as a load instruction, but will lock the 
//              corresponding addr. The returned results indicats
//              if the lock successful.
//                      return 0  :   success
//                      return 1  :   fail
//
// mutex unlock: swap.rl x0, x0, addr
//              Treated as a store instruction, but will unlock the 
//              corresponding addr. No return result, should be always  
//              successful.
//
// lock effect:
//              The locked address is just being tagged without any other
//              side affect, the general load/store operation can be used 
//              for the locked address.
//
// restrictions:
//              Only one lock avaliable for each endpoint, so we can not
//              nest or interleave multiple lock/unlock pairs for the same
//              nodes. 
//--------------------------------------------------------------------
// This module will trap any lock related result, and forwarding any 
// other signals. 
//
// 1. incoming request
//      [local mem]   <=  [ lock_ctrl ] <=  endpoint_standard
//
// 2. returning data
//      [local mem]   =>  [ lock_ctrl ] =>  endpoint_standard

module bsg_manycore_lock_ctrl         #(  data_width_p           = 32
                                         ,addr_width_p           = 32
                                         ,x_cord_width_p         = "inv"
                                         ,y_cord_width_p         = "inv"
                                         ,max_out_credits_p      = 200
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
    , output [x_cord_width_p-1:0]    comb_x_cord_o
    , output [y_cord_width_p-1:0]    comb_y_cord_o

    // The memory read value
    , input [data_width_p-1:0]       returning_data_i
    , input                          returning_v_i

    // The output read value
    , output [data_width_p-1:0]      comb_returning_data_o
    , output                         comb_returning_v_o


    );

    localparam  lock_success_lp=1'b0;
    localparam  lock_fail_lp   =1'b1;

    //-------------------------------------------------------------------------
    //  The interal registered data
    //-------------------------------------------------------------------------
    logic [addr_width_p-1:0]        swap_addr_r;
    logic                           swap_lock_r;
    logic [x_cord_width_p-1:0]      swap_x_cord_r;
    logic [y_cord_width_p-1:0]      swap_y_cord_r;

    wire node_is_idle;
    wire swap_aq_yumi    =  in_v_i & in_swap_aq_i & node_is_idle ;
    wire swap_aq_success =  swap_aq_yumi &  (~swap_lock_r); 
    wire swap_aq_fail    =  swap_aq_yumi &    swap_lock_r ; 

    // signals for rl
    wire swap_match = ( swap_addr_r   == in_addr_i )
                     &( swap_x_cord_r == in_x_cord_i)
                     &( swap_y_cord_r == in_y_cord_i);

    wire swap_rl_yumi    = in_v_i & in_swap_rl_i & node_is_idle;
    wire swap_rl_success = swap_rl_yumi ;

    always_ff@(posedge clk_i)
        if ( reset_i)                       swap_lock_r <=   1'b0     ;
        else if (swap_aq_success ) begin
                swap_lock_r <=   1'b1     ;
                swap_addr_r     <=   in_addr_i      ;
                swap_x_cord_r   <=   in_x_cord_i    ;
                swap_y_cord_r   <=   in_y_cord_i    ;
        end else if (swap_rl_success ) begin
                swap_lock_r <=   1'b0     ;
                swap_addr_r     <=   'b0  ;
                swap_x_cord_r   <=   'b0  ;
                swap_y_cord_r   <=   'b0  ;
        end
    //-------------------------------------------------------------------------
    //  The output signals
    //-------------------------------------------------------------------------

    //yumi signal to endpoint
    assign in_yumi_o = swap_aq_yumi | swap_rl_yumi | comb_yumi_i; 

    //To local memory
    assign comb_v_o       =   in_v_i & (~ (in_swap_aq_i | in_swap_rl_i) ) ;

    assign comb_data_o    =   in_data_i   ;

    assign comb_mask_o    =   in_mask_i   ;

    assign comb_addr_o    =   in_addr_i   ;

    assign comb_x_cord_o  =   in_x_cord_i ;

    assign comb_y_cord_o  =   in_y_cord_i ;

    assign comb_we_o      =   in_we_i     ;

    //returning data to endpoint
    logic                     swap_result_v_r, swap_aq_result_r;
    always_ff@( posedge clk_i) begin
        if( reset_i ) begin
                swap_result_v_r  <= 1'b0;
                swap_aq_result_r <= 1'b0;
        end else begin
                swap_result_v_r  <= (swap_aq_yumi | swap_rl_yumi );
                swap_aq_result_r <=  swap_aq_success ? lock_success_lp : lock_fail_lp;
        end
    end

    assign comb_returning_v_o       = swap_result_v_r | returning_v_i ;

    assign comb_returning_data_o    = swap_result_v_r ? swap_aq_result_r
                                                      : returning_data_i;

    //-------------------------------------------------------------------------
    // the counter to track how many request pending in the node
    //-------------------------------------------------------------------------
    wire[$clog2(max_out_credits_p+1)-1:0] request_num_in_node_lo;
    bsg_counter_up_down #( .max_val_p(max_out_credits_p)
                         ,.init_val_p(max_out_credits_p)
                         ,.max_step_p(1)
                         ) out_credit_ctr
     (.clk_i
      ,.reset_i
      ,.down_i  (comb_yumi_i   ) // launch remote store
      ,.up_i    (returning_v_i ) // receive credit back
      ,.count_o (request_num_in_node_lo )
      );
    assign node_is_idle = request_num_in_node_lo == max_out_credits_p; 
    //-------------------------------------------------------------------------
    // assertion and diagnosis
    //-------------------------------------------------------------------------
    //synopsys translate_off
    if(debug_p) begin
        always_ff@(negedge clk_i ) begin
            if( swap_aq_success ) $display("##  addr=%h : (y,x)=(%d, %d) aquire success,input value=%h,   %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i, in_data_i, $time );
            if( swap_aq_fail    ) $display("##  addr=%h : (y,x)=(%d, %d) aquire fail      %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i,$time );
            if( swap_rl_success ) $display("##  addr=%h : (y,x)=(%d, %d) release success,input value=%h,  %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i, in_data_i,$time );

            if( swap_result_v_r && swap_lock_r ) $display("## aquire return result ,value=%h, %m, %t",  swap_aq_result_r, $time );
        end

        always_ff@(negedge clk_i) begin
            if( swap_result_v_r && returning_v_i ) begin
                $display("## Conflict retuning path.     %m, %t", in_addr_i<<2, in_y_cord_i, in_x_cord_i,$time );
                $finish();
            end
        end
    end
    //synopsys translate_on
endmodule
