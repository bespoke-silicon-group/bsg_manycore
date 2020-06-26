/**
 *    bsg_decode_with_v_2d.v
 *
 */



module bsg_decode_with_v_2d
  #(parameter num_out_x_p = "inv"
    , parameter num_out_y_p = "inv"

    , parameter lg_num_out_x_lp=`BSG_SAFE_CLOG2(num_out_x_p)
    , parameter lg_num_out_y_lp=`BSG_SAFE_CLOG2(num_out_y_p)
  )
  (
    input v_i
    , input [lg_num_out_x_lp-1:0] x_i
    , input [lg_num_out_y_lp-1:0] y_i
    , output [num_out_y_p-1:0][num_out_x_p-1:0] o
  );


  logic [num_out_y_p-1:0] y_sel;
  logic [num_out_x_p-1:0] x_sel;

  bsg_decode #(
    .num_out_p(num_out_y_p)
  ) dy (
    .i(y_i)
    ,.o(y_sel)
  );

  bsg_decode #(
    .num_out_p(num_out_x_p)
  ) dx (
    .i(x_i)
    ,.o(x_sel)
  );


  for (genvar i = 0; i < num_out_y_p; i++)
    for (genvar j = 0; j < num_out_x_p; j++)
      assign o[i][j] = v_i & y_sel[i] & x_sel[j];



endmodule
