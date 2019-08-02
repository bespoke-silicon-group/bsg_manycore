`ifndef DEBUG_IF_VH
`define DEBUG_IF_VH

// DEBUG INTERFACE

typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic branch_or_jump;
  logic [RV32_instr_width_gp-1:0] btarget;
  logic is_local_load;
  logic is_local_store;
  logic [9:0] local_dmem_addr; // hard-coded for now...
  logic [RV32_reg_data_width_gp-1:0] local_store_data;
  logic is_remote_load;
  logic is_remote_store;
  logic [RV32_reg_data_width_gp-1:0] remote_addr;
  logic [RV32_reg_data_width_gp-1:0] remote_store_data;
} exe_debug_s;

typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic branch_or_jump;
  logic [RV32_instr_width_gp-1:0] btarget;
  logic is_local_load;
  logic is_local_store;
  logic [9:0] local_dmem_addr;
  logic [RV32_reg_data_width_gp-1:0] local_store_data;
  logic is_remote_load;
  logic is_remote_store;
  logic [RV32_reg_data_width_gp-1:0] remote_addr;
  logic [RV32_reg_data_width_gp-1:0] remote_store_data;
} mem_debug_s;

typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic branch_or_jump;
  logic [RV32_instr_width_gp-1:0] btarget;
  logic is_local_load;
  logic is_local_store;
  logic [9:0] local_dmem_addr;
  logic [RV32_reg_data_width_gp-1:0] local_load_data;
  logic [RV32_reg_data_width_gp-1:0] local_store_data;
  logic is_remote_load;
  logic is_remote_store;
  logic [RV32_reg_data_width_gp-1:0] remote_addr;
  logic [RV32_reg_data_width_gp-1:0] remote_store_data;
} wb_debug_s;


typedef struct packed
{
  logic [RV32_reg_data_width_gp-1:0] pc;
  logic [RV32_instr_width_gp-1:0] instr;
  logic valid;
} fp_debug_s;

`endif
