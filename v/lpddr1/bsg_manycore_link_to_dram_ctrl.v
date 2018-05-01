//====================================================================
// bsg_manycore_link_to_dram_ctrl.v
// 04/26/2017, shawnless.xie@gmail.com
//====================================================================
// This module acts as a converter that interface with DRAM controller.
//
// 1.the controller will send data back with burst order, for 128 bit data
//   Word addr [1:0] = 2'b00, Byte addr= 0x0
//   return:     B15 B14 B13 B12, B11 B10 B9 B8, B7 B6 B5 B4, B3 B2 B1 B0
//
//   Word addr [1:0] = 2'b01, Byte addr= 0x4
//   return:     B3 B2 B1 B0, B15,B14 B13 B12, B11 B10 B9 B8, B7 B6 B5 B4
//
//   Word addr [1:0] = 2'b10  Byte addr= 0x8
//   return:     B7 B6 B5 B4, B3 B2 B1 B0, B15 B14 B13 B12, B11 B10 B9 B8
//
//   Word addr [1:0] = 2'b11, Byte addr= 0x12
//   return:     B11 B10 B9 B8, B7 B6 B5 B4, B3 B2 B1 B0, B15 B14 B13 B12
`include "bsg_manycore_packet.vh"

module  bsg_manycore_link_to_dram_ctrl
  import bsg_dram_ctrl_pkg::*;
  #(  parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter dram_ctrl_dwidth_p      = 128
    , parameter dram_ctrl_awidth_p      = 28
    , parameter fifo_els_p              = 4
    , parameter max_out_credits_lp      = 16
    , parameter bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter packet_width_lp    = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    )
  (

     input clk_i
   , input reset_i

   , input  [x_cord_width_p-1:0]     my_x_i
   , input  [y_cord_width_p-1:0]     my_y_i

   //input from the manycore
   , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
   , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

   //Interface with DRAM controller
   , bsg_dram_ctrl_if.master            dram_ctrl_if
   );

    localparam core_mask_width_lp = data_width_p >> 3                   ;
    localparam dram_mask_width_lp = dram_ctrl_dwidth_p >> 3              ;
    localparam mask_fill_bits_lp  = dram_mask_width_lp - core_mask_width_lp;
    localparam data_fill_bits_lp  = dram_ctrl_dwidth_p - data_width_p;

   ///////////////////////////////////////////////////////////////////////////////////
   // instantiate the endpoint
   logic                               endpoint_v_lo    ;
   logic                               endpoint_yumi_li ;
   logic [data_width_p-1:0]            endpoint_data_lo ;
   logic [(data_width_p>>3)-1:0]       endpoint_mask_lo ;
   logic [addr_width_p-1:0]            endpoint_addr_lo ;
   logic                               endpoint_we_lo   ;
   logic [data_width_p-1:0]            endpoint_returning_data_li       ;
   logic                               endpoint_returning_v_li          ;


   bsg_manycore_endpoint_standard #(
      .x_cord_width_p     ( x_cord_width_p )
     ,.y_cord_width_p     ( y_cord_width_p )
     ,.fifo_els_p         ( fifo_els_p     )
     ,.data_width_p       ( data_width_p   )
     ,.addr_width_p       ( addr_width_p   )
     ,.max_out_credits_p  ( max_out_credits_lp)
   )dram_endpoint_standard
    (
      .clk_i         ( clk_i     )
     ,.reset_i       ( reset_i   )

     // mesh network
     ,.link_sif_i    ( link_sif_i )
     ,.link_sif_o    ( link_sif_o )

     // local incoming request interface
     ,.in_v_o        ( endpoint_v_lo       )
     ,.in_yumi_i     ( endpoint_yumi_li    )
     ,.in_data_o     ( endpoint_data_lo    )
     ,.in_mask_o     ( endpoint_mask_lo    )
     ,.in_addr_o     ( endpoint_addr_lo    )
     ,.in_we_o       ( endpoint_we_lo      )

     // local outgoing reqeust from dram
     ,.out_v_i       ( 1'b0                          )
     ,.out_packet_i  ( { packet_width_lp { 1'b0 } }  )
     ,.out_ready_o   (                               )

     // returned data into dram
     ,.returned_data_r_o ( )
     ,.returned_v_r_o    ( )

     // The memory read value
     ,.returning_data_i (  endpoint_returning_data_li  )
     ,.returning_v_i    (  endpoint_returning_v_li     )

     // whether a credit was returned; not flow controlled
     ,.out_credits_o (                       )
     ,.freeze_r_o    (                       )
     ,.reverse_arb_pr_o(                     )

     ,.my_x_i
     ,.my_y_i
     );
    ///////////////////////////////////////////////////////////////////////////////////
    // convert the manycore link reqeust from manycore
    //
    // we only present the request if dram controller is ready
    wire   read_valid  =  endpoint_v_lo  & (~endpoint_we_lo) & dram_ctrl_if.app_rdy    ;
    wire   write_valid =  endpoint_v_lo  & ( endpoint_we_lo) & dram_ctrl_if.app_wdf_rdy
                                                             & dram_ctrl_if.app_rdy    ;

    assign endpoint_yumi_li             =  read_valid | write_valid             ;

    assign dram_ctrl_if.app_en          =  endpoint_yumi_li                     ;
    assign dram_ctrl_if.app_hi_pri      =  1'b1                                 ;
    assign dram_ctrl_if.app_cmd         =  endpoint_we_lo? eAppWrite : eAppRead ;
    assign dram_ctrl_if.app_addr        =  {endpoint_addr_lo, 2'b0}             ;

    assign dram_ctrl_if.app_wdf_wren    =  write_valid                          ;
    assign dram_ctrl_if.app_wdf_data    =  { {data_fill_bits_lp{1'b0}},endpoint_data_lo };
    assign dram_ctrl_if.app_wdf_mask    =  { {mask_fill_bits_lp{1'b0}},endpoint_mask_lo };
    assign dram_ctrl_if.app_wdf_end     =  write_valid                          ;

    assign endpoint_returning_v_li      =  dram_ctrl_if.app_rd_data_valid              ;
    assign endpoint_returning_data_li   =  dram_ctrl_if.app_rd_data[data_width_p-1:0]  ;

    assign dram_ctrl_if.app_ref_req     = 1'b0                                  ;
    assign dram_ctrl_if.app_zq_req      = 1'b0                                  ;
    assign dram_ctrl_if.app_sr_req      = 1'b0                                  ;

    //synopsys translate_off
    initial begin
        if( addr_width_p +2 != dram_ctrl_awidth_p ) begin
                $error("Address range of manycore must equal to dram address range!\n");
                $finish;
        end
    end
    //synopsys translate_on
    ///////////////////////////////////////////////////////////////////////////////////
    // set up the data and mask to dram
 /*
    localparam width_ratio_lp     = dram_ctrl_dwidth_p / data_width_p    ;
    // set data
    function [dram_ctrl_dwidth_p-1:0] set_dram_data( input [data_width_p-1:0] data_i, input [addr_width_p-1:0] addr_i);
        //----------------------
        if( width_ratio_lp == 2)   begin
                set_dram_data = addr_i[0] ? { data_i            , data_width_p{1'b0} }
                                          : { data_width_p{1'b0}, data_i             }
                                          ;
        //----------------------
        end else if (width_ratio_lp == 4 ) begin
                case ( addr_i[1:0] )
                        2'b00 : set_dram_data = {  (3*data_width_p){1'b0}, data_i                         };
                        2'b01 : set_dram_data = {  (2*data_width_p){1'b0}, data_i, (1*data_width_p){1'b0} };
                        2'b10 : set_dram_data = {  (1*data_width_p){1'b0}, data_i, (2*data_width_p){1'b0} };
                        default:set_dram_data = {                          data_i, (3*data_width_p){1'b0} };
                endcase
        //----------------------
        end else begin
                set_dram_data = data_i ;
        end
    endfunction

    // set mask
    function [dram_mask_width_lp-1:0] set_dram_mask( input [core_data_mask_lp-1:0] mask_i, input [addr_width_p-1:0] addr_i);
        //----------------------
        if( width_ratio_lp == 2)   begin
                set_dram_mask = addr_i[0] ? { data_i                  , core_mask_width_lp{1'b0} }
                                          : { core_mask_width_lp{1'b0}, data_i                   }
                                          ;
        //----------------------
        end else if (width_ratio_lp == 4 ) begin
                case ( addr_i[1:0] )
                        2'b00 : set_dram_mask = {  (3*core_mask_width_p){1'b0}, data_i                              };
                        2'b01 : set_dram_mask = {  (2*core_mask_width_p){1'b0}, data_i, (1*core_mask_width_p){1'b0} };
                        2'b10 : set_dram_mask = {  (1*core_mask_width_p){1'b0}, data_i, (2*core_mask_width_p){1'b0} };
                        default:set_dram_mask = {                               data_i, (3*core_mask_width_p){1'b0} };
                endcase
        //----------------------
        end else begin
                set_dram_mask = mask_i ;
        end
    endfunction
  */
endmodule

