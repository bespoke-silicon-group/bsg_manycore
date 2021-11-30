/**
 *    bsg_manycore_proc_vanilla.v
 *
 */

`include "bsg_manycore_defines.vh"

module bsg_manycore_proc_vanilla
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(x_cord_width_p )
    , `BSG_INV_PARAM(y_cord_width_p )
    , `BSG_INV_PARAM(pod_x_cord_width_p )
    , `BSG_INV_PARAM(pod_y_cord_width_p )
    , `BSG_INV_PARAM(data_width_p )
    , `BSG_INV_PARAM(addr_width_p )

    , `BSG_INV_PARAM(icache_tag_width_p )
    , `BSG_INV_PARAM(icache_entries_p )

    , `BSG_INV_PARAM(dmem_size_p )
    , `BSG_INV_PARAM(num_vcache_rows_p )
    , `BSG_INV_PARAM(vcache_size_p )
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)
    , `BSG_INV_PARAM(vcache_sets_p )

    , `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)

    , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter `BSG_INV_PARAM(rev_fifo_els_p) // for FIFO credit counting.
    , `BSG_INV_PARAM(fwd_fifo_els_p) // for FIFO credit counting.
  
    , credit_counter_width_p = `BSG_WIDTH(32)
    , proc_fifo_els_p = 4
    , debug_p = 1

    , localparam icache_addr_width_lp = `BSG_SAFE_CLOG2(icache_entries_p)
    , dmem_addr_width_lp = `BSG_SAFE_CLOG2(dmem_size_p)
    , pc_width_lp=(icache_addr_width_lp+icache_tag_width_p)
    , data_mask_width_lp=(data_width_p>>3)
    , reg_addr_width_lp=RV32_reg_addr_width_gp

    , parameter `BSG_INV_PARAM(barrier_dirs_p)
    , localparam barrier_lg_dirs_lp=`BSG_SAFE_CLOG2(barrier_dirs_p+1)

    , link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

  )
  (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o

    , input barrier_data_i
    , output barrier_data_o
    , output [barrier_dirs_p-1:0]     barrier_src_r_o
    , output [barrier_lg_dirs_lp-1:0] barrier_dest_r_o

    // subcord within a pod
    , input [x_subcord_width_lp-1:0] my_x_i
    , input [y_subcord_width_lp-1:0] my_y_i

    // pod coordinate
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i
  );

  // endpoint standard
  //
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  logic in_v_lo;
  logic in_we_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic [data_width_p-1:0] in_data_lo;
  logic [(data_width_p>>3)-1:0] in_mask_lo;
  logic in_yumi_li;
  bsg_manycore_load_info_s in_load_info_lo;

  logic returning_data_v_li;
  logic [data_width_p-1:0] returning_data_li;

  bsg_manycore_packet_s out_packet_li;
  logic out_v_li;
  logic out_credit_or_ready_lo;
  logic link_credit_lo;

  logic returned_v_r_lo;
  logic returned_yumi_li;
  logic [data_width_p-1:0] returned_data_r_lo;
  bsg_manycore_return_packet_type_e returned_pkt_type_r_lo;
  logic [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_r_lo;
  logic returned_fifo_full_lo;

  logic [credit_counter_width_p-1:0] out_credits_used_lo;
  logic [x_cord_width_p-1:0] 	      src_x_cord_debug_lo;
  logic [y_cord_width_p-1:0] 	      src_y_cord_debug_lo;   
   
  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)

    ,.fifo_els_p(proc_fifo_els_p)

    ,.credit_counter_width_p(credit_counter_width_p)
    ,.rev_fifo_els_p(rev_fifo_els_p)

    ,.use_credits_for_local_fifo_p(1)
  ) endp (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    // rx
    ,.in_v_o(in_v_lo)
    ,.in_we_o(in_we_lo)
    ,.in_addr_o(in_addr_lo)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_yumi_i(in_yumi_li)
    ,.in_load_info_o(in_load_info_lo)
    ,.in_src_x_cord_o(src_x_cord_debug_lo)
    ,.in_src_y_cord_o(src_y_cord_debug_lo)

    ,.returning_v_i(returning_data_v_li)
    ,.returning_data_i(returning_data_li)

    // tx
    ,.out_packet_i(out_packet_li)
    ,.out_v_i(out_v_li)
    ,.out_credit_or_ready_o(out_credit_or_ready_lo)

    ,.returned_v_r_o(returned_v_r_lo)
    ,.returned_data_r_o(returned_data_r_lo)
    ,.returned_reg_id_r_o(returned_reg_id_r_lo)
    ,.returned_pkt_type_r_o(returned_pkt_type_r_lo)
    ,.returned_fifo_full_o(returned_fifo_full_lo)
    ,.returned_yumi_i(returned_yumi_li)

    ,.returned_credit_v_r_o()
    ,.returned_credit_reg_id_r_o()

    ,.out_credits_used_o(out_credits_used_lo)

    ,.global_x_i({pod_x_i, my_x_i})
    ,.global_y_i({pod_y_i, my_y_i})
  );


  // RX unit
  //
  logic remote_dmem_v_lo;
  logic remote_dmem_w_lo;
  logic [dmem_addr_width_lp-1:0] remote_dmem_addr_lo;
  logic [data_mask_width_lp-1:0] remote_dmem_mask_lo;
  logic [data_width_p-1:0] remote_dmem_data_lo;
  logic [data_width_p-1:0] remote_dmem_data_li;
  logic remote_dmem_yumi_li;

  logic icache_v_lo;
  logic [pc_width_lp-1:0] icache_pc_lo;
  logic [data_width_p-1:0] icache_instr_lo;
  logic icache_yumi_li;

  logic freeze;
  logic [x_subcord_width_lp-1:0] tgo_x;
  logic [y_subcord_width_lp-1:0] tgo_y;
  logic [pc_width_lp-1:0] pc_init_val;

  logic remote_interrupt_set_lo;
  logic remote_interrupt_clear_lo;
  logic remote_interrupt_pending_bit_li;

  network_rx #(
    .addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.icache_entries_p(icache_entries_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.x_subcord_width_p(x_subcord_width_lp)
    ,.y_subcord_width_p(y_subcord_width_lp)
  ) rx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.v_i(in_v_lo)
    ,.w_i(in_we_lo)
    ,.addr_i(in_addr_lo)
    ,.data_i(in_data_lo)
    ,.mask_i(in_mask_lo)
    ,.load_info_i(in_load_info_lo)
    ,.yumi_o(in_yumi_li)
    ,.src_x_cord_debug_i(src_x_cord_debug_lo)
    ,.src_y_cord_debug_i(src_y_cord_debug_lo)
	
    ,.returning_data_o(returning_data_li)
    ,.returning_data_v_o(returning_data_v_li)

    ,.remote_dmem_v_o(remote_dmem_v_lo)
    ,.remote_dmem_w_o(remote_dmem_w_lo)
    ,.remote_dmem_addr_o(remote_dmem_addr_lo)
    ,.remote_dmem_data_o(remote_dmem_data_lo)
    ,.remote_dmem_mask_o(remote_dmem_mask_lo)
    ,.remote_dmem_data_i(remote_dmem_data_li)
    ,.remote_dmem_yumi_i(remote_dmem_yumi_li)

    ,.icache_v_o(icache_v_lo)
    ,.icache_pc_o(icache_pc_lo)
    ,.icache_instr_o(icache_instr_lo)
    ,.icache_yumi_i(icache_yumi_li)

    ,.freeze_o(freeze)
    ,.tgo_x_o(tgo_x)
    ,.tgo_y_o(tgo_y)
    ,.pc_init_val_o(pc_init_val)

    ,.remote_interrupt_set_o(remote_interrupt_set_lo)
    ,.remote_interrupt_clear_o(remote_interrupt_clear_lo)
    ,.remote_interrupt_pending_bit_i(remote_interrupt_pending_bit_li)

    ,.global_x_i({pod_x_i, my_x_i})
    ,.global_y_i({pod_y_i, my_y_i})
  );


   wire [pod_x_cord_width_p-1:0] cfg_pod_x_lo;
   wire [pod_y_cord_width_p-1:0] cfg_pod_y_lo;
   
  // TX unit
  //
  remote_req_s remote_req;
  logic remote_req_v;
  logic remote_req_credit;

  logic ifetch_v_lo;
  logic [data_width_p-1:0] ifetch_instr_lo;

  logic [reg_addr_width_lp-1:0] float_remote_load_resp_rd_lo;
  logic [data_width_p-1:0] float_remote_load_resp_data_lo;
  logic float_remote_load_resp_v_lo;
  logic float_remote_load_resp_force_lo;
  logic float_remote_load_resp_yumi_li;

  logic [reg_addr_width_lp-1:0] int_remote_load_resp_rd_lo;
  logic [data_width_p-1:0] int_remote_load_resp_data_lo;
  logic int_remote_load_resp_v_lo;
  logic int_remote_load_resp_force_lo;
  logic int_remote_load_resp_yumi_li;

  logic invalid_eva_access_lo;

  network_tx #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_size_p(vcache_size_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
    ,.vcache_sets_p(vcache_sets_p)

    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)

    ,.num_tiles_x_p(num_tiles_x_p)
    ,.num_tiles_y_p(num_tiles_y_p)
  ) tx (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.out_packet_o(out_packet_li)
    ,.out_v_o(out_v_li)
    ,.out_credit_or_ready_i(out_credit_or_ready_lo)

    ,.returned_v_i(returned_v_r_lo)
    ,.returned_data_i(returned_data_r_lo)
    ,.returned_reg_id_i(returned_reg_id_r_lo)
    ,.returned_pkt_type_i(returned_pkt_type_r_lo)
    ,.returned_fifo_full_i(returned_fifo_full_lo)
    ,.returned_yumi_o(returned_yumi_li)

    ,.tgo_x_i(tgo_x)
    ,.tgo_y_i(tgo_y) 

    ,.pod_x_i(pod_x_i)
    ,.pod_y_i(pod_y_i)

    ,.cfg_pod_x_i(cfg_pod_x_lo)
    ,.cfg_pod_y_i(cfg_pod_y_lo)	

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)

    ,.remote_req_i(remote_req)
    ,.remote_req_v_i(remote_req_v)
    ,.remote_req_credit_o(remote_req_credit)

    ,.ifetch_v_o(ifetch_v_lo)
    ,.ifetch_instr_o(ifetch_instr_lo)

    ,.float_remote_load_resp_rd_o(float_remote_load_resp_rd_lo)
    ,.float_remote_load_resp_data_o(float_remote_load_resp_data_lo)
    ,.float_remote_load_resp_v_o(float_remote_load_resp_v_lo)
    ,.float_remote_load_resp_force_o(float_remote_load_resp_force_lo)
    ,.float_remote_load_resp_yumi_i(float_remote_load_resp_yumi_li)

    ,.int_remote_load_resp_rd_o(int_remote_load_resp_rd_lo)
    ,.int_remote_load_resp_data_o(int_remote_load_resp_data_lo)
    ,.int_remote_load_resp_v_o(int_remote_load_resp_v_lo)
    ,.int_remote_load_resp_force_o(int_remote_load_resp_force_lo)
    ,.int_remote_load_resp_yumi_i(int_remote_load_resp_yumi_li)

    ,.invalid_eva_access_o(invalid_eva_access_lo)
  );

  // Vanilla Core
  //
  vanilla_core #(
    .data_width_p(data_width_p)
    ,.dmem_size_p(dmem_size_p)
    ,.icache_entries_p(icache_entries_p)
    ,.icache_tag_width_p(icache_tag_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.credit_counter_width_p(credit_counter_width_p)
    ,.fwd_fifo_els_p(fwd_fifo_els_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)		 		 
    ,.barrier_dirs_p(barrier_dirs_p)
  ) vcore (
    .clk_i(clk_i)
    ,.reset_i(freeze)

    ,.pc_init_val_i(pc_init_val)
    
    ,.remote_req_o(remote_req)
    ,.remote_req_v_o(remote_req_v)
    ,.remote_req_credit_i(remote_req_credit)

    ,.icache_v_i(icache_v_lo)
    ,.icache_pc_i(icache_pc_lo)
    ,.icache_instr_i(icache_instr_lo)
    ,.icache_yumi_o(icache_yumi_li)

    ,.ifetch_v_i(ifetch_v_lo)
    ,.ifetch_instr_i(ifetch_instr_lo)

    ,.remote_dmem_v_i(remote_dmem_v_lo)
    ,.remote_dmem_w_i(remote_dmem_w_lo)
    ,.remote_dmem_addr_i(remote_dmem_addr_lo)
    ,.remote_dmem_data_i(remote_dmem_data_lo)
    ,.remote_dmem_mask_i(remote_dmem_mask_lo)
    ,.remote_dmem_data_o(remote_dmem_data_li)
    ,.remote_dmem_yumi_o(remote_dmem_yumi_li)

    ,.float_remote_load_resp_rd_i(float_remote_load_resp_rd_lo)
    ,.float_remote_load_resp_data_i(float_remote_load_resp_data_lo)
    ,.float_remote_load_resp_v_i(float_remote_load_resp_v_lo)
    ,.float_remote_load_resp_force_i(float_remote_load_resp_force_lo)
    ,.float_remote_load_resp_yumi_o(float_remote_load_resp_yumi_li)

    ,.int_remote_load_resp_rd_i(int_remote_load_resp_rd_lo)
    ,.int_remote_load_resp_data_i(int_remote_load_resp_data_lo)
    ,.int_remote_load_resp_v_i(int_remote_load_resp_v_lo)
    ,.int_remote_load_resp_force_i(int_remote_load_resp_force_lo)
    ,.int_remote_load_resp_yumi_o(int_remote_load_resp_yumi_li)

    ,.out_credits_used_i(out_credits_used_lo)
    ,.invalid_eva_access_i(invalid_eva_access_lo)
  
    ,.remote_interrupt_set_i(remote_interrupt_set_lo)
    ,.remote_interrupt_clear_i(remote_interrupt_clear_lo)
    ,.remote_interrupt_pending_bit_o(remote_interrupt_pending_bit_li)

    ,.barrier_data_i(barrier_data_i)
    ,.barrier_data_o(barrier_data_o)
    ,.barrier_src_r_o(barrier_src_r_o)
    ,.barrier_dest_r_o(barrier_dest_r_o)

    ,.cfg_pod_x_o(cfg_pod_x_lo)
    ,.cfg_pod_y_o(cfg_pod_y_lo)	
	   
    ,.global_x_i({pod_x_i, my_x_i})
    ,.global_y_i({pod_y_i, my_y_i})
  );

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_proc_vanilla)
