`include "bsg_manycore_packet.vh"

`ifdef bsg_FPU
`include "float_definitions.v"
`endif
module bsg_manycore
  import bsg_noc_pkg::*; // {P=0, W,E,N,S }

 #(// tile params
   parameter bank_size_p       = "inv"

   // increasing the number of banks decreases ram efficiency
   // but reduces conflicts between remote stores and local data accesses
   // If there are too many conflicts, than traffic starts backing up into
   // the network (i.e. cgni full cycles).

   ,parameter num_banks_p       = "inv"

   // array params
   ,parameter num_tiles_x_p     = -1
   ,parameter num_tiles_y_p     = -1

   // array i/o params
   ,parameter stub_w_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_e_p          = {num_tiles_y_p{1'b0}}
   ,parameter stub_n_p          = {num_tiles_x_p{1'b0}}
   ,parameter stub_s_p          = {num_tiles_x_p{1'b0}}

   // for heterogeneous, this is a vector of num_tiles_x_p*num_tiles_y_p bytes;
   // each byte contains the type of core being instantiated
   // type 0 is the standard core

   ,parameter hetero_type_vec_p      = 0

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

   wire [num_tiles_y_p-1:0][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_li;
   wire [num_tiles_y_p-1:0][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_lo;

   bsg_manycore_mesh #(.num_tiles_x_p(num_tiles_x_p)
                       ,.num_tiles_y_p(num_tiles_y_p)
                       ,.stub_w_p(stub_w_p)
                       ,.stub_e_p(stub_e_p)
                       ,.stub_n_p(stub_n_p)
                       ,.stub_s_p(stub_s_p)
                       ,.debug_p(debug_p)
                       ,.extra_io_rows_p(extra_io_rows_p)
                       ,.addr_width_p(addr_width_p)
                       ,.data_width_p(data_width_p)
                       ) bmm
     (.clk_i
      ,.reset_i

      ,.hor_link_sif_i
      ,.hor_link_sif_o

      ,.ver_link_sif_i
      ,.ver_link_sif_o

      ,.proc_link_sif_i(proc_link_sif_li)
      ,.proc_link_sif_o(proc_link_sif_lo)
      );

   genvar r,c;

`ifdef bsg_FPU 
  //The array of the interface between FAM and tile
  f_fam_in_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0]  fam_in_s_v;
  f_fam_out_s[num_tiles_y_p-1:0][num_tiles_x_p-1:0]  fam_out_s_v;

  for (r = 0; r < num_tiles_y_p; r = r+1)
  begin: fam_row_gen
    for (c = 0; c < num_tiles_x_p; c = c+2)
    begin: fam_col_gen
            fam # (.in_data_width_p ( RV32_mac_input_width_gp  )
                  ,.out_data_width_p( RV32_mac_output_width_gp )
                  ,.num_fifo_p      ( 2                      )
                  ,.num_pipe_p      ( 3                      )
                  )
                fam_g(
                 .clk_i      ( clk_i                 )
                ,.reset_i    ( reset_i               )
                ,.fam_in_s_i ( {fam_in_s_v [r][ c+1], fam_in_s_v[r][ c ]})
                ,.fam_out_s_o( {fam_out_s_v[r][ c+1], fam_out_s_v[r][ c ]})
                );
    end
  end
`endif

   for (r = 0; r < num_tiles_y_p; r = r+1)
     begin: y
        for (c = 0; c < num_tiles_x_p; c=c+1)
          begin: x
             bsg_manycore_hetero_socket #(
                                          .x_cord_width_p (x_cord_width_lp)
                                          ,.y_cord_width_p(y_cord_width_lp)
                                          ,.debug_p       (debug_p       )
                                          ,.bank_size_p   (bank_size_p   )
                                          ,.num_banks_p   (num_banks_p   )
                                          ,.data_width_p  (data_width_p  )
                                          ,.addr_width_p  (addr_width_p  )
                                          ,.hetero_type_p  ((hetero_type_vec_p >> (8*(r*num_tiles_x_p + c))) & 8'b1111_1111)
                                          ) proc
                 (.clk_i   (clk_i)
                  ,.reset_i(reset_i)

           `ifdef bsg_FPU
                  ,.fam_in_s_o (  fam_in_s_v [r][c ] ) 
                  ,.fam_out_s_i(  fam_out_s_v[r][c ] )
           `endif
                  ,.link_sif_i(proc_link_sif_lo[r][c])
                  ,.link_sif_o(proc_link_sif_li[r][c])

                  ,.my_x_i   (x_cord_width_lp'(c))
                  ,.my_y_i   (y_cord_width_lp'(r))

                  ,.freeze_o()
                  );
          end
     end
  //synopsys translate_off
  `ifdef bsg_FPU
  initial
  begin
    assert ( (num_tiles_x_p % 2 ) == 0 )
      else $error("num_tiles_x_p must be even for the shared FPU option");
  end
  `endif
  //synopsys translate on
endmodule
