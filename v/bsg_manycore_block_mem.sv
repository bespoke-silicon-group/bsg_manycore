/**
 *    bsg_manycore_block_mem.sv
 */


`include "bsg_defines.sv"
`include "block_mem_defines.vh"

module bsg_manycore_block_mem
  import block_mem_pkg::*;
  #(parameter `BSG_INV_PARAM(mem_size_in_words_p) // 2**29 (2GB)
    , `BSG_INV_PARAM(data_width_p)  // 32-bit

    , localparam lg_mem_size_in_words_lp = `BSG_SAFE_CLOG2(mem_size_in_words_p)
    , mem_addr_width_lp = lg_mem_size_in_words_lp+2 // byte addr;
    , pkt_width_lp = `block_mem_pkt_width(mem_addr_width_lp, data_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input v_i
    , input [pkt_width_lp-1:0] pkt_i  
    , output logic [data_width_p-1:0] data_o
  );


  // packet cast;
  `declare_block_mem_pkt_s(mem_addr_width_lp, data_width_p);
  block_mem_pkt_s pkt;
  assign pkt = pkt_i;


  // ctrl signals;
  wire v_li = v_i & (pkt.opcode != e_nop);
  wire w_li = (pkt.opcode == e_store);

  block_mem_op_e opcode_r;
  logic [1:0] byte_addr_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      opcode_r <= e_nop;
      byte_addr_r <= 2'b0;
    end
    else begin
      if (v_i) begin
        opcode_r <= pkt.opcode;
        byte_addr_r <= pkt.addr[1:0];
      end
    end
  end


  // DMA mem;
  logic [data_width_p-1:0] data_lo;

  bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma #(
    .width_p(data_width_p)
    ,.els_p(mem_size_in_words_p)
    ,.id_p(0)
    ,.init_mem_p(1)
  ) dma_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.v_i(v_li)
    ,.w_i(w_li)

    ,.addr_i(pkt.addr[mem_addr_width_lp-1:2])
    ,.data_i(pkt.data)
    ,.w_mask_i(pkt.mask)
    
    ,.data_o(data_lo)
  );


  // output selector;
  logic [7:0] byte_data;
  bsg_mux #(
    .els_p(4)
    ,.width_p(8)
  ) byte_mux0 (
    .data_i(data_lo)
    ,.sel_i(byte_addr_r)
    ,.data_o(byte_data)
  );

  logic [15:0] half_data;
  bsg_mux #(
    .els_p(2)
    ,.width_p(16)
  ) half_mux0 (
    .data_i(data_lo)
    ,.sel_i(byte_addr_r[1])
    ,.data_o(half_data)
  );


  always_comb begin
    case (opcode_r)
      e_store: begin
        data_o = '0;
      end
  
      e_lbu: begin
        data_o = {24'b0, byte_data};
      end      

      e_lhu: begin
        data_o = {16'b0, half_data};
      end

      e_lb: begin
        data_o = {{24{byte_data[7]}}, byte_data};
      end

      e_lh: begin
        data_o = {{16{half_data[15]}}, half_data};
      end
    
      e_lw: begin
        data_o = data_lo;
      end

      e_nop: begin
        data_o = '0;
      end

      default: begin
        data_o = '0;
      end
    endcase
  end


endmodule


`BSG_ABSTRACT_MODULE(bsg_manycore_block_mem)
