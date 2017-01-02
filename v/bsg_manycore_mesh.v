`include "bsg_manycore_packet.vh"

module bsg_manycore_mesh

import bsg_noc_pkg::*; // {P=0, W, E, N, S}

 #(
   // array params
   parameter num_tiles_x_p      = -1
   ,parameter num_tiles_y_p     = -1

   // array i/o params
   ,parameter stub_w_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_e_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_n_p          = {num_tiles_x_p{1'b0}}
   ,parameter stub_s_p          = {num_tiles_x_p{1'b0}}

   // enable debugging
   ,parameter debug_p           = 0

   // this control how many extra IO rows are addressable in
   // the network outside of the manycore array

   ,parameter extra_io_rows_p   = 1

   // this parameter sets the size of addresses that are transmitted in the network
   // and corresponds to the amount of physical words that are addressable by a remote
   // tile. here are some various settings:
   //
   // 30: maximum value, i.e. 2^30 words.
   // 20: maximum value to allow for traversal over a bsg_fsb
   // 13: value for 8 banks of 1024 words of ram in each tile
   //
   // obviously smaller values take up less die area.
   //

   ,parameter addr_width_p      = "inv"

   ,parameter x_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_x_p)
   ,parameter y_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_y_p + extra_io_rows_p) // extra row for I/O at bottom of chip


   // changing this parameter is untested

   ,parameter data_width_p      = 32

   ,parameter bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)

   // insert bufx8's on outputs
   ,parameter repeater_output_p  = 0 //   snew * x * y bits.
   
  )
  ( input clk_i
   ,input reset_i

   // horizontal -- {E,W}
   ,input  [E:W][num_tiles_y_p-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_i
   ,output [E:W][num_tiles_y_p-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_o

   // vertical -- {S,N}
   ,input   [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_i
   ,output  [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_o

   ,input  [num_tiles_y_p-1:0][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_i
   ,output [num_tiles_y_p-1:0][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_o
  );

  // synopsys translate_off
  initial
  begin
     assert ((num_tiles_x_p > 0) && (num_tiles_y_p>0))
       else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");

     $display("$bits(addr)=%-d, $bits(op)=%-d, $bits(op_ex)=%-d, $bits(data)=%-d, $bits(return_pkt)=%-d, $bits(y_cord)=%-d, $bits(x_cord)=%-d",
              addr_width_p,2,(data_width_p>>3),data_width_p,y_cord_width_lp+x_cord_width_lp,y_cord_width_lp,x_cord_width_lp);
  end
  // synopsys translate_on

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);

   bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_in;
   bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_out;

   localparam dirs_lp = 4;

  /* TILES */

  genvar r,c;

  for (r = 0; r < num_tiles_y_p; r = r+1)
  begin: y
    for (c = 0; c < num_tiles_x_p; c = c+1)
    begin: x
      bsg_manycore_mesh_node #
      (.stub_p        ({ (r == num_tiles_y_p-1) ? (((stub_s_p>>c) & 1'b1) == 1) : 1'b0  // s
                         ,(r == 0)               ? (((stub_n_p>>c) & 1'b1) == 1) : 1'b0 // n
                         ,(c == num_tiles_x_p-1) ? (((stub_e_p>>r) & 1'b1) == 1) : 1'b0 // e
                         ,(c == 0)               ? (((stub_w_p>>r) & 1'b1) == 1) : 1'b0 // w
                        }
                       )
        ,.x_cord_width_p  (x_cord_width_lp)
        ,.y_cord_width_p  (y_cord_width_lp)
        ,.data_width_p   (data_width_p)
        ,.addr_width_p   (addr_width_p)
        ,.debug_p        (debug_p)
       // select buffer instructions for this particular node
       ,.repeater_output_p(  (repeater_output_p >> (4*(r*num_tiles_x_p+c))) & 4'b1111)
       ) rtr
       ( .clk_i (clk_i)
         ,.reset_i(reset_i)

         ,.links_sif_i (link_in [r][c])
         ,.links_sif_o (link_out[r][c])

         ,.proc_link_sif_i(proc_link_sif_i [r][c])
         ,.proc_link_sif_o(proc_link_sif_o [r][c])

         ,.my_x_i   (x_cord_width_lp'(c))
         ,.my_y_i   (y_cord_width_lp'(r))
      );
    end
  end

   // stitch together all of the tiles into a mesh

   bsg_mesh_stitch #(.width_p(bsg_manycore_link_sif_width_lp), .x_max_p(num_tiles_x_p), .y_max_p(num_tiles_y_p)) link
     (.outs_i(link_out),   .ins_o(link_in)
      ,.hor_i(hor_link_sif_i), .hor_o(hor_link_sif_o)
      ,.ver_i(ver_link_sif_i), .ver_o(ver_link_sif_o)
      );

endmodule
