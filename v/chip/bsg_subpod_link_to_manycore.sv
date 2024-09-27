

`include "bsg_manycore_defines.svh"

module bsg_subpod_link_to_manycore
 import bsg_manycore_pkg::*;
 import bsg_manycore_tag_pkg::*;
 import bsg_clk_gen_pearl_pkg::*;
 import bsg_tag_pkg::*;
 #(parameter `BSG_INV_PARAM(tag_els_p)
   , parameter `BSG_INV_PARAM(tag_lg_width_p)
   , parameter `BSG_INV_PARAM(addr_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(x_cord_width_p)
   , parameter `BSG_INV_PARAM(y_cord_width_p)

   , parameter `BSG_INV_PARAM(clk_gen_ds_width_p)
   , parameter `BSG_INV_PARAM(clk_gen_num_taps_p)
   , parameter `BSG_INV_PARAM(sdr_lg_fifo_depth_p)
   , parameter `BSG_INV_PARAM(sdr_lg_credit_to_token_decimation_p)
   , parameter `BSG_INV_PARAM(sdr_subpod_num_links_p)
   
   , localparam fwd_width_lp =
       `bsg_manycore_packet_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   , localparam rev_width_lp =
       `bsg_manycore_return_packet_width(x_cord_width_p, y_cord_width_p, data_width_p)
   , localparam link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p)
   )
  (input                                                              ext_clk_i
   , input                                                            async_clk_output_disable_i
   , output logic                                                     clk_monitor_o

   , input                                                            tag_clk_i
   , input                                                            tag_data_i
   , input [`BSG_SAFE_CLOG2(tag_els_p)-1:0]                           tag_node_id_offset_i

   , output logic [sdr_subpod_num_links_p-1:0]                        io_fwd_link_clk_o
   , output logic [sdr_subpod_num_links_p-1:0][fwd_width_lp-1:0]      io_fwd_link_data_o
   , output logic [sdr_subpod_num_links_p-1:0]                        io_fwd_link_v_o
   , input [sdr_subpod_num_links_p-1:0]                               io_fwd_link_token_i
   , output logic [sdr_subpod_num_links_p-1:0]                        async_fwd_link_o_disable_o

   , input [sdr_subpod_num_links_p-1:0]                               io_fwd_link_clk_i
   , input [sdr_subpod_num_links_p-1:0][fwd_width_lp-1:0]             io_fwd_link_data_i
   , input [sdr_subpod_num_links_p-1:0]                               io_fwd_link_v_i
   , output logic [sdr_subpod_num_links_p-1:0]                        io_fwd_link_token_o
   , output logic [sdr_subpod_num_links_p-1:0]                        async_fwd_link_i_disable_o

   , output logic [sdr_subpod_num_links_p-1:0]                        io_rev_link_clk_o
   , output logic [sdr_subpod_num_links_p-1:0][rev_width_lp-1:0]      io_rev_link_data_o
   , output logic [sdr_subpod_num_links_p-1:0]                        io_rev_link_v_o
   , input [sdr_subpod_num_links_p-1:0]                               io_rev_link_token_i
   , output logic [sdr_subpod_num_links_p-1:0]                        async_rev_link_o_disable_o

   , input [sdr_subpod_num_links_p-1:0]                               io_rev_link_clk_i
   , input [sdr_subpod_num_links_p-1:0][rev_width_lp-1:0]             io_rev_link_data_i
   , input [sdr_subpod_num_links_p-1:0]                               io_rev_link_v_i
   , output logic [sdr_subpod_num_links_p-1:0]                        io_rev_link_token_o
   , output logic [sdr_subpod_num_links_p-1:0]                        async_rev_link_i_disable_o

   , output logic                                                     core_clk_o
   , output logic                                                     core_reset_o
   , output logic [x_cord_width_p-1:0]                                global_x_o
   , output logic [y_cord_width_p-1:0]                                global_y_o
   , input [sdr_subpod_num_links_p-1:0][link_sif_width_lp-1:0]        link_sif_i
   , output logic [sdr_subpod_num_links_p-1:0][link_sif_width_lp-1:0] link_sif_o
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

  bsg_manycore_subpod_tag_lines_s tag_lines_lo;
  bsg_tag_master_decentralized
   #(.els_p(tag_els_p)
     ,.local_els_p(tag_subpod_local_els_gp)
     ,.lg_width_p(tag_lg_width_p)
     )
   btm
    (.clk_i(tag_clk_i)
     ,.data_i(tag_data_i)
     ,.node_id_offset_i(subpod_tag_node_offset_li)
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

  logic sdr_disable_lo;
  bsg_tag_client_unsync
   #(.width_p(1))
   btc_sdr_disable
    (.bsg_tag_i(tag_lines_lo.sdr_disable)
     ,.data_async_r_o(sdr_disable_lo)
     );

  assign async_fwd_link_o_disable_o = {sdr_subpod_num_links_p{sdr_disable_lo}};
  assign async_fwd_link_i_disable_o = {sdr_subpod_num_links_p{sdr_disable_lo}};
  assign async_rev_link_o_disable_o = {sdr_subpod_num_links_p{sdr_disable_lo}};
  assign async_rev_link_i_disable_o = {sdr_subpod_num_links_p{sdr_disable_lo}};

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

  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
  bsg_manycore_link_sif_s [sdr_subpod_num_links_p-1:0] proc_link_sif_li, proc_link_sif_lo;
  for (genvar i = 0; i < sdr_subpod_num_links_p; i++)
    begin : links
      bsg_sdr_link_pearl
       #(.tag_els_p(tag_els_p)
         ,.tag_lg_width_p(tag_lg_width_p)
         ,.sdr_data_width_p(fwd_width_lp)
         ,.sdr_lg_fifo_depth_p(sdr_lg_fifo_depth_p)
         ,.sdr_lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_p)
         )
       fwd_sdr
        (.core_clk_i(core_clk_lo)
         ,.core_reset_i(core_reset_lo)
 
         ,.tag_clk_i(tag_clk_i)
         ,.tag_data_i(tag_data_i)
         ,.tag_node_id_offset_i(sdr_link_tag_node_id_offset_li)

         ,.core_data_i(proc_link_sif_li[i].fwd.data)
         ,.core_v_i(proc_link_sif_li[i].fwd.v)
         ,.core_ready_and_o(proc_link_sif_lo[i].fwd.ready_and_rev)
 
         ,.core_data_o(proc_link_sif_lo[i].fwd.data)
         ,.core_v_o(proc_link_sif_lo[i].fwd.v)
         ,.core_ready_and_i(proc_link_sif_li[i].fwd.ready_and_rev)
  
         ,.link_clk_o(io_fwd_link_clk_o[i])
         ,.link_data_o(io_fwd_link_data_o[i])
         ,.link_v_o(io_fwd_link_v_o[i])
         ,.link_token_i(io_fwd_link_token_i[i])
  
         ,.link_clk_i(io_fwd_link_clk_i[i])
         ,.link_data_i(io_fwd_link_data_i[i])
         ,.link_v_i(io_fwd_link_v_i[i])
         ,.link_token_o(io_fwd_link_token_o[i])
         );

      // Convert from credit for manycore rev
      logic [rev_width_lp-1:0] sdr_data_li;
      logic sdr_v_li, sdr_ready_and_lo;
      bsg_fifo_1r1w_small_credit_on_input
       #(.width_p(rev_width_lp), .els_p(3))
       credit_fifo
        (.clk_i(core_clk_lo)
         ,.reset_i(core_reset_lo)

         ,.data_i(proc_link_sif_li[i].rev.data)
         ,.v_i(proc_link_sif_li[i].rev.v)
         ,.credit_o(proc_link_sif_lo[i].rev.ready_and_rev)
      
         ,.data_o(sdr_data_li)
         ,.v_o(sdr_v_li)
         ,.yumi_i(sdr_ready_and_lo & sdr_v_li)
         );

      bsg_sdr_link_pearl
       #(.tag_els_p(tag_els_p)
         ,.tag_lg_width_p(tag_lg_width_p)
         ,.sdr_data_width_p(rev_width_lp)
         ,.sdr_lg_fifo_depth_p(sdr_lg_fifo_depth_p)
         ,.sdr_lg_credit_to_token_decimation_p(sdr_lg_credit_to_token_decimation_p)
         )
       rev_sdr
        (.core_clk_i(core_clk_lo)
         ,.core_reset_i(core_reset_lo)
  
         ,.tag_clk_i(tag_clk_i)
         ,.tag_data_i(tag_data_i)
         ,.tag_node_id_offset_i(sdr_link_tag_node_id_offset_li)

         ,.core_data_i(sdr_data_li)
         ,.core_v_i(sdr_v_li)
         ,.core_ready_and_o(sdr_ready_and_lo)
  
         ,.core_data_o(proc_link_sif_lo[i].rev.data)
         ,.core_v_o(proc_link_sif_lo[i].rev.v)
         ,.core_ready_and_i(proc_link_sif_li[i].rev.ready_and_rev)
  
         ,.link_clk_o(io_rev_link_clk_o[i])
         ,.link_data_o(io_rev_link_data_o[i])
         ,.link_v_o(io_rev_link_v_o[i])
         ,.link_token_i(io_rev_link_token_i[i])
  
         ,.link_clk_i(io_rev_link_clk_i[i])
         ,.link_data_i(io_rev_link_data_i[i])
         ,.link_v_i(io_rev_link_v_i[i])
         ,.link_token_o(io_rev_link_token_o[i])
         );

      assign link_sif_o[i] = proc_link_sif_lo[i];
      assign proc_link_sif_li[i] = link_sif_i[i];
    end

endmodule

