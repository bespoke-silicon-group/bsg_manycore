/**
 *    bsg_manycore_link_to_crossbar.v
 *
 */


`include "bsg_noc_links.vh"

module bsg_manycore_link_to_crossbar
  import bsg_manycore_pkg::*;
  #(parameter width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter num_in_x_p="inv"
    , parameter num_in_y_p="inv"

    , parameter link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)

    , parameter num_in_lp=(num_in_x_p*num_in_y_p)
    , parameter lg_num_in_lp=`BSG_SAFE_CLOG2(num_in_lp)

    , parameter xbar_width_lp = (width_p-x_cord_width_p-y_cord_width_p+lg_num_in_lp)
    , parameter xbar_link_sif_width_lp = `bsg_ready_and_link_sif_width(xbar_width_lp)
  )
  (
    //input clk_i
    //, input reset_i

    input  [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_i
    , output [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_o

    , input  [num_in_lp-1:0][xbar_link_sif_width_lp-1:0] xbar_links_sif_i
    , output [num_in_lp-1:0][xbar_link_sif_width_lp-1:0] xbar_links_sif_o
  );


  `declare_bsg_ready_and_link_sif_s(width_p,bsg_manycore_link_sif_s);
  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_in; 
  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_out; 
  assign links_sif_in = links_sif_i;
  assign links_sif_o  = links_sif_out;

  `declare_bsg_ready_and_link_sif_s(xbar_width_lp,bsg_manycore_xbar_link_sif_s);
  bsg_manycore_xbar_link_sif_s [num_in_lp-1:0] xbar_links_sif_in;
  bsg_manycore_xbar_link_sif_s [num_in_lp-1:0] xbar_links_sif_out;
  assign xbar_links_sif_in = xbar_links_sif_i;
  assign xbar_links_sif_o  = xbar_links_sif_out;


  // manycore -> crossbar
  logic [num_in_y_p-1:0][num_in_x_p-1:0][y_cord_width_p-1:0] y_cord_in;
  logic [num_in_y_p-1:0][num_in_x_p-1:0][x_cord_width_p-1:0] x_cord_in;
  
  for (genvar i = 0; i < num_in_y_p; i++) begin
    for (genvar j = 0; j < num_in_x_p; j++) begin

      assign y_cord_in[i][j] = links_sif_in[i][j].data[x_cord_width_p+:y_cord_width_p];
      assign x_cord_in[i][j] = links_sif_in[i][j].data[0+:x_cord_width_p];

      assign xbar_links_sif_out[(i*num_in_x_p)+j].data  = {
        links_sif_in[i][j].data[width_p-1:x_cord_width_p+y_cord_width_p],
        (lg_num_in_lp)'(x_cord_in[i][j] + (y_cord_in[i][j]*num_in_x_p))
      };

      assign xbar_links_sif_out[(i*num_in_x_p)+j].v = links_sif_in[i][j].v;
      assign links_sif_out[i][j].ready_and_rev = xbar_links_sif_in[(i*num_in_x_p)+j].ready_and_rev;
    end
  end



  // crossbar -> manycore
  logic [num_in_y_p-1:0][num_in_x_p-1:0][y_cord_width_p-1:0] y_cord_out;
  logic [num_in_y_p-1:0][num_in_x_p-1:0][x_cord_width_p-1:0] x_cord_out;

  for (genvar i = 0; i < num_in_y_p; i++) begin
    for (genvar j = 0; j < num_in_x_p; j++) begin

      assign y_cord_out[i][j] = (y_cord_width_p)'(xbar_links_sif_in[(i*num_in_x_p)+j].data[0+:lg_num_in_lp] / num_in_x_p);
      assign x_cord_out[i][j] = (x_cord_width_p)'(xbar_links_sif_in[(i*num_in_x_p)+j].data[0+:lg_num_in_lp] % num_in_x_p);

      assign links_sif_out[i][j].data = {
        xbar_links_sif_in[(i*num_in_x_p)+j].data[xbar_width_lp-1:lg_num_in_lp],
        y_cord_out[i][j],
        x_cord_out[i][j]
      };

      assign links_sif_out[i][j].v = xbar_links_sif_in[(i*num_in_x_p)+j].v;
      assign xbar_links_sif_out[(i*num_in_x_p)+j].ready_and_rev = links_sif_in[i][j].ready_and_rev;

    end
  end

endmodule
