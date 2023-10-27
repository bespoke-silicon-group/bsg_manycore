/**
 *      bsg_nonsynth_manycore_tag_master.v
 *
 */

`include "bsg_defines.sv"

module bsg_nonsynth_manycore_tag_master
  import bsg_tag_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter `BSG_INV_PARAM(num_pods_x_p)
    , parameter `BSG_INV_PARAM(num_pods_y_p)

    , parameter `BSG_INV_PARAM(wh_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // done signal for peripherals
    , output logic tag_done_o
    , output  bsg_tag_s [num_pods_y_p-1:0][num_pods_x_p-1:0] pod_tags_o
  );

  // one tag client per pods
  localparam num_clients_lp = (num_pods_y_p*num_pods_x_p);
  localparam rom_addr_width_lp = 12;
  localparam payload_width_lp = 1; // {reset}
  localparam lg_payload_width_lp = `BSG_WIDTH(payload_width_lp); // number of bits used to represent the payload width
  localparam max_payload_width_lp = (1<<lg_payload_width_lp)-1; 
  localparam rom_data_width_lp = 4+1+`BSG_SAFE_CLOG2(num_clients_lp)+1+lg_payload_width_lp+max_payload_width_lp;

  // BSG TAG trace replay
  logic tr_valid_lo;
  logic tr_en_r_lo;
  logic tr_data_lo;
  logic [rom_data_width_lp-1:0] rom_data;
  logic [rom_addr_width_lp-1:0] rom_addr;

  bsg_tag_trace_replay #(
    .rom_addr_width_p(rom_addr_width_lp)
    ,.rom_data_width_p(rom_data_width_lp)
    ,.num_masters_p(1)
    ,.num_clients_p(num_clients_lp)
    ,.max_payload_width_p(max_payload_width_lp)
    ,.uptime_p(0)
  ) tr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(1'b1)

    ,.rom_addr_o(rom_addr)
    ,.rom_data_i(rom_data)

    ,.valid_i(1'b0)
    ,.data_i('0)
    ,.ready_o()

    ,.valid_o(tr_valid_lo)
    ,.en_r_o(tr_en_r_lo)
    ,.tag_data_o(tr_data_lo)
    ,.yumi_i(tr_valid_lo)
    
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


  // BSG TAG MASTER
  bsg_tag_master #(
    .els_p(num_clients_lp)
    ,.lg_width_p(lg_payload_width_lp)
  ) btm (
    .clk_i(clk_i)
    ,.data_i(tr_en_r_lo & tr_valid_lo & tr_data_lo)
    ,.en_i(1'b1)
    ,.clients_r_o({pod_tags_o})
  );



endmodule

`BSG_ABSTRACT_MODULE(bsg_nonsynth_manycore_tag_master)

