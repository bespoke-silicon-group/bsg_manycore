/**
 *    network_tx.v
 *
 *    This handles sending out remote packets and receiving responses.
 */


module network_tx
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter epa_byte_addr_width_p="inv"
    , parameter vcache_size_p="inv" // vcache capacity in words
    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_sets_p="inv"
    
    , parameter num_tiles_x_p="inv"
  
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter max_out_credits_p="inv"

    , parameter max_y_cord_width_p=6
    , parameter max_x_cord_width_p=6

    , parameter vcache_addr_width_lp=`BSG_SAFE_CLOG2(vcache_size_p)

    , parameter vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p)

    , localparam credit_counter_width_lp=$clog2(max_out_credits_p+1)

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)

    , localparam epa_word_addr_width_lp=(epa_byte_addr_width_p-2)

    , localparam reg_addr_width_lp=RV32_reg_addr_width_gp

    , localparam packet_width_lp=
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
 
    // network side
    , output logic [packet_width_lp-1:0] out_packet_o
    , output logic out_v_o
    , input out_ready_i

    , input returned_v_i
    , input [data_width_p-1:0] returned_data_i
    , input [4:0] returned_reg_id_i
    , input bsg_manycore_return_packet_type_e returned_pkt_type_i
    , input returned_fifo_full_i
    , output logic returned_yumi_o
    
    , input [x_cord_width_p-1:0] tgo_x_i
    , input [y_cord_width_p-1:0] tgo_y_i
    , input dram_enable_i

    , input [credit_counter_width_lp-1:0] out_credits_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    // core side
    , input remote_req_s remote_req_i
    , input remote_req_v_i
    , output logic remote_req_yumi_o

    , output logic ifetch_v_o
    , output logic [data_width_p-1:0] ifetch_instr_o
   
    , output logic [reg_addr_width_lp-1:0] float_remote_load_resp_rd_o
    , output logic [data_width_p-1:0] float_remote_load_resp_data_o
    , output logic float_remote_load_resp_v_o

    , output logic [reg_addr_width_lp-1:0] int_remote_load_resp_rd_o
    , output logic [data_width_p-1:0] int_remote_load_resp_data_o
    , output logic int_remote_load_resp_v_o
    , output logic int_remote_load_resp_force_o
    , input int_remote_load_resp_yumi_i
  );

  wire unused = reset_i;

  // manycore packet struct
  //
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s out_packet;
  assign out_packet_o = out_packet;


  // EVA -> NPA translation
  //
  `declare_bsg_manycore_global_addr_s(epa_word_addr_width_lp,
    max_x_cord_width_p,max_y_cord_width_p); // Global
  `declare_bsg_manycore_addr_s(epa_word_addr_width_lp,
    max_x_cord_width_p,max_y_cord_width_p); // In-group

  bsg_manycore_global_addr_s global_addr;
  bsg_manycore_addr_s in_group_addr;
  assign global_addr = remote_req_i.addr; 
  assign in_group_addr = remote_req_i.addr; 

  wire is_dram_addr = (remote_req_i.addr ==? 32'b1???????_????????_????????_????????);
  wire is_global_addr = global_addr.remote == 2'b01;
  wire is_in_group_addr = in_group_addr.remote == 3'b001;

  wire is_invalid_addr = ~(is_dram_addr | is_global_addr | is_in_group_addr);


  // hash bank
  //
  localparam hash_bank_input_width_lp=data_width_p-1-2-vcache_word_offset_width_lp;
  localparam hash_bank_index_width_lp=$clog2((2**hash_bank_input_width_lp+num_tiles_x_p-1)/(num_tiles_x_p*2));

  logic [hash_bank_input_width_lp-1:0] hash_bank_input;
  logic [x_cord_width_p:0] hash_bank_lo;  // {top_not_bot, x_cord}
  logic [hash_bank_index_width_lp-1:0] hash_bank_index_lo;

  hash_function #(
    .banks_p(num_tiles_x_p*2) // vcache on top and bottom
    ,.width_p(hash_bank_input_width_lp)
    ,.vcache_sets_p(vcache_sets_p)
  ) hashb (
    .i(hash_bank_input)
    ,.bank_o(hash_bank_lo)
    ,.index_o(hash_bank_index_lo)
  );

  assign hash_bank_input = remote_req_i.addr[2+vcache_word_offset_width_lp+:hash_bank_input_width_lp];

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

    out_packet.reg_id = remote_req_i.reg_id;
    out_packet.op_ex = remote_req_i.is_amo_op
      ? remote_req_i.amo_type
      : remote_req_i.mask;
    out_packet.src_y_cord = my_y_i;
    out_packet.src_x_cord = my_x_i;

    out_packet.op = remote_req_i.is_amo_op
      ? e_remote_amo
      : (remote_req_i.write_not_read
        ? e_remote_store
        : e_remote_load);

    // EVA Address Mapping.
    if (is_dram_addr) begin
      if (dram_enable_i) begin
        out_packet.y_cord = hash_bank_lo[x_cord_width_p]
          ? {y_cord_width_p{1'b1}}
          : (y_cord_width_p)'(0);
        out_packet.x_cord = hash_bank_lo[0+:x_cord_width_p];
        out_packet.addr = {
          1'b0,
          {(addr_width_p-1-vcache_word_offset_width_lp-hash_bank_index_width_lp){1'b0}},
          hash_bank_index_lo,
          remote_req_i.addr[2+:vcache_word_offset_width_lp]
        };
      end
      else begin
        // DRAM disabled.
        if (remote_req_i.addr[30]) begin
          out_packet.y_cord = '0;
          out_packet.x_cord = '0;
          out_packet.addr = {1'b1, remote_req_i.addr[2+:addr_width_p-1]}; // HOST DRAM address
        end
        else begin
          out_packet.y_cord = remote_req_i.addr[2+vcache_addr_width_lp+x_cord_width_p+:1]
            ? {y_cord_width_p{1'b1}}
            : (y_cord_width_p)'(0);
          out_packet.x_cord = remote_req_i.addr[2+vcache_addr_width_lp+:x_cord_width_p];
          out_packet.addr = {
            1'b0,
            {(addr_width_p-1-vcache_addr_width_lp){1'b0}},
            remote_req_i.addr[2+:vcache_addr_width_lp]
          };
        end
      end
    end
    else if (is_global_addr) begin
      out_packet.y_cord = y_cord_width_p'(global_addr.y_cord);
      out_packet.x_cord = x_cord_width_p'(global_addr.x_cord);
      out_packet.addr = {{(addr_width_p-epa_word_addr_width_lp){1'b0}}, global_addr.addr};
    end
    else if (is_in_group_addr) begin
      out_packet.y_cord = y_cord_width_p'(global_addr.y_cord + tgo_y_i);
      out_packet.x_cord = x_cord_width_p'(global_addr.x_cord + tgo_x_i);
      out_packet.addr = {{(addr_width_p-epa_word_addr_width_lp){1'b0}}, in_group_addr.addr};
    end
    else begin
      // should never happen
      out_packet.y_cord = '0;
      out_packet.x_cord = '0;
      out_packet.addr = '0;
    end
  end

  // handling outgoing requests
  //
  assign out_v_o = remote_req_v_i & (|out_credits_i) & ~is_invalid_addr;
  assign remote_req_yumi_o = (out_v_o & out_ready_i) | (remote_req_v_i & is_invalid_addr);


  // handling response packets
  //
  assign ifetch_instr_o = returned_data_i;
  assign int_remote_load_resp_data_o = returned_data_i;
  assign int_remote_load_resp_rd_o = returned_reg_id_i;
  assign float_remote_load_resp_data_o = returned_data_i;
  assign float_remote_load_resp_rd_o = returned_reg_id_i;

  always_comb begin

    if (returned_pkt_type_i == e_return_ifetch) begin
      ifetch_v_o = returned_v_i;
      int_remote_load_resp_v_o = 1'b0;
      float_remote_load_resp_v_o = 1'b0;
      int_remote_load_resp_force_o = 1'b0;
      returned_yumi_o = returned_v_i;
    end
    else if (returned_pkt_type_i == e_return_float_wb) begin
      ifetch_v_o = 1'b0;
      int_remote_load_resp_v_o = 1'b0;
      float_remote_load_resp_v_o = returned_v_i;
      int_remote_load_resp_force_o = 1'b0;
      returned_yumi_o = returned_v_i;
    end
    else begin
      ifetch_v_o = 1'b0;
      int_remote_load_resp_v_o = returned_v_i;
      float_remote_load_resp_v_o = 1'b0;
      int_remote_load_resp_force_o = returned_fifo_full_i & returned_v_i;
      returned_yumi_o = int_remote_load_resp_yumi_i | (returned_fifo_full_i & returned_v_i);
    end

  end

  // synopsys translate_off

  always_ff @ (negedge clk_i) begin

    if (out_v_o & is_invalid_addr) begin
      $display("[ERROR][TX] Invalid EVA access. t=%0t, x=%d, y=%d, addr=%h",
        $time, my_x_i, my_y_i, remote_req_i.addr);
    end 

    if (returned_v_i) begin
      assert(returned_pkt_type_i != e_return_credit)
        else $error("[ERROR][TX] Credit packet should not be given to vanilla core.");
    end

  end
  // synopsys translate_on
endmodule
