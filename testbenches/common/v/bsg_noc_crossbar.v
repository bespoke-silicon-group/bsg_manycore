/**
 *    bsg_noc_crossbar.v
 *
 *    WARNING: This can be really expensive. Don't try to synthesize this at home!!
 *
 */

`include "bsg_noc_links.vh"

module bsg_noc_crossbar 
  #(parameter num_in_x_p="inv"
    , parameter num_in_y_p="inv"
    , parameter width_p="inv"
    
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter lg_num_in_x_lp = `BSG_SAFE_CLOG2(num_in_x_p)
    , parameter lg_num_in_y_lp = `BSG_SAFE_CLOG2(num_in_y_p)

    , parameter link_sif_width_lp=`bsg_ready_and_link_sif_width(width_p)
  )
  (
    input clk_i
    , input reset_i

    , input  [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_i
    , output [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_o

    , input  [num_in_y_p-1:0][num_in_x_p-1:0] links_credit_o
  );


  `declare_bsg_ready_and_link_sif_s(width_p, bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_in;
  bsg_ready_and_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_out;

  assign links_sif_in = links_sif_i;
  assign links_sif_o = links_sif_out;


  // input buffer
  logic [num_in_y_p-1:0][num_in_x_p-1:0] fifo_v_lo;
  logic [num_in_y_p-1:0][num_in_x_p-1:0][width_p-1:0] fifo_data_lo;
  logic [num_in_y_p-1:0][num_in_x_p-1:0] fifo_yumi_li;

  for (genvar i = 0; i < num_in_y_p; i++) begin: fy
    for (genvar j = 0; j < num_in_x_p; j++) begin: fx

      bsg_two_fifo #(
        .width_p(width_p)
      ) fifo (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.v_i     (links_sif_in[i][j].v)
        ,.data_i  (links_sif_in[i][j].data)
        ,.ready_o (links_sif_out[i][j].ready_and_rev)

        ,.v_o     (fifo_v_lo[i][j])
        ,.data_o  (fifo_data_lo[i][j])
        ,.yumi_i  (fifo_yumi_li[i][j])
      );
      
      assign links_credit_o[i][j] = fifo_yumi_li[i][j];

    end
  end

 
  // crossbar demux
  // [src_y][src_x][dest_y][dest_x]
  logic [num_in_y_p-1:0][num_in_x_p-1:0][num_in_y_p-1:0][num_in_x_p-1:0] dest_select, dest_select_t;
 
  for (genvar i = 0; i < num_in_y_p; i++) begin: dy
    for (genvar j = 0; j < num_in_x_p; j++) begin: dx
      bsg_decode_with_v_2d #(
        .num_out_x_p(num_in_x_p)
        ,.num_out_y_p(num_in_y_p)
      ) demux0 (
        .v_i(fifo_v_lo[i][j])
        ,.x_i(fifo_data_lo[i][j][0+:lg_num_in_x_lp])
        ,.y_i(fifo_data_lo[i][j][x_cord_width_p+:lg_num_in_y_lp])
        ,.o(dest_select[i][j]) 
      );
    end
  end 
 

  // transpose
  bsg_transpose #(
    .width_p(num_in_x_p*num_in_y_p)
    ,.els_p(num_in_x_p*num_in_y_p)
  ) trans0 (
    .i(dest_select)
    ,.o(dest_select_t)
  );

 
 
  // crossbar round robin
  logic [num_in_y_p-1:0][num_in_x_p-1:0][num_in_y_p-1:0][num_in_x_p-1:0] rr_yumi_lo, rr_yumi_lo_t;

  for (genvar i = 0; i < num_in_y_p; i++) begin: rry
    for (genvar j = 0; j < num_in_x_p; j++) begin: rrx

      bsg_round_robin_n_to_1_2d #(
        .width_p(width_p)
        ,.num_in_x_p(num_in_x_p)
        ,.num_in_y_p(num_in_y_p)
      ) rr2d (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.data_i(fifo_data_lo)
        ,.v_i(dest_select_t[i][j])
        ,.yumi_o(rr_yumi_lo[i][j])

        ,.v_o(links_sif_out[i][j].v)
        ,.data_o(links_sif_out[i][j].data)
        ,.tag_y_o()
        ,.tag_x_o()
        ,.yumi_i(links_sif_out[i][j].v & links_sif_in[i][j].ready_and_rev)
      );

    end
  end


  // transpose
  bsg_transpose #(
    .width_p(num_in_x_p*num_in_y_p)
    ,.els_p(num_in_x_p*num_in_y_p)
  ) trans1 (
    .i(rr_yumi_lo)
    ,.o(rr_yumi_lo_t)
  );


  for (genvar i = 0; i < num_in_y_p; i++)
    for (genvar j = 0; j < num_in_x_p; j++)
      assign fifo_yumi_li[i][j] = |rr_yumi_lo_t[i][j];




endmodule
