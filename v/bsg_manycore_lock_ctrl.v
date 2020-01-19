//====================================================================
// bsg_manycore_lock_ctrl.v
// 03/02/2019, shawnless.xie@gmail.com
// 12/11/2019, tommy
//====================================================================
// This module implements the lightweight local lock, which uses amoswap
// to implement the mutex primitive.
//
// restrictions:
//   Only one lock avaliable for each endpoint, so we cannot have
//   nested or interleaved multiple lock/unlock pairs for the same
//   nodes. 
//   Only one bit of data can be swapped.
//--------------------------------------------------------------------
// This module will trap any atomic packets, and forwarding any
// other packets. 
//
// 1. incoming request
//      [local mem]   <=  [ lock_ctrl ] <=  endpoint_standard
//
// 2. returning data
//      [local mem]   =>  [ lock_ctrl ] =>  endpoint_standard

module bsg_manycore_lock_ctrl
  import bsg_manycore_pkg::*;
  #(parameter data_width_p             = 32
    , parameter addr_width_p           = "inv"
    , parameter x_cord_width_p         = "inv"
    , parameter y_cord_width_p         = "inv"
    , parameter max_out_credits_p      = "inv"
    , parameter debug_p                = 0
  )
  (
    input clk_i
    , input reset_i

    // local endpoint incoming data interface
    , input                         in_v_i
    , output                        in_yumi_o
    , input [data_width_p-1:0]      in_data_i
    , input [(data_width_p>>3)-1:0] in_mask_i
    , input [addr_width_p-1:0]      in_addr_i
    , input                         in_we_i
    , input                         in_amo_op_i
    , input bsg_manycore_amo_type_e in_amo_type_i
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

  // lightweight local lock.
  logic amo_lock_r;

  wire node_is_idle;
  wire amo_op_yumi =  in_v_i & in_amo_op_i & node_is_idle;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      amo_lock_r <= 1'b0;
    end
    else begin
      // only support amoswap
      if (amo_op_yumi & (in_amo_type_i == e_amo_swap))
        amo_lock_r <= in_data_i[0];
    end
  end

  //-------------------------------------------------------------------------
  //  The output signals
  //-------------------------------------------------------------------------

  //yumi signal to endpoint
  assign in_yumi_o = amo_op_yumi | comb_yumi_i; 

  //To local memory
  assign comb_v_o       =   in_v_i & ~in_amo_op_i;
  assign comb_data_o    =   in_data_i;
  assign comb_mask_o    =   in_mask_i;
  assign comb_addr_o    =   in_addr_i;
  assign comb_x_cord_o  =   in_x_cord_i;
  assign comb_y_cord_o  =   in_y_cord_i;
  assign comb_we_o      =   in_we_i;

  // returning data to endpoint
  logic amo_result_v_r, amo_result_r;

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      amo_result_v_r  <= 1'b0;
      amo_result_r    <= 1'b0;
    end
    else begin
      amo_result_v_r  <= amo_op_yumi;
      amo_result_r    <= amo_lock_r;
    end
  end

  assign comb_returning_v_o = amo_result_v_r | returning_v_i ;
  assign comb_returning_data_o = amo_result_v_r
    ? {{(data_width_p-1){1'b0}}, amo_result_r}
    : returning_data_i;

  //-------------------------------------------------------------------------
  // the counter to track how many request pending in the node
  //-------------------------------------------------------------------------
  // TODO: find cleaner way.
  wire[$clog2(max_out_credits_p+1)-1:0] request_num_in_node_lo;

  bsg_counter_up_down #(
    .max_val_p(max_out_credits_p)
    ,.init_val_p(max_out_credits_p)
    ,.max_step_p(1)
  ) out_credit_ctr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.down_i(comb_yumi_i)
    ,.up_i(returning_v_i)
    ,.count_o(request_num_in_node_lo)
  );

  assign node_is_idle = (request_num_in_node_lo == max_out_credits_p); 

  // assertion
  //synopsys translate_off
  if (debug_p) begin
    always_ff @ (negedge clk_i) begin
      if (amo_result_v_r & returning_v_i) begin
        $display("[BSG_FATAL] Conflicting return path. %m");
        $finish();
      end
    end
  end
  //synopsys translate_on


endmodule
