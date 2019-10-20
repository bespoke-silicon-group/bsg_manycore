
//
// Paul Gao 08/2019
//
//

`include "bsg_manycore_packet.vh"

module bsg_manycore_endpoint_test_node

 #(
   parameter addr_width_p = "inv"
  ,parameter data_width_p = "inv"
  ,parameter x_cord_width_p = "inv"
  ,parameter y_cord_width_p = "inv"
  ,parameter load_id_width_p = "inv"
  
  ,parameter node_id_p = "inv"
  ,parameter max_out_credits_p = "inv"
  ,localparam credit_counter_width_lp = $clog2(max_out_credits_p+1)
  ,localparam packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  )

  (
   input clk_i
  ,input reset_i
  ,input en_i
  
  // rx
  ,input in_v_i
  ,input in_we_i
  ,input [addr_width_p-1:0] in_addr_i
  ,input [data_width_p-1:0] in_data_i
  ,input [(data_width_p>>3)-1:0] in_mask_i
  ,output logic in_yumi_o
  
  ,output logic returning_v_o
  ,output [data_width_p-1:0] returning_data_o

  // tx
  ,output [packet_width_lp-1:0] out_packet_o
  ,output logic out_v_o
  ,input out_ready_i

  ,input returned_v_r_i
  ,input [data_width_p-1:0] returned_data_r_i
  ,input [load_id_width_p-1:0] returned_load_id_r_i
  ,input returned_fifo_full_i
  ,output logic returned_yumi_o

  ,input [credit_counter_width_lp-1:0] out_credits_i
  
  ,input [x_cord_width_p-1:0] my_x_i
  ,input [y_cord_width_p-1:0] my_y_i
  );
  
  `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);
  
  bsg_manycore_packet_s out_packet;
  logic [7:0] counter_r, counter_n;
  logic [3:0] state_r, state_n;
  
  assign out_packet_o = out_packet;
  
  always_ff @(posedge clk_i)
  begin
    if (reset_i)
      begin
        counter_r <= '0;
        state_r <= '0;
      end
    else
      begin
        counter_r <= counter_n;
        state_r <= state_n;
      end
  end

  // top nodes, sending commands to bottom
  if (node_id_p == 0 || node_id_p == 1)
  begin
    
    assign in_yumi_o = in_v_i;
    assign returning_v_o = 1'b0;
    assign returning_data_o = '0;
    
    // TODO: fix later
    assign returned_yumi_o = returned_v_r_i;
    
    always_comb
      begin
        counter_n = counter_r;
        state_n = state_r;
        out_v_o = 1'b0;
        out_packet = '0;
        out_packet.x_cord = 0;
        out_packet.y_cord = 4;
        out_packet.src_x_cord = my_x_i;
        out_packet.src_y_cord = my_y_i;
        out_packet.addr = counter_r;
        if (state_r == 0)
          begin
            if (en_i)
              begin
                out_v_o = 1'b1;
                if (out_ready_i)
                  begin
                    state_n = 1;
                  end
              end
          end
        else if (state_r == 1)
          begin
            counter_n = counter_r + 1;
            state_n = 0;
            if (counter_n == 16)
              begin
                state_n = 2;
              end
          end
      end
    
  end
  else if (node_id_p == 2)
  begin
  
    assign in_yumi_o = in_v_i;
    assign returning_v_o = 1'b0;
    assign returning_data_o = '0;
    
    // TODO: fix later
    assign returned_yumi_o = returned_v_r_i;
    
    always_comb
      begin
        counter_n = counter_r;
        state_n = state_r;
        out_v_o = 1'b0;
        out_packet = '0;
        out_packet.x_cord = 0;
        out_packet.y_cord = 3;
        out_packet.src_x_cord = my_x_i;
        out_packet.src_y_cord = my_y_i;
        out_packet.addr = counter_r;
        if (state_r == 0)
          begin
            if (en_i)
              begin
                out_v_o = 1'b1;
                if (out_ready_i)
                  begin
                    state_n = 1;
                  end
              end
          end
        else if (state_r == 1)
          begin
            counter_n = counter_r + 1;
            state_n = 0;
          end
      end
  
  end
  else if (node_id_p == 3)
  begin
  
    assign out_packet = '0;
    assign out_v_o = 1'b0;
    assign returned_yumi_o = returned_v_r_i;
    
    assign returning_data_o = counter_r;
    
    always_comb
      begin
        counter_n = counter_r;
        state_n = state_r;
        in_yumi_o = 1'b0;
        returning_v_o = 1'b0;
        if (state_r == 0)
          begin
            if (in_v_i)
              begin
                in_yumi_o = 1'b1;
                state_n = 1;
              end
          end
        else if (state_r == 1)
          begin
            returning_v_o = 1'b1;
            counter_n = counter_r + 1;
            state_n = 0;
          end
      end
  
  end
  else if (node_id_p == 4)
  begin
  
    assign out_packet = '0;
    assign out_v_o = 1'b0;
    assign returned_yumi_o = returned_v_r_i;
    
    assign returning_data_o = counter_r;
    
    always_comb
      begin
        counter_n = counter_r;
        state_n = state_r;
        in_yumi_o = 1'b0;
        returning_v_o = 1'b0;
        if (state_r == 0)
          begin
            if (in_v_i)
              begin
                in_yumi_o = 1'b1;
                counter_n = counter_r + 1;
                if (counter_n == 32)
                  begin
                    counter_n = 0;
                    state_n = 1;
                  end
              end
          end
        else if (state_r == 1)
          begin
            counter_n = counter_r + 1;
            if (counter_n == 0)
              begin
                state_n = 2;
              end
          end
        else if (state_n == 2)
          begin
            returning_v_o = 1'b1;
            counter_n = counter_r + 1;
            if (counter_n == 32)
              begin
                state_n = 3;
              end
          end
      end
    
  end

endmodule
