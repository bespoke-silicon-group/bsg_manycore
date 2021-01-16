/**
 *    bsg_manycore_hor_io_router.v
 *
 *    this router is used for attaching accelerators on the side of the pod.
 *    this router gets the x coordinate of the 1-minus of the leftmost tile x coordinate.
 *    this router needs to make a connection with a local link and a ruche link reaching this router.
 *    the accelerator connects to the P-port.
 *
 *    use tieoff_west_p, if this router is attaching to the west side of the pod.
 *    use tieoff_east_p, if this router is attaching to the east side of the pod.
 */


module bsg_manycore_hor_io_router
  import bsg_noc_pkg::*;
  import bsg_manycore_pkg::*;
  import bsg_mesh_router_pkg::*;
  #(parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
   
    , parameter ruche_factor_X_p="inv"
 
    , parameter tieoff_west_p="inv"
    , parameter tieoff_east_p="inv"
    , parameter tieoff_proc_p=0

    , parameter dims_lp=3 // only support 3

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter ruche_x_link_sif_width_lp =
      `bsg_manycore_ruche_x_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  ( 
    input clk_i
    , input reset_i
    
    , input  [S:W][link_sif_width_lp-1:0] link_sif_i
    , output [S:W][link_sif_width_lp-1:0] link_sif_o

    , input  [link_sif_width_lp-1:0] proc_link_sif_i
    , output [link_sif_width_lp-1:0] proc_link_sif_o

    , input  [E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_i
    , output [E:W][ruche_x_link_sif_width_lp-1:0] ruche_link_o
    
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );

  // RE, RW, S, N, E, W
  localparam stub_lp = {
    (tieoff_east_p ? 1'b1 : 1'b0), // RE  
    (tieoff_west_p ? 1'b1 : 1'b0), // RW
    2'b00,  // S, N
    (tieoff_east_p ? 1'b1 : 1'b0), // E  
    (tieoff_west_p ? 1'b1 : 1'b0)  // W
  };


  `declare_bsg_manycore_ruche_x_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_ruche_x_link_sif_s [E:W] ruche_link_in;
  bsg_manycore_ruche_x_link_sif_s [E:W] ruche_link_out;
  assign ruche_link_in = ruche_link_i;
  assign ruche_link_o = ruche_link_out;


  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_link_sif_s [RE:W] link_sif_li;
  bsg_manycore_link_sif_s [RE:W] link_sif_lo;
  bsg_manycore_link_sif_s proc_link_sif_li;
  bsg_manycore_link_sif_s proc_link_sif_lo;

  localparam fwd_use_credits_lp = 7'b0000000;
  localparam int fwd_fifo_els_lp[dims_lp*2:0] = '{2,2,2,2,2,2,2};
  localparam rev_use_credits_lp = 7'b0000000;
  localparam int rev_fifo_els_lp[dims_lp*2:0] = '{2,2,2,2,2,2,2};


  bsg_manycore_mesh_node #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.dims_p(dims_lp)
    ,.ruche_factor_X_p(ruche_factor_X_p)
    ,.stub_p(stub_lp) 

    ,.fwd_use_credits_p(fwd_use_credits_lp)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp)
    ,.rev_use_credits_p(rev_use_credits_lp)
    ,.rev_fifo_els_p(rev_fifo_els_lp)
  ) rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.links_sif_i(link_sif_li)
    ,.links_sif_o(link_sif_lo)

    ,.proc_link_sif_i(proc_link_sif_li)
    ,.proc_link_sif_o(proc_link_sif_lo)

    ,.global_x_i(global_x_i)
    ,.global_y_i(global_y_i)
  );

  if (tieoff_proc_p) begin
    assign proc_link_sif_li = '0;
    assign proc_link_sif_o = '0;
  end
  else begin
    assign proc_link_sif_li = proc_link_sif_i;
    assign proc_link_sif_o = proc_link_sif_lo;
  end

  // connect N,S
  assign link_sif_o[N] = link_sif_lo[N];
  assign link_sif_li[N] = link_sif_i[N];
  assign link_sif_o[S] = link_sif_lo[S];
  assign link_sif_li[S] = link_sif_i[S];


  // west link
  if (tieoff_west_p) begin: tw
    assign link_sif_li[W] = '0;
    assign link_sif_li[RW] = '0;
  end
  else begin: tnw
    // local
    assign link_sif_li[W] = link_sif_i[W];
    assign link_sif_o[W] = link_sif_lo[W];
    // ruche
    assign link_sif_li[RW].fwd = 
      `bsg_manycore_ruche_x_link_fwd_inject_src_y(x_cord_width_p,y_cord_width_p,ruche_link_in[W].fwd, global_y_i);
    assign link_sif_li[RW].rev = 
      `bsg_manycore_ruche_x_link_rev_inject_dest_y(x_cord_width_p,y_cord_width_p,ruche_link_in[W].rev, global_y_i);
    assign ruche_link_out[W].fwd =
      `bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_p,y_cord_width_p,link_sif_lo[RW].fwd);
    assign ruche_link_out[W].rev =
      `bsg_manycore_link_sif_rev_filter_dest_y(x_cord_width_p,y_cord_width_p,link_sif_lo[RW].rev);
  end


 
  // east link
  if (tieoff_east_p) begin
    assign link_sif_li[E] = '0;
    assign link_sif_li[RE] = '0;
  end
  else begin
    // local
    assign link_sif_li[E] = link_sif_i[E];
    assign link_sif_o[E] = link_sif_lo[E];
    // ruche
    assign link_sif_li[RE].fwd = 
      `bsg_manycore_ruche_x_link_fwd_inject_src_y(x_cord_width_p,y_cord_width_p,ruche_link_in[E].fwd, global_y_i);
    assign link_sif_li[RE].rev = 
      `bsg_manycore_ruche_x_link_rev_inject_dest_y(x_cord_width_p,y_cord_width_p,ruche_link_in[E].rev, global_y_i);
    assign ruche_link_out[E].fwd =
      `bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_p,y_cord_width_p,link_sif_lo[RE].fwd);
    assign ruche_link_out[E].rev =
      `bsg_manycore_link_sif_rev_filter_dest_y(x_cord_width_p,y_cord_width_p,link_sif_lo[RE].rev);
  end


endmodule
