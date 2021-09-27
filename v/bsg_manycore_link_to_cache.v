/**
 *  bsg_manycore_link_to_cache.v
 *
 *  @author tommy
 *
 */

`include "bsg_defines.v"

module bsg_manycore_link_to_cache
  import bsg_manycore_pkg::*;
  import bsg_cache_pkg::*;
  #(`BSG_INV_PARAM(link_addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(sets_p)
    , `BSG_INV_PARAM(ways_p)
    , `BSG_INV_PARAM(block_size_in_words_p)

    , parameter fifo_els_p=4

    , parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_p)
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , parameter cache_addr_width_lp=(link_addr_width_p-1+byte_offset_width_lp) 
    , parameter block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
  
    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter bsg_cache_pkt_width_lp=
      `bsg_cache_pkt_width(cache_addr_width_lp,data_width_p)
    , parameter manycore_packet_width_lp=
      `bsg_manycore_packet_width(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // manycore-side
    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o

    // cache-side
    , output [bsg_cache_pkt_width_lp-1:0] cache_pkt_o
    , output logic v_o
    , input ready_i

    , input [data_width_p-1:0] data_i
    , input v_i
    , output logic yumi_o

    , input v_we_i

    , output logic wh_dest_east_not_west_o
  );


  // instantiate endpoint
  //
  `declare_bsg_manycore_packet_s(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

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
    ,.addr_width_p(link_addr_width_p)
    ,.fifo_els_p(fifo_els_p)
  ) bme (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    ,.packet_o(packet_lo)
    ,.packet_v_o(packet_v_lo)
    ,.packet_yumi_i(packet_yumi_li)

    ,.return_packet_i(return_packet_li)
    ,.return_packet_v_i(return_packet_v_li)
    ,.return_packet_credit_or_ready_o(return_packet_ready_lo)

    ,.packet_i('0)
    ,.packet_v_i(1'b0)
    ,.packet_credit_or_ready_o()

    ,.return_packet_o()
    ,.return_packet_v_o()
    ,.return_packet_yumi_i(1'b0)
    ,.return_packet_fifo_full_o()     
  );


  // load info
  bsg_manycore_load_info_s load_info;
  assign load_info = packet_lo.payload.load_info_s.load_info;


  // at the reset, this module intializes all the tags and valid bits to zero.
  // After all the tags are completedly initialized, this module starts
  // accepting packets from manycore network.
  `declare_bsg_cache_pkt_s(cache_addr_width_lp, data_width_p);
  bsg_cache_pkt_s cache_pkt;
  assign cache_pkt_o = cache_pkt;

  typedef enum logic [1:0] {
    RESET
    ,CLEAR_TAG
    ,READY
  } state_e;

  state_e state_r, state_n;
  logic [lg_sets_lp+lg_ways_lp:0] tagst_sent_r, tagst_sent_n;
  logic [lg_sets_lp+lg_ways_lp:0] tagst_received_r, tagst_received_n;
  logic wh_dest_east_not_west_r, wh_dest_east_not_west_n;
  assign wh_dest_east_not_west_o = wh_dest_east_not_west_r;

  // cache pipeline tracker
  // 
  typedef struct packed {
    bsg_manycore_return_packet_type_e pkt_type;
    logic [4:0] reg_id;
    logic [y_cord_width_p-1:0] y_cord;
    logic [x_cord_width_p-1:0] x_cord;
  } cache_info_s;

  cache_info_s tl_info_r, tv_info_r;
  
  bsg_manycore_return_packet_type_e return_pkt_type;

  always_comb begin
    unique case (packet_lo.op_v2)
      e_remote_store, e_remote_sw: begin
        return_pkt_type = e_return_credit;
      end
      e_remote_load: begin
        if (load_info.icache_fetch)
          return_pkt_type = e_return_ifetch;
        else if (load_info.float_wb)
          return_pkt_type = e_return_float_wb;
        else
          return_pkt_type = e_return_int_wb;
      end
      e_cache_op: begin
        return_pkt_type = e_return_credit;
      end
      e_remote_amoswap, e_remote_amoor, e_remote_amoadd: begin
        return_pkt_type = e_return_int_wb;
      end
      // should never happen
      default: begin
        return_pkt_type = e_return_credit;
      end
    endcase
  end  

  wire [bsg_manycore_reg_id_width_gp-1:0] payload_reg_id;
  bsg_manycore_reg_id_decode pd0 (
    .data_i(packet_lo.payload)
    ,.mask_i(packet_lo.reg_id.store_mask_s.mask)
    ,.reg_id_o(payload_reg_id)
  );

  always_ff @ (posedge clk_i) begin
    if (state_r == READY) begin
      if (v_o & ready_i) begin
        tl_info_r <= '{
          pkt_type: return_pkt_type,
          reg_id : ((packet_lo.op_v2 == e_remote_store) | (packet_lo.op_v2 == e_cache_op)) 
              ? payload_reg_id
              : packet_lo.reg_id,
          y_cord: packet_lo.src_y_cord,
          x_cord: packet_lo.src_x_cord
        };
      end
      if (v_we_i) begin
        tv_info_r <= tl_info_r;
      end
    end
  end



  always_comb begin

    cache_pkt.mask = '0;
    cache_pkt.data = '0;
    cache_pkt.addr = '0;
    cache_pkt.opcode = TAGST;
    tagst_sent_n = tagst_sent_r;
    tagst_received_n = tagst_received_r;
    wh_dest_east_not_west_n = wh_dest_east_not_west_r;
    v_o = 1'b0;
    yumi_o = 1'b0;
    state_n = state_r;

    packet_yumi_li = 1'b0;
    return_packet_v_li = 1'b0;  

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
          {(block_offset_width_lp){1'b0}}
        };


        tagst_sent_n = (v_o & ready_i)
          ? tagst_sent_r + 1
          : tagst_sent_r;
        tagst_received_n = v_i
          ? tagst_received_r + 1
          : tagst_received_r;

        yumi_o = v_i;

        state_n = (tagst_sent_r == ways_p*sets_p) & (tagst_received_r == ways_p*sets_p)
          ? READY
          : CLEAR_TAG;
      end

      READY: begin

        // cache pkt
        v_o = packet_v_lo;
        packet_yumi_li = packet_v_lo & ready_i;
    

        // if two MSBs are ones, then it maps to wh_dest_east_not_west.
        // store-only;
        if (packet_lo.addr[link_addr_width_p-1-:2] == 2'b11) begin

          case (packet_lo.op_v2)
            e_remote_store: cache_pkt.opcode = TAGLA; // it injects TAGLA as noop;
            default: begin
              cache_pkt.opcode = TAGLA;
              // synopsys translate_off
              assert final(reset_i !== 1'b0 | ~packet_v_lo)
                else $error("[BSG_ERROR] Invalid packet op for wh_dest_east_not_west EPA: %b", packet_lo.op_v2);
              // synopsys translate_on
            end
          endcase

          // updated when nop packet is taken by the cache.
          wh_dest_east_not_west_n = (packet_v_lo & ready_i)
            ? packet_lo.payload[0]
            : wh_dest_east_not_west_r;
        end
        // if MSB of addr is one, then it maps to tag_mem
        // otherwise it's regular access to data_mem.
        // we want to expose read/write access to tag_mem on NPA
        // for extra debugging capability.
        else if (packet_lo.addr[link_addr_width_p-1]) begin
          case (packet_lo.op_v2)
            e_remote_store, e_remote_sw: cache_pkt.opcode = TAGST;
            e_remote_load:  cache_pkt.opcode = TAGLA;
            e_cache_op:     cache_pkt.opcode = TAGFL;
            default:        cache_pkt.opcode = TAGLA;
          endcase
        end
        else begin
          unique case (packet_lo.op_v2)
            e_remote_store, e_remote_sw: begin
              cache_pkt.opcode = SM;
            end

            e_remote_amoswap: begin
              cache_pkt.opcode = AMOSWAP_W;
            end

            e_remote_amoor: begin
              cache_pkt.opcode = AMOOR_W;
            end

            e_remote_amoadd: begin
              cache_pkt.opcode = AMOADD_W;
            end

            e_cache_op: begin
              case (packet_lo.reg_id.cache_op)
                e_afl: cache_pkt.opcode = AFL;
                e_aflinv: cache_pkt.opcode = AFLINV;
                e_ainv: cache_pkt.opcode = AINV;
                default: begin
                  cache_pkt.opcode = AFL; // should never happen
                end
              endcase
            end

            e_remote_load: begin
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
            // this should never happen.
            default: begin
              cache_pkt.opcode = AFL;
              // synopsys translate_off
              assert final(reset_i !== 1'b0 | ~packet_v_lo) else $error("[BSG_ERROR] Invalid packet op: %b", packet_lo.op_v2);
              // synopsys translate_on
            end
          endcase
        end

        cache_pkt.data = packet_lo.payload;
        cache_pkt.mask = (packet_lo.op_v2 == e_remote_sw)
          ? 4'b1111
          : packet_lo.reg_id.store_mask_s.mask;
        cache_pkt.addr = {
          packet_lo.addr[0+:link_addr_width_p-1],
          (packet_lo.op_v2 == e_remote_load) ? load_info.part_sel : 2'b00
        };

        // return pkt
        return_packet_v_li = v_i;
        yumi_o = v_i & return_packet_ready_lo;

        state_n = READY;
      end

      default: begin
        // this should never happen.
        state_n = READY;
      end
    endcase
  end

  // return packet
  assign return_packet_li = '{
    pkt_type : tv_info_r.pkt_type,
    data   : data_i,
    reg_id : tv_info_r.reg_id,
    y_cord : tv_info_r.y_cord,
    x_cord : tv_info_r.x_cord
  };

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r          <= RESET;
      tagst_sent_r     <= '0;
      tagst_received_r <= '0;
      wh_dest_east_not_west_r <= 1'b0;
    end
    else begin
      state_r          <= state_n;
      tagst_sent_r     <= tagst_sent_n;
      tagst_received_r <= tagst_received_n;
      wh_dest_east_not_west_r <= wh_dest_east_not_west_n;
    end
  end


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_link_to_cache)
