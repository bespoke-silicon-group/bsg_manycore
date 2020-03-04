/**
 *  bsg_manycore.v
 *
 */


module bsg_manycore
  import bsg_manycore_pkg::*;
  import bsg_noc_pkg::*; // {P=0, W,E,N,S }
  #(parameter dmem_size_p = "inv"
    , parameter icache_entries_p = "inv" // in words
    , parameter icache_tag_width_p = "inv"

    , parameter vcache_size_p = "inv" // capacity of vcache in words
    , parameter vcache_block_size_in_words_p ="inv"
    , parameter vcache_sets_p = "inv"

    // change the default values from "inv" back to -1
    // since num_tiles_x_p and num_tiles_y_p will be used to define the size of 2D array
    // hetero_type_vec_p, they should be integer by default to avoid tool crash during
    // synthesis (DC versions at least up to 2018.06)
    , parameter num_tiles_x_p = -1
    , parameter num_tiles_y_p = -1

   // for heterogeneous, this is a vector of num_tiles_x_p*num_tiles_y_p bytes;
   // each byte contains the type of core being instantiated
   // type 0 is the standard core
   , parameter int hetero_type_vec_p [0:num_tiles_y_p-1][0:num_tiles_x_p-1]  ='{default:0}


   // this control how many extra IO rows are addressable in
   // the network outside of the manycore array

   , parameter extra_io_rows_p = 1

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

   , parameter addr_width_p = "inv"

   //the epa_addr_width_lp is the address bit used in C for remote access.
   //the value should be set to EPA_ADDR_WIDTH-2, refer to bsg_manycore.h for EPA_ADDR_WDITH setting
   , parameter epa_byte_addr_width_p =  "inv" 

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
  , parameter dram_ch_addr_width_p = "inv"
   //  Suppose the first channel is connected to column 0
  , parameter dram_ch_start_col_p  = 0
  // usually 32
  , parameter data_width_p = "inv"
  //The IO router row index
  , parameter IO_row_idx_p = 0

  // EPA parameter

  // Enable branch/jalr trace
  , parameter branch_trace_en_p = 0

  , localparam x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
  , localparam y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p + extra_io_rows_p) // extra row for I/O at bottom of chip
  , localparam link_sif_width_lp =
     `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)

   // snew * y * x bits
  , parameter repeater_output_p = 0

  // The number of registers between the reset_i port and the reset sinks
  // Must be >= 1
  , parameter reset_depth_p = 3

   // enable debugging
  , parameter debug_p = 0
  )
  (
    input clk_i
    , input reset_i

    // horizontal -- {E,W}
    , input [E:W][num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_i
    , output [E:W][num_tiles_y_p-1:0][link_sif_width_lp-1:0] hor_link_sif_o

    // vertical -- {S,N}
    , input [S:N][num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_i
    , output [S:N][num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_o

    //IO
    , input [num_tiles_x_p-1:0][link_sif_width_lp-1:0] io_link_sif_i
    , output [num_tiles_x_p-1:0][link_sif_width_lp-1:0] io_link_sif_o
  );

// Manycore is stubbed out when running synthesis on the top-level chip
`ifndef SYNTHESIS_TOPLEVEL_STUB

   // synopsys translate_off
   initial
   begin
        int i,j;
       assert ((num_tiles_x_p > 0) && (num_tiles_y_p > 0))
           else $error("num_tiles_x_p and num_tiles_y_p must be positive constants");
        $display("## ----------------------------------------------------------------");
        $display("## MANYCORE HETERO TYPE CONFIGUREATIONS");
        $display("## ----------------------------------------------------------------");
        for(i=0; i < num_tiles_y_p; i ++) begin
                $write("## ");
                for(j=0; j< num_tiles_x_p; j++) begin
                        $write("%0d,", hetero_type_vec_p[i][j]);
                end
                if( i==0 ) begin
                $write(" //Ignored, Set to IO Router");
                end
                $write("\n");
        end
        $display("## ----------------------------------------------------------------");
   end
   // synopsys translate_on

   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);


   bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_in;
   bsg_manycore_link_sif_s [num_tiles_y_p-1:0][num_tiles_x_p-1:0][S:W] link_out;

   genvar r,c;

  // Pipeline the reset. The bsg_manycore_tile has a single pipeline register
  // on reset already, so we only want to pipeline reset_depth_p-1 times.
  logic [reset_depth_p-1:0][num_tiles_y_p-1:0][num_tiles_x_p-1:0] reset_i_r;

  assign reset_i_r[0] = {(num_tiles_y_p*num_tiles_x_p){reset_i}};

  genvar k;
  for (k = 1; k < reset_depth_p; k++)
    begin
      always_ff @(posedge clk_i)
        begin
          reset_i_r[k] <= reset_i_r[k-1];
        end
    end

   for (r = IO_row_idx_p+1; r < num_tiles_y_p; r = r+1)
     begin: y
        for (c = 0; c < num_tiles_x_p; c=c+1)
          begin: x
            bsg_manycore_tile
              #(
                .dmem_size_p     (dmem_size_p),
                .vcache_size_p (vcache_size_p),
                .icache_entries_p(icache_entries_p),
                .icache_tag_width_p(icache_tag_width_p),
                .x_cord_width_p(x_cord_width_lp),
                .y_cord_width_p(y_cord_width_lp),
                .data_width_p(data_width_p),
                .addr_width_p(addr_width_p),
                .epa_byte_addr_width_p(epa_byte_addr_width_p),
                .hetero_type_p( hetero_type_vec_p[r][c] ),
                .debug_p(debug_p)
                ,.branch_trace_en_p(branch_trace_en_p)
                ,.num_tiles_x_p(num_tiles_x_p)
                ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
                ,.vcache_sets_p(vcache_sets_p)
              )
            tile
              (
                .clk_i(clk_i),
                .reset_i(reset_i_r[reset_depth_p-1][r][c]),

                .link_in(link_in[r][c]),
                .link_out(link_out[r][c]),

                .my_x_i(x_cord_width_lp'(c)),
                .my_y_i(y_cord_width_lp'(r))
              );
          end
     end

for (c = 0; c < num_tiles_x_p; c=c+1) begin:io
        bsg_manycore_mesh_node #(
            .x_cord_width_p     (x_cord_width_lp )
           ,.y_cord_width_p     (y_cord_width_lp )
           ,.data_width_p       (data_width_p    )
           ,.addr_width_p       (addr_width_p    )
          ) io_router
           (  .clk_i    (clk_i      )
             ,.reset_i  (reset_i_r[reset_depth_p-1][0][c] )
        
             ,.links_sif_i      ( link_in [ IO_row_idx_p][ c ] )
             ,.links_sif_o      ( link_out[ IO_row_idx_p][ c ] )
        
             ,.proc_link_sif_i  ( io_link_sif_i [ c ])
             ,.proc_link_sif_o  ( io_link_sif_o [ c ])
        
             // tile coordinates
             ,.my_x_i   ( x_cord_width_lp'(c              ))
             ,.my_y_i   ( y_cord_width_lp'(IO_row_idx_p  ))
             );
        
end
    // stitch together all of the tiles into a mesh

    bsg_mesh_stitch
     #(.width_p(link_sif_width_lp)
      ,.x_max_p(num_tiles_x_p)
      ,.y_max_p(num_tiles_y_p)
      )
    link
      (.outs_i(link_out)
      ,.ins_o(link_in)
      ,.hor_i(hor_link_sif_i)
      ,.hor_o(hor_link_sif_o)
      ,.ver_i(ver_link_sif_i)
      ,.ver_o(ver_link_sif_o)
      );

`endif
endmodule
