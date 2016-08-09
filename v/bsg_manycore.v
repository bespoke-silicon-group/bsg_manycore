`include "bsg_manycore_packet.vh"

`ifndef bsg_FPU
`include "float_definitions.v"
`endif
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

   // horizontal -- {E,W}
   ,input  [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0] hor_data_i
   ,input  [E:W][num_tiles_y_p-1:0]                      hor_v_i
   ,output [E:W][num_tiles_y_p-1:0]                      hor_ready_o
   ,output [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0] hor_data_o
   ,output [E:W][num_tiles_y_p-1:0]                      hor_v_o
   ,input  [E:W][num_tiles_y_p-1:0]                      hor_ready_i

   // vertical -- {S,N}
   ,input  [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0] ver_data_i
   ,input  [S:N][num_tiles_x_p-1:0]                      ver_v_i
   ,output [S:N][num_tiles_x_p-1:0]                      ver_ready_o
   ,output [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0] ver_data_o
   ,output [S:N][num_tiles_x_p-1:0]                      ver_v_o
   ,input  [S:N][num_tiles_x_p-1:0]                      ver_ready_i
  );

  // synopsys translate off
  initial
  begin
    assert ((num_tiles_x_p > 0) && (num_tiles_y_p>0))
      else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
  end
  `ifdef bsg_FPU
  initial
  begin
    assert ( (num_tiles_x_p % 2 ) == 0 )
      else $error("num_tiles_x_p must be even for the shared FPU option");
  end
  `endif
  // synopsys translate on



  /* TILES */




  // tiles' outputs
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W][packet_width_lp-1:0] data_out;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W]                      v_out;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W]                      ready_out;

  genvar r,c;

`ifdef bsg_FPU 
  //The array of the interface between FAM and tile
  fpi_fam_inter  ff_inter[num_tiles_y_p][num_tiles_x_p]();

  for (r = 0; r < num_tiles_y_p; r = r+1)
  begin: fam_row_gen
    for (c = 0; c < num_tiles_x_p; c = c+1)
    begin: fam_col_gen
        if ( c %2 == 0 )
        begin: shared
            fam # (.in_data_width_p ( RV32_fam_input_width_gp)
                  ,.out_data_width_p( RV32_reg_data_width_gp )
                  ,.num_fifo_p      ( 2                      )
                  ,.num_pipe_p      ( 3                      )
                  )
                fam_g(
                 .clk_i     ( clk_i                 )
                ,.reset_i   ( reset_i               )
                ,.fpi_inter ( ff_inter[r][ c/2 : c/2+1 ] )
                );
        end
    end
  end
`endif


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

`ifdef bsg_FPU
        ,.fam_inter( ff_inter[r][c] )
`endif
        ,.data_i ({ (r == num_tiles_y_p-1)
                       ? ver_data_i[S][c]
                       : data_out[r+1][c][N] // s
                     ,(r == 0)
                       ? ver_data_i[N][c]
                       : data_out[r-1][c][S] // n
                     ,(c == num_tiles_x_p-1)
                       ? hor_data_i[E][r]
                       : data_out[r][c+1][W] // e
                     ,(c == 0)
                       ? hor_data_i[W][r]
                       : data_out[r][c-1][E] // w
                    }
                   )
        ,.v_i  ({ (r == num_tiles_y_p-1)
                       ? ver_v_i[S][c]
                       : v_out[r+1][c][N] // s
                     ,(r == 0)
                       ? ver_v_i[N][c]
                       : v_out[r-1][c][S] // n
                     ,(c == num_tiles_x_p-1)
                       ? hor_v_i[E][r]
                       : v_out[r][c+1][W] // e
                     ,(c == 0)
                       ? hor_v_i[W][r]
                       : v_out[r][c-1][E] // w
                    }
                   )
        ,.ready_o  (ready_out[r][c])

        ,.data_o  (data_out[r][c])
        ,.v_o  (v_out[r][c])
        ,.ready_i   (
                    { (r == num_tiles_y_p-1)
                       ? ver_ready_i[S][c]
                       : ready_out[r+1][c][N] // s
                     ,(r == 0)
                       ? ver_ready_i[N][c]
                       : ready_out[r-1][c][S] // n
                     ,(c == num_tiles_x_p-1)
                       ? hor_ready_i[E][r]
                       : ready_out[r][c+1][W] // e
                     ,(c == 0)
                       ? hor_ready_i[W][r]
                       : ready_out[r][c-1][E] // w
                    }
                   )

        ,.my_x_i   (x_cord_width_lp'(c))
        ,.my_y_i   (y_cord_width_lp'(r))
      );
    end
  end



  /* OUTPUTS */

  for(r = 0; r < num_tiles_y_p; r = r+1)
  begin: hor_outputs
    assign {hor_data_o [E][r], hor_data_o [W][r]} = {data_out [r][num_tiles_x_p-1][E], data_out [r][0][W]};
    assign {hor_v_o    [E][r], hor_v_o    [W][r]} = {v_out    [r][num_tiles_x_p-1][E], v_out    [r][0][W]};
    assign {hor_ready_o[E][r], hor_ready_o[W][r]} = {ready_out[r][num_tiles_x_p-1][E], ready_out[r][0][W]};
  end

  for(c = 0; c < num_tiles_x_p; c = c+1)
  begin: ver_outputs
    assign {ver_data_o [S][c], ver_data_o [N][c]} = {data_out [num_tiles_y_p-1][c][S], data_out [0][c][N]};
    assign {ver_v_o    [S][c], ver_v_o    [N][c]} = {v_out    [num_tiles_y_p-1][c][S], v_out    [0][c][N]};
    assign {ver_ready_o[S][c], ver_ready_o[N][c]} = {ready_out[num_tiles_y_p-1][c][S], ready_out[0][c][N]};
  end

   
endmodule
