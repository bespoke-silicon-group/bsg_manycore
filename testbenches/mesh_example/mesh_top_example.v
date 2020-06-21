//====================================================================
// mesh_top_example.v
// 04/10/2018, shawnless.xie@gmail.com
//====================================================================
// This module instantiate an mesh router, a client and master
//
//  MASTER(0,0)   TIED          TIED       TIED      (Y, X)
//        \        |               \        |
//         \       |                \       |
//          |-------------|          |-------------|
//   TIED---| ROUTER(0,0) | ---------| ROUTER(0,1) | --- TIED
//          |-------------|          |-------------|
//                 |                        |
//                 |                        |
//               TIED                     SLAVE(1,1)
//
`include "bsg_manycore_packet.vh"

module mesh_top_example #(   x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,data_width_p           = 32
                            ,addr_width_p           = 32
                            ,load_id_width_p        = 11
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p, load_id_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                           )
   (  input     clk_i
    , input     reset_i

    , output    finish_o
   );

    //which direction of the router should be stubbed
    localparam w_idx_lp =bsg_noc_pkg::W            ;// index of the direction starts from West
    localparam s_idx_lp =bsg_noc_pkg::S            ;// index of the direction ends at South
    localparam nodes_lp =2                         ;// two nodes

    // the interconnections
    wire [nodes_lp-1:0] [s_idx_lp : w_idx_lp][bsg_manycore_link_sif_width_lp-1:0]  router_link_sif_li, router_link_sif_lo;
    wire [nodes_lp-1:0] [bsg_manycore_link_sif_width_lp-1:0]                       proc_link_sif_li, proc_link_sif_lo;

   // Instantiate the router and connects the master
   genvar i;
   for( i=0; i< nodes_lp; i++) begin
         bsg_manycore_mesh_node #(
                               // S         N         E         W
           //.stub_p           ({(i==0),   1'b1,    (i==1),  (i==0)} )
           //1. stub_p will only affect the synthesis, for simplicity, we can
           //   set the stub_p to 4'b0.
           //
           //2. We should use tieoff module for unused ports.
           .stub_p           ( 4'b0)
           ,.x_cord_width_p   (x_cord_width_p )
           ,.y_cord_width_p   (y_cord_width_p )
           ,.data_width_p     (data_width_p   )
           ,.addr_width_p     (addr_width_p   )
           ,.load_id_width_p  (load_id_width_p)
         )mesh_node
         (
            .clk_i            (clk_i                  )
           ,.reset_i          (reset_i                )
           ,.links_sif_i      (router_link_sif_li[i]  )
           ,.links_sif_o      (router_link_sif_lo[i]  )
           ,.proc_link_sif_i  (proc_link_sif_lo[i]    )
           ,.proc_link_sif_o  (proc_link_sif_li[i]    )
           ,.my_x_i           ( x_cord_width_p'(i)    )
           ,.my_y_i           ( y_cord_width_p'(0)    )
         );
  end

  assign router_link_sif_li[0][ bsg_noc_pkg::E ] = router_link_sif_lo[1][ bsg_noc_pkg::W ] ;
  assign router_link_sif_li[1][ bsg_noc_pkg::W ] = router_link_sif_lo[0][ bsg_noc_pkg::E ] ;

  //Instantiate the master
  mesh_master_example
  #(
       .x_cord_width_p   (x_cord_width_p )
      ,.y_cord_width_p   (y_cord_width_p )
      ,.data_width_p     (data_width_p   )
      ,.addr_width_p     (addr_width_p   )
      ,.load_id_width_p  (load_id_width_p)
  )master
   (  .clk_i
    , .reset_i

    // mesh network
    , .link_sif_i       ( proc_link_sif_li[0])
    , .link_sif_o       ( proc_link_sif_lo[0])

    , .my_x_i           ( x_cord_width_p'(0) )
    , .my_y_i           ( y_cord_width_p'(0) )

    , .dest_x_i         ( x_cord_width_p'(1) )
    , .dest_y_i         ( y_cord_width_p'(1) )

    , .finish_o
    );

  //Instantiate the slave
  mesh_slave_example
  #(
       .x_cord_width_p   (x_cord_width_p )
      ,.y_cord_width_p   (y_cord_width_p )
      ,.data_width_p     (data_width_p   )
      ,.addr_width_p     (addr_width_p   )
      ,.load_id_width_p  (load_id_width_p)
  )slave
   (  .clk_i
    , .reset_i

    // mesh network
    , .link_sif_i       ( router_link_sif_lo[1][ bsg_noc_pkg::S ] )
    , .link_sif_o       ( router_link_sif_li[1][ bsg_noc_pkg::S ] )

    , .my_x_i           ( x_cord_width_p'(1) )
    , .my_y_i           ( x_cord_width_p'(1) )
  );


  //tie up the stubbed routers
  genvar j;
  for( i=0; i< nodes_lp ; i++) begin
        for( j= w_idx_lp; j <= s_idx_lp; j++) begin:tie_up // {P=0, W, E, N, S}
              if(      ( i==0  && j != bsg_noc_pkg::E  )
                    || ( i==1  && (     j != bsg_noc_pkg::W 
                                    &&  j != bsg_noc_pkg::S 
                                  )
                       )
                )begin //this direction is stubbed
                      bsg_manycore_link_sif_tieoff
                      #(.addr_width_p  (addr_width_p  )
                       ,.data_width_p  (data_width_p  )
                       ,.x_cord_width_p(x_cord_width_p)
                       ,.y_cord_width_p(y_cord_width_p)
                       ,.load_id_width_p(load_id_width_p)
                      ) bmlst_router
                      (        .clk_i
                              ,.reset_i
                              ,.link_sif_i( router_link_sif_lo [ i ][ j ] )
                              ,.link_sif_o( router_link_sif_li [ i ][ j ] )
                      );

              end
         end
   end

   bsg_manycore_link_sif_tieoff
   #(.addr_width_p  (addr_width_p  )
    ,.data_width_p  (data_width_p  )
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
   ) bmlst_proc
   (        .clk_i
           ,.reset_i
           ,.link_sif_i( proc_link_sif_li  [ 1 ] )
           ,.link_sif_o( proc_link_sif_lo  [ 1 ] )
   );

endmodule
