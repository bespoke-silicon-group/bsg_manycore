`include "bsg_manycore_packet.vh"

module bsg_manycore_pkt_decode
  #(
    x_cord_width_p   = -1
    , y_cord_width_p = -1
    , data_width_p   = -1
    , addr_width_p   = -1
    , packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p, data_width_p)
    )
   (
    input   v_i
    ,input [packet_width_lp-1:0] data_i
    ,output logic pkt_freeze_o
    ,output logic pkt_unfreeze_o
    ,output logic pkt_arb_cfg_o
    ,output logic pkt_unknown_o

    ,output logic pkt_remote_store_o
    ,output logic pkt_remote_load_o
    ,output logic pkt_remote_swap_aq_o
    ,output logic pkt_remote_swap_rl_o

    ,output logic [data_width_p-1:0] data_o
    ,output logic [addr_width_p-1:0] addr_o
    ,output logic [(data_width_p>>3)-1:0] mask_o
    );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_packet_s pkt;

   assign pkt = data_i;
   assign data_o = pkt.data;
   assign addr_o = addr_width_p ' (pkt.addr);

   wire is_config_op    = v_i & pkt.addr[addr_width_p-1]
                              & (pkt.op == `ePacketOp_remote_store) ;
   wire is_mem_op       = v_i & ( ~ pkt.addr[addr_width_p-1]      )  ;

   wire is_freeze_addr  = {1'b0,pkt.addr[addr_width_p-2:0]} == addr_width_p'(0);
   wire is_arb_cfg_addr = {1'b0,pkt.addr[addr_width_p-2:0]} == addr_width_p'(1);

   assign pkt_freeze_o          = is_config_op & is_freeze_addr & pkt.data[0]    ;
   assign pkt_unfreeze_o        = is_config_op & is_freeze_addr & (~pkt.data[0]) ;
   assign pkt_arb_cfg_o         = is_config_op & is_arb_cfg_addr                 ;
   assign pkt_remote_store_o    = is_mem_op    & ( pkt.op == `ePacketOp_remote_store);
   assign pkt_remote_load_o     = is_mem_op    & ( pkt.op == `ePacketOp_remote_load );
   assign pkt_remote_swap_aq_o  = is_mem_op    & ( pkt.op == `ePacketOp_remote_swap_aq );
   assign pkt_remote_swap_rl_o  = is_mem_op    & ( pkt.op == `ePacketOp_remote_swap_rl );

   assign pkt_unknown_o      = &{    ~pkt_freeze_o   ,
                                    ~pkt_unfreeze_o ,
                                    ~pkt_arb_cfg_o  ,
                                    ~pkt_remote_store_o ,
                                    ~pkt_remote_load_o  ,
                                    ~pkt_remote_swap_aq_o   ,
                                    ~pkt_remote_swap_rl_o
                               };
   assign mask_o            = pkt.op_ex;

endmodule
