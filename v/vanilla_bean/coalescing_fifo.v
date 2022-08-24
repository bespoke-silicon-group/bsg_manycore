/**
 *      coalescing_fifo.v
 *
 */



`include "bsg_defines.v"
`include "bsg_manycore_defines.vh"

module coalescing_fifo
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)

    , localparam pkt_width_lp=
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
  
    , input v_i
    , input load_coalescing_hint_i
    , input load_coalescing_pair_i
    , input [pkt_width_lp-1:0] packet_i
    , output logic credit_o 

    , output logic v_o
    , output [pkt_width_lp-1:0] packet_o
    , input yumi_i
  );

  localparam lg_vcache_block_size_in_words_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p);

  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  
  localparam fifo_els_lp = 4; // const
  localparam num_els_width_lp = `BSG_WIDTH(fifo_els_lp);

  // FIFO entry struct.
  typedef struct packed {
    logic load_coalescing_hint;
    logic load_coalescing_pair;
    bsg_manycore_packet_s packet;
  } fifo_entry_s;

  fifo_entry_s input_el;
  fifo_entry_s coalesced_el;
  assign input_el.packet = packet_i;
  assign input_el.load_coalescing_hint = load_coalescing_hint_i;
  assign input_el.load_coalescing_pair = load_coalescing_pair_i;


  // Storage elements
  logic [num_els_width_lp-1:0] num_els_r; // entry counter
  fifo_entry_s [fifo_els_lp-1:0] el_r, el_n;
  logic [fifo_els_lp-1:0] el_enable;
  logic [fifo_els_lp-1:0] el_valid;

  for (genvar i = 0; i < fifo_els_lp; i++) begin:e
    bsg_dff_en #(
      .width_p($bits(fifo_entry_s))
    ) dff (
      .clk_i(clk_i)
      ,.en_i(el_enable[i])
      ,.data_i(el_n[i])
      ,.data_o(el_r[i])
    );
  end

  assign packet_o = el_r[0].packet;

  // Mux0
  // [0] = el_r[1]
  // [1] = input
  // [2] = coalesced
  logic [2:0] mux0_sel;
  bsg_mux_one_hot #(
    .els_p(3)
    ,.width_p($bits(fifo_entry_s))
  ) mux0 (
    .data_i({coalesced_el, input_el, el_r[1]})
    ,.sel_one_hot_i(mux0_sel)
    ,.data_o(el_n[0])
  );


  // Mux1
  logic [1:0] mux1_sel;
  bsg_mux_one_hot #(
    .els_p(2)
    ,.width_p($bits(fifo_entry_s))
  ) mux1 (
    .data_i({input_el, el_r[2]})
    ,.sel_one_hot_i(mux1_sel)
    ,.data_o(el_n[1])
  );

  // Mux2
  logic [1:0] mux2_sel;
  bsg_mux_one_hot #(
    .els_p(2)
    ,.width_p($bits(fifo_entry_s))
  ) mux2 (
    .data_i({input_el, el_r[3]})
    ,.sel_one_hot_i(mux2_sel)
    ,.data_o(el_n[2])
  );

  
  // el2 next data
  assign el_n[3] = input_el;


  // coalescing detection logic
  bsg_manycore_load_info_s el0_load_info;
  assign el0_load_info = el_r[0].packet.payload.load_info_s.load_info;
  wire [lg_vcache_block_size_in_words_lp:0] next_coal_addr = el_r[0].packet.addr[0+:lg_vcache_block_size_in_words_lp]
                                                      + 1'b1 + el0_load_info.coalesce_len;

  wire coalesce_v = (el_valid[0] & el_valid[1])
                  &&  el_r[0].load_coalescing_hint   // got hint?
                  && el_r[1].load_coalescing_pair   // got the pair bit?
                  && (el0_load_info.coalesce_len != 2'b11)  // coalesce len not max?
                  && (~next_coal_addr[lg_vcache_block_size_in_words_lp]); // check block boundary overflow.
    
  // Coalesced entry
  bsg_manycore_packet_s coalesced_packet;  
  bsg_manycore_load_info_s coalesced_load_info;
  assign coalesced_load_info = '{
    coalesce_rd:  {
      (el0_load_info.coalesce_len == 2'b10) ? el_r[1].packet.reg_id : el0_load_info.coalesce_rd[2],
      (el0_load_info.coalesce_len == 2'b01) ? el_r[1].packet.reg_id : el0_load_info.coalesce_rd[1],
      (el0_load_info.coalesce_len == 2'b00) ? el_r[1].packet.reg_id : el0_load_info.coalesce_rd[0]
    },
    coalesce_len: 2'(el0_load_info.coalesce_len + 1'b1),
    float_wb: el0_load_info.float_wb,
    icache_fetch: 1'b0,
    is_unsigned_op: 1'b0,
    is_byte_op: 1'b0,
    is_hex_op:1'b0,
    part_sel: 2'b00
  };

  assign coalesced_packet = '{
    addr: el_r[0].packet.addr,
    op_v2: el_r[0].packet.op_v2,
    reg_id: el_r[0].packet.reg_id,
    payload: data_width_p'(coalesced_load_info),
    src_y_cord: el_r[0].packet.src_y_cord,
    src_x_cord: el_r[0].packet.src_x_cord,
    y_cord: el_r[0].packet.y_cord,
    x_cord: el_r[0].packet.x_cord
  };

  assign coalesced_el = '{
    load_coalescing_hint: el_r[1].load_coalescing_hint,
    load_coalescing_pair: 1'b0, // dont care
    packet: coalesced_packet
  };

  logic timeout_r;
  logic timeout_clear, timeout_set;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      timeout_r <= 1'b0;
    end
    else begin
      if (timeout_set) begin
        timeout_r <= 1'b1;
      end
      else if (timeout_clear) begin
        timeout_r <= 1'b0;
      end
    end
  end
  

  // FIFO logic
  always_comb begin
    timeout_clear = 1'b0;
    timeout_set   = 1'b0;

    case (num_els_r)
      // FIFO is empty.
      3'b000: begin
        v_o = 1'b0;
        mux0_sel = 3'b010;
        mux1_sel = 2'b00;
        mux2_sel = 2'b00;
        el_enable[0] = v_i;
        el_enable[1] = 1'b0;
        el_enable[2] = 1'b0;
        el_enable[3] = 1'b0;
        el_valid = 4'b0000;
      end

      // check if el0 has the hint bit.
      // if it does, then it waits for el1 to appear for at most 1 cycle.
      3'b001: begin
        if (timeout_r) begin
          v_o = 1'b1;
          mux0_sel = 3'b010;
          mux1_sel = 2'b10;
          mux2_sel = 2'b10;
          el_enable[0] = v_i & yumi_i;
          el_enable[1] = v_i & ~yumi_i;
          el_enable[2] = 1'b0;
          el_enable[3] = 1'b0;
          timeout_clear = v_i | yumi_i;
        end
        else begin
          v_o = ~el_r[0].load_coalescing_hint;
          mux0_sel = 3'b010;
          mux1_sel = 2'b10;
          mux2_sel = 2'b00;
          el_enable[0] = v_i & yumi_i;
          el_enable[1] = v_i & ~yumi_i;
          el_enable[2] = 1'b0;
          el_enable[3] = 1'b0;
          timeout_set = el_r[0].load_coalescing_hint & ~v_i;
        end
        el_valid = 4'b0001;
      end

      // 2 valid
      3'b010: begin
        v_o = ~coalesce_v;
        mux0_sel = coalesce_v
          ? 3'b100
          : 3'b001;
        mux1_sel = 2'b10;
        mux2_sel = 2'b10;
        el_enable[0] = (coalesce_v | yumi_i);
        el_enable[1] = v_i & (coalesce_v | yumi_i);
        el_enable[2] = v_i & ~(coalesce_v | yumi_i);
        el_enable[3] = 1'b0;
        el_valid = 4'b0011;
      end

      // 3 valid
      3'b011: begin
        v_o =  ~coalesce_v;
        mux0_sel = coalesce_v
          ? 3'b100
          : 3'b001;
        mux1_sel = 2'b01;
        mux2_sel = 2'b10;
        el_enable[0] = (coalesce_v | yumi_i);
        el_enable[1] = (coalesce_v | yumi_i);
        el_enable[2] = v_i & (coalesce_v | yumi_i);
        el_enable[3] = v_i & ~(coalesce_v | yumi_i);
        el_valid = 4'b0111;
      end

      // FIFO is FULL.
      3'b100: begin
        v_o =  ~coalesce_v;
        mux0_sel = coalesce_v
          ? 3'b100
          : 3'b001;
        mux1_sel = 2'b01;
        mux2_sel = 2'b01;
        el_enable[0] = (coalesce_v | yumi_i);
        el_enable[1] = (coalesce_v | yumi_i);
        el_enable[2] = (coalesce_v | yumi_i);
        el_enable[3] = v_i & (coalesce_v | yumi_i);
        el_valid = 4'b1111;
      end
      
      // should never happen.
      default: begin
        v_o = 1'b0;
        mux0_sel = 3'b000;
        mux1_sel = 2'b00;
        mux2_sel = 2'b00;
        el_enable = '0;
        el_valid = '0;
      end
    endcase
  end


  // credit
  logic credit_r;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      credit_r <= 1'b0;
    end
    else begin
      credit_r <= (coalesce_v | yumi_i);
    end
  end

  assign credit_o = credit_r;
  


  // counter logic
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      num_els_r <= '0;
    end
    else begin
      num_els_r <= num_els_r + v_i - coalesce_v - yumi_i;
    end
  end


endmodule

`BSG_ABSTRACT_MODULE(coalesing_fifo)


