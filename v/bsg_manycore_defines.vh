`ifndef BSG_MANYCORE_DEFINES_VH
`define BSG_MANYCORE_DEFINES_VH

/**
 *    bsg_manycore_defines.vh
 *
 *    The mother of all SV definitions in bsg_manycore.
 *
 */

  `include "bsg_defines.v"
  `include "bsg_noc_links.vh"

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

`endif

