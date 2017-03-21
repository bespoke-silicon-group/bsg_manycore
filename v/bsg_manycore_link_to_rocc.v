//====================================================================
// bsg_manycore_link_to_rocc.v
// 01/18/2016, shawnless.xie@gmail.com
//====================================================================
// This module acts as a converter between the bsg_manycore_link_sif
// of a manycore and rocc interface.
//
// Pleas contact Prof Taylor for the document.
//
`include "bsg_rocc.v"
`include "bsg_manycore_packet.vh"

module  bsg_manycore_link_to_rocc
  #(  parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter fifo_els_p    = 4
    , parameter bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter debug_lp      =0
    )
  (
   // manycore side: manycore_link_sif
   //the manycore clock and reset

     input   [x_cord_width_p-1:0]                my_x_i
   , input   [y_cord_width_p-1:0]                my_y_i

   , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
   , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

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

    //the reset signal output to the manycore
   , output                             reset_manycore_r_o
   );

   //local parameter definition
    localparam max_out_credits_lp =200;
    localparam packet_width_lp    = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
    localparam byte_addr_width_lp = addr_width_p + 2;

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

  logic [$clog2(max_out_credits_lp+1)-1:0] out_credits     ;

  bsg_manycore_endpoint_standard #(
     .x_cord_width_p     ( x_cord_width_p )
    ,.y_cord_width_p     ( y_cord_width_p )
    ,.fifo_els_p         ( fifo_els_p     )
    ,.data_width_p       ( data_width_p   )
    ,.addr_width_p       ( addr_width_p   )
    ,.max_out_credits_p  ( max_out_credits_lp)
 )rocc_endpoint_standard
   (
     .clk_i         ( rocket_clk_i    )
    ,.reset_i       ( rocket_reset_i   )

    // mesh network
    ,.link_sif_i
    ,.link_sif_o

    // local incoming data interface
    ,.in_v_o        ( manycore2rocc_v       )
    ,.in_yumi_i     ( manycore2rocc_yumi    )
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

    ,.my_x_i
    ,.my_y_i
    );

  ///////////////////////////////////////////////////////////////////////////////////
  // Code for rocket reset manycore
  logic reset_manycore_r;

  wire is_core_reset=  core_cmd_valid_i
                    &( core_cmd_s_i.instr.funct7 == eRoCC_core_reset );

  always_ff@(posedge rocket_clk_i) begin
    if( rocket_reset_i )            reset_manycore_r <=  1'b0 ;
    else if ( is_core_reset )       reset_manycore_r <=  1'b1 ;
    else if ( reset_manycore_r )    reset_manycore_r <=  1'b0 ;
  end

  ///////////////////////////////////////////////////////////////////////////////////
  // Code for  Segment Register

  //write segment address register, which is BYTE address
  localparam seg_addr_width_lp = rocc_addr_width_gp - byte_addr_width_lp;
  logic [seg_addr_width_lp-1:0]     seg_addr_r;

  wire write_seg_en =     core_cmd_valid_i
                      & ( core_cmd_s_i.instr.funct7 == eRoCC_core_seg_addr );

  always_ff@(posedge rocket_clk_i )
    if( write_seg_en )
        seg_addr_r <= core_cmd_s_i.rs1_val[ rocc_addr_width_gp-1 : byte_addr_width_lp ];

  ///////////////////////////////////////////////////////////////////////////////////
  // Code for writing manycore memory
  //control signals coming from DMA
  wire                          dma_core_cmd_ready;
  wire                          dma_mem_req_valid ;
  rocc_mem_req_s                dma_mem_req_s     ;
  wire                          dma_rocc2manycore_v;
  rocc_manycore_addr_s          dma_rocc2manycore_addr_s;
  wire [data_width_p-1:0]       dma_rocc2manycore_data  ;
  wire                          dma_mem_req_credit      ;

  wire is_dma_cmd  = ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_addr )
                    |( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_skip )
                    |( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_xfer )
                    ;

  //control signals coming from core
  wire is_core_write = ( core_cmd_s_i.instr.funct7 == eRoCC_core_write );

  rocc_manycore_addr_s      core_rocc2manycore_addr_s;
  wire [data_width_p-1:0]   core_rocc2manycore_data  = core_cmd_s_i.rs2_val[data_width_p-1:0];
  wire                      is_mc_write_cmd     = core_cmd_valid_i & is_core_write;
  assign                    core_rocc2manycore_addr_s= core_cmd_s_i.rs1_val;


  //merged control signals sent to manycore
  //DMA and core can't write at the same time. ready signal to core will be
  //disasserted while DMA is running.
  rocc_manycore_addr_s    mc_addr_s ;
  wire [data_width_p-1:0] mc_data   = dma_rocc2manycore_v ? dma_rocc2manycore_data
                                                          : core_rocc2manycore_data ;
  assign                  mc_addr_s = dma_rocc2manycore_v ? dma_rocc2manycore_addr_s
                                                          : core_rocc2manycore_addr_s;

  assign rocc2manycore_v        = dma_rocc2manycore_v | is_mc_write_cmd ;
  assign rocc2manycore_packet   = get_manycore_pkt( mc_addr_s, mc_data) ;

  ///////////////////////////////////////////////////////////////////////////////////
  // Code for accessing rocket memory
  // Mancyore and DMA can't access the rocket memory at the same time. We
  // won't yumi the fifo while DMA is running
  rocc_mem_req_s    mc_mem_req_s;
  assign            mc_mem_req_s = get_rocket_mem_req(   manycore2rocc_data,
                                                         manycore2rocc_mask,
                                                         manycore2rocc_addr  );
  assign mem_req_valid_o    = dma_mem_req_valid | manycore2rocc_v ;
  assign mem_req_s_o        = dma_mem_req_valid ? dma_mem_req_s   : mc_mem_req_s;

  //if the rocket memory is ready, and DMA is not running, we complete the request
  assign manycore2rocc_yumi = manycore2rocc_v & mem_req_ready_i & dma_core_cmd_ready;


