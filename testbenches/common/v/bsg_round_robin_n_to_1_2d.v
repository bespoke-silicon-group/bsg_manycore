/**
 *    bsg_round_robin_n_to_1_2d.v
 *
 */


module bsg_round_robin_n_to_1_2d
  #(parameter width_p="inv"
    , parameter num_in_x_p="inv"
    , parameter num_in_y_p="inv"
  
    , parameter lg_num_in_x_lp=`BSG_SAFE_CLOG2(num_in_x_p)
    , parameter lg_num_in_y_lp=`BSG_SAFE_CLOG2(num_in_y_p)

    , parameter strict_p = 0
  )
  (
    input clk_i
    , input reset_i

    , input [num_in_y_p-1:0][num_in_x_p-1:0][width_p-1:0] data_i
    , input [num_in_y_p-1:0][num_in_x_p-1:0] v_i 
    , output [num_in_y_p-1:0][num_in_x_p-1:0] yumi_o

    , output v_o
    , output [width_p-1:0] data_o
    , output [lg_num_in_y_lp-1:0] tag_y_o
    , output [lg_num_in_y_lp-1:0] tag_x_o
    , input yumi_i
  );


  // col round_robin
  logic [num_in_y_p-1:0] col_v_lo;
  logic [num_in_y_p-1:0][width_p-1:0] col_data_lo;
  logic [num_in_y_p-1:0][lg_num_in_x_lp-1:0] col_tag_x_lo;
  logic [num_in_y_p-1:0] col_yumi_li;

  for (genvar i = 0; i < num_in_y_p; i++) begin: y
    bsg_round_robin_n_to_1 #(
      .width_p(width_p)
      ,.num_in_p(num_in_x_p)
      ,.strict_p(strict_p)
    ) col_rr (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i(data_i[i])
      ,.v_i(v_i[i])
      ,.yumi_o(yumi_o[i])

      ,.v_o(col_v_lo[i])
      ,.data_o(col_data_lo[i])
      ,.tag_o(col_tag_x_lo[i])
      ,.yumi_i(col_yumi_li[i])
    );
  end


  // row round_robin
  bsg_round_robin_n_to_1 #(
    .width_p(width_p)
    ,.num_in_p(num_in_y_p)
    ,.strict_p(strict_p)
  ) row_rr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(col_data_lo)
    ,.v_i(col_v_lo)
    ,.yumi_o(col_yumi_li)

    ,.v_o(v_o)
    ,.data_o(data_o)
    ,.tag_o(tag_y_o)
    ,.yumi_i(yumi_i)
  );

 
  assign tag_x_o = col_tag_x_lo[tag_y_o]; 



endmodule
