/**
 *  lsu.v
 *
 *  load store unit
 *
 */


`include "definitions.vh"

module lsu
  #(parameter data_width_p="inv"
    , parameter pc_width_p="inv"
    , parameter dmem_size_p="inv"

    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam data_mask_width_lp=(data_width_p>>3)
  )
  (
    // from EXE
    , input decode_s exe_decode_i
    , input [data_width_p-1:0] rs1_i
    , input [data_width_p-1:0] rs2_i
    , input [data_width_p-1:0] mem_offset_i
    , input icache_miss_i
    , input [data_width_p-1:0] pc_plus4_i

    // to network TX
    , output remote_req_s remote_req_o
    , output logic remote_req_v_o

    // to MEM
    , output logic dmem_v_o
    , output logic dmem_w_o
    , output logic [dmem_addr_width_lp-1:0] dmem_addr_o
    , output logic [data_width_p-1:0] dmem_data_o
    , output logic [data_mask_width_lp-1:0] dmem_mask_o 
    , output logic reserve_o
    , output logic [data_width_p-1:0] mem_addr_send_o
  );

  logic [data_width_p-1:0] mem_addr;
  logic [data_width_p-1:0] miss_addr
  logic [data_width_p-1:0] final_addr;

  assign mem_addr = rs1_i + mem_offset_i;
  assign miss_addr = (pc_plus4_i - 'h4) | 32'h80000000;
  assign final_addr = icache_miss_i
    ? miss_addr
    : mem_addr;




endmodule
