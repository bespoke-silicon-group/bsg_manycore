/**
 *  bsg_manycore_tile.v
 *
 */

module bsg_manycore_tile
  import bsg_noc_pkg::*; // { P=0, W,E,N,S }
  import bsg_manycore_pkg::*;
  #(parameter dmem_size_p = 1024
    , parameter vcache_size_p =2048
    , parameter icache_entries_p = 1024
    , parameter icache_tag_width_p = 12
    , parameter x_cord_width_p = 4
    , parameter y_cord_width_p = 4
    , parameter num_tiles_x_p= 16
    , parameter num_tiles_y_p= 9
    
    , parameter data_width_p = 32
    , parameter addr_width_p = 28

    , parameter vcache_block_size_in_words_p=8
    , parameter vcache_sets_p=64

    , localparam dirs_lp = 4

    , parameter stub_p = {dirs_lp{1'b0}}           // {s,n,e,w}
    , parameter repeater_output_p = {dirs_lp{1'b0}} // {s,n,e,w}
    , parameter hetero_type_p = 0
    , parameter debug_p = 0

    , parameter branch_trace_en_p = 0

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

    , parameter fwd_packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter rev_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input  [link_sif_width_lp-1:0][S:W] link_in
    , output [link_sif_width_lp-1:0][S:W] link_out

    // tile coordinate
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i


    // FAST LINK
    // { E2, E1, E0, W2, W1, W0 }


    // fast link fwd
    , input  [2:0][fwd_packet_width_lp-1:0] fast_link_fwd_east_data_i
    , input  [2:0]                          fast_link_fwd_east_v_i
    , output [2:0]                          fast_link_fwd_east_ready_o

    , output [2:0][fwd_packet_width_lp-1:0] fast_link_fwd_east_data_o
    , output [2:0]                          fast_link_fwd_east_v_o
    , input  [2:0]                          fast_link_fwd_east_ready_i

    , input  [2:0][fwd_packet_width_lp-1:0] fast_link_fwd_west_data_i
    , input  [2:0]                          fast_link_fwd_west_v_i
    , output [2:0]                          fast_link_fwd_west_ready_o

    , output [2:0][fwd_packet_width_lp-1:0] fast_link_fwd_west_data_o
    , output [2:0]                          fast_link_fwd_west_v_o
    , input  [2:0]                          fast_link_fwd_west_ready_i

    // fast link rev
    , input  [2:0][rev_packet_width_lp-1:0] fast_link_rev_east_data_i
    , input  [2:0]                          fast_link_rev_east_v_i
    , output [2:0]                          fast_link_rev_east_ready_o

    , output [2:0][rev_packet_width_lp-1:0] fast_link_rev_east_data_o
    , output [2:0]                          fast_link_rev_east_v_o
    , input  [2:0]                          fast_link_rev_east_ready_i

    , input  [2:0][rev_packet_width_lp-1:0] fast_link_rev_west_data_i
    , input  [2:0]                          fast_link_rev_west_v_i
    , output [2:0]                          fast_link_rev_west_ready_o

    , output [2:0][rev_packet_width_lp-1:0] fast_link_rev_west_data_o
    , output [2:0]                          fast_link_rev_west_v_o
    , input  [2:0]                          fast_link_rev_west_ready_i
  );

  logic [link_sif_width_lp-1:0] proc_link_sif_li;
  logic [link_sif_width_lp-1:0] proc_link_sif_lo;

  //-------------------------------------------
  //As the manycore will distribute across large area, it will take long
  //time for the reset signal to propgate. We should register the reset
  //signal in each tile
  logic reset_r;
  always_ff @ (posedge clk_i) begin
    reset_r <= reset_i;
  end

  // For vanilla core (hetero type = 0), it uses credit interface for the P ports,
  // which has three-element fifo because the credit returns with one extra cycle delay.
  localparam fwd_use_credits_lp = (hetero_type_p == 0)
    ? 5'b00001
    : 5'b00000;
  localparam int fwd_fifo_els_lp[dirs_lp:0] = (hetero_type_p == 0)
    ? '{2,2,2,2,3}
    : '{2,2,2,2,2};
  localparam rev_use_credits_lp = 5'b00000;
  localparam int rev_fifo_els_lp[dirs_lp:0] = '{2,2,2,2,2};
    

  bsg_manycore_mesh_node #(
    .stub_p(stub_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.debug_p(debug_p)
    ,.repeater_output_p(repeater_output_p) // select buffer for this particular node
    ,.fwd_use_credits_p(fwd_use_credits_lp)
    ,.fwd_fifo_els_p(fwd_fifo_els_lp)
    ,.rev_use_credits_p(rev_use_credits_lp)
    ,.rev_fifo_els_p(rev_fifo_els_lp)
  ) rtr (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.links_sif_i(link_in)
    ,.links_sif_o(link_out)
    ,.proc_link_sif_i(proc_link_sif_li)
    ,.proc_link_sif_o(proc_link_sif_lo)
    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );

  bsg_manycore_hetero_socket #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)

    ,.dmem_size_p(dmem_size_p)
    ,.vcache_size_p(vcache_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.hetero_type_p(hetero_type_p)
    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)

    ,.branch_trace_en_p(branch_trace_en_p)

    ,.debug_p(debug_p)
  ) proc (
    .clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_sif_i(proc_link_sif_lo)
    ,.link_sif_o(proc_link_sif_li)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );



  // fast link fwd
  assign fast_link_fwd_west_v_o[0]      =   fast_link_fwd_east_v_i[2];
  assign fast_link_fwd_west_data_o[0]   =   fast_link_fwd_east_data_i[2];
  assign fast_link_fwd_east_ready_o[2]  =   fast_link_fwd_west_ready_i[0];

  assign fast_link_fwd_west_v_o[1]      =   fast_link_fwd_east_v_i[0];
  assign fast_link_fwd_west_data_o[1]   =   fast_link_fwd_east_data_i[0];
  assign fast_link_fwd_east_ready_o[0]  =   fast_link_fwd_west_ready_i[1];

  assign fast_link_fwd_west_v_o[2]      =   fast_link_fwd_east_v_i[1];
  assign fast_link_fwd_west_data_o[2]   =   fast_link_fwd_east_data_i[1];
  assign fast_link_fwd_east_ready_o[1]  =   fast_link_fwd_west_ready_i[2];

  assign fast_link_fwd_east_v_o[2]      =   fast_link_fwd_west_v_i[1];
  assign fast_link_fwd_east_data_o[2]   =   fast_link_fwd_west_data_i[1];
  assign fast_link_fwd_west_ready_o[1]  =   fast_link_fwd_east_ready_i[2];

  assign fast_link_fwd_east_v_o[1]      =   fast_link_fwd_west_v_i[0];
  assign fast_link_fwd_east_data_o[1]   =   fast_link_fwd_west_data_i[0];
  assign fast_link_fwd_west_ready_o[0]  =   fast_link_fwd_east_ready_i[1];

  assign fast_link_fwd_east_v_o[0]      =   fast_link_fwd_west_v_i[2];
  assign fast_link_fwd_east_data_o[0]   =   fast_link_fwd_west_data_i[2];
  assign fast_link_fwd_west_ready_o[2]  =   fast_link_fwd_east_ready_i[0];



  // fast link rev
  assign fast_link_rev_west_v_o[0]      =   fast_link_rev_east_v_i[2];
  assign fast_link_rev_west_data_o[0]   =   fast_link_rev_east_data_i[2];
  assign fast_link_rev_east_ready_o[2]  =   fast_link_rev_west_ready_i[0];

  assign fast_link_rev_west_v_o[1]      =   fast_link_rev_east_v_i[0];
  assign fast_link_rev_west_data_o[1]   =   fast_link_rev_east_data_i[0];
  assign fast_link_rev_east_ready_o[0]  =   fast_link_rev_west_ready_i[1];

  assign fast_link_rev_west_v_o[2]      =   fast_link_rev_east_v_i[1];
  assign fast_link_rev_west_data_o[2]   =   fast_link_rev_east_data_i[1];
  assign fast_link_rev_east_ready_o[1]  =   fast_link_rev_west_ready_i[2];

  assign fast_link_rev_east_v_o[2]      =   fast_link_rev_west_v_i[1];
  assign fast_link_rev_east_data_o[2]   =   fast_link_rev_west_data_i[1];
  assign fast_link_rev_west_ready_o[1]  =   fast_link_rev_east_ready_i[2];

  assign fast_link_rev_east_v_o[1]      =   fast_link_rev_west_v_i[0];
  assign fast_link_rev_east_data_o[1]   =   fast_link_rev_west_data_i[0];
  assign fast_link_rev_west_ready_o[0]  =   fast_link_rev_east_ready_i[1];

  assign fast_link_rev_east_v_o[0]      =   fast_link_rev_west_v_i[2];
  assign fast_link_rev_east_data_o[0]   =   fast_link_rev_west_data_i[2];
  assign fast_link_rev_west_ready_o[2]  =   fast_link_rev_east_ready_i[0];




endmodule
