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


  //  Declare fwd and rev packet
  //
  //  Request Packet (fwd)
  //  addr         :  EPA (word address)
  //  op           :  packet opcode 
  //  reg_id       :  This field is unionized with bsg_manycore_packet_reg_id_u.
  //                  For remote load/atomic (e_remote_load/e_remote_amo*), this field contains reg_id (rd), which gets returned by the return packet.
  //                  For e_cache_op, this field contains bsg_manycore_cache_op_type_e.
  //                  For e_remote_sw, this field contains reg_id.
  //                  For e_remote_store, this field contains store mask. reg_id for tracking is placed in unmasked bytes of payload.
  //  payload      :  for store and amo, this is the store data. for load, it contains load info.
  //  src_y_cord   :  y-cord, origin of this packet
  //  src_x_cord   :  x_cord, origin of this packet
  //  y_cord       :  y-cord of the destination
  //  x_cord       :  x-cord of the destination
  //
  //  Return Packet (rev)
  //  pkt_type     :  return pkt type
  //  data         :  load data
  //  reg_id       :  reg_id in all responses should return the same reg_id in the request packet,
  //                  except for e_remote_store and e_cache_op, where reg_id is used as store mask, or cache op.
  //                  For e_remote_store and e_cache_op, some AND-OR decoding is neede to retrieve the reg_id from the payload.
  //                  Basically, OR all the 5 LSBs of unmasked bytes.
  //  y_cord       :  y-cord of the destination
  //  x_cord       :  x-cord of the destination
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
    typedef union packed {                                                      \
      bsg_manycore_cache_op_type_e cache_op;                                    \
      struct packed {                                                           \
        logic [bsg_manycore_reg_id_width_gp-(data_width_mp>>3)-1:0] unused;     \
        logic [(data_width_mp>>3)-1:0] mask;                                    \
      } store_mask_s;                                                           \
      logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;                          \
    } bsg_manycore_packet_reg_id_u;                                             \
                                                                        \
    typedef struct packed {                                             \
       logic [addr_width_mp-1:0] addr;                                  \
       bsg_manycore_packet_op_e op_v2;                                  \
       bsg_manycore_packet_reg_id_u reg_id;                             \
       bsg_manycore_packet_payload_u payload;                           \
       logic [y_cord_width_mp-1:0] src_y_cord;                          \
       logic [x_cord_width_mp-1:0] src_x_cord;                          \
       logic [y_cord_width_mp-1:0] y_cord;                              \
       logic [x_cord_width_mp-1:0] x_cord;                              \
    } bsg_manycore_packet_s
  
  `define bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp) \
    ($bits(bsg_manycore_return_packet_type_e)+data_width_mp+bsg_manycore_reg_id_width_gp+x_cord_width_mp+y_cord_width_mp)

  `define bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    (addr_width_mp+$bits(bsg_manycore_packet_op_e)+bsg_manycore_reg_id_width_gp+data_width_mp+(2*(y_cord_width_mp+x_cord_width_mp)))



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



  //  Ruche X link struct
  //  We can take advantage of the dimension-ordered depopulated routing,
  //  and optimize out some of the coordinate bits to save wiring tracks.
  //  For request packet, src_y cord can be optimized out.
  //  For response packet, dest_y cord can be optimized out.

  `define bsg_manycore_ruche_x_link_sif_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    (`bsg_manycore_link_sif_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp)-(2*y_cord_width_mp))

  `define declare_bsg_manycore_ruche_x_link_sif_s(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
    `declare_bsg_ready_and_link_sif_s(`bsg_manycore_packet_width(addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp)-y_cord_width_mp,bsg_manycore_fwd_ruche_x_link_s); \
    `declare_bsg_ready_and_link_sif_s(`bsg_manycore_return_packet_width(x_cord_width_mp,y_cord_width_mp,data_width_mp)-y_cord_width_mp,bsg_manycore_rev_ruche_x_link_s); \
    typedef struct packed {                 \
      bsg_manycore_fwd_ruche_x_link_s fwd;  \
      bsg_manycore_rev_ruche_x_link_s rev;  \
    } bsg_manycore_ruche_x_link_sif_s


  // Use these macros to convert between ruche links and local links.
  `define bsg_manycore_ruche_x_link_fwd_inject_src_y(x_cord_width_mp,y_cord_width_mp,ruche_link_fwd,my_y)       \
    {                                                                                                           \
      ruche_link_fwd[$bits(ruche_link_fwd)-1:(2*x_cord_width_mp)+y_cord_width_mp],                              \
      my_y,                                                                                                     \
      ruche_link_fwd[(2*x_cord_width_mp)+y_cord_width_mp-1:0]                                                   \
    }
  
  `define bsg_manycore_ruche_x_link_rev_inject_dest_y(x_cord_width_mp,y_cord_width_mp,ruche_link_rev,my_y)      \
    {                                                                                                           \
      ruche_link_rev[$bits(ruche_link_rev)-1:x_cord_width_mp],                                                  \
      my_y,                                                                                                     \
      ruche_link_rev[x_cord_width_mp-1:0]                                                                       \
    }

  `define bsg_manycore_link_sif_fwd_filter_src_y(x_cord_width_mp,y_cord_width_mp,link_fwd)                      \
    {                                                                                                           \
      link_fwd[$bits(link_fwd)-1:2*(x_cord_width_mp+y_cord_width_mp)],                                          \
      link_fwd[(2*x_cord_width_mp)+y_cord_width_mp-1:0]                                                         \
    }
  
  `define bsg_manycore_link_sif_rev_filter_dest_y(x_cord_width_mp,y_cord_width_mp,link_rev)                     \
    {                                                                                                           \
      link_rev[$bits(link_rev)-1:x_cord_width_mp+y_cord_width_mp],                                              \
      link_rev[x_cord_width_mp-1:0]                                                                             \
    }
 

  // vcache DMA wormhole header flit format 
  `define declare_bsg_manycore_vcache_wh_header_flit_s(wh_flit_width_mp,wh_cord_width_mp,wh_len_width_mp,wh_cid_width_mp) \
    typedef struct packed { \
      logic [wh_flit_width_mp-(wh_cord_width_mp*2)-1-wh_len_width_mp-wh_cid_width_mp-1:0] unused; \
      logic write_not_read; \
      logic [wh_cord_width_mp-1:0] src_cord; \
      logic [wh_cid_width_mp-1:0] cid; \
      logic [wh_len_width_mp-1:0] len; \
      logic [wh_cord_width_mp-1:0] dest_cord; \
    } bsg_manycore_vcache_wh_header_flit_s


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
