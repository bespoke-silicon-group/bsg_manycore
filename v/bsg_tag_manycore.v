// bsg_tag_manycre, bsg_manycore with bsg_tag interface.
//
// 9/20/2016, shawnless.xie@gmail.com
//
// < id >         < data_not_reset > < payload length >          <  payload >
// ****************************************************************************
// $clog2(els_p+1)      1        $clog2(max_payload_length+1)  (variable size)
//
// To reset slave nodes, set data_not_reset to 0, and payload to 1's.

`include "bsg_manycore_packet.vh"
`include "bsg_tag.vh"

`ifndef bsg_FPU
`include "float_definitions.v"
`endif
module bsg_tag_manycore

import bsg_noc_pkg::*; // {P=0, W, E, N, S}
import bsg_tag_pkg::bsg_tag_s;

 #(// tile params
    parameter dirs_p            = 4
   ,parameter fifo_els_p        = 2
   ,parameter bank_size_p       = "inv" 

   // increasing the number of banks decreases ram efficiency
   // but reduces conflicts between remote stores and local data accesses
   // If there are too many conflicts, than traffic starts backing up into
   // the network (i.e. cgni full cycles).

   ,parameter num_banks_p       = "inv" 
   ,parameter data_width_p      = 32 
   ,parameter addr_width_p      = 32 

   // array params
   ,parameter num_tiles_x_p     = -1 
   ,parameter num_tiles_y_p     = -1
   ,parameter x_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_x_p)
   ,parameter y_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_y_p + 1)
   ,parameter packet_width_lp   = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)

   // array i/o params
   ,parameter stub_w_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_e_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_n_p          = {num_tiles_x_p{1'b0}}
   ,parameter stub_s_p          = {num_tiles_x_p{1'b0}}

   ,parameter debug_p           = 0
  )
  ( input clk_i
   ,input reset_i

   // East I/O is used for bsg_tag injection
   ,input tag_clk_i
   ,input tag_en_i
   ,input tag_data_i
  
   //indicating that test is done. which should connect to the JTAG_TDO 
   ,output done_r_o
  );

   localparam   finish_code_lp = 20'hDEAD_0;
   localparam   lg_packet_width_lp = `BSG_SAFE_CLOG2(packet_width_lp);

   logic [S:N][num_tiles_x_p-1:0]                      ver_v_in, ver_v_out;
   logic [S:N][num_tiles_x_p-1:0]                      ver_ready_in;
   logic [S:N][num_tiles_x_p-1:0]                      ver_ready_out;
   logic [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0] ver_data_in, ver_data_out;
   logic [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0] hor_data_in;
   logic [E:W][num_tiles_y_p-1:0]                      hor_v_in;
   logic [E:W][num_tiles_y_p-1:0]                      hor_ready_out;
   logic [E:W][num_tiles_y_p-1:0]                      hor_ready_in;

 
   //The East I/O will be connected to bsg_tag 
   bsg_tag_s [num_tiles_y_p-1:0]                  tag_clients;

/////////////////////////////////////////////////////////////////////////
//Instantiate the bsg_tag master 
 bsg_tag_master #(
      .els_p     ( num_tiles_y_p      ) 
     ,.lg_width_p( lg_packet_width_lp )
 ) manycore_tag_master (
     .clk_i         (tag_clk_i  )
    ,.en_i          (tag_en_i   )
    ,.data_i        (tag_data_i )
    ,.clients_r_o   (tag_clients)
    );

/////////////////////////////////////////////////////////////////////////
//Instantiate the bsg_tag clients
genvar i;

for(i=0; i< num_tiles_y_p; i++)
begin:bsg_manycore_tag_clients
    bsg_tag_client#( 
         .width_p       ( packet_width_lp )
        ,.default_p     ( 0               )
        ,.harden_p      ( 1               )
    )bsg_tag_client_gen(
         .bsg_tag_i     ( tag_clients[i]  )
        ,.recv_clk_i    ( clk_i           )
//        ,.recv_reset_i  ( 1'b0            )
        ,.recv_reset_i  ( reset_i                )
        ,.recv_new_r_o  ( hor_v_in[W][i]        )
        ,.recv_data_r_o ( hor_data_in[W][i]     )
    );
    assign hor_ready_in[W][i] = 1'b1; 
end

