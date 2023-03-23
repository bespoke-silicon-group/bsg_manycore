/**
 *    bsg_fifo_delay.v
 *
 */


`include "bsg_defines.v"


module bsg_fifo_delay
  #(parameter `BSG_INV_PARAM(delay_p)
    , `BSG_INV_PARAM(width_p)
    , `BSG_INV_PARAM(els_p)
  )
  (
    input clk_i
    , input reset_i
    
    , input v_i
    , input [width_p-1:0] data_i
    , output logic ready_o


    , output logic v_o
    , output logic [width_p-1:0] data_o
    , input yumi_i
  );

  logic [delay_p-1:0] fifo_v_li, fifo_ready_lo;
  logic [delay_p-1:0][width_p-1:0] fifo_data_li;

  logic [delay_p-1:0] fifo_v_lo, fifo_yumi_li;
  logic [delay_p-1:0][width_p-1:0] fifo_data_lo;

  for (genvar i = 0; i < delay_p; i++) begin: d
    bsg_fifo_1r1w_small #(
      .width_p(width_p)
      ,.els_p((i==0) ? els_p : 2)
    ) fifo0 (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.v_i(fifo_v_li[i])
      ,.data_i(fifo_data_li[i])
      ,.ready_o(fifo_ready_lo[i])

      ,.v_o(fifo_v_lo[i])
      ,.data_o(fifo_data_lo[i])
      ,.yumi_i(fifo_yumi_li[i])
    );
  
    if (i == 0) begin
      assign fifo_v_li[i] = v_i;
      assign fifo_data_li[i] = data_i;
      assign ready_o = fifo_ready_lo[i];
    end

    if (i < delay_p-1) begin
      assign fifo_v_li[i+1] = fifo_v_lo[i];
      assign fifo_data_li[i+1] = fifo_data_lo[i];
      assign fifo_yumi_li[i] = fifo_v_lo[i] & fifo_ready_lo[i+1];
    end
  
    if (i == delay_p-1) begin
      assign v_o = fifo_v_lo[i];
      assign data_o = fifo_data_lo[i];
      assign fifo_yumi_li[i] = yumi_i;
    end
  end

endmodule


`BSG_ABSTRACT_MODULE(bsg_fifo_delay)
