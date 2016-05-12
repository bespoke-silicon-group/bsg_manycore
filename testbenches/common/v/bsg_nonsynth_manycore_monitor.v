
module bsg_nonsynth_manycore_monitor #(parameter xcord_width_p="inv"
                                       ,parameter ycord_width_p="inv"
                                       ,parameter addr_width_p="inv"
                                       ,parameter data_width_p="inv"
                                       ,parameter num_channels_p="inv"
                                       ,parameter packet_width_lp = 6+xcord_width_p+ycord_width_p+addr_width_p+data_width_p
                                       ,parameter max_cycles_p=1_000_000
                              )
   (input clk_i
    ,input reset_i
    ,input [num_channels_p-1:0][packet_width_lp-1:0] data_i
    ,input [num_channels_p-1:0] v_i
    , input finish_i
    );

  typedef struct packed {
    logic [5:0]               op;
    logic [addr_width_p-1:0]  addr;
    logic [data_width_p-1:0]  data;
    logic [ycord_width_p-1:0]   y_cord;
    logic [xcord_width_p-1:0]   x_cord;
  } bsg_vscale_remote_packet_s;

   logic [39:0]                 trace_count;

   bsg_cycle_counter #(.width_p(40)) bcc (.clk(clk_i),.reset_i(reset_i),.ctr_r_o(trace_count));

   always_ff @(negedge clk_i)
     if (trace_count > max_cycles_p)
       begin
          $display("## TIMEOUT reached max_cycles_p = %x",max_cycles_p);
          $finish();
       end

   bsg_vscale_remote_packet_s [num_channels_p-1:0] pkt_cast;
   assign pkt_cast = data_i;

   genvar                       i;

   for (i = 0; i < num_channels_p; i=i+1)
     begin: rof
        always_ff @(negedge clk_i)
          if (reset_i == 0)
          begin
             if (v_i[i] | finish_i)
               begin
                  unique case (pkt_cast[i].addr[19:0])
                    20'hDEAD_0:
                      begin
                         $display("## RECEIVED FINISH PACKET from tile x,y=%2d,%2d at I/O %x on cycle 0x%x"
                                  ,(pkt_cast[i].data >> 16)
                                  ,(pkt_cast[i].data & 16'hffff)
                                  , i,trace_count
				  );
                         $finish();
                      end
                    20'hDEAD_4:
                      begin
                         $display("## RECEIVED TIME PACKET from tile x,y=%2d,%2d at I/O %x on cycle 0x%x"
                                  ,(pkt_cast[i].data >> 16)
                                  ,(pkt_cast[i].data & 16'hffff)
                                  , i,trace_count);
                      end
                    default:
                      $display("## received I/O device %x, addr %x, data %x",i,pkt_cast[i].addr, pkt_cast[i].data);
                  endcase
               end
          end
     end : rof
endmodule

