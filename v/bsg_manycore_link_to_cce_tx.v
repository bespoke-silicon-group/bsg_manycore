/**
 *  bsg_manycore_link_to_cce_tx.v
 *
 *  @author tommy
 */

module bsg_manycore_link_to_cce_tx
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
    , localparam tx_counter_width_lp=`BSG_SAFE_CLOG2(num_flits_lp+1)
    , localparam lg_num_flits_lp=`BSG_SAFE_CLOG2(num_flits_lp)

    , localparam bp_cce_mem_data_cmd_width_lp=
      `bp_cce_mem_data_cmd_width(bp_addr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
    , localparam bp_mem_cce_resp_width_lp=
      `bp_mem_cce_resp_width(bp_addr_width_p,num_lce_p,lce_assoc_p)

    , localparam packet_width_lp=
      `bsg_manycore_packet_width(link_addr_width_p,link_data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    // cce side
    , input [bp_cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    , input mem_data_cmd_v_i
    , output logic mem_data_cmd_yumi_o

    , output logic [bp_mem_cce_resp_width_lp-1:0] mem_resp_o
    , output logic mem_resp_v_o
    , input mem_resp_ready_i

    // manycore side
    , output logic [packet_width_lp-1:0] tx_pkt_o
    , output logic tx_pkt_v_o
    , input tx_pkt_yumi_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // casting structs
  //
  `declare_bsg_manycore_packet_s(link_addr_width_p,link_data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);
  
  bsg_manycore_packet_s tx_pkt;
  assign tx_pkt_o = tx_pkt;

  `declare_bp_me_if(bp_addr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);

  bp_cce_mem_data_cmd_s mem_data_cmd;
  bp_mem_cce_resp_s mem_resp;

  assign mem_data_cmd = mem_data_cmd_i;
  assign mem_resp_o = mem_resp;

  
  // mem_data_cmd
  //
  typedef enum logic [1:0] {
    WAIT
    ,WRITE_CACHE_BLOCK
  } tx_state_e;

  tx_state_e tx_state_r, tx_state_n;
  bp_cce_mem_data_cmd_s mem_data_cmd_r, mem_data_cmd_n;

  logic tx_counter_clear_li;
  logic tx_counter_up_li;
  logic [tx_counter_width_lp-1:0] tx_counter_lo;
  

  bsg_counter_clear_up #(
    .max_val_p(num_flits_lp)
    ,.init_val_p(0)
  ) tx_counter (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(tx_counter_clear_li)
    ,.up_i(tx_counter_up_li)
    ,.count_o(tx_counter_lo)
  );

  always_comb begin

    tx_state_n = tx_state_r;
    mem_data_cmd_n = mem_data_cmd_r;
    mem_data_cmd_ready_o = 1'b0;
    tx_counter_clear_li = 1'b0;
    tx_counter_up_li = 1'b0;
    tx_pkt_v_o = 1'b0;
    mem_resp_v_o = 1'b0;

    case (tx_state_r)
      // wait until mem_data_cmd arrives.
      WAIT: begin
        mem_data_cmd_ready_o = 1'b1;

        if (mem_data_cmd_v_i) begin
          mem_data_cmd_n = mem_data_cmd;
          tx_counter_clear_li = 1'b1;
          tx_state_n = WRITE_CACHE_BLOCK;
        end
      end

      // send out packets to write the cache block.
      WRITE_CACHE_BLOCK: begin
        tx_pkt_v_o = tx_counter_lo != num_flits_lp;
        tx_counter_up_li = tx_pkt_yumi_i;
        mem_resp_v_o = tx_counter_lo == num_flits_lp;
        tx_state_n = (mem_resp_v_o & mem_resp_ready_i)
          ? WAIT
          : WRITE_CACHE_BLOCK;
      end
    endcase
  end

  logic [num_flits_lp-1:0][link_data_width_p-1:0] mem_data;
  assign mem_data = mem_data_cmd_r.data;

  assign tx_pkt.addr = {
    1'b0,
    mem_cmd_r.addr[link_byte_offset_width_lp+lg_num_flits_lp+:link_addr_width_p+lg_num_flits_lp-1]
    tx_counter_lo[0+:lg_num_flits_lp]
  };
  assign tx_pkt.op = `ePacketOp_remote_store;
  assign tx_pkt.op_ex = {link_mask_width_lp{1'b1}};
  assign tx_pkt.payload = mem_data[tx_counter_lo[0+:lg_num_flits_lp]];
  assign tx_pkt.src_y_cord = my_y_i;
  assign tx_pkt.src_x_cord = my_x_i;
  assign tx_pkt.y_cord = my_y_i;
  assign tx_pkt.x_cord = mem_cmd_r.addr[link_byte_offset_width_lp+link_addr_width_p-1+:x_cord_width_p];

  assign mem_resp.msg_type = mem_data_cmd_r.msg_type;
  assign mem_resp.addr = mem_data_cmd_r.addr;
  assign mem_resp.payload = mem_data_cmd_r.payload;

  // sequential
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      tx_state_r <= WAIT;
    end
    else begin
      tx_state_r <= tx_state_n;
      mem_data_cmd_r <= mem_data_cmd_n;
    end
  end

endmodule
