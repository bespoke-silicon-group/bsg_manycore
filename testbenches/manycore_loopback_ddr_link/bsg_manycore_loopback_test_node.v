
`include "bsg_manycore_packet.vh"

module  bsg_manycore_loopback_test_node

 #(parameter num_channels_p = "inv"
  ,parameter channel_width_p = "inv"
  ,parameter addr_width_p="inv"
  ,parameter data_width_p="inv"
  ,parameter load_id_width_p = 5
  ,parameter x_cord_width_p="inv"
  ,parameter y_cord_width_p="inv"
  
  ,localparam bsg_manycore_link_sif_width_lp=`bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  ,localparam width_p = num_channels_p * channel_width_p
  )

  (input clk_i
  ,input reset_i
  ,input en_i
  
  ,output logic  error_o
  ,output [31:0] sent_o
  ,output [31:0] received_o

  ,input  [bsg_manycore_link_sif_width_lp-1:0] links_sif_i
  ,output [bsg_manycore_link_sif_width_lp-1:0] links_sif_o
  );
  
  
  // Define link packets
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  // Define req and resp packets
  `declare_bsg_manycore_packet_s  (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  
  localparam req_width_lp  = $bits(bsg_manycore_packet_s);
  localparam resp_width_lp = $bits(bsg_manycore_return_packet_s);
  localparam min_width_lp  = `BSG_MIN(req_width_lp, resp_width_lp);
  
  // synopsys translate_off
  initial 
  begin
    assert (min_width_lp >= width_p)
    else $error("Packet width %d is smaller than test data width %d", min_width_lp, width_p);
  end
  // synopsys translate_on
  
  
  // Cast of link packets
  bsg_manycore_link_sif_s links_sif_i_cast, links_sif_o_cast;

  assign links_sif_i_cast = links_sif_i;
  assign links_sif_o = links_sif_o_cast;
  
  
  // Req and Resp packets
  bsg_manycore_fwd_link_sif_s fwd_li, fwd_lo;
  bsg_manycore_rev_link_sif_s rev_li, rev_lo;

  // coming in from manycore
  assign fwd_li = links_sif_i_cast.fwd;
  assign rev_li = links_sif_i_cast.rev;

  // going out to manycore
  assign links_sif_o_cast.fwd = fwd_lo;
  assign links_sif_o_cast.rev = rev_lo;
  

  logic                         resp_in_v;
  bsg_manycore_return_packet_s  resp_in_data;
  logic                         resp_in_yumi;

  logic                         req_out_ready;
  bsg_manycore_packet_s         req_out_data;
  logic                         req_out_v;

  bsg_two_fifo 
 #(.width_p(resp_width_lp)
  ) resp_in_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(rev_lo.ready_and_rev)
  ,.v_i    (rev_li.v)
  ,.data_i (rev_li.data)

  ,.v_o    (resp_in_v)
  ,.data_o (resp_in_data)
  ,.yumi_i (resp_in_yumi)
  );
  
  
  bsg_two_fifo 
 #(.width_p(req_width_lp)
  ) req_out_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(req_out_ready)
  ,.v_i    (req_out_v)
  ,.data_i (req_out_data)

  ,.v_o    (fwd_lo.v)
  ,.data_o (fwd_lo.data)
  ,.yumi_i (fwd_lo.v & fwd_li.ready_and_rev)
  );


  logic [width_p-1:0] data_gen, data_check;

  test_bsg_data_gen
 #(.channel_width_p(channel_width_p)
  ,.num_channels_p(num_channels_p)
  ) gen_out
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.yumi_i (req_out_v & req_out_ready)
  ,.o      (data_gen)
  );

  assign req_out_v    = en_i;
  assign req_out_data = {'0, data_gen};

  test_bsg_data_gen
 #(.channel_width_p(channel_width_p)
  ,.num_channels_p(num_channels_p)
  ) gen_in
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.yumi_i (resp_in_v)
  ,.o      (data_check)
  );
  
  assign resp_in_yumi = resp_in_v;

  // synopsys translate_off
  always_ff @(negedge clk_i)
    if (resp_in_v & ~reset_i)
      assert(data_check == resp_in_data[width_p-1:0])
        else $error("check mismatch %x %x ", data_check,resp_in_data[width_p-1:0]);
  // synopsys translate_on

  always_ff @(posedge clk_i)
    if (reset_i) 
        error_o <= 0;
    else 
        if (resp_in_v & data_check != resp_in_data[width_p-1:0])
            error_o <= 1;
        else
            error_o <= error_o;
  
  // Count sent and received packets
  bsg_counter_clear_up 
 #(.max_val_p(1<<32-1)
  ,.init_val_p(0)
  ) sent_count
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.clear_i(1'b0)
  ,.up_i   (req_out_v & req_out_ready)
  ,.count_o(sent_o)
  );
  
  bsg_counter_clear_up 
 #(.max_val_p(1<<32-1)
  ,.init_val_p(0)
  ) received_count
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.clear_i(1'b0)
  ,.up_i   (resp_in_v)
  ,.count_o(received_o)
  );
   
   

  logic                         req_in_v;
  bsg_manycore_packet_s         req_in_data;
  logic                         req_in_yumi;

  logic                         resp_out_ready;
  bsg_manycore_return_packet_s  resp_out_data;
  logic                         resp_out_v;

  bsg_two_fifo 
 #(.width_p(req_width_lp)
  ) req_in_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(fwd_lo.ready_and_rev)
  ,.v_i    (fwd_li.v)
  ,.data_i (fwd_li.data)

  ,.v_o    (req_in_v)
  ,.data_o (req_in_data)
  ,.yumi_i (req_in_yumi)
  );

  // loopback any data received
  assign resp_out_data = {'0, req_in_data[width_p-1:0]};
  assign resp_out_v = req_in_v;
  assign req_in_yumi = resp_out_v & resp_out_ready;

  bsg_two_fifo 
 #(.width_p(resp_width_lp)
  ) resp_out_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(resp_out_ready)
  ,.v_i    (resp_out_v)
  ,.data_i (resp_out_data)

  ,.v_o    (rev_lo.v)
  ,.data_o (rev_lo.data)
  ,.yumi_i (rev_lo.v & rev_li.ready_and_rev)
  );
   


endmodule