/**
 *  lsu.v
 *
 *  load store unit
 *
 *  this module is responsible of address generation, address checking,
 *  handshaking glue logic, etc.
 *
 */


`include "definitions.vh"
`include "parameters.vh"


module lsu
  #(parameter data_width_p="inv"
    , parameter pc_width_p="inv"
    , parameter dmem_size_p="inv"

    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam reg_addr_width_lp=RV32_reg_addr_width_gp
  )
  (
    // from EXE
    input decode_s exe_decode_i
    , input [data_width_p-1:0] exe_rs1_i
    , input [data_width_p-1:0] exe_rs2_i
    , input [reg_addr_width_lp-1:0] exe_rd_i
    , input [data_width_p-1:0] mem_offset_i
    , input [data_width_p-1:0] pc_plus4_i
    , input icache_miss_i

    // to network TX
    , output remote_req_s remote_req_o
    , output logic remote_req_v_o

    // to MEM
    , output logic dmem_v_o
    , output logic dmem_w_o
    , output logic [dmem_addr_width_lp-1:0] dmem_addr_o
    , output logic [data_width_p-1:0] dmem_data_o
    , output logic [data_mask_width_lp-1:0] dmem_mask_o 
    , output load_info_s dmem_load_info_o

    , output logic reserve_o
    , output logic [data_width_p-1:0] mem_addr_sent_o

  );

  logic [data_width_p-1:0] mem_addr;
  logic [data_width_p-1:0] miss_addr;

  assign mem_addr = exe_rs1_i + mem_offset_i;
  assign miss_addr = (pc_plus4_i - 'h4) | 32'h80000000;

  // store data mask
  //
  logic [data_width_p-1:0] store_data;
  logic [data_mask_width_lp-1:0] store_mask;

  always_comb begin
    if (exe_decode_i.is_byte_op) begin
      store_data = {4{exe_rs2_i[7:0]}};
      store_mask = {
         mem_addr[1] &  mem_addr[0],
         mem_addr[1] & ~mem_addr[0],
        ~mem_addr[1] &  mem_addr[0],
        ~mem_addr[1] & ~mem_addr[0]
      };
    end
    else if (exe_decode_i.is_hex_op) begin
      store_data = {2{exe_rs2_i[15:0]}};
      store_mask = {
        {2{mem_addr[1]}},
        {2{~mem_addr[1]}}
      };
    end
    else begin
      store_data = exe_rs2_i;
      store_mask = 4'b1111;
    end
  end

  // load info
  //
  load_info_s load_info;
  assign load_info = '{
    float_wb: exe_decode_i.op_writes_fp_rf,
    icache_fetch: icache_miss_i,
    is_unsigned_op: exe_decode_i.is_load_unsigned,
    is_byte_op: exe_decode_i.is_byte_op,
    is_hex_op: exe_decode_i.is_hex_op,
    part_sel: mem_addr[1:0],
    reg_id: exe_rd_i
  };

  // to MEM
  //
  logic is_local_dmem_addr;
  assign is_local_dmem_addr = mem_addr[2+dmem_addr_width_lp]
    & (mem_addr[data_width_p-1:(2+1+dmem_addr_width_lp)] == '0);

  assign dmem_v_o = exe_decode_i.is_mem_op & is_local_dmem_addr;
  assign dmem_w_o = exe_decode_i.is_store_op;
  assign dmem_addr_o = mem_addr[2+:dmem_addr_width_lp]; 
  assign dmem_data_o = store_data;
  assign dmem_mask_o = store_mask;
  assign dmem_load_info_o = load_info;

  assign mem_addr_sent_o = icache_miss_i
    ? miss_addr
    : mem_addr;

  // remote req
  //
  payload_u payload;
  
  always_comb begin
    if (exe_decode_i.is_load_op | icache_miss_i) begin
      payload.read_info = '{
        reserved: '0,
        load_info: load_info
      };
    end
    else begin
      payload.write_data = store_data;
    end 
  end
  
  assign remote_req_o = '{
    write_not_read: exe_decode_i.is_store_op,
    swap_aq: exe_decode_i.op_is_swap_aq,
    swap_rl: exe_decode_i.op_is_swap_rl,
    mask: store_mask,
    addr: (icache_miss_i ? miss_addr : mem_addr),
    payload: payload
  };

  assign remote_req_v_o = (exe_decode_i.is_mem_op & ~is_local_dmem_addr) | icache_miss_i;

  // reserve
  // only valid on local DMEM (for now)
  assign reserve_o = exe_decode_i.op_is_lr & is_local_dmem_addr;



endmodule
