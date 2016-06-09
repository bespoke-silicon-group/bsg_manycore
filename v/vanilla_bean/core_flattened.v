`include "parameters.v"
`include "definitions.v"

/**
 *  Top-level module for vanilla-bean core. Instantiates a
 *  vanilla-bean core module. Uses flattened port definitions.
 */
module core_flattened #(parameter imem_addr_width_p = -1, gw_ID_p = -1, ring_ID_p = -1)
(
    input  clk,
    input  reset,

    input  [$bits(ring_packet_s)-1:0] net_packet_flat_i,
    output [$bits(ring_packet_s)-1:0] net_packet_flat_o,

    input  [$bits(mem_out_s)-1:0] from_mem_flat_i,
    output [$bits(mem_in_s)-1:0]  to_mem_flat_o,

    input                             gate_way_full_i,
    output logic [mask_length_gp-1:0] barrier_o,
    output logic                      exception_o,
    output [$bits(debug_s)-1:0]       debug_flat_o
);

hobbit #(.imem_addr_width_p(imem_addr_width_p), .ring_ID_p(ring_ID_p), .gw_ID_p(gw_ID_p)) core1
(
    .clk(clk),
    .reset(reset),

    .net_packet_i(net_packet_flat_i),
    .net_packet_o(net_packet_flat_o),

    .from_mem_i(from_mem_flat_i),
    .to_mem_o(to_mem_flat_o),

    .gate_way_full_i(gate_way_full_i),
    .barrier_o(barrier_o),
    .exception_o(exception_o),
    .debug_o(debug_flat_o)
);

endmodule

