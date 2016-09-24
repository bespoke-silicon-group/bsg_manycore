// bsg_manycore_tag_adaptor.v
// 09/20/2016 shawnless.xie@gmail.com

// this router requires that the X coordinates be located
// at lowest bits in the packet, and the Y coordinates at the next lowest
// position
//
`include "bsg_manycore_packet.vh"


`define SPMD       ????             // test program to be loaded
`define ROM(spmd)  bsg_rom_``spmd`` // ROM contaning the spmd
`define MEM_SIZE   32768
`define BANK_SIZE  1024   // in words
`define BANK_NUM   8
`ifndef bsg_tiles_X
`error bsg_tiles_X must be defined; pass it in through the makefile
`endif

`ifndef bsg_tiles_Y
`error bsg_tiles_Y must be defined; pass it in through the makefile
`endif

`define MAX_CYCLES 1000000

module test_tag_manycore;

   import  bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

   localparam debug_lp = 0;
   localparam tile_id_ptr_lp  = -1;
   localparam mem_size_lp     = `MEM_SIZE;  // actually the size of the file being loaded, in bytes
   localparam bank_size_lp    = `BANK_SIZE;   // in 32-bit words
   localparam num_banks_lp    = `BANK_NUM;
   localparam data_width_lp   = 32;
   localparam addr_width_lp   = 32;
   localparam num_tiles_x_lp  = `bsg_tiles_X;
   localparam num_tiles_y_lp  = `bsg_tiles_Y;
   localparam lg_node_x_lp    = `BSG_SAFE_CLOG2(num_tiles_x_lp);
   localparam lg_node_y_lp    = `BSG_SAFE_CLOG2(num_tiles_y_lp + 1);
   localparam packet_width_lp = 6 + lg_node_x_lp + lg_node_y_lp
                                + data_width_lp + addr_width_lp;
   localparam cycle_time_lp   = 20;


  // clock and reset generation
  wire clk;
  wire reset;

  bsg_nonsynth_clock_gen #( .cycle_time_p(cycle_time_lp)
                          ) clock_gen
                          ( .o(clk)
                          );

  bsg_nonsynth_reset_gen #(  .num_clocks_p     (1)
                           , .reset_cycles_lo_p(1)
                           , .reset_cycles_hi_p(10)
                          )  reset_gen
                          (  .clk_i        (clk)
                           , .async_reset_o(reset)
                          );



  logic [addr_width_lp-1:0]   mem_addr;
  logic [data_width_lp-1:0]   mem_data;

  logic [packet_width_lp-1:0] test_data_in;
  logic                       test_v_in, test_done, test_ready_out;
  logic                       tag_clk, tag_en, tag_data;

  logic                       target_reset;

  bsg_tag_manycore #
    (
      .bank_size_p  (bank_size_lp)
     ,.num_banks_p (num_banks_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.num_tiles_x_p(num_tiles_x_lp)
     ,.num_tiles_y_p(num_tiles_y_lp)
     ,.stub_w_p     ({{(num_tiles_y_lp-1){1'b1}}, 1'b0})
     ,.stub_e_p     ({num_tiles_y_lp{1'b1}})
     ,.stub_n_p     ({num_tiles_x_lp{1'b1}}) // loads through N-side of (0,0)
     ,.stub_s_p     ({num_tiles_x_lp{1'b0}})
     ,.debug_p(debug_lp)
    ) UUT
    ( .clk_i   (clk)
     ,.reset_i (reset | target_reset)

   // East I/O is used for bsg_tag injection
     ,.tag_clk_i ( tag_clk )
     ,.tag_en_i  ( tag_en  )
     ,.tag_data_i( tag_data)
  
   //indicating that test is done. which should connect to the JTAG_TDO 
     ,.done_r_o  ( test_done)
    );

  bsg_manycore_tag_adaptor
   #(
    .width_p( packet_width_lp)
   ,.els_p  ( 1              )
   ) tag_adaptor
   (
    .clk_i      (  clk      )
   ,.reset_i    (  reset    )
   ,.tag_clk_o  (  tag_clk  )
   ,.tag_en_o   (  tag_en   )
   ,.tag_data_o (  tag_data )

   ,.v_i        ( test_v_in     )
   ,.data_i     ( test_data_in  )
   ,.ready_o    ( test_ready_out)

   ,.nodeID_i   ( 'b0           )
   ,.target_reset_o( target_reset)
   );


  bsg_manycore_spmd_loader
    #(  .mem_size_p    (mem_size_lp)
       ,.num_rows_p    (num_tiles_y_lp)
       ,.num_cols_p    (num_tiles_x_lp)

       ,.data_width_p  (data_width_lp)
       ,.addr_width_p  (addr_width_lp)
       ,.tile_id_ptr_p (tile_id_ptr_lp)
     ) spmd_loader
     ( .clk_i     (clk)
       ,.reset_i  (reset)
       ,.data_o   (test_data_in)
       ,.v_o      (test_v_in)
       ,.ready_i  (test_ready_out)
       ,.data_i   (mem_data)
       ,.addr_o   (mem_addr)
     );

/*  
  always_ff@( negedge clk )
  begin
    if( test_v_in & test_ready_out) 
      $display("<= loader sending => : %b", test_data_in );
  end
*/

  `ROM(`SPMD)
    #( .addr_width_p(addr_width_lp)
      ,.width_p     (data_width_lp)
     ) spmd_rom
     ( .addr_i (mem_addr)
      ,.data_o (mem_data)
     );

  ///////////////////////////////////////////////////////
  // check the result
  always@(negedge clk ) 
    if( test_done == 1'b1 )  
    begin
        $display("================ Test finished !======================");
        $finish;
    end

endmodule
