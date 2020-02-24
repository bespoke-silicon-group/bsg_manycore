/**
 *  bsg_nonsynth_manycore_io_complex.v
 *
 *  this has a monitor and spmd loader.
 *
 */


module bsg_nonsynth_manycore_io_complex
  import bsg_manycore_pkg::*;
  #(parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"

    , parameter io_x_cord_p=0 
    , parameter io_y_cord_p=1

    , parameter max_out_credits_p=200
    , parameter credit_counter_width_lp=`BSG_SAFE_CLOG2(max_out_credits_p+1)
 
    , parameter data_mask_width_lp=(data_width_p>>3)

    , parameter link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,
        x_cord_width_p,y_cord_width_p)

    , parameter mc_packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,
        x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
    , output loader_done_o

    , input [link_sif_width_lp-1:0] io_link_sif_i
    , output [link_sif_width_lp-1:0] io_link_sif_o

    , output logic print_stat_v_o
    , output logic [data_width_p-1:0] print_stat_tag_o
  );

  initial begin
    $display("## creating manycore io complex num_tiles.");
  end

  // endpoint standard
  //
  logic in_v_lo;
  logic in_yumi_i;
  logic [data_width_p-1:0] in_data_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic [data_mask_width_lp-1:0] in_mask_lo;
  logic in_we_lo;
  logic [x_cord_width_p-1:0] in_src_x_cord;
  logic [y_cord_width_p-1:0] in_src_y_cord;
  bsg_manycore_load_info_s in_load_info_lo;

  logic [data_width_p-1:0] returning_data_li;
  logic returning_v_li;

  logic out_v_li;
  logic [mc_packet_width_lp-1:0] out_packet_li;
  logic out_ready_lo;
  logic out_packet_lo;

  logic returned_v_r_lo;

  logic [credit_counter_width_lp-1:0] out_credits_lo;
  
  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.max_out_credits_p(max_out_credits_p)
    ,.fifo_els_p(16)
  ) endp (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(io_link_sif_i)
    ,.link_sif_o(io_link_sif_o)

    // monitor
    ,.in_v_o(in_v_lo)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_addr_o(in_addr_lo)
    ,.in_we_o(in_we_lo)
    ,.in_src_x_cord_o(in_src_x_cord)
    ,.in_src_y_cord_o(in_src_y_cord)
    ,.in_yumi_i(in_yumi_i)
    ,.in_load_info_o(in_load_info_lo)

    ,.returning_data_i(returning_data_li)
    ,.returning_v_i(returning_v_li)

    // loader
    ,.out_v_i(out_v_li)
    ,.out_packet_i(out_packet_li)
    ,.out_ready_o(out_ready_lo)

    ,.returned_data_r_o()
    ,.returned_reg_id_r_o()
    ,.returned_pkt_type_r_o()
    ,.returned_v_r_o(returned_v_r_lo)
    ,.returned_fifo_full_o()
    ,.returned_yumi_i(returned_v_r_lo)

    // misc
    ,.out_credits_o(out_credits_lo)
    ,.my_x_i((x_cord_width_p)'(io_x_cord_p))
    ,.my_y_i((y_cord_width_p)'(io_y_cord_p))
  );

  // monitor
  //
  bsg_nonsynth_manycore_monitor #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
  ) monitor (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(in_v_lo)
    ,.data_i(in_data_lo)
    ,.mask_i(in_mask_lo)
    ,.addr_i(in_addr_lo)
    ,.we_i(in_we_lo)
    ,.src_x_cord_i(in_src_x_cord)
    ,.src_y_cord_i(in_src_y_cord)
    ,.load_info_i(in_load_info_lo)
    ,.yumi_o(in_yumi_i)

    ,.data_o(returning_data_li)
    ,.v_o(returning_v_li) 

    ,.print_stat_v_o(print_stat_v_o)
    ,.print_stat_tag_o(print_stat_tag_o)
  );

  // SPMD loader
  //
  logic spmd_v_lo;
  logic spmd_ready_li;

  bsg_nonsynth_manycore_spmd_loader #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.max_out_credits_p(max_out_credits_p)
  ) loader (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.done_o(loader_done_o)

    ,.packet_o(out_packet_li)
    ,.v_o(spmd_v_lo)
    ,.ready_i(spmd_ready_li)

    ,.my_x_i((x_cord_width_p)'(io_x_cord_p))
    ,.my_y_i((y_cord_width_p)'(io_y_cord_p))

    ,.out_credits_i(out_credits_lo)
  );

  assign out_v_li = spmd_v_lo & (out_credits_lo > 1);
  assign spmd_ready_li = out_ready_lo & (out_credits_lo > 1);


endmodule
