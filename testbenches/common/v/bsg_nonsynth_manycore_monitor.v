`include "bsg_manycore_packet.vh"

module bsg_nonsynth_manycore_monitor #(parameter x_cord_width_p="inv"
                                       ,parameter y_cord_width_p="inv"
                                       ,parameter addr_width_p="inv"
                                       ,parameter data_width_p="inv"
                                       ,parameter channel_num_p="inv"
                                       ,parameter max_cycles_p=1_000_000
                                       ,parameter packet_width_lp        = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                       ,parameter return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
                                       ,parameter num_nets_lp=2
                                       )
   (input clk_i
    ,input  reset_i

    ,input  [num_nets_lp-1:0]            v_i
    ,input  [packet_width_lp-1:0]        data_i
    ,input  [return_packet_width_lp-1:0] return_data_i
    ,output [num_nets_lp-1:0]            ready_o

    ,output [num_nets_lp-1:0]            v_o
    ,output [packet_width_lp-1:0]        data_o
    ,output [return_packet_width_lp-1:0] return_data_o
    ,input  [num_nets_lp-1:0]            ready_i

    ,input [39:0] cycle_count_i
    ,output finish_o
    );

   logic                              cgni_v, cgni_yumi;
   logic [packet_width_lp-1:0]        cgni_data;
   wire                               credit_return_lo;

   bsg_manycore_endpoint #(.x_cord_width_p (x_cord_width_p)
                           ,.y_cord_width_p(y_cord_width_p)
                           ,.fifo_els_p    (2)
                           ,.data_width_p  (data_width_p)
                           ,.addr_width_p  (addr_width_p)
                           ) endp
     (.clk_i
      ,.reset_i
      ,.v_i, .data_i, .return_data_i, .ready_o
      ,.return_v_o(v_o[1]), .return_data_o, .return_ready_i(ready_i[1])

      ,.fifo_data_o (cgni_data)
      ,.fifo_v_o    (cgni_v   )
      ,.fifo_yumi_i (cgni_yumi)

      ,.credit_v_r_o(credit_return_lo)   // we don't actually track credits in this device
      );

   // outgoing packets on main network: none sent
   assign v_o[0]    = 1'b0 & ready_i[0];
   assign data_o[0] = 0;

   // incoming packets on main network: always deque
   assign cgni_yumi = cgni_v;

   logic                        finish_r, finish_r_r;

   assign finish_o = finish_r;

   always_ff @(posedge clk_i)
     finish_r_r <= finish_r;

   always_ff @(posedge clk_i)
     if (finish_r_r)
       $finish();

   always_ff @(negedge clk_i)
     if (cycle_count_i > max_cycles_p)
       begin
          $display("## TIMEOUT reached max_cycles_p = %x",max_cycles_p);
          finish_r <= 1'b1;
       end

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_packet_s pkt_cast;

   assign pkt_cast = cgni_data;

   always_ff @(negedge clk_i)
     if (reset_i == 0)
       begin
          if (cgni_v)
            begin
               unique case (pkt_cast.addr[19:0])
                 20'hDEAD_0:
                   begin
                      $display("## RECEIVED FINISH PACKET from tile x,y=%2d,%2d at I/O %x on cycle 0x%x (%d)"
                               ,(pkt_cast.data >> 16)
                               ,(pkt_cast.data & 16'hffff)
                               , channel_num_p, cycle_count_i,cycle_count_i
                               );
                      finish_r <= 1'b1;
                   end
                 20'hDEAD_4:
                   begin
                      $display("## RECEIVED TIME PACKET from tile x,y=%2d,%2d at I/O %x on cycle 0x%x (%d)"
                               ,(pkt_cast.data >> 16)
                               ,(pkt_cast.data & 16'hffff)
                               , channel_num_p,cycle_count_i,cycle_count_i);
                   end
                 default:
                   $display("## received I/O device %x, addr %x, data %x on cycle %d", channel_num_p, pkt_cast.addr, pkt_cast.data,cycle_count_i);
               endcase
            end
       end

endmodule

