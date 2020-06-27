/**
 *    bsg_manycore_crossbar.v
 *
 */


`include "bsg_noc_links.vh"


module bsg_manycore_crossbar
  import bsg_manycore_pkg::*;
  #(parameter num_in_x_p="inv"
    , parameter num_in_y_p="inv"

    , parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter num_in_lp=(num_in_x_p*num_in_y_p)
    , parameter lg_num_in_lp=`BSG_SAFE_CLOG2(num_in_lp)

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


  localparam packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  localparam return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p);


  // FWD
  bsg_manycore_fwd_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] fwd_links_in;
  bsg_manycore_fwd_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] fwd_links_out;

  for (genvar i = 0 ; i < num_in_y_p; i++) begin
    for (genvar j = 0 ; j < num_in_x_p; j++) begin
      assign fwd_links_in[i][j] = links_sif_in[i][j].fwd;
      assign links_sif_out[i][j].fwd = fwd_links_out[i][j];
    end
  end

  localparam xbar_fwd_pkt_width_lp = packet_width_lp-x_cord_width_p-y_cord_width_p+lg_num_in_lp;
  `declare_bsg_ready_and_link_sif_s(xbar_fwd_pkt_width_lp, xbar_fwd_link_sif_s);
  xbar_fwd_link_sif_s [num_in_lp-1:0] xbar_fwd_links_in;
  xbar_fwd_link_sif_s [num_in_lp-1:0] xbar_fwd_links_out;

  bsg_manycore_link_to_crossbar #(
    .width_p(packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_in_x_p(num_in_x_p)
    ,.num_in_y_p(num_in_y_p)
  ) link_to_xbar_fwd (
    .links_sif_i(fwd_links_in)
    ,.links_sif_o(fwd_links_out)

    ,.xbar_links_sif_i(xbar_fwd_links_out)
    ,.xbar_links_sif_o(xbar_fwd_links_in)
  );


  bsg_noc_crossbar #(
    .num_in_p(num_in_lp)
    ,.width_p(xbar_fwd_pkt_width_lp)
  ) fwdx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.links_sif_i(xbar_fwd_links_in)
    ,.links_sif_o(xbar_fwd_links_out)

    ,.links_credit_o(links_credit_o)
  );


  // REV
  bsg_manycore_rev_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] rev_links_in;
  bsg_manycore_rev_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] rev_links_out;

  for (genvar i = 0 ; i < num_in_y_p; i++) begin
    for (genvar j = 0 ; j < num_in_x_p; j++) begin
      assign rev_links_in[i][j] = links_sif_in[i][j].rev;
      assign links_sif_out[i][j].rev = rev_links_out[i][j];
    end
  end

  localparam xbar_rev_pkt_width_lp = return_packet_width_lp-x_cord_width_p-y_cord_width_p+lg_num_in_lp;
  `declare_bsg_ready_and_link_sif_s(xbar_rev_pkt_width_lp,xbar_rev_link_sif_s);
  xbar_rev_link_sif_s [num_in_lp-1:0] xbar_rev_links_in;
  xbar_rev_link_sif_s [num_in_lp-1:0] xbar_rev_links_out;

  bsg_manycore_link_to_crossbar #(
    .width_p(return_packet_width_lp)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_in_x_p(num_in_x_p)
    ,.num_in_y_p(num_in_y_p)
  ) link_to_xbar_rev (
    .links_sif_i(rev_links_in)
    ,.links_sif_o(rev_links_out)

    ,.xbar_links_sif_i(xbar_rev_links_out)
    ,.xbar_links_sif_o(xbar_rev_links_in)
  );
  
  bsg_noc_crossbar #(
    .num_in_p(num_in_lp)
    ,.width_p(xbar_rev_pkt_width_lp)
  ) revx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.links_sif_i(xbar_rev_links_in)
    ,.links_sif_o(xbar_rev_links_out)

    ,.links_credit_o()
  );



endmodule
