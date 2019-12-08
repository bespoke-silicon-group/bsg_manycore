/**
 *    bsg_manycore_pkg.v
 *
 *    The mother of all SV packages in bsg_manycore.
 *    Other packages should import this, but not the other way around.
 *
 */


package bsg_manycore_pkg;

  
  `include "bsg_noc_links.vh"

  //                                  //
  //  manycore packet definition      //
  //                                  //

  localparam bsg_manycore_reg_id_width_gp = 5;

  typedef enum logic [1:0] {
    e_remote_load
    , e_remote_store
    , e_remote_amo
  } bsg_manycore_packet_op_e;

  typedef enum logic [1:0] {
    e_return_credit
    , e_return_int_wb
    , e_return_float_wb
    , e_return_ifetch
  } bsg_manycore_return_packet_type_e;

  typedef struct packed {
    logic float_wb;
    logic icache_fetch;
    logic is_unsigned_op;
    logic is_byte_op;
    logic is_hex_op;
    logic [1:0] part_sel;
  } bsg_manycore_load_info_s;

  typedef enum logic [3:0] {
    e_amo_swap
    ,e_amo_add
    ,e_amo_xor
    ,e_amo_and
    ,e_amo_or
    ,e_amo_min
    ,e_amo_max
    ,e_amo_minu
    ,e_amo_maxu
  } bsg_manycore_amo_type_e;

  typedef union packed {
    bsg_manycore_amo_type_e amo_type; // for remote atomic packet
    logic [3:0] store_mask;           // for remote store packet
  } bsg_manycore_packet_op_ex_u;

  // declare fwd and rev packet
  //
  `define declare_bsg_manycore_packet_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    typedef struct packed {                                                    \
      bsg_manycore_return_packet_type_e pkt_type;                              \
      logic [data_width_mp-1:0] data;                                          \
      logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;                         \
      logic [y_cord_width_mp-1:0] y_cord;                                      \
      logic [x_cord_width_mp-1:0] x_cord;                                      \
    } bsg_manycore_return_packet_s;                                            \
                                                                               \
    typedef union packed {                                                               \
      logic [data_width_mp-1:0] data;                                                    \
      struct packed {                                                                    \
        logic [data_width_mp-$bits(bsg_manycore_load_info_s)-1:0] reserved;              \
        bsg_manycore_load_info_s load_info;                                              \
      } load_info_s;                                                                     \
    } bsg_manycore_packet_payload_u;                                                     \
                                                                        \
    typedef struct packed {                                             \
       logic [addr_width_mp-1:0] addr;                                  \
       bsg_manycore_packet_op_e op;                                     \
       bsg_manycore_packet_op_ex_u op_ex;                               \
       logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;                 \
       bsg_manycore_packet_payload_u payload;                           \
       logic [y_cord_width_mp-1:0] src_y_cord;                          \
       logic [x_cord_width_mp-1:0] src_x_cord;                          \
       logic [y_cord_width_mp-1:0] y_cord;                              \
       logic [x_cord_width_mp-1:0] x_cord;                              \
    } bsg_manycore_packet_s
  
  `define bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp) \
    ($bits(bsg_manycore_return_packet_type_e)+data_width_mp+bsg_manycore_reg_id_width_gp+x_cord_width_mp+y_cord_width_mp)

  `define bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    (addr_width_mp+$bits(bsg_manycore_packet_op_e)+$bits(bsg_manycore_packet_op_ex_u)+bsg_manycore_reg_id_width_gp+data_width_mp+(2*(y_cord_width_mp+x_cord_width_mp)))



  // declare manycore link interface
  //
  `define bsg_manycore_link_sif_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    ( `bsg_ready_and_link_sif_width(`bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp)) \
    + `bsg_ready_and_link_sif_width(`bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp)))

  `define declare_bsg_manycore_fwd_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    `declare_bsg_ready_and_link_sif_s(`bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp),bsg_manycore_fwd_link_sif_s)

  `define declare_bsg_manycore_rev_link_sif_s(x_cord_width_mp,y_cord_width_mp,data_width_mp) \
    `declare_bsg_ready_and_link_sif_s(`bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp),bsg_manycore_rev_link_sif_s)


  // Users should use this macro to declare link_sif.
  `define declare_bsg_manycore_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    `declare_bsg_manycore_fwd_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp); \
    `declare_bsg_manycore_rev_link_sif_s(x_cord_width_mp,y_cord_width_mp,data_width_mp);               \
                                         \
    typedef struct packed {              \
      bsg_manycore_fwd_link_sif_s fwd;   \
      bsg_manycore_rev_link_sif_s rev;   \
    } bsg_manycore_link_sif_s


  // EVA Address Format

  // global
  `define declare_bsg_manycore_global_addr_s(epa_addr_width, max_x_cord_width, max_y_cord_width) \
    typedef struct packed {                                      \
      logic [1:0]       remote;                                 \
      logic [max_y_cord_width-1:0]       y_cord;                \
      logic [max_x_cord_width-1:0]       x_cord;                \
      logic [epa_addr_width-1:0]          addr;                  \
      logic [1:0]                        low_bits;              \
    } bsg_manycore_global_addr_s;

  // tile-group
  `define declare_bsg_manycore_addr_s(epa_addr_width, max_x_cord_width, max_y_cord_width) \
    typedef struct packed {                                      \
      logic [2:0]       remote;                                 \
      logic [max_y_cord_width-2:0]       y_cord;                \
      logic [max_x_cord_width-1:0]       x_cord;                \
      logic [epa_addr_width-1:0]          addr;                  \
      logic [1:0]                        low_bits;              \
    } bsg_manycore_addr_s;

endpackage
