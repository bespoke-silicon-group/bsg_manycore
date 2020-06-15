/**
 *  bsg_manycore_mesh_node.v
 *
 */

module bsg_manycore_mesh_node
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W, E, N, S}
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter dirs_lp=4
    , parameter stub_p            = {dirs_lp{1'b0}} // {s,n,e,w}
    , parameter repeater_output_p = {dirs_lp{1'b0}} // {s,n,e,w}

    , parameter num_nets_lp = 2 // 1=return network, 0=data network
    , parameter debug_p = 0

    , parameter packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter return_packet_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
    , parameter bsg_manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  ( 
    input clk_i
    , input reset_i

    // input and output links
    , input  [dirs_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_i
    , output [dirs_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_o
    , output [dirs_lp-1:0] links_credit_o 

    , input  [bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_o
    , output proc_credit_o

    // tile coordinates
    , input  [x_cord_width_p-1:0] my_x_i
    , input  [y_cord_width_p-1:0] my_y_i
  );

  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p);

  // typecast
  bsg_manycore_link_sif_s [dirs_lp-1:0] links_sif_i_cast, links_sif_o_cast;
  assign links_sif_i_cast = links_sif_i;
  assign links_sif_o = links_sif_o_cast;

  bsg_manycore_fwd_link_sif_s [dirs_lp+1-1:0] link_fwd_sif_i_cast, link_fwd_sif_o_cast;
  bsg_manycore_rev_link_sif_s [dirs_lp+1-1:0] link_rev_sif_i_cast, link_rev_sif_o_cast;

  // repackage proc link
  bsg_manycore_link_sif_s proc_link_li, proc_link_lo;

  assign proc_link_sif_o = proc_link_li;
  assign proc_link_lo    = proc_link_sif_i;

  assign proc_link_li.fwd = link_fwd_sif_o_cast[0];
  assign proc_link_li.rev = link_rev_sif_o_cast[0];
  assign link_fwd_sif_i_cast[0] = proc_link_lo.fwd;
  assign link_rev_sif_i_cast[0] = proc_link_lo.rev;


  // gather links from the outside networks
  // we still need to gather the links from the proc
  for (genvar k = 1; k <= dirs_lp; k=k+1) begin: rof27
    assign link_fwd_sif_i_cast[k] = links_sif_i_cast[k-1].fwd;
    assign link_rev_sif_i_cast[k] = links_sif_i_cast[k-1].rev;
    assign links_sif_o_cast[k-1].fwd = link_fwd_sif_o_cast[k];
    assign links_sif_o_cast[k-1].rev = link_rev_sif_o_cast[k];
  end

  logic [4:0] fwd_credit_lo;
  logic [4:0] rev_credit_lo;

  for (genvar i = 0; i < num_nets_lp; i=i+1) begin: rof
    logic [4:0] [(i ? $bits(bsg_manycore_rev_link_sif_s) : $bits (bsg_manycore_fwd_link_sif_s))-1:0] link_li;
    logic [4:0] [(i ? $bits(bsg_manycore_rev_link_sif_s) : $bits (bsg_manycore_fwd_link_sif_s))-1:0] link_lo;

    logic [4:0] credit_lo;

    // i = 1 -> return packet
    if (i) begin
      assign link_li             = link_rev_sif_i_cast;
      assign link_rev_sif_o_cast = link_lo;
      assign rev_credit_lo       = credit_lo;
    end
    else begin
      assign link_li             = link_fwd_sif_i_cast;
      assign link_fwd_sif_o_cast = link_lo;
      assign fwd_credit_lo       = credit_lo;
    end

    bsg_mesh_router_buffered #(
      .width_p(i ? return_packet_width_lp : packet_width_lp)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.debug_p(debug_p)
      // adding proc into stub
      ,.stub_p({stub_p, 1'b0})
      //forward router:  X/Y routing
      //reverse router:  Y/X routing
      ,.XY_order_p(!i)
      ,.repeater_output_p({repeater_output_p,1'b0})
    ) bmrb (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.link_i(link_li)
      ,.link_o(link_lo)

      ,.credit_o(credit_lo)

      ,.my_x_i(my_x_i)
      ,.my_y_i(my_y_i)
    );
  end

  assign links_credit_o = fwd_credit_lo[4:1];
  assign proc_credit_o = fwd_credit_lo[0];

endmodule

