
//
// Paul Gao 08/2019
//
//

`timescale 1ps/1ps

`include "bsg_manycore_packet.vh"

module bsg_manycore_endpoint_tester

 #(
   parameter addr_width_p = 32
  ,parameter data_width_p = 32
  ,parameter x_cord_width_p = 4
  ,parameter y_cord_width_p = 4
  ,parameter load_id_width_p = 8
  
  ,parameter num_nodes_p = 5
  ,parameter max_out_credits_p = 32
  ,parameter proc_fifo_els_p = 4
  ,parameter debug_p = 0
  
  ,localparam credit_counter_width_lp=$clog2(max_out_credits_p+1)
  )
  
  ();
  
  `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);
  
  logic clk, reset, en;
  
  bsg_manycore_link_sif_s [num_nodes_p-1:0][3:0] node_links_li;
  bsg_manycore_link_sif_s [num_nodes_p-1:0][3:0] node_links_lo;
  
  bsg_manycore_link_sif_s [num_nodes_p-1:0] proc_link_li;
  bsg_manycore_link_sif_s [num_nodes_p-1:0] proc_link_lo;
  
  logic [num_nodes_p-1:0] in_v_lo;
  logic [num_nodes_p-1:0] in_we_lo;
  logic [num_nodes_p-1:0][addr_width_p-1:0] in_addr_lo;
  logic [num_nodes_p-1:0][data_width_p-1:0] in_data_lo;
  logic [num_nodes_p-1:0][(data_width_p>>3)-1:0] in_mask_lo;
  logic [num_nodes_p-1:0] in_yumi_li;

  logic [num_nodes_p-1:0] returning_data_v_li;
  logic [num_nodes_p-1:0][data_width_p-1:0] returning_data_li;

  bsg_manycore_packet_s [num_nodes_p-1:0] out_packet_li;
  logic [num_nodes_p-1:0] out_v_li;
  logic [num_nodes_p-1:0] out_ready_lo;

  logic [num_nodes_p-1:0] returned_v_r_lo;
  logic [num_nodes_p-1:0] returned_yumi_li;
  logic [num_nodes_p-1:0][data_width_p-1:0] returned_data_r_lo;
  logic [num_nodes_p-1:0][load_id_width_p-1:0] returned_load_id_r_lo;
  logic [num_nodes_p-1:0] returned_fifo_full_lo;

  logic [num_nodes_p-1:0][credit_counter_width_lp-1:0] out_credits_lo;
  
  
  genvar i;
  
  for (i = 0; i < num_nodes_p; i++)
  begin: nodes
    
    // routers
    bsg_manycore_mesh_node 
   #(.stub_p(4'b0000)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ) router
    (.clk_i(clk)
    ,.reset_i(reset)
    ,.links_sif_i(node_links_li[i])
    ,.links_sif_o(node_links_lo[i])
    ,.proc_link_sif_i(proc_link_li[i])
    ,.proc_link_sif_o(proc_link_lo[i])
    ,.my_x_i('0)
    ,.my_y_i(y_cord_width_p'(i))
    );
    
    // stub west and east
    assign node_links_li[i][0] = '0;
    assign node_links_li[i][1] = '0;
    
    // link stitching
    if (i == 0)
      begin: top
        assign node_links_li[i][2] = '0;
      end
    else
      begin: middle
        assign node_links_li[i][2] = node_links_lo[i-1][3];
        assign node_links_li[i-1][3] = node_links_lo[i][2];
      end
      
    if (i == num_nodes_p-1)
      begin: bottom
        assign node_links_li[i][3] = '0;
      end
  
    // endpoint
    bsg_manycore_endpoint_standard 
   #(.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.fifo_els_p(proc_fifo_els_p)
    ,.max_out_credits_p(max_out_credits_p)
    ,.returned_fifo_p(1)
    ,.debug_p(debug_p)
    ) endp 
    (.clk_i(clk)
    ,.reset_i(reset)
    
    ,.link_sif_i(proc_link_lo[i])
    ,.link_sif_o(proc_link_li[i])

    // rx
    ,.in_v_o(in_v_lo[i])
    ,.in_we_o(in_we_lo[i])
    ,.in_addr_o(in_addr_lo[i])
    ,.in_data_o(in_data_lo[i])
    ,.in_mask_o(in_mask_lo[i])
    ,.in_yumi_i(in_yumi_li[i])
    ,.in_src_x_cord_o()
    ,.in_src_y_cord_o()

    ,.returning_v_i(returning_data_v_li[i])
    ,.returning_data_i(returning_data_li[i])

    // tx
    ,.out_packet_i(out_packet_li[i])
    ,.out_v_i(out_v_li[i])
    ,.out_ready_o(out_ready_lo[i])

    ,.returned_v_r_o(returned_v_r_lo[i])
    ,.returned_data_r_o(returned_data_r_lo[i])
    ,.returned_load_id_r_o(returned_load_id_r_lo[i])
    ,.returned_fifo_full_o(returned_fifo_full_lo[i])
    ,.returned_yumi_i(returned_yumi_li[i])

    ,.out_credits_o(out_credits_lo[i])

    ,.my_x_i('0)
    ,.my_y_i(y_cord_width_p'(i))
    );
    
    // test node
    bsg_manycore_endpoint_test_node
   #(.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.node_id_p(i)
    ,.max_out_credits_p(max_out_credits_p)
    ) node
    (.clk_i(clk)
    ,.reset_i(reset)
    ,.en_i(en)
    
    ,.in_v_i(in_v_lo[i])
    ,.in_we_i(in_we_lo[i])
    ,.in_addr_i(in_addr_lo[i])
    ,.in_data_i(in_data_lo[i])
    ,.in_mask_i(in_mask_lo[i])
    ,.in_yumi_o(in_yumi_li[i])
  
    ,.returning_v_o(returning_data_v_li[i])
    ,.returning_data_o(returning_data_li[i])
  
    ,.out_packet_o(out_packet_li[i])
    ,.out_v_o(out_v_li[i])
    ,.out_ready_i(out_ready_lo[i])
  
    ,.returned_v_r_i(returned_v_r_lo[i])
    ,.returned_data_r_i(returned_data_r_lo[i])
    ,.returned_load_id_r_i(returned_load_id_r_lo[i])
    ,.returned_fifo_full_i(returned_fifo_full_lo[i])
    ,.returned_yumi_o(returned_yumi_li[i])
  
    ,.out_credits_i(out_credits_lo[i])
    );

  end
  
  
  // Simulation of Clock
  always #4 clk = ~clk;
  
  
  initial 
  begin

    $display("Start Simulation\n");
  
    // init
    clk = 1;
    reset = 1;
    en = 0;
    
    #500;
    
    // disable reset
    @(posedge clk); #1;
    reset = 0;
    $display("reset LOW"); 
    
    #500;

    // node enable
    @(posedge clk); #1;
    en = 1;
    $display("node enable HIGH");
    
    #5000;
    
    // node disable
    @(posedge clk); #1;
    en = 0;
    $display("node enable LOW");
    
    #500
    
    $display("\nFinished\n");
    $finish;
    
  end

endmodule
