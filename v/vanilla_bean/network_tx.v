/**
 *    network_tx.v
 *
 */

`include "bsg_manycore_packet.vh"
`include "bsg_manycore_addr.vh"
`include "definitions.vh"

module network_tx
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"
    , parameter dram_ch_addr_width_p="inv"
    , parameter epa_byte_addr_width_p="inv"
  
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter max_out_credits_p="inv"

    , parameter max_y_cord_width_p=6
    , parameter max_x_cord_width_p=6

    , localparam credit_counter_width_lp=$clog2(max_out_credits_p+1)

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)

    , localparam epa_word_addr_width_lp=(epa_byte_addr_width_p-2)

    , localparam packet_width_lp=
      `bsg_manycore_packet_width(addr_width_p,data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    // core side
    , input remote_req_s remote_req_i
    , input remote_req_v_i
    , output logic remote_req_yumi_o

    , output logic ifetch_v_o
    , output logic [data_width_p-1:0] ifetch_instr_o
   
    , output remote_load_resp_s remote_load_resp_o
    , output logic remote_load_resp_v_o
    , output logic remote_load_resp_force_o
    , input remote_load_resp_yumi_i 
    
    // network side
    , output logic [packet_width_lp-1:0] out_packet_o
    , output logic out_v_o
    , input out_ready_i

    , input returned_v_i
    , input [data_width_p-1:0] returned_data_i
    , input [load_id_width_p-1:0] returned_load_id_i
    , input returned_fifo_full_i
    , output logic returned_yumi_o
    
    , input [x_cord_width_p-1:0] tgo_x_i
    , input [y_cord_width_p-1:0] tgo_y_i

    , input [credit_counter_width_lp-1:0] out_credits_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // manycore packet struct
  //
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);

  bsg_manycore_packet_s out_packet;

  assign out_packet_o = out_packet;

  assign out_packet.op_ex = remote_req_i.mask;
  assign out_packet.payload = remote_req_i.payload;
  assign out_packet.src_y_cord = my_y_i;
  assign out_packet.src_x_cord = my_x_i;

  // EVA -> NPA translation
  //
  `declare_bsg_manycore_dram_addr_s(dram_ch_addr_width_p); // DRAM
  `declare_bsg_manycore_global_addr_s(epa_word_addr_width_lp,
    max_x_cord_width_p,max_y_cord_width_p); // Global
  `declare_bsg_manycore_addr_s(epa_word_addr_width_lp,
    max_x_cord_width_p,max_y_cord_width_p); // In-group

  bsg_manycore_dram_addr_s dram_addr;
  bsg_manycore_global_addr_s global_addr;
  bsg_manycore_addr_s in_group_addr;

  always_comb begin

    out_packet.op = remote_req_i.swap_aq
      ? `ePacketOp_remote_swap_aq
      : (remote_req_i.swap_rl
        ? `ePacketOp_remote_swap_rl
        : (remote_req_i.write_not_read
          ? `ePacketOp_remote_store
          : `ePacketOp_remote_load));

    if (dram_addr.is_dram_addr) begin
      out_packet.y_cord = {y_cord_width_p{1'b1}};
      out_packet.x_cord = dram_addr.x_cord;
      out_packet.addr = {1'b0, {(addr_width_p-1-dram_ch_addr_width_p){1'b0}}, dram_addr.addr};
    end
    else if (global_addr.remote == 2'b01) begin
      out_packet.y_cord = y_cord_width_p'(global_addr.y_cord);
      out_packet.x_cord = x_cord_width_p'(global_addr.x_cord);
      out_packet.addr = {{(addr_width_p-epa_word_addr_width_lp){1'b0}}, global_addr.addr};
    end
    else if (in_group_addr.remote == 3'b001) begin
      out_packet.y_cord = y_cord_width_p'(global_addr.y_cord + tgo_y_i);
      out_packet.x_cord = x_cord_width_p'(global_addr.x_cord + tgo_x_i);
      out_packet.addr = {{(addr_width_p-epa_word_addr_width_lp){1'b0}}, in_group_addr.addr};
    end
    else begin
      // this should never happen, but if it does, send out fail packet to host
      // interface.
      out_packet.y_cord = y_cord_width_p'(0);
      out_packet.x_cord = x_cord_width_p'(0);
      out_packet.addr = 'hEAD8; // fail packet address
      out_packet.op = `ePacketOp_remote_store;
    end
  end

  // handling outgoing requests
  //
  assign out_v_o = remote_req_v_i & (|out_credits_i);
  assign remote_req_yumi_o = out_v_o & out_ready_i;


  // handling response packets
  //
  load_info_s returned_load_info;
  assign returned_load_info = returned_load_id_i;

  always_comb begin

    ifetch_instr_o = returned_data_i;
    remote_load_resp_o.load_info = returned_load_info;
    remote_load_resp_o.load_data = returned_data_i;

    if (returned_load_info.icache_fetch) begin
      ifetch_v_o = returned_v_i;
      remote_load_resp_v_o = 1'b0;
      remote_load_resp_force_o = 1'b0;
      returned_yumi_o = returned_v_i;
    end
    else begin
      ifetch_v_o = 1'b0;
      remote_load_resp_v_o = returned_v_i;
      remote_load_resp_force_o = returned_fifo_full_i;
      returned_yumi_o = remote_load_resp_yumi_i;
    end

  end


endmodule
