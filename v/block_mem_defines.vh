`ifndef BLOCK_MEM_DEFINES_VH
`define BLOCK_MEM_DEFINES_VH

// addr is byte addr;
`define declare_block_mem_pkt_s(addr_width_mp,data_width_mp) \
  typedef struct packed {                 \
    block_mem_op_e opcode;                \
    logic [addr_width_mp-1:0] addr;       \
    logic [data_width_mp-1:0] data;       \
    logic [(data_width_mp>>3)-1:0] mask;  \
  } block_mem_pkt_s;

`define block_mem_pkt_width(addr_width_mp,data_width_mp) \
  ($bits(block_mem_op_e)+addr_width_mp+data_width_mp+(data_width_mp>>3))


`endif
