//====================================================================
// bsg_dram_ctrl_if.v
// 04/26/2017, shawnless.xie@gmail.com
//====================================================================
// This module define the interface with dram controller
// We use Xilinx DRAM controller interface which is called 'user
// interface'. Please refer to Figure 1-31 and Table 1-17 in following
// document: "7 Series FPGAs Memory Interface Solutions"
//
// (https://www.xilinx.com/support/documentation/ip_documentation/mig_7series/v1_4/ug586_7Series_MIS.pdf)
//

interface bsg_dram_ctrl_if
        import bsg_dram_ctrl_pkg::*;
        #(
        //the basic dram parameters
         parameter addr_width_p = 32
        ,parameter data_width_p = 64
        ,parameter mask_width_p = data_width_p >> 3
        )
        //synopsys translate_off
        ( input clk_i ) //used for simualtion check only
        //synopsys translate_on
        ;


        //The three groups, command, write, and read have seperated FIFO, and
        //do not need to be synced with the same cycle, but sure need to be in
        //order.
        //We don't support burst mode .
        //ONE Reqest, ONE Data, ONE Response.

        //command group
        logic                           app_en          ;   //the enable signal, equal to 'valid' signal
        logic                           app_rdy         ;   //the ready singal
        logic                           app_hi_pri      ;   //request priority
        eAppCmd                         app_cmd         ;   //the command signal,
        logic [addr_width_p-1:0]        app_addr        ;   //address for both read and write

        //write group
        logic                           app_wdf_wren    ;   //write data valid
        logic                           app_wdf_rdy     ;   //write data ready
        logic [data_width_p-1:0]        app_wdf_data    ;
        logic [mask_width_p-1:0]        app_wdf_mask    ;   //write mask, ACTIVE_LOW!!!!
        logic                           app_wdf_end     ;   //last data of the burst.
                                                            //Should be same with app_wdf_wren in our design

        //read group
        logic                           app_rd_data_valid;  //read data valid signal
        logic                           app_rd_data_end ;   //last data of the burst
                                                            //Should be same with app_wdf_wren in our design
        logic [data_width_p-1:0]        app_rd_data     ;

        //phy group
        logic                           app_ref_req     ;   //refresh request
        logic                           app_ref_ack     ;   //refresh ack

        logic                           app_zq_req      ;   //ZQ calibration request
        logic                           app_zq_ack      ;   //ZQ calibration ack
        logic                           init_calib_complete; //initial calibration

        logic                           app_sr_req      ;   //reserved, tied to 0
        logic                           app_sr_ack      ;   //reserved, ignored
        //other

        modport master(
                 output  app_en
                ,input   app_rdy
                ,output  app_hi_pri
                ,output  app_cmd
                ,output  app_addr

                ,output  app_wdf_wren
                ,input   app_wdf_rdy
                ,output  app_wdf_data
                ,output  app_wdf_mask
                ,output  app_wdf_end

                ,input   app_rd_data_valid
                ,input   app_rd_data_end
                ,input   app_rd_data

                ,output  app_ref_req
                ,input   app_ref_ack

                ,output  app_zq_req
                ,input   app_zq_ack
                ,input   init_calib_complete

                ,output  app_sr_req
                ,input   app_sr_ack
                );

        modport slave(
                 input  app_en
                ,output app_rdy
                ,input  app_hi_pri
                ,input  app_cmd
                ,input  app_addr

                ,input  app_wdf_wren
                ,output app_wdf_rdy
                ,input  app_wdf_data
                ,input  app_wdf_mask
                ,input  app_wdf_end

                ,output app_rd_data_valid
                ,output app_rd_data_end
                ,output app_rd_data

                ,input  app_ref_req
                ,output app_ref_ack

                ,input  app_zq_req
                ,output app_zq_ack
                ,output init_calib_complete

                ,input  app_sr_req
                ,output app_sr_ack
                );
        //synopsys translate_off
        always@(negedge clk_i) begin
                assert(         (app_wdf_wren === app_wdf_end)
                        &&      (app_rd_data_valid === app_rd_data_end )
                      ) else begin
                        $display("Only supprot back to back reqeust");
                end

        end
        //synopsys translate_on
endinterface
