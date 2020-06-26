/**
 *    bsg_manycore_crossbar_network.v
 *
 */


module bsg_manycore_crossbar_network
  //import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter num_in_x_p="inv"
    , parameter num_in_y_p="inv"

    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input  [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_i
    , output [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_o 
  
    , output [num_in_y_p-1:0][num_in_x_p-1:0] links_credit_o
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_in;
  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_out;
  assign links_sif_in = links_sif_i;
  assign links_sif_o = links_sif_out;


  localparam bsg_manycore_packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  localparam bsg_manycore_return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p);


  // fwd  
  bsg_manycore_fwd_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] fwd_links_in;
  bsg_manycore_fwd_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] fwd_links_out;

  for (genvar i = 0 ; i < num_in_y_p; i++) begin
    for (genvar j = 0 ; j < num_in_x_p; j++) begin
      assign fwd_links_in[i][j] = links_sif_in[i][j].fwd;
      assign links_sif_out[i][j].fwd = fwd_links_out[i][j];
    end
  end

  bsg_noc_crossbar #(
    .num_in_x_p(num_in_x_p)
    ,.num_in_y_p(num_in_y_p)
    ,.width_p(bsg_manycore_packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) fwd (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.links_sif_i(fwd_links_in)
    ,.links_sif_o(fwd_links_out)

    ,.links_credit_o(links_credit_o)
  );


  // rev
  bsg_manycore_rev_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] rev_links_in;
  bsg_manycore_rev_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] rev_links_out;

  for (genvar i = 0 ; i < num_in_y_p; i++) begin
    for (genvar j = 0 ; j < num_in_x_p; j++) begin
      assign rev_links_in[i][j] = links_sif_in[i][j].rev;
      assign links_sif_out[i][j].rev = rev_links_out[i][j];
    end
  end

  bsg_noc_crossbar #(
    .num_in_x_p(num_in_x_p)
    ,.num_in_y_p(num_in_y_p)
    ,.width_p(bsg_manycore_return_packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
  ) rev (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.links_sif_i(rev_links_in)
    ,.links_sif_o(rev_links_out)

    ,.links_credit_o()
  );



endmodule
