`include "bsg_manycore_packet.vh"

module bsg_manycore

import bsg_vscale_pkg::*
       , bsg_noc_pkg::*; // {P=0, W, E, N, S}

 #(// tile params
    parameter dirs_p            = 4
   ,parameter fifo_els_p        = 2
   ,parameter bank_size_p       = "inv"

   // increasing the number of banks decreases ram efficiency
   // but reduces conflicts between remote stores and local data accesses
   // If there are too many conflicts, than traffic starts backing up into
   // the network (i.e. cgni full cycles).

   ,parameter num_banks_p       = "inv"
   ,parameter data_width_p      = hdata_width_p
   ,parameter addr_width_p      = haddr_width_p

   // array params
   ,parameter num_tiles_x_p     = "inv"
   ,parameter num_tiles_y_p     = "inv"
   ,parameter x_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_x_p)
   ,parameter y_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_y_p + 1)
   ,parameter packet_width_lp        = `bsg_manycore_packet_width       (addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)
   ,parameter return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_lp,y_cord_width_lp)
   // array i/o params
   ,parameter stub_w_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_e_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_n_p          = {num_tiles_x_p{1'b0}}
   ,parameter stub_s_p          = {num_tiles_x_p{1'b0}}

   ,parameter debug_p           = 0

   ,parameter num_nets_lp       = 2
  )
  ( input clk_i
   ,input reset_i

   // horizontal -- {E,W}
   ,input  [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0]        hor_data_i
   ,input  [E:W][num_tiles_y_p-1:0][return_packet_width_lp-1:0] hor_return_data_i

   ,input  [E:W][num_tiles_y_p-1:0][num_nets_lp-1:0]            hor_v_i
   ,output [E:W][num_tiles_y_p-1:0][num_nets_lp-1:0]            hor_ready_o
   ,output [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0]        hor_data_o
   ,output [E:W][num_tiles_y_p-1:0][return_packet_width_lp-1:0] hor_return_data_o

   ,output [E:W][num_tiles_y_p-1:0][num_nets_lp-1:0]     hor_v_o
   ,input  [E:W][num_tiles_y_p-1:0][num_nets_lp-1:0]     hor_ready_i

   // vertical -- {S,N}
   ,input  [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0]        ver_data_i
   ,input  [S:N][num_tiles_x_p-1:0][return_packet_width_lp-1:0] ver_return_data_i

   ,input  [S:N][num_tiles_x_p-1:0][num_nets_lp-1:0]     ver_v_i
   ,output [S:N][num_tiles_x_p-1:0][num_nets_lp-1:0]     ver_ready_o

    ,output [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0]        ver_data_o
    ,output [S:N][num_tiles_x_p-1:0][return_packet_width_lp-1:0] ver_return_data_o

    ,output [S:N][num_tiles_x_p-1:0][num_nets_lp-1:0]     ver_v_o
    ,input  [S:N][num_tiles_x_p-1:0][num_nets_lp-1:0]     ver_ready_i
  );

  // synopsys translate off
  initial
  begin
    assert ((num_tiles_x_p > 0) && (num_tiles_y_p>0))
      else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
  end
  // synopsys translate on



  /* TILES */

  // tiles' outputs WENS
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W][packet_width_lp-1:0       ]        data_out,        data_in;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W][return_packet_width_lp-1:0] return_data_out, return_data_in;

  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][num_nets_lp-1:0][S:W]     v_out,     v_in;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][num_nets_lp-1:0][S:W] ready_out, ready_in;

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

         ,.data_i        (       data_in  [r][c])
         ,.return_data_i (return_data_in  [r][c])
         ,.v_i           (v_in     [r][c])
         ,.ready_o       (ready_out[r][c])

         ,.data_o        (data_out       [r][c])
         ,.return_data_o (return_data_out[r][c])
         ,.v_o           (v_out          [r][c])
         ,.ready_i       (ready_in       [r][c])

        ,.my_x_i   (x_cord_width_lp'(c))
        ,.my_y_i   (y_cord_width_lp'(r))
      );
    end
  end

   // stitch together all of the tiles into a mesh
   bsg_mesh_stitch #(.width_p(packet_width_lp), .x_max_p(num_tiles_x_p), .y_max_p(num_tiles_y_p)) data
     (.outs_i(data_out),   .ins_o(data_in)
      ,.hor_i(hor_data_i), .hor_o(hor_data_o)
      ,.ver_i(ver_data_i), .ver_o(ver_data_o)
      );

   bsg_mesh_stitch #(.width_p(return_packet_width_lp), .x_max_p(num_tiles_x_p), .y_max_p(num_tiles_y_p)) return_data
     (.outs_i(return_data_out), .ins_o(return_data_in)
      ,.hor_i(hor_return_data_i), .hor_o(hor_return_data_o)
      ,.ver_i(ver_return_data_i), .ver_o(ver_return_data_o)
      );

   bsg_mesh_stitch #(.width_p(1), .x_max_p(num_tiles_x_p), .y_max_p(num_tiles_y_p), .nets_p(num_nets_lp)) ready
     (.outs_i(ready_out),   .ins_o(ready_in)
      ,.hor_i(hor_ready_i), .hor_o(hor_ready_o)
      ,.ver_i(ver_ready_i), .ver_o(ver_ready_o)
      );

   bsg_mesh_stitch #(.width_p(1), .x_max_p(num_tiles_x_p), .y_max_p(num_tiles_y_p), .nets_p(num_nets_lp)) v
     (.outs_i(v_out),   .ins_o(v_in)
      ,.hor_i(hor_v_i), .hor_o(hor_v_o)
      ,.ver_i(ver_v_i), .ver_o(ver_v_o)
      );

endmodule
