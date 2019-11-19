/**
 *    bsg_manycore_pkg.v
 *
 *
 */



package bsg_manycore_pkg;

  
  `include "bsg_noc_links.vh"

  //                                  //
  //  manycore packet definition      //
  //                                  //

  typedef enum logic [1:0] {
    e_remote_load
    , e_remote_store
    , e_remote_swap_aq
    , e_remote_swap_rl
  } bsg_manycore_packet_op_e;


  typedef enum logic {
    e_return_credit
    , e_return_data
  } bsg_manycore_return_packet_type_e;


  // declare fwd and rev packet
  //
  `define declare_bsg_manycore_packet_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp) \
    typedef struct packed {                                                       \
      bsg_manycore_return_packet_type_e pkt_type;                                 \
      logic [data_width_mp-1:0] data;                                           \
      logic [load_id_width_mp-1:0] load_id;                                    \
      logic [y_cord_width_mp-1:0] y_cord;                                      \
      logic [x_cord_width_mp-1:0] x_cord;                                      \
    } bsg_manycore_return_packet_s;                                         \
                                                                            \
    typedef union packed {                                                  \
      logic [data_width_mp-1:0] data;                                     \
      struct packed {                                                     \
        logic [data_width_mp-load_id_width_mp-1:0] load_info_padding;     \
        logic [load_id_width_mp-1:0] load_id;                             \
      } load_info_s;                                                      \
    } bsg_manycore_packet_payload_u;                                     \
                                                                         \
    typedef struct packed {                                              \
       logic [addr_width_mp-1:0] addr;                                  \
       bsg_manycore_packet_op_e op;                                     \
       logic [(data_width_mp>>3)-1:0] op_ex;                            \
       bsg_manycore_packet_payload_u payload;                           \
       logic [y_cord_width_mp-1:0] src_y_cord;                          \
       logic [x_cord_width_mp-1:0] src_x_cord;                          \
       logic [y_cord_width_mp-1:0] y_cord;                              \
       logic [x_cord_width_mp-1:0] x_cord;                              \
    } bsg_manycore_packet_s
  
  `define bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp,load_id_width_mp) \
    ($bits(bsg_manycore_return_packet_type_e)+data_width_mp+load_id_width_mp+x_cord_width_mp+y_cord_width_mp)

  `define bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp) \
    (addr_width_mp+$bits(bsg_manycore_packet_op_e)+(data_width_mp>>3)+data_width_mp+(2*(y_cord_width_mp+x_cord_width_mp)))



  // declare manycore link interface
  //
  `define bsg_manycore_link_sif_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp) \
    ( `bsg_ready_and_link_sif_width(`bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp)) \
    + `bsg_ready_and_link_sif_width(`bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp,load_id_width_mp)))

  `define declare_bsg_manycore_fwd_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp) \
    `declare_bsg_ready_and_link_sif_s(`bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp),bsg_manycore_fwd_link_sif_s)

  `define declare_bsg_manycore_rev_link_sif_s(x_cord_width_mp,y_cord_width_mp,data_width_mp,load_id_width_mp) \
    `declare_bsg_ready_and_link_sif_s(`bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp,load_id_width_mp),bsg_manycore_rev_link_sif_s)

  `define declare_bsg_manycore_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp) \
    `declare_bsg_manycore_fwd_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp,load_id_width_mp); \
    `declare_bsg_manycore_rev_link_sif_s(x_cord_width_mp,y_cord_width_mp,data_width_mp,load_id_width_mp); \
                                         \
    typedef struct packed {              \
      bsg_manycore_fwd_link_sif_s fwd;   \
      bsg_manycore_rev_link_sif_s rev;   \
    } bsg_manycore_link_sif_s



endpackage
