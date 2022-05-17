/**
 *    network_tx.v
 *
 *    This handles sending out remote packets and receiving responses.
 */

`include "bsg_manycore_defines.vh"

module network_tx
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)
    , `BSG_INV_PARAM(num_vcache_rows_p)
    , `BSG_INV_PARAM(vcache_size_p) // vcache capacity in words
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_sets_p)
 
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , localparam x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)
  
    , parameter `BSG_INV_PARAM(icache_entries_p)
    , `BSG_INV_PARAM(icache_tag_width_p)

    , localparam vcache_addr_width_lp=`BSG_SAFE_CLOG2(vcache_size_p)

    , vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p)

    , icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)

    , reg_addr_width_lp=RV32_reg_addr_width_gp

    , packet_width_lp=
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
 
    // network side
    , output logic [packet_width_lp-1:0] out_packet_o
    , output logic out_v_o
    , input out_credit_or_ready_i

    , input returned_v_i
    , input [data_width_p-1:0] returned_data_i
    , input [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_i
    , input bsg_manycore_return_packet_type_e returned_pkt_type_i
    , input returned_fifo_full_i
    , output logic returned_yumi_o
    
    , input [x_subcord_width_lp-1:0] tgo_x_i
    , input [y_subcord_width_lp-1:0] tgo_y_i

    , input [x_subcord_width_lp-1:0] my_x_i
    , input [y_subcord_width_lp-1:0] my_y_i
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i

    , input [pod_x_cord_width_p-1:0] cfg_pod_x_i
    , input [pod_y_cord_width_p-1:0] cfg_pod_y_i

    // core side
    // vanilla core uses valid-credit interface for outgoing requests.
    , input remote_req_s remote_req_i
    , input remote_req_v_i
    , output logic remote_req_credit_o

    , output logic ifetch_v_o
    , output logic [data_width_p-1:0] ifetch_instr_o
   
    , output logic [reg_addr_width_lp-1:0] float_remote_load_resp_rd_o
    , output logic [data_width_p-1:0] float_remote_load_resp_data_o
    , output logic float_remote_load_resp_v_o
    , output logic float_remote_load_resp_force_o
    , input float_remote_load_resp_yumi_i

    , output logic [reg_addr_width_lp-1:0] int_remote_load_resp_rd_o
    , output logic [data_width_p-1:0] int_remote_load_resp_data_o
    , output logic int_remote_load_resp_v_o
    , output logic int_remote_load_resp_force_o
    , input int_remote_load_resp_yumi_i

    , output logic invalid_eva_access_o
  );

  wire unused = reset_i;

  // manycore packet struct
  //
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s out_packet;
  assign out_packet_o = out_packet;


  // EVA -> NPA translation
  //
  logic is_invalid_addr_lo;
  logic [x_cord_width_p-1:0] x_cord_lo;
  logic [y_cord_width_p-1:0] y_cord_lo;
  logic [addr_width_p-1:0] epa_lo;

  bsg_manycore_eva_to_npa #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_sets_p(vcache_sets_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
  ) eva2npa (
    .eva_i(remote_req_i.addr)
    ,.tgo_x_i(tgo_x_i)
    ,.tgo_y_i(tgo_y_i)

    ,.x_cord_o(x_cord_lo)
    ,.y_cord_o(y_cord_lo)
    ,.epa_o(epa_lo)

    ,.is_invalid_addr_o(is_invalid_addr_lo) 

    // the pod rehoming stuff should not affect instruction cache fetches	     
    ,.pod_x_i(remote_req_i.load_info.icache_fetch ? pod_x_i : cfg_pod_x_i)
    ,.pod_y_i(remote_req_i.load_info.icache_fetch ? pod_y_i : cfg_pod_y_i)
  );

  // Out Packet Builder.
  //
  always_comb begin

    if (remote_req_i.write_not_read | remote_req_i.is_amo_op) begin
      out_packet.payload = remote_req_i.data;
    end
    else begin
      out_packet.payload.load_info_s.load_info = remote_req_i.load_info;
      out_packet.payload.load_info_s.reserved  = '0;
    end

    out_packet.y_cord = y_cord_lo;
    out_packet.x_cord = x_cord_lo;
    out_packet.addr = epa_lo;

    if (remote_req_i.write_not_read) begin
      out_packet.reg_id.store_mask_s.mask = remote_req_i.mask;
      out_packet.reg_id.store_mask_s.unused = 1'b0;
    end
    else begin
      out_packet.reg_id = remote_req_i.reg_id;
    end
    
    out_packet.src_y_cord = {pod_y_i, my_y_i};
    out_packet.src_x_cord = {pod_x_i, my_x_i};

    if (remote_req_i.is_amo_op) begin
      case (remote_req_i.amo_type)
        e_vanilla_amoswap:  out_packet.op_v2 = e_remote_amoswap;
        e_vanilla_amoor:    out_packet.op_v2 = e_remote_amoor;
        e_vanilla_amoadd:   out_packet.op_v2 = e_remote_amoadd;
        default:            out_packet.op_v2 = e_remote_amoswap;  // should never happen.
      endcase
    end
    else begin
      if (remote_req_i.write_not_read) begin
        out_packet.op_v2 = e_remote_store;
      end
      else begin
        out_packet.op_v2 = e_remote_load;
      end
    end

  end

  // handling outgoing requests
  //
  assign out_v_o = remote_req_v_i & ~is_invalid_addr_lo;
  assign remote_req_credit_o = out_credit_or_ready_i;
  assign invalid_eva_access_o = remote_req_v_i & is_invalid_addr_lo;


  // handling response packets
  //
  assign ifetch_instr_o = returned_data_i;
  assign int_remote_load_resp_data_o = returned_data_i;
  assign int_remote_load_resp_rd_o = returned_reg_id_i;
  assign float_remote_load_resp_data_o = returned_data_i;
  assign float_remote_load_resp_rd_o = returned_reg_id_i;

  always_comb begin
    ifetch_v_o = 1'b0;
    int_remote_load_resp_v_o = 1'b0;
    int_remote_load_resp_force_o = 1'b0;
    float_remote_load_resp_v_o = 1'b0;
    float_remote_load_resp_force_o = 1'b0;
    returned_yumi_o = 1'b0;

    // vanilla_core must accept ifetch right away.
    // vanilla_core must accept writeback return if the fifo full is valid, as indicated by the force signal.
    // The force signal being high implies that there is a valid return pkt (non-credit)
    unique casez (returned_pkt_type_i)
      e_return_ifetch: begin
        ifetch_v_o = returned_v_i;
        returned_yumi_o = returned_v_i;
      end
      e_return_float_wb: begin
        float_remote_load_resp_v_o = returned_v_i;
        float_remote_load_resp_force_o = returned_v_i  & returned_fifo_full_i;
        returned_yumi_o = float_remote_load_resp_yumi_i;
      end
      e_return_int_wb: begin
        int_remote_load_resp_v_o = returned_v_i;
        int_remote_load_resp_force_o = returned_v_i & returned_fifo_full_i;
        returned_yumi_o = int_remote_load_resp_yumi_i;
      end
      default: begin
        // Default case covers both e_return_credit and X cases, where no data is presented to the core.
        // Warning: returner_v_i will not be high for e_return_credit.
      end
    endcase

  end

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin

    if (remote_req_v_i & is_invalid_addr_lo) begin
      $display("[ERROR][TX] Invalid EVA access. t=%0t, x=%d, y=%d, cfg_pod_x_i=%d, cfg_pod_y_i=%d, addr=%h data=%h w=%b",
        $time, {pod_x_i, my_x_i}, {pod_y_i, my_y_i}, cfg_pod_x_i, cfg_pod_y_i, remote_req_i.addr, remote_req_i.data, remote_req_i.write_not_read);
    end 

    if (returned_v_i) begin
      assert(returned_pkt_type_i != e_return_credit)
        else $error("[ERROR][TX] Credit packet should not be given to vanilla core.");
    end

    // if the return fifo is full, the response has to be taken by the core at that cycle.
    if (returned_v_i & returned_fifo_full_i) begin
      assert(returned_yumi_o) else $error("[ERROR][TX] Return fifo is full, but the response is not taken by the core.");
    end

  end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(network_tx)
