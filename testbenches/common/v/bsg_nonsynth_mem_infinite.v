/**
 *  bsg_nonsynth_mem_infinite.v
 *
 *  memory with "infinite" capacity and zero latency.
 *  it attaches to the manycore link interface.
 *  
 */

module bsg_nonsynth_mem_infinite
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter link_sif_width_lp=
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // endpoint standard
  //
  logic in_v_lo;
  logic in_yumi_li;
  logic [data_width_p-1:0] in_data_lo;
  logic [data_mask_width_lp-1:0] in_mask_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic in_we_lo;
  bsg_manycore_load_info_s in_load_info_lo, in_load_info_r;

  logic returning_v_li;
  logic [data_width_p-1:0] returning_data_li;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.fifo_els_p(4)
    ,.max_out_credits_p(16)
  ) ep (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    ,.in_v_o(in_v_lo)
    ,.in_yumi_i(in_yumi_li)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_addr_o(in_addr_lo)
    ,.in_we_o(in_we_lo)
    ,.in_src_x_cord_o()
    ,.in_src_y_cord_o()
    ,.in_load_info_o(in_load_info_lo)

    ,.returning_v_i(returning_v_li)
    ,.returning_data_i(returning_data_li)

    ,.out_v_i(1'b0)
    ,.out_packet_i('0)
    ,.out_ready_o()

    ,.returned_data_r_o()
    ,.returned_reg_id_r_o()
    ,.returned_pkt_type_r_o()
    ,.returned_v_r_o()
    ,.returned_yumi_i(1'b0)
    ,.returned_fifo_full_o()

    ,.out_credits_o()
    
    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );


  assign in_yumi_li = in_v_lo;

  logic [data_width_p-1:0] mem_data_lo; 
 
  bsg_nonsynth_mem_1rw_sync_mask_write_byte_assoc #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
  ) assoc_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(in_v_lo)
    ,.w_i(in_we_lo)
    
    ,.addr_i(in_addr_lo)
    ,.data_i(in_data_lo)
    ,.write_mask_i(in_mask_lo)

    ,.data_o(mem_data_lo) 
  );

  logic [data_width_p-1:0] load_data_lo;
  load_packer lp0 (
    .mem_data_i(mem_data_lo)
    ,.unsigned_load_i(in_load_info_r.is_unsigned_op)
    ,.byte_load_i(in_load_info_r.is_byte_op)
    ,.hex_load_i(in_load_info_r.is_hex_op)
    ,.part_sel_i(in_load_info_r.part_sel)
    ,.load_data_o(load_data_lo)
  );
 
  logic returning_v_r;
  logic we_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      returning_v_r <= 1'b0;
      we_r <= 1'b0;
      in_load_info_r <= '0;
    end
    else begin
      returning_v_r <= in_v_lo;
      we_r <= in_we_lo;
      if (in_v_lo & ~in_we_lo)
        in_load_info_r <= in_load_info_lo;
    end
  end

  assign returning_v_li = returning_v_r;
  assign returning_data_li = we_r
    ? '0
    : load_data_lo;

endmodule
