`include "bsg_manycore_packet.vh"
`include "bsg_defines.v"

`define SPMD       ????             // test program to be loaded
`define ROM(spmd)  bsg_rom_``spmd`` // ROM contaning the spmd
//`define MEM_SIZE   32768
//`define BANK_SIZE  1024   // in words
//`define BANK_NUM   8
//`define bsg_tiles_X 2
//`define bsg_tiles_Y 2

`define MEM_SIZE   64
`define BANK_SIZE  8   // in words
`define BANK_NUM   2
`define bsg_tiles_X 2
`define bsg_tiles_Y 1

import  bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

localparam debug_lp = 0;
localparam bank_size_lp    = `BANK_SIZE;   // in 32-bit words
localparam num_banks_lp    = `BANK_NUM;
localparam data_width_lp   = 32;
localparam addr_width_lp   = 32;
localparam num_tiles_x_p  = `bsg_tiles_X;
localparam num_tiles_y_p  = `bsg_tiles_Y;
localparam lg_node_x_lp    = `BSG_SAFE_CLOG2(num_tiles_x_p);
localparam lg_node_y_lp    = `BSG_SAFE_CLOG2(num_tiles_y_p + 1);
localparam packet_width_lp = 6 + lg_node_x_lp + lg_node_y_lp
                            + data_width_lp + addr_width_lp;
localparam cycle_time_lp   = 20;

//localparam trace_vscale_pipeline_lp=0;
module syn_bsg_manycore ( 
    input clk_i
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
   bsg_manycore #
    (
     .bank_size_p  (bank_size_lp)
     ,.num_banks_p (num_banks_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.num_tiles_x_p(num_tiles_x_p)
     ,.num_tiles_y_p(num_tiles_y_p)
     ,.stub_w_p     ({{(num_tiles_y_p-1){1'b1}}, 1'b0})
     ,.stub_e_p     ({num_tiles_y_p{1'b1}})
     ,.stub_n_p     ({num_tiles_x_p{1'b1}}) // loads through N-side of (0,0)
     ,.stub_s_p     ({num_tiles_x_p{1'b0}})
     ,.debug_p(debug_lp)
    ) UUT
    ( .clk_i   (clk_i)
     ,.reset_i (reset_i)

     ,.ver_data_i 
     ,.ver_v_i 
     ,.ver_ready_o 
     ,.ver_data_o
     ,.ver_v_o 
     ,.ver_ready_i  

     ,.hor_data_i 
     ,.hor_v_i 
     ,.hor_ready_o
     ,.hor_data_o
     ,.hor_v_o 
     ,.hor_ready_i 
    );


endmodule
