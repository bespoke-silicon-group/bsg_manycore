//====================================================================
// bsg_manycore_links_to_rocc.v
// 01/18/2016, shawnless.xie@gmail.com
//====================================================================
// This module acts as a converter between the bsg_manycore_link_sif
// of a manycore and rocc interface.
// 
// Pleas contact Prof Taylor for the document.
//
`include "bsg_rocc.v"
`include "bsg_manycore_packet.vh"

module  bsg_manycore_links_to_rocc
  #(  parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter fifo_els_p    = 4
    , parameter bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    )
  ( 
   // manycore side: manycore_link_sif
   //the manycore clock and reset 
   // TODO: using the cross clock domain
   //  input manycore_clk_i
   //, input manycore_reset_i

     input   [x_cord_width_p-1:0]                my_x_i
   , input   [y_cord_width_p-1:0]                my_y_i

   , input  [bsg_manycore_link_sif_width_lp-1:0] links_sif_i
   , output [bsg_manycore_link_sif_width_lp-1:0] links_sif_o

   // Rocket side
   , input rocket_clk_i
   , input rocket_reset_i

   //core control signals
   , input                              core_status_i   
   , input                              core_exception_i
   , output                             acc_interrupt_o 
   , output                             acc_busy_o      
   //command signals
   , input                              core_cmd_valid_i
   , input  rocc_core_cmd_s             core_cmd_s_i
   , output                             core_cmd_ready_o

   , output                             core_resp_valid_o
   , output rocc_core_resp_s            core_resp_s_o  
   , input                              core_resp_ready_i

   //mem signals
   , output                             mem_req_valid_o
   , output  rocc_mem_req_s             mem_req_s_o
   , input                              mem_req_ready_i

   , input                              mem_resp_valid_i
   , input  rocc_mem_resp_s             mem_resp_s_i
   );

   //local parameter definition
    localparam max_out_credits_lp =200;
    localparam packet_width_lp    = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  ///////////////////////////////////////////////////////////////////////////////////
  // instantiate the endpoint 
  logic                                manycore2rocc_v    ;
  logic                                manycore2rocc_yumi ;
  logic [data_width_p-1:0]             manycore2rocc_data ;
  logic [(data_width_p>>3)-1:0]        manycore2rocc_mask ;
  logic [addr_width_p-1:0]             manycore2rocc_addr ;

  logic [packet_width_lp-1:0]          rocc2manycore_packet;
  logic                                rocc2manycore_v     ;
  logic                                rocc2manycore_ready ;

  logic [$clog2(max_out_credits_p+1)-1:0] out_credits     ;

  bsg_manycore_endpoint_standard #( 
     .x_cord_width_p     ( x_cord_width_p )
    ,.y_cord_width_p     ( y_cord_width_p )
    ,.fifo_els_p         ( fifo_els_p     )
    ,.data_width_p       ( data_width_p   )
    ,.addr_width_p       ( addr_width_p   )
    ,.max_out_credits_p  ( max_out_credits_lp)
 )rocc_endpoint_standard
   ( //TODO: changing to manycore clock domain. 
     .clk_i         ( rocket_clk_i    )
    ,.reset_i       ( rocet_reset_i   )

    // mesh network
    ,.link_sif_i
    ,.link_sif_o

    // local incoming data interface
    ,.in_v_o        ( manycore2rocc_v       )
    ,.in_yumi       ( manycore2rocc_yumi    )
    ,.in_data_o     ( manycore2rocc_data    )
    ,.in_mask_o     ( manycore2rocc_mask    )
    ,.in_addr_o     ( manycore2rocc_addr    )

    // local outgoing data interface (does not include credits)
    ,.out_v_i       ( rocc2manycore_v       )
    ,.out_packet_i  ( rocc2manycore_packet  )
    ,.out_ready_o   ( rocc2manycore_ready   )

    // whether a credit was returned; not flow controlled
    ,.out_credits_o ( out_credits           )
    ,.freeze_r_o    (                       )
    ,.reverse_arb_pr_o(                     )
    );

  ///////////////////////////////////////////////////////////////////////////////////
  // Code for handling rocket command
 
  //write segment address register 
  localparam seg_addr_width_lp = rocc_addr_width_gp - addr_width_p;
  logic [seg_addr_width_lp-1:0]     seg_addr_r;

  wire write_seg_en =     core_cmd_valid_i 
                      & ( core_cmd_s_i.instr.funct7 == eRoCC_core_seg_addr );
 
  always_ff@(posedge rocket_clk_i )
    if( write_seg_en ) 
        seg_addr_r <= core_cmd_s_i.rs1_val[ rocc_addr_width_gp : addr_width_p ];

  //store data into manycore
  assign rocc2manycore_v =   core_cmd_valid_i 
                         & ( core_cmd_s_i.instr.funct7 == eRoCC_core_write );

  assign rocc2manycore_packet = get_manycore_pkt( core_cmd_s_i.rs1_val, 
                                                  core_cmd_s_i.rs2_val);
   
  //TODO:store data into rocket
  assign manycore2rocc_yumi = manycore2rocc_v; 

  ///////////////////////////////////////////////////////////////////////////////////
  // assign the outputs to rocc_mem
   assign   mem_req_valid_o     =   1'b0   ;
   assign   rocc_mem_req_o      =    'b0   ;

  // assign the outputs to rocc_core
   assign   core_cmd_ready_o    =   rocc2manycore_ready   ;

   assign   core_resp_valid_o   =   1'b0   ;
   assign   core_resp_s_o       =    'b0   ;

   assign   acc_interrupt_o     =   1'b0   ;
   //TODO: Improve this with flow control
   assign   acc_busy_o          =   1'b0   ;

  ///////////////////////////////////////////////////////////////////////////////////
  // functions and tasks 
  function [rocc_addr_width_gp-1:0] get_rocket_addr( input logic [ addr_width_p-1 : 0]  manycore_addr);
    return { seg_addr_r, manycore_addr };
  endfunction 

  //functions to encode the manycore packet
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  function bsg_manycore_packet_s get_manycore_pkt( 
                             input rocc_manycore_addr_s               rocket_addr_s
                           , input logic [ rocc_data_width_gp-1 : 0]  rocket_value
                           );

    assign get_manycore_pkt.op     = rocket_addr_s.cfg ? rocc_write_cfg_op_gp : rocc_write_store_op_gp;           

    //this is acutally the mask
    assign get_manycore_pkt.op_ex  = 'b1;

    // remote top bit of address, which is the special op code space.
    // low bits are automatically cut off
    assign get_manycore_pkt.addr   = rocket_addr_s.word_addr  [ addr_width_p-1: 0];

    assign get_manycore_pkt.data   = rocket_value             [ data_width_p -1 : 0];
    assign get_manycore_pkt.x_cord = rocket_addr_s.x_cord     [ x_cord_width_p-1: 0];
    assign get_manycore_pkt.y_cord = rocket_addr_s.y_cord     [ y_cord_width_p-1: 0];

    assign get_manycore_pkt.return_pkt.x_cord = my_x_i;
    assign get_manycore_pkt.return_pkt.y_cord = my_y_i;

  endfunction 

endmodule

