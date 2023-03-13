/**
 *    bsg_manycore_xbar_fanout.v
 *
 */

`include "bsg_manycore_defines.vh"


module bsg_manycore_xbar_fanout
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(host_x_cord_p)
    , `BSG_INV_PARAM(host_y_cord_p)

    , `BSG_INV_PARAM(fifo_els_p)
    , `BSG_INV_PARAM(use_credits_p)

    , `BSG_INV_PARAM(fwd_not_rev_p)

    , parameter input_fifo_els_p = 2
    , localparam num_out_lp = (fwd_not_rev_p
                              ? 1+(num_tiles_x_p*num_tiles_y_p)+(2*num_tiles_x_p)
                              : 1+(num_tiles_x_p*num_tiles_y_p))
    , packet_width_lp = fwd_not_rev_p
                      ? `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                      : `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
                
  )
  (
    input clk_i
    , input reset_i

    , input v_i
    , input [packet_width_lp-1:0] packet_i
    , output logic credit_or_ready_o

    , output logic [num_out_lp-1:0] v_o
    , output logic [num_out_lp-1:0][packet_width_lp-1:0] packet_o 
    , input [num_out_lp-1:0] yumi_i
  );


  // Input FIFO
  logic in_ready_lo;
  logic in_v_lo, in_yumi_li;
  logic [packet_width_lp-1:0] in_packet_lo;

  bsg_fifo_1r1w_small #(
    .width_p(packet_width_lp)
    ,.els_p(input_fifo_els_p)
  ) in0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(v_i)
    ,.data_i(packet_i)
    ,.ready_o(in_ready_lo)

    ,.v_o(in_v_lo)
    ,.data_o(in_packet_lo)
    ,.yumi_i(in_yumi_li)
  ); 

  // credit interface;
  if (use_credits_p) begin:cr
    bsg_dff_reset #(
      .width_p(1)
      ,.reset_val_p(0)
    ) dff0 (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(in_yumi_li)
      ,.data_o(credit_or_ready_o)
    );
  end
  else begin
    assign credit_or_ready_o = in_ready_lo;
  end


  // coord translate;
  logic [num_out_lp-1:0] sel_one_hot;
  bsg_manycore_xbar_coord_translate #(
    .y_cord_width_p(y_cord_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.host_x_cord_p(host_x_cord_p)
    ,.host_y_cord_p(host_y_cord_p)
    ,.fwd_not_rev_p(fwd_not_rev_p)
  ) ct0 (
    .cord_i(in_packet_lo[0+:y_cord_width_p+x_cord_width_p])
    ,.sel_one_hot_o(sel_one_hot)
  );

  // Fanout FIFO
  logic [num_out_lp-1:0] fifo_v_li, fifo_ready_lo;
  logic [num_out_lp-1:0] fifo_v_lo, fifo_yumi_li;
  logic [num_out_lp-1:0][packet_width_lp-1:0] fifo_data_lo;

  for (genvar i = 0; i < num_out_lp; i++) begin: ff
    bsg_fifo_1r1w_small #(
      .width_p(packet_width_lp)
      ,.els_p(fifo_els_p)     
    ) fifo0 (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.v_i(fifo_v_li[i])
      ,.data_i(in_packet_lo)
      ,.ready_o(fifo_ready_lo[i])

      ,.v_o(v_o[i])
      ,.data_o(packet_o[i])
      ,.yumi_i(yumi_i[i])
    );
  end

  assign fifo_v_li = sel_one_hot & {num_out_lp{in_v_lo}};
  assign in_yumi_li = in_v_lo & (|(sel_one_hot & fifo_ready_lo));

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_xbar_fanout)
