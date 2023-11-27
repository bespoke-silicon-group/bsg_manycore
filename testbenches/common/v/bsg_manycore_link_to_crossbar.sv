/**
 *    bsg_manycore_link_to_crossbar.v
 *
 */


`include "bsg_manycore_defines.svh"

module bsg_manycore_link_to_crossbar
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)
    , parameter `BSG_INV_PARAM(num_in_x_p)
    , parameter `BSG_INV_PARAM(num_in_y_p)

    , parameter link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)

    , parameter num_in_lp=(num_in_x_p*num_in_y_p)
    , parameter lg_num_in_lp=`BSG_SAFE_CLOG2(num_in_lp)

    , parameter xbar_width_lp = (width_p-x_cord_width_p-y_cord_width_p+lg_num_in_lp)
  )
  (
    input  [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_i
    , output [num_in_y_p-1:0][num_in_x_p-1:0][link_sif_width_lp-1:0] links_sif_o


    , output [num_in_lp-1:0] valid_o
    , output [num_in_lp-1:0][xbar_width_lp-1:0] data_o
    , input  [num_in_lp-1:0] credit_or_ready_i
    
    , input  [num_in_lp-1:0] valid_i
    , input  [num_in_lp-1:0][xbar_width_lp-1:0] data_i
    , output [num_in_lp-1:0] ready_and_o
  );


  `declare_bsg_ready_and_link_sif_s(width_p,bsg_manycore_link_sif_s);
  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_in; 
  bsg_manycore_link_sif_s [num_in_y_p-1:0][num_in_x_p-1:0] links_sif_out; 
  assign links_sif_in = links_sif_i;
  assign links_sif_o  = links_sif_out;


  // manycore -> crossbar
  logic [num_in_y_p-1:0][num_in_x_p-1:0][y_cord_width_p-1:0] y_cord_in;
  logic [num_in_y_p-1:0][num_in_x_p-1:0][x_cord_width_p-1:0] x_cord_in;
  
  for (genvar i = 0; i < num_in_y_p; i++) begin
    for (genvar j = 0; j < num_in_x_p; j++) begin

      assign y_cord_in[i][j] = links_sif_in[i][j].data[x_cord_width_p+:y_cord_width_p];
      assign x_cord_in[i][j] = links_sif_in[i][j].data[0+:x_cord_width_p];

      assign data_o[(i*num_in_x_p)+j]  = {
        links_sif_in[i][j].data[width_p-1:x_cord_width_p+y_cord_width_p],
        (lg_num_in_lp)'(x_cord_in[i][j] + (y_cord_in[i][j]*num_in_x_p))
      };

      assign valid_o[(i*num_in_x_p)+j] = links_sif_in[i][j].v;
      assign links_sif_out[i][j].ready_and_rev = credit_or_ready_i[(i*num_in_x_p)+j];
    end
  end



  // crossbar -> manycore
  logic [num_in_y_p-1:0][num_in_x_p-1:0][y_cord_width_p-1:0] y_cord_out;
  logic [num_in_y_p-1:0][num_in_x_p-1:0][x_cord_width_p-1:0] x_cord_out;

  for (genvar i = 0; i < num_in_y_p; i++) begin
    for (genvar j = 0; j < num_in_x_p; j++) begin

      assign y_cord_out[i][j] = (y_cord_width_p)'(data_i[(i*num_in_x_p)+j][0+:lg_num_in_lp] / num_in_x_p);
      assign x_cord_out[i][j] = (x_cord_width_p)'(data_i[(i*num_in_x_p)+j][0+:lg_num_in_lp] % num_in_x_p);

      assign links_sif_out[i][j].data = {
        data_i[(i*num_in_x_p)+j][xbar_width_lp-1:lg_num_in_lp],
        y_cord_out[i][j],
        x_cord_out[i][j]
      };

      assign links_sif_out[i][j].v = valid_i[(i*num_in_x_p)+j];
      assign ready_and_o[(i*num_in_x_p)+j] = links_sif_in[i][j].ready_and_rev;

    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_to_crossbar)

