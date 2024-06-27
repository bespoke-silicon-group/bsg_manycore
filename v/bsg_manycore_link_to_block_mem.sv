/**
 *    bsg_manycore_link_to_block_mem.sv
 *
 */

`include "bsg_manycore_defines.svh"
`include "block_mem_defines.vh"


module bsg_manycore_link_to_block_mem
  import bsg_manycore_pkg::*;
  import block_mem_pkg::*;
  #(parameter `BSG_INV_PARAM(link_addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(mem_size_in_words_p)
    , `BSG_INV_PARAM(icache_block_size_in_words_p)
    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , parameter fifo_els_p=4

    , localparam  mem_addr_width_lp = `BSG_SAFE_CLOG2(mem_size_in_words_p) + 2 // byte addr;
    , mem_block_addr_width_lp = `BSG_SAFE_CLOG2(mem_size_in_words_p/2/num_tiles_x_p) // word_addr;
    , icache_block_offset_width_lp = `BSG_SAFE_CLOG2(icache_block_size_in_words_p)
    , link_sif_width_lp =
      `bsg_manycore_link_sif_width(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , block_mem_pkt_width_lp =
      `block_mem_pkt_width(mem_addr_width_lp,data_width_p)
    , block_id_width_lp = `BSG_SAFE_CLOG2(2*num_tiles_x_p)
    , y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)
    , x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
  )
  (
    input clk_i
    , input reset_i

    // manycore side;
    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o
    
    // block mem side;
    , output logic [block_mem_pkt_width_lp-1:0] pkt_o
    , output logic v_o
    , input [data_width_p-1:0] data_i

    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );

  // my block id;
  wire [y_subcord_width_lp-1:0] y_subcord = global_y_i[0+:y_subcord_width_lp];
  wire [x_subcord_width_lp-1:0] x_subcord = global_x_i[0+:x_subcord_width_lp];
  wire [block_id_width_lp-1:0] my_block_id = ((y_subcord == '0) ? num_tiles_x_p : 0) 
                                           + x_subcord;

  // instantiate endpoint;
  `declare_bsg_manycore_packet_s(link_addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s packet_lo;
  logic packet_v_lo, packet_yumi_li;

  bsg_manycore_return_packet_s return_packet_li;
  logic return_packet_v_li, return_packet_credit_lo;

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

    // valid-credit interface;
    ,.return_packet_i(return_packet_li)
    ,.return_packet_v_i(return_packet_v_li)
    ,.return_packet_credit_or_ready_o(return_packet_credit_lo)

    ,.packet_i('0)
    ,.packet_v_i(1'b0)
    ,.packet_credit_or_ready_o()

    ,.return_packet_o()
    ,.return_packet_v_o()
    ,.return_packet_yumi_i(1'b0)
    ,.return_packet_fifo_full_o()
  );


  // load info;
  bsg_manycore_load_info_s load_info;
  assign load_info = packet_lo.payload.load_info_s.load_info;

  wire is_packet_ifetch = (packet_lo.op_v2 == e_remote_load) && load_info.icache_fetch;
  wire is_packet_amo = (packet_lo.op_v2 == e_remote_amoswap)
                     || (packet_lo.op_v2 == e_remote_amoor)
                     || (packet_lo.op_v2 == e_remote_amoadd);

  // block mem packet;
  `declare_block_mem_pkt_s(mem_addr_width_lp,data_width_p);
  block_mem_pkt_s block_mem_pkt;
  assign pkt_o = block_mem_pkt;


  // FSM;
  typedef enum logic [1:0] {
    RESET
    ,READY
    ,IFETCH
    ,AMO_WRITE
  } state_e;
  state_e state_r, state_n;
  

  // metadata tracking;
  logic [y_cord_width_p-1:0] src_y_r;
  logic [x_cord_width_p-1:0] src_x_r;
  bsg_manycore_return_packet_type_e return_type_r, return_type_n;
  logic [bsg_manycore_reg_id_width_gp-1:0] reg_id_r, reg_id_n;
  logic v_r, v_n;


  always_comb begin
    unique case (packet_lo.op_v2)
      e_remote_store, e_remote_sw: begin
        return_type_n = e_return_credit;
      end
      e_remote_load: begin
        if (load_info.icache_fetch)
          return_type_n = e_return_ifetch;
        else if (load_info.float_wb) 
          return_type_n = e_return_float_wb;
        else
          return_type_n = e_return_int_wb;
      end
      e_cache_op: begin
        return_type_n = e_return_credit;
      end
      e_remote_amoswap, e_remote_amoor, e_remote_amoadd:  begin
        return_type_n = e_return_int_wb;
      end
      default: begin
        return_type_n = e_return_credit; // should never happen;
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
    if (reset_i) begin
      src_y_r <= '0;
      src_x_r <= '0;
      return_type_r <= e_return_credit;
      reg_id_r <= '0;
    end
    else begin
      if (v_n) begin
        src_y_r <= packet_lo.src_y_cord;
        src_x_r <= packet_lo.src_x_cord;
        reg_id_r <= ((packet_lo.op_v2 == e_remote_store) || (packet_lo.op_v2 == e_cache_op))
          ? payload_reg_id
          : packet_lo.reg_id;
        return_type_r <= return_type_n;
      end
    end
  end


  // ifetch counter;
  logic ifetch_count_up;
  logic [icache_block_offset_width_lp-1:0] ifetch_count_r;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      ifetch_count_r <= '0;
    end
    else begin
      if (ifetch_count_up) begin
        ifetch_count_r <= ifetch_count_r + 1'b1;
      end
    end
  end


  // credit counter;
  localparam credit_max_lp = 3;
  localparam credit_width_lp = `BSG_WIDTH(credit_max_lp);

  logic [credit_width_lp-1:0] credit_count_r;
  wire can_send = ((credit_width_lp)'(credit_count_r - return_packet_credit_lo)) < credit_max_lp;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      credit_count_r <= '0;
    end
    else begin
      credit_count_r <= credit_count_r + v_n - return_packet_credit_lo;
    end
  end


  // FSM logic;
  always_comb begin
    v_o = 1'b0;
    block_mem_pkt.opcode = e_nop;
    block_mem_pkt.addr = '0;
    block_mem_pkt.data = '0;
    block_mem_pkt.mask = '0;
    state_n = state_r;
    v_n = 1'b0;
    packet_yumi_li = 1'b0;
    ifetch_count_up = 1'b0;

    case (state_r)
      RESET: begin
        state_n = READY;
      end

      READY: begin
        v_o = packet_v_lo & can_send;
        v_n = packet_v_lo & can_send;
        packet_yumi_li = (is_packet_ifetch | is_packet_amo)
          ? 1'b0
          : packet_v_lo & can_send;

        // OPCODES;
        // if two MSBs are ones, then it maps to wh_dest_east_not_west,
        // which is not used here;
        if (packet_lo.addr[link_addr_width_p-1-:2] == 2'b11) begin
          block_mem_pkt.opcode = e_nop;
        end
        // mapped to tag mem, also not used here;
        else if (packet_lo.addr[link_addr_width_p-1] == 1'b1) begin
          block_mem_pkt.opcode = e_nop;
        end
        else begin
          unique case (packet_lo.op_v2)
            // Store;
            e_remote_store, e_remote_sw: begin
              block_mem_pkt.opcode = e_store;
            end
            // atomic;
            e_remote_amoswap, e_remote_amoor, e_remote_amoadd: begin
              block_mem_pkt.opcode = e_lw; // read on first cycle;
            end
            // cache op;
            e_cache_op: begin
              block_mem_pkt.opcode = e_nop; // not used;
            end
            // loads;
            e_remote_load: begin
              if (load_info.is_byte_op)
                block_mem_pkt.opcode = load_info.is_unsigned_op
                  ? e_lbu
                  : e_lb;
              else if (load_info.is_hex_op)
                block_mem_pkt.opcode = load_info.is_unsigned_op
                  ? e_lhu
                  : e_lh;
              else begin
                block_mem_pkt.opcode = e_lw;
              end
            end
      
            default: begin
              block_mem_pkt.opcode = e_nop; // should never happen;
            end
          endcase
        end
      
        // data and mask;
        block_mem_pkt.data = packet_lo.payload;
        block_mem_pkt.mask = (packet_lo.op_v2 == e_remote_sw) 
          ? 4'b1111
          : packet_lo.reg_id.store_mask_s.mask;

        // addr;
        unique case (packet_lo.op_v2)
          e_remote_load: begin
            block_mem_pkt.addr = {
              my_block_id,
              packet_lo.addr[mem_block_addr_width_lp-1:icache_block_offset_width_lp],
              load_info.icache_fetch ? ifetch_count_r : packet_lo.addr[icache_block_offset_width_lp-1:0],
              load_info.part_sel
            };
          end
          default: begin
            block_mem_pkt.addr = {
              my_block_id,
              packet_lo.addr[mem_block_addr_width_lp-1:0],
              2'b00
            };
          end
        endcase

        ifetch_count_up = is_packet_ifetch & packet_v_lo & can_send;
        state_n = (packet_v_lo & can_send)
          ? (is_packet_ifetch
            ? IFETCH
            : (is_packet_amo
              ? AMO_WRITE
              : READY))
          : READY;
      end

      IFETCH: begin
        v_n = packet_v_lo & can_send;
        v_o = packet_v_lo & can_send;
        packet_yumi_li = packet_v_lo & can_send & (ifetch_count_r == icache_block_size_in_words_p-1);
        
        block_mem_pkt.opcode = e_lw;
        block_mem_pkt.addr = {
          my_block_id,
          packet_lo.addr[mem_block_addr_width_lp-1:icache_block_offset_width_lp],
          ifetch_count_r,
          2'b00
        };

        block_mem_pkt.data = '0;  // dont care;
        block_mem_pkt.mask = '0; // dont care;

        ifetch_count_up = packet_v_lo & can_send;
        state_n = packet_v_lo & can_send
          ? ((ifetch_count_r == icache_block_size_in_words_p-1)
            ? READY
            : IFETCH)
          : IFETCH;
      end

      AMO_WRITE: begin
        v_n = 1'b0; // already sent one in the previous cycle;
        v_o = 1'b1;
        packet_yumi_li = 1'b1;
        block_mem_pkt.opcode = e_store;
        block_mem_pkt.mask = {(data_width_p>>3){1'b1}};

        block_mem_pkt.addr = {
          my_block_id,
          packet_lo.addr[mem_block_addr_width_lp-1:0],
          2'b00
        };

        case (packet_lo.op_v2)
          e_remote_amoswap: begin
            block_mem_pkt.data = packet_lo.payload;
          end
          e_remote_amoor: begin
            block_mem_pkt.data = packet_lo.payload | data_i;
          end
          e_remote_amoadd: begin
            block_mem_pkt.data = packet_lo.payload + data_i;
          end
          default: begin
            block_mem_pkt.data = '0; // should never happen;
          end
        endcase

        state_n = READY;
      end

      default: begin
        state_n = READY;  // should never happen;
      end
    endcase
  end

  assign return_packet_v_li = v_r;
  assign return_packet_li = '{
    pkt_type  : return_type_r,
    data      : data_i,
    reg_id    : reg_id_r,
    y_cord    : src_y_r,
    x_cord    : src_x_r
  };


  // sequential;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= RESET;
      v_r  <= 1'b0;
    end
    else begin
      state_r <= state_n;
      v_r <= v_n;
    end
  end


endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_link_to_block_mem)
