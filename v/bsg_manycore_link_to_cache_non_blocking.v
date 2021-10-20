/**
 *    bsg_manycore_link_to_cache_non_blocking.v
 *
 *    This module connects manycore link to the non-blocking vcache.
 *
 */

`include "bsg_cache_non_blocking.vh"

module bsg_manycore_link_to_cache_non_blocking 
  import bsg_manycore_pkg::*;
  import bsg_cache_non_blocking_pkg::*;
  #(`BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    // cache parmeters
    , `BSG_INV_PARAM(sets_p)
    , `BSG_INV_PARAM(ways_p)
    , `BSG_INV_PARAM(block_size_in_words_p)
    , `BSG_INV_PARAM(miss_fifo_els_p)

    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , parameter cache_addr_width_lp=(addr_width_p-1+byte_offset_width_lp)
    
    , parameter id_width_lp=(x_cord_width_p+y_cord_width_p+5+2)
    , parameter cache_pkt_width_lp=
      `bsg_cache_non_blocking_pkt_width(id_width_lp,cache_addr_width_lp,data_width_p)
  )
  (
    input clk_i
    , input reset_i

    // manycore link
    , input  [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    // cache side
    , output [cache_pkt_width_lp-1:0] cache_pkt_o
    , output logic v_o
    , input ready_i
  
    , input [data_width_p-1:0] data_i
    , input [id_width_lp-1:0] id_i
    , input v_i
    , output logic yumi_o
  );

  // localparam
  localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p);
  localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p);
  localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_size_in_words_p)+byte_offset_width_lp;


  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s packet_lo;
  logic packet_v_lo;
  logic packet_yumi_li;

  bsg_manycore_return_packet_s return_packet_li;
  logic return_packet_v_li;
  logic return_packet_ready_lo;

  bsg_manycore_endpoint #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p) 
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.fifo_els_p(4)
  ) ep (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    ,.packet_o(packet_lo)
    ,.packet_v_o(packet_v_lo)
    ,.packet_yumi_i(packet_yumi_li)

    ,.return_packet_i(return_packet_li)
    ,.return_packet_v_i(return_packet_v_li)
    ,.return_packet_ready_o(return_packet_ready_lo)

    ,.packet_i('0)
    ,.packet_v_i(1'b0)
    ,.packet_credit_or_ready_o()

    ,.return_packet_o()
    ,.return_packet_v_o()
    ,.return_packet_yumi_i(1'b0)
    ,.return_packet_fifo_full_o()
  );

  
  typedef enum logic [1:0] {
    RESET
    , CLEAR_TAG
    , READY
  } state_e;

  state_e state_r, state_n;
  logic [lg_ways_lp+lg_sets_lp:0] tagst_sent_r, tagst_sent_n;
  logic [lg_ways_lp+lg_sets_lp:0] tagst_recv_r, tagst_recv_n;

  `declare_bsg_cache_non_blocking_pkt_s(id_width_lp,cache_addr_width_lp,data_width_p);

  bsg_cache_non_blocking_pkt_s cache_pkt;
  assign cache_pkt_o = cache_pkt;

  bsg_manycore_load_info_s load_info;
  assign load_info = packet_lo.payload.load_info_s.load_info;


  typedef struct packed {
    logic [x_cord_width_p-1:0] src_x;
    logic [y_cord_width_p-1:0] src_y;
    bsg_manycore_return_packet_type_e pkt_type; 
    logic [4:0] reg_id;
  } bsg_manycore_cache_id_s; // non-blocking cache request id.

  bsg_manycore_cache_id_s cache_pkt_id;
  bsg_manycore_cache_id_s id_li;
  assign id_li = id_i;

  always_comb begin
    
    v_o = 1'b0;
    yumi_o = 1'b0;
    cache_pkt.opcode = TAGST;
    cache_pkt.addr = '0;
    cache_pkt.data = '0;
    cache_pkt.mask = '0;

    tagst_sent_n = tagst_sent_r;
    tagst_recv_n = tagst_recv_r;

    packet_yumi_li = 1'b0;

    return_packet_v_li = 1'b0;
    return_packet_li = '0;

    cache_pkt_id = '0;
    cache_pkt.id = cache_pkt_id;

    case (state_r)

      RESET: begin
        v_o = 1'b0;
        yumi_o = 1'b0;
        state_n = CLEAR_TAG;
      end

      CLEAR_TAG: begin
        v_o = tagst_sent_r != (ways_p*sets_p);
        cache_pkt.opcode = TAGST;
        cache_pkt.data = '0;
        cache_pkt.addr = {
          {(cache_addr_width_lp-lg_sets_lp-lg_ways_lp-block_offset_width_lp){1'b0}},
          tagst_sent_r[0+:lg_sets_lp+lg_ways_lp],
          {block_offset_width_lp{1'b0}}
        };

        tagst_sent_n = (v_o & ready_i)
          ? tagst_sent_r + 1
          : tagst_sent_r;

        tagst_recv_n = v_i
          ? tagst_recv_r + 1
          : tagst_recv_r;

        yumi_o = v_i;
        
        state_n = (tagst_sent_r == ways_p*sets_p) & (tagst_recv_r == ways_p*sets_p)
          ? READY
          : CLEAR_TAG;
        
      end

      READY: begin

        // cache pkt
        v_o = packet_v_lo;
        packet_yumi_li = packet_v_lo & ready_i;
        
        if (packet_lo.addr[addr_width_p-1]) begin
          case (packet_lo.op_v2)
            e_remote_store: cache_pkt.opcode = TAGST;
            e_remote_load:  cache_pkt.opcode = TAGLA;
            e_cache_op:     cache_pkt.opcode = TAGFL;
            default:        cache_pkt.opcode = TAGLA; // should never happen
          endcase
        end
        else begin
          if (packet_lo.op_v2 == e_remote_store) begin
            cache_pkt.opcode = SM;
          end
          else if (packet_lo.op_v2 == e_cache_op) begin
            case (packet_lo.reg_id.cache_op)
              e_afl: cache_pkt.opcode = AFL;
              e_aflinv: cache_pkt.opcode = AFLINV;
              e_ainv: cache_pkt.opcode = AINV;
              default: cache_pkt.opcode = AINV; // (what should the default be? shouldn't happen)
            endcase
          end
          else begin
            if (load_info.is_byte_op)
              cache_pkt.opcode = load_info.is_unsigned_op
                ? LBU
                : LB;
            else if (load_info.is_hex_op)
              cache_pkt.opcode = load_info.is_unsigned_op
                ? LHU
                : LH;
            else begin
              cache_pkt.opcode = LW;
            end
          end
        end

        cache_pkt.data = packet_lo.payload;
        cache_pkt.addr = {
          packet_lo.addr[0+:addr_width_p-1],
          (packet_lo.op == e_remote_store) | (packet_lo.op == e_cache_op) ? 2'b00 : load_info.part_sel
        };
        cache_pkt.mask = packet_lo.store_mask_s.mask;

        cache_pkt_id.src_x = packet_lo.src_x_cord;
        cache_pkt_id.src_y = packet_lo.src_y_cord;
        cache_pkt_id.reg_id = packet_lo.reg_id; 
        cache_pkt_id.pkt_type = (packet_lo.op == e_remote_store) | (packet_lo.op == e_cache_op)
          ? e_return_credit
          : (load_info.icache_fetch
            ? e_return_ifetch
            : (load_info.float_wb ? e_return_float_wb : e_return_int_wb));
        cache_pkt.id = cache_pkt_id;

        // return packet
        return_packet_v_li = v_i;
        yumi_o = v_i & return_packet_ready_lo;

        return_packet_li.pkt_type = id_li.pkt_type;
        return_packet_li.data = data_i;
        return_packet_li.reg_id = id_li.reg_id;
        return_packet_li.y_cord = id_li.src_y;
        return_packet_li.x_cord = id_li.src_x;
        
        state_n = READY;

      end

      default: begin
        state_n = RESET;
      end

    endcase
  end




  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= RESET;
      tagst_sent_r <= '0;
      tagst_recv_r <= '0;
    end
    else begin
      state_r <= state_n;
      tagst_sent_r <= tagst_sent_n;
      tagst_recv_r <= tagst_recv_n;
    end
  end




endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_to_cache_non_blocking)
