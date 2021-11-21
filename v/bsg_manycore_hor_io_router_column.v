/**
 *    bsg_manycore_hor_io_router_column.v
 *
 *    This modules instantiates a vertical chain of bsg_manycore_hor_io_router,
 *    which can attach to the side of the pods to provide accelerator connectivity.
 */

`include "bsg_defines.v"

module bsg_manycore_hor_io_router_column
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(ruche_factor_X_p)
    
    , `BSG_INV_PARAM(num_row_p)
    , `BSG_INV_PARAM(bit [num_row_p-1:0] tieoff_west_p)
    , `BSG_INV_PARAM(bit [num_row_p-1:0] tieoff_east_p )


    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , localparam ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // vertical links
    , input  [S:N][link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][link_sif_width_lp-1:0] ver_link_sif_o
    
    , input  [num_row_p-1:0][link_sif_width_lp-1:0] proc_link_sif_i
    , output [num_row_p-1:0][link_sif_width_lp-1:0] proc_link_sif_o
    
    , input  [num_row_p-1:0][E:W][link_sif_width_lp-1:0] hor_link_sif_i
    , output [num_row_p-1:0][E:W][link_sif_width_lp-1:0] hor_link_sif_o

    , input  [num_row_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [num_row_p-1:0][E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_o

    , input [x_cord_width_p-1:0] global_x_i
    , input [num_row_p-1:0][y_cord_width_p-1:0] global_y_i
  );


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s [num_row_p-1:0][S:W] link_sif_li;
  bsg_manycore_link_sif_s [num_row_p-1:0][S:W] link_sif_lo;


  for (genvar i = 0; i < num_row_p; i++) begin: r

    bsg_manycore_hor_io_router #(
      .addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.ruche_factor_X_p(ruche_factor_X_p)
    
      ,.tieoff_west_p(tieoff_west_p[i])
      ,.tieoff_east_p(tieoff_east_p[i])
    ) io_rtr (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.link_sif_i(link_sif_li[i])
      ,.link_sif_o(link_sif_lo[i])

      ,.proc_link_sif_i(proc_link_sif_i[i])
      ,.proc_link_sif_o(proc_link_sif_o[i])

      ,.ruche_link_i(ruche_link_i[i])
      ,.ruche_link_o(ruche_link_o[i])
    
      ,.global_x_i(global_x_i)
      ,.global_y_i(global_y_i[i])
    );

    assign hor_link_sif_o[i][W] = link_sif_lo[i][W];
    assign link_sif_li[i][W] = hor_link_sif_i[i][W];
    assign hor_link_sif_o[i][E] = link_sif_lo[i][E];
    assign link_sif_li[i][E] = hor_link_sif_i[i][E];

    if (i != num_row_p-1) begin
      assign link_sif_li[i][S] = link_sif_lo[i+1][N];
      assign link_sif_li[i+1][N] = link_sif_lo[i][S];
    end

  end

  assign ver_link_sif_o[N] = link_sif_lo[0][N];
  assign link_sif_li[0][N] = ver_link_sif_i[N];

  assign ver_link_sif_o[S] = link_sif_lo[num_row_p-1][S];
  assign link_sif_li[num_row_p-1][S] = ver_link_sif_i[S];

  



endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_hor_io_router_column)
