`ifndef BSG_MANYCORE_PACKET_VH
`define BSG_MANYCORE_PACKET_VH

`include "bsg_noc_links.vh"

`define return_packet_type_width  1

`define  ePacketOp_remote_load    2'b00
`define  ePacketOp_remote_store   2'b01
`define  ePacketOp_remote_swap_aq 2'b10
`define  ePacketOp_remote_swap_rl 2'b11

`define  ePacketType_credit      `return_packet_type_width'(0)  
`define  ePacketType_data        `return_packet_type_width'(1)   


`define declare_bsg_manycore_packet_s(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width) \
   typedef struct packed {                                  \
      logic [`return_packet_type_width-1:0]     pkt_type;   \
      logic [(in_data_width)-1:0]               data  ;     \
      logic [(in_y_cord_width)-1:0]             y_cord;     \
      logic [(in_x_cord_width)-1:0]             x_cord;     \
      } bsg_manycore_return_packet_s;                       \
                                                     \
   typedef struct packed {                           \
      logic [(in_addr_width)-1:0]    addr;           \
      logic [1:0]                    op;             \
      logic [(in_data_width>>3)-1:0] op_ex;          \
      logic [(in_data_width)-1:0]    data;           \
      logic [(in_y_cord_width)-1:0]  src_y_cord;     \
      logic [(in_x_cord_width)-1:0]  src_x_cord;     \
      logic [(in_y_cord_width)-1:0]  y_cord;         \
      logic [(in_x_cord_width)-1:0]  x_cord;         \
   } bsg_manycore_packet_s

`define bsg_manycore_return_packet_width(in_x_cord_width,in_y_cord_width,in_data_width) ( (in_x_cord_width) \
                                                                           +(in_y_cord_width) \
                                                                           +(in_data_width  ) \
                                                                           +(`return_packet_type_width) \
                                                                          )

`define bsg_manycore_packet_width(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width) \
        (                                     \
            ( 2 * (in_x_cord_width) )         \
          + ( 2 * (in_y_cord_width) )         \
          + ( in_data_width         )         \
          + ( 2                     )         \
          + ( (in_data_width) >> 3  )         \
          + ( in_addr_width         )         \
        )



// note op_ex above is the byte mask for writes.
// we put the addr at the top of the packet so that we can truncate it
// X must be lowest in the packet, and Y must be the next lowest for bsg_mesh_router to work.
//

`define bsg_manycore_link_sif_width(in_addr_width,in_data_width,in_x_cord_width, in_y_cord_width)                              \
     (   `bsg_ready_and_link_sif_width(`bsg_manycore_packet_width(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width))        \
       + `bsg_ready_and_link_sif_width(`bsg_manycore_return_packet_width(in_x_cord_width,in_y_cord_width, in_data_width))                     \
     )

`define declare_bsg_manycore_fwd_link_sif_s(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width,name)  \
     `declare_bsg_ready_and_link_sif_s(`bsg_manycore_packet_width(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width),name)

`define declare_bsg_manycore_rev_link_sif_s(in_x_cord_width,in_y_cord_width,in_data_width, name)  \
     `declare_bsg_ready_and_link_sif_s(`bsg_manycore_return_packet_width(in_x_cord_width,in_y_cord_width, in_data_width),name)

`define write_bsg_manycore_packet_s(PKT)                                                                                                     \
    $write("op=2'b%b, op_ex=4'b%b, addr=%-d'h%h data=%-d'h%h (x,y)=(%-d'b%b,%-d'b%b), return (x,y)=(%-d'b%b,%-d'b%b)"                        \
           , PKT.op, PKT.op_ex, $bits(PKT.addr), PKT.addr, $bits(PKT.data), PKT.data, $bits(PKT.x_cord), PKT.x_cord, $bits(PKT.y_cord), PKT.y_cord, $bits(PKT.src_x_cord), PKT.src_x_cord, $bits(PKT.src_y_cord), PKT.src_y_cord)

// defines bsg_manycore_fwd_link_sif, bsg_manycore_rev_link_sif, and the combination, bsg_manycore_link_sif_s
`define declare_bsg_manycore_link_sif_s(in_addr_width, in_data_width, in_x_cord_width, in_y_cord_width)                                \
    `declare_bsg_manycore_fwd_link_sif_s(in_addr_width, in_data_width, in_x_cord_width, in_y_cord_width, bsg_manycore_fwd_link_sif_s); \
    `declare_bsg_manycore_rev_link_sif_s(in_x_cord_width, in_y_cord_width,in_data_width, bsg_manycore_rev_link_sif_s);                               \
                                                                                                                                       \
   typedef struct packed {             \
      bsg_manycore_fwd_link_sif_s fwd; \
      bsg_manycore_rev_link_sif_s rev; \
   } bsg_manycore_link_sif_s

// For I/O, we want to have large address spaces
// but for tiles, we do not need a large address space.
// If we always have power-of-two tile dimensions in Y direction,
// then we can say the "extra row" owns all of the address space,
// and we use the additional Y bits as address space. Requires
// changes to the address map, to avoid the "special opcodes" though.
//
// We also need to efficiently encode the transfer of
// of packets across the bsg_fsb in a way that does not lose the
// information of what column it was in.
//
// For smaller arrays, we can still use the 80 bit packet. For larger
// arrays, we would have to use a larger packet.
//
// bsg_fsb_manycore_80_bits small packet
// 4  dest id (we could reduce in future; but breaks some compatibility)
// 1  cmd
// 75 payload
//    3 channel bits (x4 configs; fwd+rev channel)  (supports 4 exposed links)
//    72 network payload
//       20 address (= 1 M words = 4 MB)
//        2 op
//        4 mask
//       32 data
//        7 route sender --> 3+3+1 bits
//        7 route dest   --> 3+3+1 bits  (supports 8x8 mesh)
//
// For larger manycore arrays that are split across two chips (e.g. FPGA and ASIC
// for NASA for a mesh "ADN"), we need to have a wider packet. Here is an encoding
// of that packet.
//
// bsg_fsb_manycore_96_bits large packet
//
// 2  destid  (assumes point-to-point, 1 = forward net, 2 = return net)
// 1  cmd     (1=switch,0=node)
// 93 payload
//    5  channel bits (32x32)
//    88 network packet
//      32 data
//       4 mask (for bytes)
//       2 op
//      11 route dest
//      11 route sender
//      28 address (= 1 GB)
//
// Clearly if we are sending packets in/out to a DRAM, our use of the bsg_comm_link
// link is not very bandwidth optimal since we encode 32 bits of data per 80 bits.
// In that case, a different mechanism would be employed that would first transmit
// a single address, and then transmit data. Probably, we will never do this.
//
// In the case of the CERTUS chip, we will go
// through the Rocket core's cache, which presumably will have its own DRAM optimized
// path over FSB.
//

/*
  typedef struct packed {
    logic [3:0]      srcid;  // 4 bits
    logic [3:0]      destid; // 4 bits
    logic [0:0]      cmd;    // 1 bits (1 for switch, 0 for node)
    bsg_fsb_opcode_s opcode; // 7 bits
    logic [63:0]     data;   // 64 bits
  } bsg_fsb_pkt_s;

  we can basically use srcid,opcode,data-> 4+7+64 = 75 = 80-5 bits.

     data        32 -> 32
    return/dest  12 -> 44
    op            2 -> 46    (no op_ex      )
    addr         24 -> 70    (64 MB per tile)
    channel       3 -> 75

    we could steal away 2 SRCID bits from comm link, and get to 256 MB per tile.

   Q: what about the return network?

   */


`endif // BSG_MANYCORE_PACKET_VH
