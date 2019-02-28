/**
 *  bsg_manycore_link_to_cce_rx.v
 */

`include "bsg_manycore_packet.vh"

module bsg_manycore_link_to_cce_rx
  import bp_common_pkg::*;
  #(parameter link_data_width_p="inv"
    , parameter link_addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter bp_addr_width_p="inv"
    , parameter num_lce_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter block_size_in_bits_p="inv"

    , localparam link_byte_offset_width_lp=`BSG_SAFE_CLOG2(link_data_width_p>>3)
    , localparam link_mask_width_lp=(link_data_width_p>>3)
    , localparam num_flits_lp=(block_size_in_bits_p/link_data_width_p)
    , localparam lg_num_flits_lp=`BSG_SAFE_CLOG2(num_flits_lp)
    , localparam rx_counter_width_lp=`BSG_SAFE_CLOG2(num_flits_lp+1)

    , localparam packet_width_lp=
      `bsg_manycore_packet_width(link_addr_width_p,link_data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)

    , localparam mem_cmd_width_lp=
      `bp_cce_mem_cmd_width(bp_addr_width_p,num_lce_p,lce_assoc_p)

    , localparam mem_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(bp_addr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
  )
  (
    input clk_i
    , input reset_i

    // cce side
    , input [mem_cmd_width_lp-1:0] mem_cmd_i
    , input mem_cmd_v_i
    , output logic mem_cmd_ready_o
    
    , output logic [mem_data_resp_width_lp-1:0] mem_data_resp_o
    , output logic mem_data_resp_v_o
    , input  mem_data_resp_ready_i

    // manycore side
    , output logic [packet_width_lp-1:0] rx_pkt_o
    , output logic rx_pkt_v_o
    , input rx_pkt_yumi_i

    , input [link_data_width_p-1:0] returned_data_i
    , output logic returned_yumi_o
    , input returned_v_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // manycore_packet struct
  //
  `declare_bsg_manycore_packet_s(link_addr_width_p,link_data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);
  
  bsg_manycore_packet_s rx_pkt;
  assign rx_pkt_o = rx_pkt;

  // bp_mem struct
  //
  `declare_bp_me_if(bp_addr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);
  
  bp_cce_mem_cmd_s mem_cmd;
  bp_mem_cce_data_resp_s mem_data_resp;

  assign mem_cmd = mem_cmd_i;
  assign mem_data_resp_o = mem_data_resp;

  // mem_cmd logic
  //
  typedef enum logic [1:0] {
    WAIT
    ,READ_CACHE_BLOCK
  } rx_state_e;

  rx_state_e rx_state_r, rx_state_n;

  logic rx_counter_clear_li;
  logic rx_counter_up_li;
  logic [rx_counter_width_lp-1:0] rx_counter_lo;

  bsg_counter_clear_up #(
    .max_val_p(num_flits_lp)
    ,.init_val_p(0)
  ) rx_counter (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(rx_counter_clear_li)
    ,.up_i(rx_counter_up_li)
    ,.count_o(rx_counter_lo)
  );

  bp_cce_mem_cmd_s mem_cmd_r, mem_cmd_n;

  // fifo to queue mem_cmd after packets are sent out
  //
  logic mem_cmd_fifo_v_li;
  logic mem_cmd_fifo_ready_lo;
  logic mem_cmd_fifo_v_lo;
  logic mem_cmd_fifo_yumi_li;
  bp_cce_mem_cmd_s mem_cmd_fifo_data_lo;

  bsg_fifo_1r1w_small #(
    .width_p(mem_cmd_width_lp)
    ,.els_p(num_lce_p)  
  ) mem_cmd_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(mem_cmd_fifo_v_li)
    ,.ready_o(mem_cmd_fifo_ready_lo)
    ,.data_i(mem_cmd_r)

    ,.v_o(mem_cmd_fifo_v_lo)
    ,.data_o(mem_cmd_fifo_data_lo)
    ,.yumi_i(mem_cmd_fifo_yumi_li)
  );
  
  always_comb begin
    rx_state_n = rx_state_r;
    mem_cmd_n = mem_cmd_r;
    mem_cmd_ready_o = 1'b0;
    rx_counter_clear_li = 1'b0;
    rx_counter_up_li = 1'b0;
    rx_pkt_v_o = 1'b0;
    mem_cmd_fifo_v_li = 1'b0;

    case (rx_state_r)

      // wait for mem_cmd to arrive.
      WAIT: begin
        mem_cmd_ready_o = 1'b1;
        if (mem_cmd_v_i) begin
          mem_cmd_n = mem_cmd;
          rx_counter_clear_li = 1'b1;
          rx_counter_up_li = 1'b0;
          rx_state_n = READ_CACHE_BLOCK;
        end
      end

      // send packets to read a cache block
      // once all the packets are sent out, queue the mem_cmd, and return to
      // WAIT state.
      READ_CACHE_BLOCK: begin
        rx_pkt_v_o = (rx_counter_lo != num_flits_lp);
        rx_counter_up_li = rx_pkt_yumi_i;
        mem_cmd_fifo_v_li = (rx_counter_lo == num_flits_lp);
        rx_state_n = (mem_cmd_fifo_v_li & mem_cmd_fifo_ready_lo)
          ? WAIT
          : READ_CACHE_BLOCK;
      end
    endcase
  end
    
  assign rx_pkt.addr = {
    1'b0,
    mem_cmd_r.addr[link_byte_offset_width_lp+lg_num_flits_lp+:link_addr_width_p-lg_num_flits_lp-1],
    rx_counter_lo[0+:lg_num_flits_lp]
  };
  assign rx_pkt.op = `ePacketOp_remote_load;
  assign rx_pkt.op_ex = {link_mask_width_lp{1'b1}};
  assign rx_pkt.payload = '0;
  assign rx_pkt.src_y_cord = my_y_i;
  assign rx_pkt.src_x_cord = my_x_i;
  assign rx_pkt.y_cord = (y_cord_width_p)'(my_y_i+1);
  assign rx_pkt.x_cord = mem_cmd_r.addr[link_byte_offset_width_lp+link_addr_width_p-1+:x_cord_width_p];

  // mem_data_resp logic
  //
  logic sipo_v_li;
  logic sipo_ready_lo;
  logic [num_flits_lp-1:0][link_data_width_p-1:0] sipo_data_lo;
  logic sipo_v_lo;
  logic sipo_yumi_li;

  bsg_serial_in_parallel_out_full #(
    .width_p(link_data_width_p)
    ,.els_p(num_flits_lp)
  ) sipo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.v_i(sipo_v_li)
    ,.ready_o(sipo_ready_lo)
    ,.data_i(returned_data_i)
  
    ,.data_o(sipo_data_lo)
    ,.v_o(sipo_v_lo)
    ,.yumi_i(sipo_yumi_li)
  );
  assign sipo_v_li = returned_v_i;
  assign returned_yumi_o = returned_v_i & sipo_ready_lo;

  assign mem_data_resp.msg_type = mem_cmd_fifo_data_lo.msg_type;
  assign mem_data_resp.addr = mem_cmd_fifo_data_lo.addr;
  assign mem_data_resp.payload = mem_cmd_fifo_data_lo.payload;
  assign mem_data_resp.data = sipo_data_lo;

  assign mem_data_resp_v_o = sipo_v_lo;
  assign sipo_yumi_li = sipo_v_lo & mem_data_resp_ready_i;

  assign mem_cmd_fifo_yumi_li = mem_cmd_fifo_v_lo & sipo_v_lo & mem_data_resp_ready_i;

  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      rx_state_r <= WAIT;
      //mem_cmd_r <= '0;
    end
    else begin
      rx_state_r <= rx_state_n;
      mem_cmd_r <= mem_cmd_n;
    end
  end

endmodule 
