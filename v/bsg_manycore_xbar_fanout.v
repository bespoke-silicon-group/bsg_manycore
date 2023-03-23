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
    , `BSG_INV_PARAM(global_x_p)
    , `BSG_INV_PARAM(global_y_p)
  
    , parameter ruche_factor_X_p = 3

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
  //logic [num_out_lp-1:0] fifo_v_lo, fifo_yumi_li;
  //logic [num_out_lp-1:0][packet_width_lp-1:0] fifo_data_lo;
/*
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

      ,.v_o(fifo_v_lo[i])
      ,.data_o(fifo_data_lo[i])
      ,.yumi_i(fifo_yumi_li[i])
    );
  end
*/
  assign fifo_v_li = sel_one_hot & {num_out_lp{in_v_lo}};
  assign in_yumi_li = in_v_lo & (|(sel_one_hot & fifo_ready_lo));


  // delay FIFO
  function int calculate_delay(int src_x, int src_y, int dest_x, int dest_y);
    int diff_y;
    int diff_x;
    int delay_x;
    diff_y = dest_y - src_y;
    diff_x = dest_x - src_x;

    if (diff_y < 0) begin
      diff_y = -diff_y;
    end

    if (diff_x < 0) begin
      diff_x = -diff_x;
    end

    if ((diff_x % ruche_factor_X_p == 0) && (diff_x != 0)) begin
      delay_x = ((diff_x-ruche_factor_X_p)/ruche_factor_X_p) + ruche_factor_X_p;
    end
    else begin
      delay_x = (diff_x/ruche_factor_X_p) + (diff_x%ruche_factor_X_p);
    end
    return diff_y + delay_x;
  endfunction


  //logic [num_out_lp-1:0] delay_ready_lo;

  // host
  bsg_fifo_delay #(
    .delay_p(`BSG_MAX(1,calculate_delay(global_x_p,global_y_p,num_tiles_x_p,num_tiles_y_p-2)))
    ,.width_p(packet_width_lp)
    ,.els_p(fifo_els_p)
  ) delay0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(fifo_v_li[0])
    ,.ready_o(fifo_ready_lo[0])
    ,.data_i(in_packet_lo)

    ,.v_o(v_o[0])
    ,.data_o(packet_o[0])
    ,.yumi_i(yumi_i[0])
  );
  //assign fifo_yumi_li[0] = fifo_v_lo[0] & delay_ready_lo[0];

  // tiles
  for (genvar r = 0; r < num_tiles_y_p; r++) begin: ty
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: tx

      localparam id = 1+c+(r*num_tiles_x_p);

      bsg_fifo_delay #(
        .delay_p(`BSG_MAX(1,calculate_delay(global_x_p,global_y_p,num_tiles_x_p+c,num_tiles_y_p+r)))
        ,.width_p(packet_width_lp)
        ,.els_p(fifo_els_p)
      ) delay0 (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(fifo_v_li[id])
        ,.ready_o(fifo_ready_lo[id])
        ,.data_i(in_packet_lo)

        ,.v_o(v_o[id])
        ,.data_o(packet_o[id])
        ,.yumi_i(yumi_i[id])
      );

      //assign fifo_yumi_li[id] = fifo_v_lo[id] & delay_ready_lo[id];
    end
  end
  
  // vc
  if (fwd_not_rev_p) begin
    for (genvar c = 0; c < num_tiles_x_p; c++) begin: vx
      // north
      localparam nid = 1+c+(num_tiles_y_p*num_tiles_x_p);
      bsg_fifo_delay #(
        .delay_p(`BSG_MAX(1,calculate_delay(global_x_p,global_y_p,num_tiles_x_p+c,num_tiles_y_p-1)))
        ,.width_p(packet_width_lp)
        ,.els_p(fifo_els_p)
      ) delayn (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(fifo_v_li[nid])
        ,.ready_o(fifo_ready_lo[nid])
        ,.data_i(in_packet_lo)

        ,.v_o(v_o[nid])
        ,.data_o(packet_o[nid])
        ,.yumi_i(yumi_i[nid])
      );

      //assign fifo_yumi_li[nid] = fifo_v_lo[nid] & delay_ready_lo[nid];

      // south
      localparam sid = 1+c+(num_tiles_y_p*num_tiles_x_p)+num_tiles_x_p;
      bsg_fifo_delay #(
        .delay_p(`BSG_MAX(1,calculate_delay(global_x_p,global_y_p,num_tiles_x_p+c,num_tiles_y_p*2)))
        ,.width_p(packet_width_lp)
        ,.els_p(fifo_els_p)
      ) delays (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i(fifo_v_li[sid])
        ,.ready_o(fifo_ready_lo[sid])
        ,.data_i(in_packet_lo)

        ,.v_o(v_o[sid])
        ,.data_o(packet_o[sid])
        ,.yumi_i(yumi_i[sid])
      );

      //assign fifo_yumi_li[sid] = fifo_v_lo[sid] & delay_ready_lo[sid];
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_xbar_fanout)
