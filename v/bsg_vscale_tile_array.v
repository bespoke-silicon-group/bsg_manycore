module bsg_vscale_tile_array

import bsg_vscale_pkg::*
       , bsg_noc_pkg::*; // {P=0, W, E, N, S}

 #(// tile params
    parameter dirs_p            = 4
   ,parameter fifo_els_p        = 2
   ,parameter bank_size_p       = "inv"
   ,parameter num_banks_p       = 4
   ,parameter data_width_p      = hdata_width_p
   ,parameter addr_width_p      = haddr_width_p 
    
   // array params
   ,parameter num_tiles_x_p     = "inv"
   ,parameter num_tiles_y_p     = "inv"
   ,parameter xcord_width_lp    = `BSG_SAFE_CLOG2(num_tiles_x_p)
   ,parameter ycord_width_lp    = `BSG_SAFE_CLOG2(num_tiles_y_p + 1)
   ,parameter packet_width_lp   = 6 + xcord_width_lp + ycord_width_lp
                                    + addr_width_p + data_width_p

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
   ,input  [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0] hor_packet_i
   ,input  [E:W][num_tiles_y_p-1:0]                      hor_valid_i
   ,output [E:W][num_tiles_y_p-1:0]                      hor_ready_o
   ,output [E:W][num_tiles_y_p-1:0][packet_width_lp-1:0] hor_packet_o
   ,output [E:W][num_tiles_y_p-1:0]                      hor_valid_o
   ,input  [E:W][num_tiles_y_p-1:0]                      hor_yumi_i

   // vertical -- {S,N}
   ,input  [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0] ver_packet_i
   ,input  [S:N][num_tiles_x_p-1:0]                      ver_valid_i
   ,output [S:N][num_tiles_x_p-1:0]                      ver_ready_o
   ,output [S:N][num_tiles_x_p-1:0][packet_width_lp-1:0] ver_packet_o
   ,output [S:N][num_tiles_x_p-1:0]                      ver_valid_o
   ,input  [S:N][num_tiles_x_p-1:0]                      ver_yumi_i

   // synopsys translate off
   ,output [num_tiles_y_p-1:0][num_tiles_x_p-1:0]                       htif_pcr_resp_valid_o
   ,output [num_tiles_y_p-1:0][num_tiles_x_p-1:0][htif_pcr_width_p-1:0] htif_pcr_resp_data_o
   // synopsys translate on
  );

  // synopsys translate off
  initial
  begin
    assert ((num_tiles_x_p > 0) && (num_tiles_y_p>0))
      else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
  end
  // synopsys translate on



  /* TILES */

  // tiles' outputs
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W][packet_width_lp-1:0] packet_out;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W]                      valid_out;
  logic [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W]                      ready_out;

  genvar r,c;

  for (r = 0; r < num_tiles_y_p; r = r+1)
  begin: tile_row_gen
    for (c = 0; c < num_tiles_x_p; c = c+1)
    begin: tile_col_gen
      bsg_vscale_tile # 
      ( .dirs_p        (dirs_p)                                           
       ,.stub_p        ({ (r == num_tiles_y_p-1) ? (((stub_s_p>>c) & 1'b1) == 1) : 1'b0 // s 
                         ,(r == 0)               ? (((stub_n_p>>c) & 1'b1) == 1) : 1'b0 // n
                         ,(c == num_tiles_x_p-1) ? (((stub_e_p>>r) & 1'b1) == 1) : 1'b0 // e
                         ,(c == 0)               ? (((stub_w_p>>r) & 1'b1) == 1) : 1'b0 // w
                        }                                                 
                       )                                                  
        ,.xcord_width_p  (xcord_width_lp)                                   
        ,.ycord_width_p  (ycord_width_lp)                                   
        ,.fifo_els_p   (fifo_els_p)                                       
        ,.bank_size_p  (bank_size_p)                                      
        ,.num_banks_p  (num_banks_p)                                      
        ,.data_width_p (data_width_p)                                     
        ,.addr_width_p (addr_width_p)                                     
	,.debug_p      (debug_p)
       ) tile                                                             
       ( .clk_i (clk_i)                                                   
        ,.reset_i(reset_i)
                                                                          
        ,.packet_i ({ (r == num_tiles_y_p-1)                              
                       ? ver_packet_i[S][c]                               
                       : packet_out[r+1][c][N] // s                         
                     ,(r == 0)                                            
                       ? ver_packet_i[N][c]                               
                       : packet_out[r-1][c][S] // n                         
                     ,(c == num_tiles_x_p-1)                              
                       ? hor_packet_i[E][r]                               
                       : packet_out[r][c+1][W] // e                         
                     ,(c == 0)                                            
                       ? hor_packet_i[W][r]                               
                       : packet_out[r][c-1][E] // w                         
                    }                                                     
                   )                                                      
        ,.valid_i  ({ (r == num_tiles_y_p-1)                              
                       ? ver_valid_i[S][c]                                
                       : valid_out[r+1][c][N] // s                          
                     ,(r == 0)                                            
                       ? ver_valid_i[N][c]                                
                       : valid_out[r-1][c][S] // n                          
                     ,(c == num_tiles_x_p-1)                              
                       ? hor_valid_i[E][r]                                
                       : valid_out[r][c+1][W] // e                          
                     ,(c == 0)                                            
                       ? hor_valid_i[W][r]                                
                       : valid_out[r][c-1][E] // w                          
                    }                                                     
                   )                                                      
        ,.ready_o  (ready_out[r][c])
                                                                          
        ,.packet_o (packet_out[r][c])
        ,.valid_o  (valid_out[r][c])
        ,.yumi_i   (valid_out[r][c] &
                    { (r == num_tiles_y_p-1) 
                       ? ver_yumi_i[S][c] 
                       : ready_out[r+1][c][N] // s                           
                     ,(r == 0)                                            
                       ? ver_yumi_i[N][c]                                 
                       : ready_out[r-1][c][S] // n                           
                     ,(c == num_tiles_x_p-1)                              
                       ? hor_yumi_i[E][r]                                 
                       : ready_out[r][c+1][W] // e                           
                     ,(c == 0)                                            
                       ? hor_yumi_i[W][r]                                 
                       : ready_out[r][c-1][E] // w                           
                    }                                                     
                   )

        ,.my_x_i   (xcord_width_lp'(c))
        ,.my_y_i   (ycord_width_lp'(r))
 
        // synopsys translate off
        ,.htif_pcr_resp_valid_o (htif_pcr_resp_valid_o[r][c])
        ,.htif_pcr_resp_data_o  (htif_pcr_resp_data_o[r][c])
        // synopsys translate on
      );
    end
  end



  /* OUTPUTS */

  for(r = 0; r < num_tiles_y_p; r = r+1)
  begin: hor_outputs
    assign {hor_packet_o[E][r], hor_packet_o[W][r]} = {packet_out[r][num_tiles_y_p-1][E], packet_out[r][0][W]};
    assign {hor_valid_o [E][r], hor_valid_o [W][r]} = {valid_out [r][num_tiles_y_p-1][E], valid_out [r][0][W]};
    assign {hor_ready_o [E][r], hor_ready_o [W][r]} = {ready_out [r][num_tiles_y_p-1][E], ready_out [r][0][W]};
  end

  for(c = 0; c < num_tiles_x_p; c = c+1)
  begin: ver_outputs
    assign {ver_packet_o[S][c], ver_packet_o[N][c]} = {packet_out[num_tiles_x_p-1][c][S], packet_out[0][c][N]};
    assign {ver_valid_o [S][c], ver_valid_o [N][c]} = {valid_out [num_tiles_x_p-1][c][S], valid_out [0][c][N]};
    assign {ver_ready_o [S][c], ver_ready_o [N][c]} = {ready_out [num_tiles_x_p-1][c][S], ready_out [0][c][N]};
  end

endmodule
