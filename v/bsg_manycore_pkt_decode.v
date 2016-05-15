module bsg_manycore_pkt_decode #(
                                 x_cord_width_p   = "inv"
                                 , y_cord_width_p = "inv"
                                 , data_width_p   = "inv"
                                 , addr_width_p   = "inv"
                                 , packet_width_lp = 6+x_cord_width_p+y_cord_width_p+data_width_p+addr_width_p
                                 )
   (
    input   v_i
    ,input [packet_width_lp-1:0] data_i

    ,output logic pkt_freeze_o
    ,output logic pkt_unfreeze_o
    ,output logic pkt_unknown_o

    ,output logic pkt_remote_store_o
    ,output logic [data_width_p-1:0] data_o
    ,output logic [addr_width_p-1:0] addr_o
    );

   typedef struct packed {
      logic [5:0] op;
      logic [addr_width_p-1:0] addr;
      logic [data_width_p-1:0] data;
      logic [y_cord_width_p-1:0] y_cord;
      logic [x_cord_width_p-1:0] x_cord;
   } bsg_manycore_packet_s;

   bsg_manycore_packet_s pkt;

   assign pkt = data_i;
   assign data_o = pkt.data;
   assign addr_o = pkt.addr;

   always_comb
     begin
        pkt_freeze_o        = 1'b0;
        pkt_unfreeze_o      = 1'b0;
        pkt_remote_store_o  = 1'b0;
        pkt_unknown_o       = 1'b0;

        if (v_i)
          unique case (pkt.op)
            6'd2: if (~|pkt.addr[addr_width_p-1:0])
              begin
                 pkt_freeze_o   = pkt.data[0];
                 pkt_unfreeze_o = ~pkt.data[0];
              end
            6'd1:
		pkt_remote_store_o = 1'b1;
            default:
              pkt_unknown_o = 1'b1;
          endcase // unique case (fifo_out_data[0].op)
     end

endmodule
