//====================================================================
// mesh_top_example.v
// 04/10/2018, shawnless.xie@gmail.com
//====================================================================
// This module instantiate an mesh router, a slave and master
//
//     (Y,X=0,0)   MASTER   TIED
//                    \      |
//                     \     |
//                      |----------|
//               TIED---| ROUTER   | --- SLAVE (Y,X = 0,1)
//                      |----------|
//                           |
//                           |
//                         TIED
//
`include "bsg_manycore_packet.vh"

module mesh_top_example #(   x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32
                            ,addr_width_p           = 32
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                           )
   (  input     clk_i
    , input     reset_i

    , output    finish_o
   );

    //which direction of the router should be stubbed
    localparam stub_lp  ={1'b1, 1'b1, 1'b0, 1'b1}  ;// {s,n,e,w}
    localparam w_idx_lp =bsg_noc_pkg::W            ;// index of the direction starts from West
    localparam s_idx_lp =bsg_noc_pkg::S            ;// index of the direction ends at South

    // the interconnections
    wire [bsg_manycore_link_sif_width_lp-1:0]                       master_link_sif_li, master_link_sif_lo;
    wire [s_idx_lp : w_idx_lp][bsg_manycore_link_sif_width_lp-1:0]  router_link_sif_li, router_link_sif_lo;

   // Instantiate the router and connects the master
    bsg_manycore_mesh_node #(
       .stub_p           ( stub_lp       )
      ,.x_cord_width_p   (x_cord_width_p )
      ,.y_cord_width_p   (y_cord_width_p )
      ,.data_width_p     (data_width_p   )
      ,.addr_width_p     (addr_width_p   )
    )mesh_node
    (
       .clk_i            (clk_i                  )
      ,.reset_i          (reset_i                )
      ,.links_sif_i      (router_link_sif_li     )
      ,.links_sif_o      (router_link_sif_lo     )
      ,.proc_link_sif_i  (master_link_sif_lo     )
      ,.proc_link_sif_o  (master_link_sif_li     )
      ,.my_x_i           ( x_cord_width_p'(0)    )
      ,.my_y_i           ( y_cord_width_p'(0)    )
    );

  //Instantiate the master
  mesh_master_example
  #(
       .x_cord_width_p   (x_cord_width_p )
      ,.y_cord_width_p   (y_cord_width_p )
      ,.data_width_p     (data_width_p   )
      ,.addr_width_p     (addr_width_p   )
  )master
   (  .clk_i
    , .reset_i

    // mesh network
    , .link_sif_i       ( master_link_sif_li )
    , .link_sif_o       ( master_link_sif_lo )

    , .my_x_i           ( x_cord_width_p'(0) )
    , .my_y_i           ( y_cord_width_p'(0) )

    , .dest_x_i         ( x_cord_width_p'(1) )
    , .dest_y_i         ( y_cord_width_p'(0) )

    , .finish_o
    );

  //Instantiate the slave
  mesh_slave_example
  #(
       .x_cord_width_p   (x_cord_width_p )
      ,.y_cord_width_p   (y_cord_width_p )
      ,.data_width_p     (data_width_p   )
      ,.addr_width_p     (addr_width_p   )
  )slave
   (  .clk_i
    , .reset_i

    // mesh network
    , .link_sif_i       ( router_link_sif_lo[ bsg_noc_pkg::E ] )
    , .link_sif_o       ( router_link_sif_li[ bsg_noc_pkg::E ] )

    , .my_x_i           ( x_cord_width_p'(1) )
    , .my_y_i           ( x_cord_width_p'(0) )
  );


  //tie up the stubbed routers
  genvar i;
  for( i= w_idx_lp; i <= s_idx_lp; i++) begin:tie_up // {P=0, W, E, N, S}
        if( stub_lp [  (i-w_idx_lp) ] ) begin //this direction is stubbed
                bsg_manycore_link_sif_tieoff
                #(.addr_width_p  (addr_width_p  )
                 ,.data_width_p  (data_width_p  )
                 ,.x_cord_width_p(x_cord_width_p)
                 ,.y_cord_width_p(y_cord_width_p)
                ) bmlst
                (        .clk_i
                        ,.reset_i
                        ,.link_sif_i( router_link_sif_lo [ i ] )
                        ,.link_sif_o( router_link_sif_li [ i ] )
                );

        end
   end

endmodule
