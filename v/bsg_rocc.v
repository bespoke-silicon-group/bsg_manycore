//====================================================================
// bsg_rocc.v
// 01/19/2016, shawnless.xie@gmail.com
//====================================================================
// This module define the RoCC interface and parameters

`ifndef _bsg_rocc_vh_
`define _bsg_rocc_vh_

localparam rocc_data_width_gp           = 64;
localparam rocc_addr_width_gp           = 64;

localparam rocc_reg_addr_width_gp       = 5 ;
localparam rocc_instr_funct7_width_gp   = 7 ;
localparam rocc_instr_opcode_width_gp   = 7 ;

localparam rocc_mem_addr_width_gp       = 40;
localparam rocc_mem_tag_width_gp        = 10;
localparam rocc_mem_cmd_width_gp        = 5;
localparam rocc_mem_typ_width_gp        = 3;
localparam rocc_y_cord_width_gp         = 15;
localparam rocc_x_cord_width_gp         = 16;
localparam rocc_cfg_width_gp            = 16;
//the parameter for rocc write command
localparam rocc_write_addr_width_gp     = 32;
localparam rocc_write_store_op_gp       = 2'b01;
localparam rocc_write_cfg_op_gp         = 2'b10;
/////////////////////////////////////////////////////////////////////
//different command and type defines.
  typedef enum logic[rocc_instr_funct7_width_gp-1:0] {
        eRoCC_core_write    =rocc_instr_funct7_width_gp'(0),
        eRoCC_core_seg_addr =rocc_instr_funct7_width_gp'(1),
        eRoCC_core_dma_addr =rocc_instr_funct7_width_gp'(2),
        eRoCC_core_dma_skip =rocc_instr_funct7_width_gp'(3),
        eRoCC_core_dma_xfer =rocc_instr_funct7_width_gp'(4),
        eRoCC_core_reset    =rocc_instr_funct7_width_gp'(5)
  }eRoCC_core_cmd;

  typedef enum logic[rocc_mem_cmd_width_gp-1:0] {
        eRoCC_mem_load      =rocc_mem_cmd_width_gp'(0),
        eRoCC_mem_store     =rocc_mem_cmd_width_gp'(1)
  }eRoCC_mem_cmd;

  typedef enum logic[rocc_mem_typ_width_gp-1:0] {
        eRoCC_mem_8bits     =rocc_mem_typ_width_gp'(0),
        eRoCC_mem_16bits    =rocc_mem_typ_width_gp'(1),
        eRoCC_mem_32bits    =rocc_mem_typ_width_gp'(2),
        eRoCC_mem_64bits    =rocc_mem_typ_width_gp'(3)
  }eRoCC_mem_typ;

////////////////////////////////////////////////////////////////////
//The state machine
    localparam dma_stat_bits_lp = 1 ;
    typedef enum logic[dma_stat_bits_lp-1:0] {
        eRoCC_dma_idle    = dma_stat_bits_lp'(0),
        eRoCC_dma_busy    = dma_stat_bits_lp'(1)
    }eRoCC_dma_stat;
/////////////////////////////////////////////////////////////////////
//the instruction foramt of the rocc
typedef struct packed {
  logic [rocc_instr_funct7_width_gp-1:0]        funct7;
  logic [rocc_reg_addr_width_gp-1:0]            rs2;
  logic [rocc_reg_addr_width_gp-1:0]            rs1;
  logic                                         xd ;
  logic                                         xs1;
  logic                                         xs2;
  logic [rocc_reg_addr_width_gp-1:0]            rd;
  logic [rocc_instr_opcode_width_gp-1:0]        op;
} rocc_instr_s;

//manycore address representing in Rocket
typedef struct packed {
  logic [rocc_y_cord_width_gp-1:0]              y_cord;
  logic [rocc_x_cord_width_gp-1:0]              x_cord;
  logic                                         cfg;
  logic [rocc_write_addr_width_gp-3 : 0]        word_addr;
  logic [1 : 0]                                 low_bits;
}rocc_manycore_addr_s;

//the output signal of the core
typedef struct packed{
    rocc_instr_s                                instr;
    logic [rocc_data_width_gp-1:0]              rs1_val;
    logic [rocc_data_width_gp-1:0]              rs2_val;
    //only 2 core right now.
    logic                                       core_host_id  ;
}rocc_core_cmd_s;

//the input signal of the core
typedef struct packed{
    logic[rocc_reg_addr_width_gp-1:0]           rd;
    logic[rocc_data_width_gp-1    :0]           rd_data;
}rocc_core_resp_s;

//the input signal to the mem
typedef struct packed{
    logic [rocc_mem_addr_width_gp-1 :0]         req_addr;
    //tag of different request, in case of out-of-order memory response
    logic [rocc_mem_tag_width_gp-1  :0]         req_tag;
    // 0000 for load, 0001 for store
    eRoCC_mem_cmd                               req_cmd;
    // type for the request : 000=8bits, 0001=16bits, 010=32bits, 011=64bits
    eRoCC_mem_typ                               req_typ;
    // whether the address is physical
    logic                                       req_phys;
    logic [rocc_data_width_gp-1     :0]         req_data;
}rocc_mem_req_s;

//the output signal from the mem
typedef struct packed{
    logic [rocc_mem_addr_width_gp-1 :0]         resp_addr;
    logic [rocc_mem_tag_width_gp-1  :0]         resp_tag;
    eRoCC_mem_cmd                               resp_cmd;
    eRoCC_mem_typ                               resp_typ;
    logic [rocc_data_width_gp-1     :0]         resp_data;
    //Not clear yet
    logic                                       resp_nack;
    //Not clear yet
    logic                                       resp_replay;
    // whether the response contains valid data
    logic                                       resp_has_data;
    logic [rocc_data_width_gp-1     :0]         resp_data_word_bypass;
    // the turned back written data
    logic [rocc_data_width_gp-1     :0]         resp_store_data;
}rocc_mem_resp_s;

`endif
