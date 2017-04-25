`include "bsg_manycore_packet.vh"

`ifdef bsg_FPU
  `include "float_definitions.v"
`endif

module bsg_manycore_tile
  import bsg_noc_pkg::*; // { P=0, W,E,N,S }

#(
  parameter bank_size_p = -1,
  parameter num_banks_p = "inv",
  parameter imem_size_p = bank_size_p,

  parameter x_cord_width_p = -1,
  parameter y_cord_width_p = -1,

  parameter data_width_p = 32,
  parameter addr_width_p = "inv",

  parameter bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p),

  parameter dirs_lp = 4,
  parameter stub_p  = {dirs_lp{1'b0}}, // {s,n,e,w}
  parameter repeater_output_p = {dirs_lp{1'b0}}, // {s,n,e,w}

  parameter hetero_type_p = 0,

  parameter debug_p = 0
)
(
    input clk_i,
    input reset_i,

    input  [bsg_manycore_link_sif_width_lp-1:0][S:W] link_in,
    output [bsg_manycore_link_sif_width_lp-1:0][S:W] link_out,
`ifdef bsg_FPU
    input  f_fam_out_s fam_out_s_i,
    output f_fam_in_s  fam_in_s_o,
`endif

    input [x_cord_width_p-1:0] my_x_i,
    input [y_cord_width_p-1:0] my_y_i
);

  wire [bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_li;
  wire [bsg_manycore_link_sif_width_lp-1:0] proc_link_sif_lo;

  //-------------------------------------------
  //As the manycore will distribute across large area, it will take long
  //time for the reset signal to propgate. We should register the reset
  //signal in each tile
  logic reset_r ;
  always_ff@(posedge clk_i ) reset_r <= reset_i;


  bsg_manycore_mesh_node
    #(
      .stub_p(stub_p),
      .x_cord_width_p(x_cord_width_p),
      .y_cord_width_p(y_cord_width_p),
      .data_width_p(data_width_p),
      .addr_width_p(addr_width_p),
      .debug_p(debug_p),
      // select buffer instructions for this particular node
      .repeater_output_p(repeater_output_p)
    )
  rtr
    (
      .clk_i(clk_i),
      .reset_i(reset_r),
      .links_sif_i(link_in),
      .links_sif_o(link_out),
      .proc_link_sif_i(proc_link_sif_li),
      .proc_link_sif_o(proc_link_sif_lo),
      .my_x_i(my_x_i),
      .my_y_i(my_y_i)
    );

  bsg_manycore_hetero_socket
    #(
      .x_cord_width_p(x_cord_width_p),
      .y_cord_width_p(y_cord_width_p),
      .debug_p(debug_p),
      .bank_size_p(bank_size_p),
      .imem_size_p(imem_size_p),
      .num_banks_p(num_banks_p),
      .data_width_p(data_width_p),
      .addr_width_p(addr_width_p),
      .hetero_type_p(hetero_type_p)
    )
  proc
    (
      .clk_i(clk_i),
      .reset_i(reset_r) ,

    `ifdef bsg_FPU
      .fam_in_s_o(fam_in_s_o),
      .fam_out_s_i(fam_out_s_i),
    `endif

      .link_sif_i(proc_link_sif_lo),
      .link_sif_o(proc_link_sif_li),

      .my_x_i(my_x_i),
      .my_y_i(my_y_i),

      .freeze_o()
    );

endmodule