/*
always_ff @( negedge clk_i )
begin
  if( hor_v_in[W][0] ) $display("bsg_tag_manycore: %b", hor_data_in[W][0]);
end
*/

/////////////////////////////////////////////////////////////////////////
//Instantiate the bsg_manycore
bsg_manycore #(
    .dirs_p         ( dirs_p         ) 
   ,.fifo_els_p     ( fifo_els_p     ) 
   ,.bank_size_p    ( bank_size_p    )  

   ,.num_banks_p    ( num_banks_p    ) 
   ,.data_width_p   ( data_width_p   )
   ,.addr_width_p   ( addr_width_p   )
   
   ,.num_tiles_x_p  ( num_tiles_x_p  )
   ,.num_tiles_y_p  ( num_tiles_y_p  )
   ,.x_cord_width_lp( x_cord_width_lp)
   ,.y_cord_width_lp( y_cord_width_lp)
   ,.packet_width_lp( packet_width_lp)
  
   ,.stub_w_p       ( stub_w_p       )
   ,.stub_e_p       ( stub_e_p       )
   ,.stub_n_p       ( stub_n_p       )
   ,.stub_s_p       ( stub_s_p       )
 
   ,.debug_p        ( debug_p        )
  
) manycore_0(
   .clk_i 
  ,.reset_i

  ,.hor_data_i  ( hor_data_in   )
  ,.hor_v_i     ( hor_v_in      )
  ,.hor_ready_o ( hor_ready_out )
  ,.hor_data_o  ( )
  ,.hor_v_o     ( )
  ,.hor_ready_i ( hor_ready_in  )

  ,.ver_data_i  ( ver_data_in   )
  ,.ver_v_i     ( ver_v_in      )
  ,.ver_ready_o ( ver_ready_out )
  ,.ver_data_o  ( ver_data_out  )
  ,.ver_v_o     ( ver_v_out     )
  ,.ver_ready_i ( ver_ready_in  )
);

  assign ver_data_in = (2*num_tiles_x_p*packet_width_lp)'(0);
  assign ver_v_in  = (2*num_tiles_x_p)'(0);
   // absorb all outgoing packets
  assign ver_ready_in   = { (2*num_tiles_x_p) {1'b1}};
 
  //West data have injected by tag
  assign hor_data_in[E] = (num_tiles_y_p*packet_width_lp)'(0) ;
  assign hor_v_in[E]    = (num_tiles_y_p)'(0)               ;
   // absorb all outgoing packets
  assign hor_ready_in[E]   = { (num_tiles_y_p) {1'b1}};


  localparam lg_node_x_lp    = `BSG_SAFE_CLOG2(num_tiles_x_p);
  localparam lg_node_y_lp    = `BSG_SAFE_CLOG2(num_tiles_y_p + 1);

  logic finish_lo;
  bsg_nonsynth_manycore_monitor #(.xcord_width_p(lg_node_x_lp)
                                   ,.ycord_width_p(lg_node_y_lp)
                                   ,.addr_width_p(addr_width_p)
                                   ,.data_width_p(data_width_p)
                                   ,.num_channels_p(num_tiles_x_p)
                                   ,.max_cycles_p(1000000000)
                                   ) bmm (.clk_i(clk_i)
                                          ,.reset_i (reset_i)
                                          ,.data_i(ver_data_out[S])
                                          ,.v_i (ver_v_out [S])
                                          ,.finish_o (finish_lo)
                                          );



/////////////////////////////////////////////////////////////////////////
// the finish detection logic
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, num_tiles_x_p, num_tiles_y_p);
   bsg_manycore_packet_s [num_tiles_y_p-1:0]      pkt_cast;
   wire                  [num_tiles_y_p-1:0]      S_finish_v;
   logic                                          done_r;
   assign pkt_cast = ver_data_out[S];

   genvar                       k;
   for (k = 0; k < num_tiles_x_p ; k=k+1)
   begin: finish_test
        assign S_finish_v[k] = ver_v_out[S][k] &  (pkt_cast[k].addr[19:0]  == finish_code_lp);
   end
   
   always_ff@(posedge clk_i ) 
   begin
    if( reset_i ) done_r <= 1'b0;
    else          done_r <= | S_finish_v;
   end

   assign done_r_o = done_r;

endmodule
