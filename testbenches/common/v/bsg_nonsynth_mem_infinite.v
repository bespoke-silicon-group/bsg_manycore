/**
 *    bsg_nonsynth_mem_infinite.v
 *
 *    memory with "infinite" capacity and zero latency.
 *    it attaches to the manycore link interface.
 *  
 */

module bsg_nonsynth_mem_infinite
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter id_p="inv"
    , parameter mem_els_p="inv"
    , parameter mem_addr_width_lp=`BSG_SAFE_CLOG2(mem_els_p)
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // instantiate endpoint
  //
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s packet_lo;
  bsg_manycore_packet_s packet_r, packet_n;
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
  ) ep0 (
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
    ,.packet_ready_o()

    ,.return_packet_o()
    ,.return_packet_v_o()
    ,.return_packet_yumi_i(1'b0)
    ,.return_packet_fifo_full_o()
  );


  // mem
  logic mem_v_li;
  logic mem_w_li;
  logic [mem_addr_width_lp-1:0] mem_addr_li;
  logic [data_width_p-1:0] mem_data_li;
  logic [data_mask_width_lp-1:0] mem_mask_li; 
  logic [data_width_p-1:0] mem_data_lo; 

  bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma #(
    .width_p(data_width_p)
    ,.els_p(mem_els_p)
    ,.id_p(id_p)
  ) assoc_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(mem_v_li)
    ,.w_i(mem_w_li)
    
    ,.addr_i(mem_addr_li)
    ,.data_i(mem_data_li)
    ,.w_mask_i(mem_mask_li)

    ,.data_o(mem_data_lo) 
  );

  logic [data_width_p-1:0] load_data_lo;

  bsg_manycore_load_info_s load_info;
  assign load_info = packet_r.payload.load_info_s.load_info;

  load_packer lp0 (
    .mem_data_i(mem_data_lo)
    ,.unsigned_load_i(load_info.is_unsigned_op)
    ,.byte_load_i(load_info.is_byte_op)
    ,.hex_load_i(load_info.is_hex_op)
    ,.part_sel_i(load_info.part_sel)
    ,.load_data_o(load_data_lo)
  );


  // FSM
  //
  typedef enum logic {
    READY,
    ATOMIC
  } state_e;

  state_e state_r, state_n;
  logic return_v_r, return_v_n;
  
  always_comb begin
  
    packet_yumi_li = 1'b0;

    mem_v_li = 1'b0;
    mem_w_li = 1'b0;
    mem_addr_li = '0;
    mem_data_li = '0;
    mem_mask_li = '0;
    
    return_packet_li = '0;
    return_packet_v_li  = 1'b0;

    state_n = state_r;
    packet_n = packet_r;
    return_v_n = return_v_r;

    case (state_r) 

      READY: begin

        mem_w_li = (packet_lo.op == e_remote_store);
        mem_addr_li = packet_lo.addr[0+:mem_addr_width_lp];
        mem_data_li = packet_lo.payload;
        mem_mask_li = packet_lo.op_ex.store_mask;

        if (packet_r.op == e_remote_store) begin
          return_packet_li.pkt_type = e_return_credit;
        end
        else begin
          if (load_info.icache_fetch)
            return_packet_li.pkt_type = e_return_ifetch;
          else if (load_info.float_wb)
            return_packet_li.pkt_type = e_return_float_wb;
          else 
            return_packet_li.pkt_type = e_return_int_wb;
        end
    
        return_packet_li.data = (packet_r.op == e_remote_load)
          ? load_data_lo
          : '0;
        return_packet_li.reg_id = (packet_r.op == e_remote_load)
          ? packet_r.reg_id
          : '0;
        return_packet_li.y_cord = packet_r.src_y_cord;
        return_packet_li.x_cord = packet_r.src_x_cord;

        // return_v_r means there is a response to be sent out.
        if (return_v_r) begin
          packet_yumi_li = packet_v_lo & return_packet_ready_lo;
          mem_v_li = packet_v_lo & return_packet_ready_lo;
          packet_n = (packet_v_lo & return_packet_ready_lo)
            ? packet_lo
            : packet_r;
          return_packet_v_li = 1'b1;
          return_v_n = return_packet_ready_lo
            ? (packet_v_lo & (packet_lo.op != e_remote_amo))
            : return_v_r;
          state_n =  (return_packet_ready_lo & packet_v_lo & (packet_lo.op == e_remote_amo))
            ? ATOMIC
            : READY;
        end
        else begin
          packet_yumi_li = packet_v_lo;
          mem_v_li = packet_v_lo;
          packet_n = packet_v_lo
            ? packet_lo
            : packet_r;
          return_packet_v_li = 1'b0;
          return_v_n = packet_v_lo & (packet_lo.op != e_remote_amo);
          state_n = (packet_v_lo & (packet_lo.op == e_remote_amo))
            ? ATOMIC
            : READY;
        end
        
      end

      ATOMIC: begin
        mem_v_li = return_packet_ready_lo;
        mem_w_li = return_packet_ready_lo;
        mem_addr_li = packet_r.addr[0+:mem_addr_width_lp];
        case (packet_r.op_ex.amo_type)
          e_amo_swap: mem_data_li = packet_r.payload;
          e_amo_or:  mem_data_li = packet_r.payload | mem_data_lo;
          default: mem_data_li = '0; // should never happen.
        endcase
        mem_mask_li = {data_mask_width_lp{1'b1}};

        return_packet_v_li = 1'b1;
        return_packet_li.data = mem_data_lo;
        return_packet_li.reg_id = packet_r.reg_id;
        return_packet_li.y_cord = packet_r.src_y_cord;
        return_packet_li.x_cord = packet_r.src_x_cord;

        if (load_info.float_wb) begin
          return_packet_li.pkt_type = e_return_float_wb;
        end
        else begin
          return_packet_li.pkt_type = e_return_int_wb;
        end

        state_n = return_packet_ready_lo 
          ? READY
          : ATOMIC;
      end

      // should never happen.
      default: begin
        state_n = READY;
      end

    endcase

  end


  // sequential
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= READY;
      packet_r <= '0;
      return_v_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      packet_r <= packet_n;
      return_v_r <= return_v_n;
    end
  end

  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin

      if (packet_v_lo) begin
        assert(packet_lo.op != e_cache_op) else $error("infinite mem does not support cache mgmt op.");
      end

    end
  end


endmodule
