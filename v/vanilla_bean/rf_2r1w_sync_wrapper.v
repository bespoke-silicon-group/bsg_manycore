//====================================================================
// rf_2r1w_sync_wrapper.v
// 11/02/2016, shawnless.xie@gmail.com
//====================================================================

//This module instantiate a 2r1w sync memory file and add a bypass
//register. When there is a write and read and the same time, it output
//the newly written value, which is "write through"

module rf_2r1w_sync_wrapper  #(parameter width_p=-1
                           , parameter els_p=-1
                           , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
                           , parameter harden_p=0
                           )
   (  input clk_i
    , input reset_i

    , input                     w_v_i
    , input [addr_width_lp-1:0] w_addr_i
    , input [width_p-1:0]       w_data_i

    , input                      r0_v_i
    , input [addr_width_lp-1:0]  r0_addr_i
    , output logic [width_p-1:0] r0_data_o

    , input                      r1_v_i
    , input [addr_width_lp-1:0]  r1_addr_i
    , output logic [width_p-1:0] r1_data_o
    );

    wire r0_rw_same_addr = w_v_i & r0_v_i & ( w_addr_i == r0_addr_i);
    wire r1_rw_same_addr = w_v_i & r1_v_i & ( w_addr_i == r1_addr_i);

    wire r0_wrapper_v    = r0_rw_same_addr ? 1'b0 : r0_v_i;
    wire r1_wrapper_v    = r1_rw_same_addr ? 1'b0 : r1_v_i;

    wire [width_p-1:0] r0_mem_data, r1_mem_data;

    bsg_mem_2r1w_sync #( .width_p       ( width_p       )
                        ,.els_p         ( els_p         )
                        ,.addr_width_lp ( addr_width_lp )
                        ,.harden_p      ( harden_p      )

                        ,.read_write_same_addr_p( 1'b0  )
                        ) rf_mem
        ( .clk_i
         ,.reset_i

         ,.w_v_i
         ,.w_addr_i
         ,.w_data_i

         ,.r0_v_i      ( r0_wrapper_v  )
         ,.r0_addr_i   ( r0_addr_i     )
         ,.r0_data_o   ( r0_mem_data   )

         ,.r1_v_i      ( r1_wrapper_v  )
         ,.r1_addr_i   ( r1_addr_i     )
         ,.r1_data_o   ( r1_mem_data   )
        );

    logic                   r0_rw_same_addr_r,  r1_rw_same_addr_r;
    always_ff@(posedge clk_i)
    begin
        if( reset_i )  begin
            r0_rw_same_addr_r  <= 1'b0;
            r1_rw_same_addr_r  <= 1'b0;
        end else begin
            r0_rw_same_addr_r  <= r0_rw_same_addr;
            r1_rw_same_addr_r  <= r1_rw_same_addr;
        end
    end


    //record the latest written data
    logic [width_p-1:0]      w_data_r;
    always_ff@(posedge clk_i)
    begin
        if( reset_i )   w_data_r <= 'b0;
        else if( w_v_i) w_data_r <= w_data_i;
    end

    //get the safe data
    wire [width_p-1:0]  r0_data_safe = r0_rw_same_addr_r ? w_data_r : r0_mem_data;
    wire [width_p-1:0]  r1_data_safe = r1_rw_same_addr_r ? w_data_r : r1_mem_data;

    //save the output if the pipleline is stalled.
    logic [width_p-1:0]         r0_data_r, r1_data_r;
    logic [addr_width_lp-1:0]   r0_addr_r, r1_addr_r;
    logic r0_v_r, r1_v_r;


    always_ff@( posedge clk_i ) begin
        r0_addr_r   <=  r0_addr_i;
        r1_addr_r   <=  r1_addr_i;
    end

    wire update_hold_reg0 = r0_v_r &&  w_v_i && (r0_addr_r == w_addr_i ) ;
    wire update_hold_reg1 = r1_v_r &&  w_v_i && (r1_addr_r == w_addr_i ) ;

    always_ff@( posedge clk_i ) begin
        r0_data_r   <=  update_hold_reg0 ? w_data_i : r0_data_o;
        r1_data_r   <=  update_hold_reg1 ? w_data_i : r1_data_o;
    end

    always_ff@( posedge clk_i) begin
        r0_v_r <= r0_v_i;
        r1_v_r <= r1_v_i;
    end

    //assign the output
    assign  r0_data_o   = r0_v_r ? r0_data_safe : r0_data_r;
    assign  r1_data_o   = r1_v_r ? r1_data_safe : r1_data_r;

    ///////////////////////////////////////
    // synopsys translate_off
    if(0) begin
        always_ff@ ( negedge clk_i ) begin
            if ( r0_rw_same_addr )
                $display("port0 read with the same address with write: addr=%08x, value=%08x\n",r0_addr_i, w_data_i);
            if ( r1_rw_same_addr )
                $display("port1 read with the same address with write: addr=%08x, value=%08x\n",r1_addr_i, w_data_i);
        end
    end
    // synopsys translate_on

endmodule

