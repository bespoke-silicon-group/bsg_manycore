`include "bsg_manycore_packet.vh"

`ifdef bsg_FPU
`include "float_definitions.vh"
`endif
module bsg_manycore
  import bsg_noc_pkg::*; // {P=0, W,E,N,S }

 #(// tile params

    parameter dmem_size_p       = "inv"
   ,parameter icache_entries_p  = "inv" // in words
   ,parameter icache_tag_width_p= -1
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

   ,parameter extra_io_rows_p   = 2

   //one extra routers for the IO.
   ,parameter num_routers_y_lp = num_tiles_y_p + extra_io_rows_p -1 
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

   //the epa_addr_width_lp is the address bit used in C for remote access.
   //the value should be set to EPA_ADDR_WIDTH-2, refer to bsg_manycore.h for EPA_ADDR_WDITH setting
   ,parameter epa_addr_width_p =  "inv" 

    //------------------------------------------------------
    //  DRAM Address Definition
    //------------------------------------------------------
    // DRAMs are located at the south of mesh, and are divided
    // into different channels depending on which column the dram 
    // is attached to. 
    //
    // Should be less or equal to addr_width_p
    //
    //      |       |       |       |
    //-----------------------------------
    //      |       |       |       |
    //      |       |       |       |
    //     CH0     CH1     CH2     CH3
    //
    //  LOW_ADDR     ----->         HIGH_ADDR
    //
    // This parameter is used to decode which DRAM channel should be 
    // send to.
    // 32 bits = {1'b1, CH0, network address}
    
    //  26 = 32M WORDS for each channel
   ,parameter dram_ch_addr_width_p = "inv"
    //  Suppose the first channel is connected to column 0
   ,parameter dram_ch_start_col_p  = 0

   ,parameter x_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_x_p)
   ,parameter y_cord_width_lp   = `BSG_SAFE_CLOG2(num_tiles_y_p + extra_io_rows_p) // extra row for I/O at bottom of chip

   // changing this parameter is untested
   ,parameter data_width_p      = 32

   // ID for load requests in the network
   ,parameter load_id_width_p = 5

   ,parameter bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p)

   // snew * y * x bits
   ,parameter repeater_output_p = 0

  )
  ( input clk_i
   ,input reset_i

   // horizontal -- {E,W}
   ,input  [E:W][num_routers_y_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_i
   ,output [E:W][num_routers_y_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] hor_link_sif_o

   // vertical -- {S,N}
   ,input   [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_i
   ,output  [S:N][num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_o

   //IO
   ,input   [num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] io_link_sif_i
   ,output  [num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] io_link_sif_o
  );

// Manycore is stubbed out when running synthesis on the top-level chip
`ifndef SYNTHESIS_TOPLEVEL_STUB

   // synopsys translate_off
   initial
   begin
       assert ((num_tiles_x_p > 0) && (num_tiles_y_p > 0))
           else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");

       $display("$bits(addr)=%-d, $bits(op)=%-d, $bits(op_ex)=%-d, $bits(data)=%-d, $bits(return_pkt)=%-d, $bits(y_cord)=%-d, $bits(x_cord)=%-d",
           addr_width_p,2,(data_width_p>>3),data_width_p,y_cord_width_lp+x_cord_width_lp,y_cord_width_lp,x_cord_width_lp);
   end
   // synopsys translate_on

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p);


   bsg_manycore_link_sif_s [num_routers_y_lp-1:0][num_tiles_x_p-1:0][S:W] link_in;
   bsg_manycore_link_sif_s [num_routers_y_lp-1:0][num_tiles_x_p-1:0][S:W] link_out;

   genvar r,c;

  // Pipeline the reset by 2 flip flops (for 16nm layout)
  logic reset_i_r, reset_i_rr;

  always_ff @(posedge clk_i)
    begin
      reset_i_r <= reset_i;
      reset_i_rr <= reset_i_r;
    end


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
                ,.reset_i    ( reset_i_rr            )
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
            bsg_manycore_tile
              #(
                .dmem_size_p     (dmem_size_p),
                .icache_entries_p(icache_entries_p),
                .icache_tag_width_p(icache_tag_width_p),
                .x_cord_width_p(x_cord_width_lp),
                .y_cord_width_p(y_cord_width_lp),
                .data_width_p(data_width_p),
                .addr_width_p(addr_width_p),
                .load_id_width_p(load_id_width_p),
                .epa_addr_width_p(epa_addr_width_p),
                .dram_ch_addr_width_p( dram_ch_addr_width_p),
                .dram_ch_start_col_p ( dram_ch_start_col_p ),
                .stub_p({(r == num_tiles_y_p-1) ? (((stub_s_p>>c) & 1'b1) == 1) : 1'b0 /* s */
                        ,(r == 0)               ? (((stub_n_p>>c) & 1'b1) == 1) : 1'b0 /* n */
                        ,(c == num_tiles_x_p-1) ? (((stub_e_p>>r) & 1'b1) == 1) : 1'b0 /* e */
                        ,(c == 0)               ? (((stub_w_p>>r) & 1'b1) == 1) : 1'b0 /* w */}),
                .repeater_output_p((repeater_output_p >> (4*(r*num_tiles_x_p+c))) & 4'b1111),
                .hetero_type_p((hetero_type_vec_p >> (8*(r*num_tiles_x_p + c))) & 8'b1111_1111),
                .debug_p(debug_p)
              )
            tile
              (
                .clk_i(clk_i),
                .reset_i(reset_i_rr),

                .link_in(link_in[r][c]),
                .link_out(link_out[r][c]),

              `ifdef bsg_FPU
                .fam_in_s_o(fam_in_s_v[r][c]),
                .fam_out_s_i(fam_out_s_v[r][c]),
              `endif

                .my_x_i(x_cord_width_lp'(c)),
                .my_y_i(y_cord_width_lp'(r))
              );
          end
     end

for (c = 0; c < num_tiles_x_p; c=c+1) begin:io
        bsg_manycore_mesh_node #(
            .x_cord_width_p     (x_cord_width_lp )
           ,.y_cord_width_p     (y_cord_width_lp )
           ,.load_id_width_p    (load_id_width_p )
        
           ,.data_width_p       (data_width_p    )
           ,.addr_width_p       (addr_width_p    )
           ,.allow_S_to_EW_p    ( 1'b1           )
          ) io_router
           (  .clk_i    (clk_i      )
             ,.reset_i  (reset_i_rr )
        
             ,.links_sif_i      ( link_in [ num_tiles_y_p ][ c ] )
             ,.links_sif_o      ( link_out[ num_tiles_y_p ][ c ] )
        
             ,.proc_link_sif_i  ( io_link_sif_i [ c ])
             ,.proc_link_sif_o  ( io_link_sif_o [ c ])
        
             // tile coordinates
             ,.my_x_i   ( x_cord_width_lp'(c              ))
             ,.my_y_i   ( y_cord_width_lp'(num_tiles_y_p  ))
             );
        
end
    // stitch together all of the tiles into a mesh

    bsg_mesh_stitch
     #(.width_p(bsg_manycore_link_sif_width_lp)
      ,.x_max_p(num_tiles_x_p)
      ,.y_max_p(num_routers_y_lp)
      )
    link
      (.outs_i(link_out)
      ,.ins_o(link_in)
      ,.hor_i(hor_link_sif_i)
      ,.hor_o(hor_link_sif_o)
      ,.ver_i(ver_link_sif_i)
      ,.ver_o(ver_link_sif_o)
      );

  //synopsys translate_off
  `ifdef bsg_FPU
  initial
  begin
    assert ( (num_tiles_x_p % 2 ) == 0 )
      else $error("num_tiles_x_p must be even for the shared FPU option");
  end
  `endif
  //synopsys translate_on
`endif
endmodule
