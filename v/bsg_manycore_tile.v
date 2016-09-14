`include "bsg_manycore_packet.vh"
`include "bsg_noc_links.vh"

`ifdef bsg_FPU
 `include "float_definitions.v"
`endif

module bsg_manycore_tile

import bsg_noc_pkg::*; // {P=0, W, E, N, S}

 #( parameter dirs_p            = 4
   ,parameter stub_p            = {dirs_p{1'b0}} // {s,n,e,w}
   ,parameter x_cord_width_p       = 5
   ,parameter y_cord_width_p       = 5

   ,parameter bank_size_p       = -1 
   ,parameter num_banks_p       = -1
   ,parameter data_width_p      = 32 
   ,parameter addr_width_p      = 32 
   ,parameter mem_addr_width_lp = $clog2(num_banks_p) + `BSG_SAFE_CLOG2(bank_size_p)
   ,parameter packet_width_lp   = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

   ,parameter debug_p = 0
  )
  ( input                                       clk_i
   ,input                                       reset_i

   // input fifos
   ,input   [dirs_p-1:0] [packet_width_lp-1:0]  data_i
   ,input   [dirs_p-1:0]                        v_i
   ,output  [dirs_p-1:0]                        ready_o

   // output channels
   ,output  [dirs_p-1:0] [packet_width_lp-1:0]  data_o
   ,output  [dirs_p-1:0]                        v_o
   ,input   [dirs_p-1:0]                        ready_i

`ifdef bsg_FPU
   , input  f_fam_out_s                         fam_out_s_i 
   , output f_fam_in_s                          fam_in_s_o 
`endif

   // tile coordinates
   ,input   [x_cord_width_p-1:0]                 my_x_i
   ,input   [y_cord_width_p-1:0]                 my_y_i

  );

   logic [packet_width_lp-1:0] proc_to_router_data, router_to_proc_data;
   logic                       proc_to_router_ready, router_to_proc_ready, proc_to_router_v, router_to_proc_v;

   `declare_bsg_ready_and_link_sif_s(packet_width_lp,bsg_ready_and_link_sif_s);
    
   //The processor will add one direction;
   bsg_ready_and_link_sif_s [dirs_p:0] link_i_cast, link_o_cast;

   ///////////////////////////////////////////////
    genvar i;
    for( i=1; i<dirs_p +1; i++ ) 
    begin
        assign link_i_cast[i].v                 = v_i       [ i-1 ];
        assign link_i_cast[i].ready_and_rev     = ready_i   [ i-1 ];
        assign link_i_cast[i].data              = data_i    [ i-1 ];

        assign  v_o       [ i-1 ]   =link_o_cast[i].v                 ;
        assign  ready_o   [ i-1 ]   =link_o_cast[i].ready_and_rev     ;
        assign  data_o    [ i-1 ]   =link_o_cast[i].data              ;
    end 

    assign link_i_cast[0].v                 = proc_to_router_v      ;
    assign link_i_cast[0].ready_and_rev     = router_to_proc_ready  ;
    assign link_i_cast[0].data              = proc_to_router_data   ;

    assign router_to_proc_v         = link_o_cast[0].v              ;  
    assign proc_to_router_ready     = link_o_cast[0].ready_and_rev  ; 
    assign router_to_proc_data      = link_o_cast[0].data           ; 
   ///////////////////////////////////////////////

   bsg_mesh_router_buffered #(.width_p(packet_width_lp)
                              ,.x_cord_width_p(x_cord_width_p)
                              ,.y_cord_width_p(y_cord_width_p)
                              ,.debug_p(debug_p)
                              // adding proc into stub
                              ,.stub_p({stub_p, 1'b0})
                              ) bmrb
     (.clk_i   (clk_i)
      ,.reset_i(reset_i)
      ,.link_i (link_i_cast )
      ,.link_o (link_o_cast ) 
      ,.my_x_i
      ,.my_y_i
      );

   logic 		       freeze;

   bsg_manycore_proc #(
                       .x_cord_width_p (x_cord_width_p)
                       ,.y_cord_width_p(y_cord_width_p)
                       ,.debug_p       (debug_p)
                       ,.bank_size_p   (bank_size_p)
                       ,.num_banks_p   (num_banks_p)
                       ,.data_width_p  (data_width_p)
                       ,.addr_width_p  (addr_width_p)
                       ) proc
   (.clk_i   (clk_i)
    ,.reset_i(reset_i)
    ,.v_i    (router_to_proc_v)

    ,.data_i (router_to_proc_data)
    ,.ready_o(router_to_proc_ready)
    ,.v_o    (proc_to_router_v)
    ,.data_o (proc_to_router_data)
    ,.ready_i(proc_to_router_ready)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)

`ifdef bsg_FPU
    ,.fam_in_s_o (fam_in_s_o    )
    ,.fam_out_s_i(fam_out_s_i   )
`endif

    ,.freeze_o(freeze)
    );


endmodule