///////////////////////////////////////////////////////////////////////////////
// THE DMA CONTROLLER
bsg_manycore_rocc_dma #(
        .addr_width_p ( addr_width_p )
       ,.data_width_p ( data_width_p )
       ,.cfg_width_p  ( rocc_cfg_width_gp  )
    )rocc_dma_controller(
       .clk_i                (rocket_clk_i          )
      ,.reset_i              (rocket_reset_i        )
      //command signals
      ,.core_cmd_valid_i     (core_cmd_valid_i   )
      ,.core_cmd_s_i         (core_cmd_s_i       )
      ,.core_cmd_ready_o     (dma_core_cmd_ready )

      ,.core_resp_valid_o    (core_resp_valid_o  )
      ,.core_resp_s_o        (core_resp_s_o      )
      ,.core_resp_ready_i    (core_resp_ready_i  )

      //rocket mem signals
      ,.mem_req_valid_o      (dma_mem_req_valid  )
      ,.mem_req_s_o          (dma_mem_req_s      )
      ,.mem_req_ready_i      (mem_req_ready_i    )

      ,.mem_resp_valid_i     (mem_resp_valid_i   )
      ,.mem_resp_s_i         (mem_resp_s_i       )
      //manycore mem signals
      ,.rocc2manycore_v_o        (dma_rocc2manycore_v     )
      ,.rocc2manycore_addr_s_o   (dma_rocc2manycore_addr_s)
      ,.rocc2manycore_data_o     (dma_rocc2manycore_data  )
      ,.rocc2manycore_ready_i    (rocc2manycore_ready   )

      //DMA status signals
      ,.mem_req_credit_i         (dma_mem_req_credit      )
    );

   // counting the pending request into rocket
   logic [$clog2(max_out_credits_lp+1)-1:0] rocket_out_credits_o ;
   wire launch_rocket_mem_req = mem_req_valid_o & mem_req_ready_i ;
   bsg_counter_up_down #(.max_val_p  (max_out_credits_lp)
                         ,.init_val_p(max_out_credits_lp)
                         ) out_credit_ctr
     ( .clk_i    (rocket_clk_i )
      ,.reset_i  (rocket_reset_i )
      ,.down_i   (launch_rocket_mem_req )  // launch remote store
      ,.up_i     (mem_resp_valid_i      )  // receive credit back
      ,.count_o  (rocket_out_credits_o  )
      );
   //only allows 1 pending rocket memory request
   assign dma_mem_req_credit = rocket_out_credits_o > (max_out_credits_lp -1);
  ///////////////////////////////////////////////////////////////////////////////////
  // assign the outputs to rocc_core
   assign   core_cmd_ready_o    =   rocc2manycore_ready & dma_core_cmd_ready  ;

   assign   acc_interrupt_o     =   1'b0   ;
   assign   acc_busy_o =  (rocket_out_credits_o != max_out_credits_lp) | (~dma_core_cmd_ready);
  ///////////////////////////////////////////////////////////////////////////////////
  // functions and tasks
  function [rocc_addr_width_gp-1:0] get_rocket_addr( input logic [ addr_width_p-1 : 0]  manycore_addr);
    return { seg_addr_r, manycore_addr,2'b0 };
  endfunction

  //functions to encode the manycore packet
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  function bsg_manycore_packet_s get_manycore_pkt(
                             input rocc_manycore_addr_s               rocket_addr_s
                           , input [data_width_p-1 : 0]               manycore_value
                           );

          get_manycore_pkt = '{
                                op     : rocket_addr_s.cfg
                                       ? rocc_write_cfg_op_gp : rocc_write_store_op_gp,

                                //this is acutally the mask
                                op_ex  : 4'b1111                                      ,

                                // remote top bit of address, which is the special op code space.
                                // low bits are automatically cut off
                                addr   : rocket_addr_s.word_addr  [ addr_width_p-1: 0],

                                data   : manycore_value                                 ,
                                x_cord : rocket_addr_s.x_cord     [ x_cord_width_p-1: 0],
                                y_cord : rocket_addr_s.y_cord     [ y_cord_width_p-1: 0],

                                return_pkt : '{ x_cord : my_x_i,
                                                y_cord : my_y_i
                                              }
                               };

  endfunction

  //functions to encode the rocket memory request
  function rocc_mem_req_s get_rocket_mem_req(input [data_width_p-1:0        ] data,
                                             input [(data_width_p>>3)-1:0   ] mask,
                                             input [addr_width_p-1:0        ] word_addr
                                            );
    get_rocket_mem_req.req_addr =  get_rocket_addr( word_addr )   ;
    get_rocket_mem_req.req_tag  =  rocc_mem_tag_width_gp'(0) ;
    get_rocket_mem_req.req_cmd  =  eRoCC_mem_store           ;
    //currently only support 32bits
    get_rocket_mem_req.req_typ  =  eRoCC_mem_32bits          ;
    get_rocket_mem_req.req_phys =  1'b1                      ;
    get_rocket_mem_req.req_data =  rocc_data_width_gp'(data) ;

  endfunction

  ///////////////////////////////////////////////////////////////////////////////////
  //synopsys translate_off
  if( debug_lp ) begin:debug_link_to_rocc
    always@(negedge rocket_clk_i ) begin
      if( write_seg_en ) begin
        $display("Configuring Segment Register with value :\
             %h, Seg Reg bitwidth=%d, Maycore Byte Addr bitwidth=%d", seg_addr_r, seg_addr_width_lp, byte_addr_width_lp);
      end
    end
  end

  always@(negedge rocket_clk_i ) begin
    if( manycore2rocc_v ) assert ( & manycore2rocc_mask) else
        $error("Only supports word access to rocket right now");
  end
  //synopsys translate_on

  assign    reset_manycore_r_o  = reset_manycore_r     ;
endmodule

