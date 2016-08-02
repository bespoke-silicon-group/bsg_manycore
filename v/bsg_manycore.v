`include "bsg_manycore_packet.vh"

module bsg_manycore

import bsg_noc_pkg::*; // {P=0, W, E, N, S}

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
   ,parameter num_tiles_x_p     = "inv"
   ,parameter num_tiles_y_p     = "inv"

   // array i/o params
   ,parameter stub_w_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_e_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_n_p          = {num_tiles_x_p{1'b0}}
   ,parameter stub_s_p          = {num_tiles_x_p{1'b0}}

   ,parameter debug_p           = 0

   ,parameter x_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_x_p)
   ,parameter y_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_y_p + 1)
   ,parameter bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)
  )
  ( input clk_i
   ,input reset_i

   // horizontal -- {E,W}
   ,input  [E:W][num_tiles_y_p-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_i
   ,output [E:W][num_tiles_y_p-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_o

   // vertical -- {S,N}
   ,input   [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_i
   ,output  [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_o
  );

  // synopsys translate off
  initial
  begin
    assert ((num_tiles_x_p > 0) && (num_tiles_y_p>0))
      else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
  end
  // synopsys translate on

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);

   bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_in;
   bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_out;

  /* TILES */

  genvar r,c;

  for (r = 0; r < num_tiles_y_p; r = r+1)
  begin: tile_row_gen
    for (c = 0; c < num_tiles_x_p; c = c+1)
    begin: tile_col_gen
      bsg_manycore_tile #
      ( .dirs_p        (dirs_p)
       ,.stub_p        ({ (r == num_tiles_y_p-1) ? (((stub_s_p>>c) & 1'b1) == 1) : 1'b0 // s
                         ,(r == 0)               ? (((stub_n_p>>c) & 1'b1) == 1) : 1'b0 // n
                         ,(c == num_tiles_x_p-1) ? (((stub_e_p>>r) & 1'b1) == 1) : 1'b0 // e
                         ,(c == 0)               ? (((stub_w_p>>r) & 1'b1) == 1) : 1'b0 // w
                        }
                       )
        ,.x_cord_width_p  (x_cord_width_lp)
        ,.y_cord_width_p  (y_cord_width_lp)
        ,.bank_size_p  (bank_size_p)
        ,.num_banks_p  (num_banks_p)
        ,.data_width_p (data_width_p)
        ,.addr_width_p (addr_width_p)
        ,.debug_p      (debug_p)
       ) tile
       ( .clk_i (clk_i)
         ,.reset_i(reset_i)

         ,.links_sif_i (link_in [r][c])
         ,.links_sif_o (link_out[r][c])

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
