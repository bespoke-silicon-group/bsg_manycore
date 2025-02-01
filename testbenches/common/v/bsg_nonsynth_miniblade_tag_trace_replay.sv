/**
 *      bsg_nonsynth_miniblade_tag_trace_replay.sv
 *
 */

`include "bsg_defines.sv"

module bsg_nonsynth_miniblade_tag_trace_replay
  import bsg_tag_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter `BSG_INV_PARAM(tag_els_p)
  )
  (
    input clk_i
    , input reset_i

    , output logic tag_clk_o
    , output logic tag_data_o
    , output logic tag_done_o  // done signal for peripherals
  );

  
  localparam rom_addr_width_lp = 32;
  localparam max_payload_width_lp = 12;
  localparam tag_lg_width_lp = `BSG_SAFE_CLOG2(max_payload_width_lp+1);
  localparam num_masters_lp = 1;
  localparam lg_tag_els_lp = `BSG_SAFE_CLOG2(tag_els_p);
  localparam rom_data_width_lp = 4+num_masters_lp+lg_tag_els_lp+1+tag_lg_width_lp+max_payload_width_lp;

  logic tr_valid_lo;
  logic [num_masters_lp-1:0] tr_en_r_lo;
  logic tr_data_lo;


  logic [rom_addr_width_lp-1:0] rom_addr;
  logic [rom_data_width_lp-1:0] rom_data;

  bsg_tag_trace_replay #(
    .rom_addr_width_p     (rom_addr_width_lp)
    ,.rom_data_width_p    (rom_data_width_lp)
    ,.num_masters_p       (num_masters_lp)
    ,.num_clients_p       (tag_els_p)
    ,.max_payload_width_p (max_payload_width_lp)
    ,.uptime_p(0)
  ) tr (
    .clk_i    (clk_i)
    ,.reset_i (reset_i)
    ,.en_i    (1'b1)

    ,.rom_addr_o(rom_addr)
    ,.rom_data_i(rom_data)

    ,.valid_i(1'b0)
    ,.data_i('0)
    ,.ready_o()

    ,.valid_o     (tr_valid_lo)
    ,.en_r_o      (tr_en_r_lo)
    ,.tag_data_o  (tr_data_lo)
    ,.yumi_i      (tr_valid_lo)
    
    ,.done_o(tag_done_o)
    ,.error_o()
  );  

  // BSG TAG boot rom
  bsg_tag_boot_rom #(
    .width_p(rom_data_width_lp)
    ,.addr_width_p(rom_addr_width_lp)
  ) rom (
    .addr_i(rom_addr)
    ,.data_o(rom_data)
  );


  // outputs;
  assign tag_clk_o = tag_done_o ? 1'b1 : clk_i;
  assign tag_data_o = tr_en_r_lo[0] & tr_valid_lo ? tr_data_lo : 1'b0;



endmodule



`BSG_ABSTRACT_MODULE(bsg_nonsynth_miniblade_tag_trace_replay)

