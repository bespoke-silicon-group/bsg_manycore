/**
 *    bsg_manycore_pkg.v
 *
 *    The mother of all SV packages in bsg_manycore.
 *    Other packages should import this, but not the other way around.
 *
 */


package bsg_manycore_pkg;


  //                                  //
  //  manycore packet definition      //
  //                                  //


  localparam bsg_manycore_reg_id_width_gp = 5;

  //  request packet type
  //
  typedef enum logic [3:0] {
    e_remote_load
    , e_remote_store  // masked store (reg_id is used as store mask)
    , e_remote_sw     // store word   (reg_id is used as a tracking id)
    , e_cache_op // AFL, AFLINV, AINV for DRAM addresses - TAGFL for tag memory
    , e_remote_amoswap
    , e_remote_amoadd
    , e_remote_amoxor
    , e_remote_amoand
    , e_remote_amoor
    , e_remote_amomin
    , e_remote_amomax
    , e_remote_amominu
    , e_remote_amomaxu
  } bsg_manycore_packet_op_e;


  //  return packet type
  //
  //  For e_remote_load,
  //  1) if icache_fetch=1 in load_info, e_return_ifetch should be returned.
  //  2) if float_wb=1 in load_info, e_return_float_wb should be returned.
  //  3) otherwise, e_return_int_wb is returned.
  //  For e_remote_store or e_cache_op, e_return_credit should be returned.
  //  For e_remote_amo, e_return_int_wb should be returned. 
  typedef enum logic [1:0] {
    e_return_credit
    , e_return_int_wb
    , e_return_float_wb
    , e_return_ifetch
  } bsg_manycore_return_packet_type_e;


  // load_info
  // this is included in payload for e_remote_load.
  // byte-selection for int_wb load should be done at the destination of request packet.
  typedef struct packed {
    logic float_wb;
    logic icache_fetch;
    logic is_unsigned_op;
    logic is_byte_op;
    logic is_hex_op;  // this is a "half" op.
    logic [1:0] part_sel;
  } bsg_manycore_load_info_s;
 

  // e_cache_op subop
  typedef enum logic [bsg_manycore_reg_id_width_gp-1:0] {
    e_afl
    ,e_ainv
    ,e_aflinv
    ,e_tagfl
  } bsg_manycore_cache_op_type_e;


  // manycore POD bsg_tag_client payload
  // contains reset
  typedef struct packed {
    logic reset;
  } bsg_manycore_pod_tag_payload_s;


  // EVA Address Format


  // global
  localparam global_epa_word_addr_width_gp = 14; // max EPA width on global EVA. (word addr)
  localparam max_global_x_cord_width_gp = 7;
  localparam max_global_y_cord_width_gp = 7;

  typedef struct packed {
    logic [1:0]                                   remote;
    logic [max_global_y_cord_width_gp-1:0]        y_cord;
    logic [max_global_x_cord_width_gp-1:0]        x_cord;
    logic [global_epa_word_addr_width_gp-1:0]     addr;
    logic [1:0]                                   low_bits;
  } bsg_manycore_global_addr_s;

  // tile-group
  localparam tile_group_epa_word_addr_width_gp = 16; // max EPA width on tile-group EVA. (word addr)
  localparam max_tile_group_x_cord_width_gp = 6;
  localparam max_tile_group_y_cord_width_gp = 5;

  typedef struct packed {
    logic [2:0]                                       remote;
    logic [max_tile_group_y_cord_width_gp-1:0]        y_cord;
    logic [max_tile_group_x_cord_width_gp-1:0]        x_cord;
    logic [tile_group_epa_word_addr_width_gp-1:0]     addr;
    logic [1:0]                                       low_bits;
  } bsg_manycore_tile_group_addr_s;



endpackage
