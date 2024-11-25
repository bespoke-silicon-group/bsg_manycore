

`include "bsg_manycore_defines.svh"

module bsg_manycore_pod_link
 import bsg_manycore_pkg::*;
 import bsg_manycore_tag_pkg::*;
 import bsg_clk_gen_pearl_pkg::*;
 import bsg_tag_pkg::*;
 #(parameter `BSG_INV_PARAM(tag_els_p)
   , parameter `BSG_INV_PARAM(tag_lg_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)
   , parameter `BSG_INV_PARAM(sdr_data_width_p)

   , parameter `BSG_INV_PARAM(clk_gen_ds_width_p)
   , parameter `BSG_INV_PARAM(clk_gen_num_taps_p)
   , parameter `BSG_INV_PARAM(sdr_lg_fifo_depth_p)
   , parameter `BSG_INV_PARAM(sdr_lg_credit_to_token_decimation_p)
   , parameter `BSG_INV_PARAM(sdr_num_links_p)

   , localparam link_sif_width_lp = `bsg_ready_and_link_sif_width(sdr_data_width_p)
   )
  (input                                                       ext_clk_i
   , input                                                     async_clk_output_disable_i
   , output logic                                              clk_monitor_o

   , input                                                     tag_clk_i
   , input                                                     tag_data_i
   , input [`BSG_SAFE_CLOG2(tag_els_p)-1:0]                    tag_node_id_offset_i

   , output logic [sdr_num_links_p-1:0]                        link_clk_o
   , output logic [sdr_num_links_p-1:0][sdr_data_width_p-1:0]  link_data_o
   , output logic [sdr_num_links_p-1:0]                        link_v_o
   , input [sdr_num_links_p-1:0]                               link_token_i

   , input [sdr_num_links_p-1:0]                               link_clk_i
   , input [sdr_num_links_p-1:0][sdr_data_width_p-1:0]         link_data_i
   , input [sdr_num_links_p-1:0]                               link_v_i
   , output logic [sdr_num_links_p-1:0]                        link_token_o

   , output logic                                              core_clk_o
   , output logic                                              core_reset_o
   , output logic [x_cord_width_p-1:0]                         global_x_o
   , output logic [y_cord_width_p-1:0]                         global_y_o
   , input [sdr_num_links_p-1:0][link_sif_width_lp-1:0]        link_sif_i
   , output logic [sdr_num_links_p-1:0][link_sif_width_lp-1:0] link_sif_o
   );

  wire [`BSG_SAFE_CLOG2(tag_els_p)-1:0] clk_gen_tag_node_offset_li = tag_node_id_offset_i + '0;
  wire [`BSG_SAFE_CLOG2(tag_els_p)-1:0] subpod_tag_node_offset_li = clk_gen_tag_node_offset_li + '0;
  wire [`BSG_SAFE_CLOG2(tag_els_p)-1:0] sdr_link_tag_node_id_offset_li = clk_gen_tag_node_offset_li + bsg_clk_gen_pearl_tag_local_els_gp + bsg_tag_local_els_gp;

  logic core_clk_lo;
  bsg_clk_gen_pearl
   #(.ds_width_p(clk_gen_ds_width_p)
     ,.num_taps_p(clk_gen_num_taps_p)
     ,.tag_els_p(tag_els_p)
     ,.tag_lg_width_p(tag_lg_width_p)
     )
   clk_gen
    (.ext_clk_i(ext_clk_i)
     ,.async_output_disable_i(async_clk_output_disable_i)

     ,.tag_clk_i(tag_clk_i)
     ,.tag_data_i(tag_data_i)
     ,.tag_node_id_offset_i(clk_gen_tag_node_offset_li)

     ,.clk_o(core_clk_lo)
     ,.clk_monitor_o(clk_monitor_o)
     );
  assign core_clk_o = core_clk_lo;

  bsg_manycore_pod_tag_lines_s tag_lines_lo;
  bsg_tag_master_decentralized
   #(.els_p(tag_els_p)
     ,.local_els_p(tag_pod_local_els_gp)
     ,.lg_width_p(tag_lg_width_p)
     )
   btm
    (.clk_i(tag_clk_i)
     ,.data_i(tag_data_i)
     ,.node_id_offset_i(tag_node_id_offset_i)
     ,.clients_o(tag_lines_lo)
     );

  logic core_reset_lo;
  bsg_tag_client
   #(.width_p(1))
   btc_core_reset
    (.bsg_tag_i(tag_lines_lo.core_reset)
     ,.recv_clk_i(core_clk_lo)
     ,.recv_new_r_o()
     ,.recv_data_r_o(core_reset_lo)
     );
  assign core_reset_o = core_reset_lo;

  logic [x_cord_width_p-1:0] global_x_li;
  bsg_tag_client_unsync
   #(.width_p(x_cord_width_p))
   btc_global_x
    (.bsg_tag_i(tag_lines_lo.global_x)
     ,.data_async_r_o(global_x_li)
     );
  assign global_x_o = global_x_li;

  logic [y_cord_width_p-1:0] global_y_li;
  bsg_tag_client_unsync
   #(.width_p(y_cord_width_p))
   btc_global_y
    (.bsg_tag_i(tag_lines_lo.global_y)
     ,.data_async_r_o(global_y_li)
     );
  assign global_y_o = global_y_li;

  `declare_bsg_ready_and_link_sif_s(sdr_data_width_p, bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s [sdr_num_links_p-1:0] proc_link_sif_li, proc_link_sif_lo;
  for (genvar i = 0; i < sdr_num_links_p; i++)
    begin : links
      bsg_sdr_link_pearl
       #(.tag_els_p(tag_els_p)
         ,.tag_lg_width_p(tag_lg_width_p)
         ,.sdr_data_width_p(sdr_data_width_p)
         ,.sdr_lg_fifo_depth_p(sdr_lg_fifo_depth_p)
         ,.sdr_lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_p)
         )
       sdr
        (.core_clk_i(core_clk_lo)
         ,.core_reset_i(core_reset_lo)
 
         ,.tag_clk_i(tag_clk_i)
         ,.tag_data_i(tag_data_i)
         ,.tag_node_id_offset_i(sdr_link_tag_node_id_offset_li)

         ,.core_data_i(proc_link_sif_li[i].data)
         ,.core_v_i(proc_link_sif_li[i].v)
         ,.core_ready_and_o(proc_link_sif_lo[i].ready_and_rev)
 
         ,.core_data_o(proc_link_sif_lo[i].data)
         ,.core_v_o(proc_link_sif_lo[i].v)
         ,.core_ready_and_i(proc_link_sif_li[i].ready_and_rev)
  
         ,.link_clk_o(link_clk_o[i])
         ,.link_data_o(link_data_o[i])
         ,.link_v_o(link_v_o[i])
         ,.link_token_i(link_token_i[i])
  
         ,.link_clk_i(link_clk_i[i])
         ,.link_data_i(link_data_i[i])
         ,.link_v_i(link_v_i[i])
         ,.link_token_o(link_token_o[i])

         // Manycore pod link uses global disable
         ,.async_link_i_disable_o()
         ,.async_link_o_disable_o()
         );
  
      assign link_sif_o[i] = proc_link_sif_lo[i];
      assign proc_link_sif_li[i] = link_sif_i[i];
    end

endmodule

