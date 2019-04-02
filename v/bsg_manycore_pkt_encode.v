`include "bsg_manycore_addr.vh"
`include "bsg_manycore_packet.vh"

module bsg_manycore_pkt_encode
  #(
    x_cord_width_p   = -1
    , y_cord_width_p = -1
    , data_width_p   = -1
    , addr_width_p   = -1
    , load_id_width_p = 5
    , epa_word_addr_width_p = -1
    , dram_ch_addr_width_p = -1
    , dram_ch_start_col_p  = 0
    , remote_addr_prefix_lp = 3'b001
    , global_addr_prefix_lp = 2'b01
    , packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
    , max_x_cord_width_lp = 6
    , max_y_cord_width_lp = 6
    , debug_p=0
    )
   (
     input clk_i // for debug only
    ,input v_i

    // we take in the full 32-bit address here
    ,input [32-1:0]                         addr_i
    ,input [data_width_p-1:0]               data_i
    ,input [(data_width_p>>3)-1:0]          mask_i
    ,input                                  we_i
    ,input                                  swap_aq_i
    ,input                                  swap_rl_i
    ,input [x_cord_width_p-1:0]             my_x_i
    ,input [y_cord_width_p-1:0]             my_y_i

    ,input [x_cord_width_p-1:0]             tile_group_x_i
    ,input [y_cord_width_p-1:0]             tile_group_y_i

    ,output                                 v_o
    ,output [packet_width_lp-1:0]           data_o
    );

   `declare_bsg_manycore_addr_s(epa_word_addr_width_p, max_x_cord_width_lp, max_y_cord_width_lp);
   `declare_bsg_manycore_global_addr_s(epa_word_addr_width_p, max_x_cord_width_lp, max_y_cord_width_lp);
   `declare_bsg_manycore_dram_addr_s(dram_ch_addr_width_p);
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);

   bsg_manycore_packet_s        pkt;
   bsg_manycore_addr_s          addr_decode;
   bsg_manycore_dram_addr_s     dram_addr_decode;
   bsg_manycore_global_addr_s   global_addr_decode;

   assign addr_decode           = addr_i;
   assign dram_addr_decode      = addr_i;
   assign global_addr_decode    = addr_i;
   assign data_o                = pkt;

   // memory map in special opcodes; fixme, can reclaim more address space by
   // checking more bits.

   assign pkt.op     =  swap_aq_i ? `ePacketOp_remote_swap_aq :
                        swap_rl_i ? `ePacketOp_remote_swap_rl :
                        we_i      ? `ePacketOp_remote_store   : `ePacketOp_remote_load ;

   assign pkt.op_ex  = mask_i;

   // global addr -- global network addr
   // remote addr -- in tile group remote addr 
   wire is_global_addr = global_addr_decode.remote == global_addr_prefix_lp;
   wire is_remote_addr = addr_decode.remote == remote_addr_prefix_lp;
   wire is_dram_addr   = dram_addr_decode.is_dram_addr;

   assign pkt.addr   =  dram_addr_decode.is_dram_addr
                        ? {1'b0, (dram_ch_addr_width_p)'(dram_addr_decode.addr)}
                        : (addr_width_p)'(addr_decode.addr);


   assign pkt.payload    = data_i;
   assign pkt.x_cord     = dram_addr_decode.is_dram_addr ? 
                            x_cord_width_p'(dram_addr_decode.x_cord + dram_ch_start_col_p)
                           :( is_global_addr  ?  x_cord_width_p'(addr_decode.x_cord)
                                              :  x_cord_width_p'(addr_decode.x_cord + tile_group_x_i)
                            );

   assign pkt.y_cord     = dram_addr_decode.is_dram_addr
                          ? {y_cord_width_p{1'b1}} //Set to Y_MAX
                          : ( is_global_addr ? y_cord_width_p'(addr_decode.y_cord)
                                             : y_cord_width_p'(addr_decode.y_cord + tile_group_y_i)
                            );

   assign pkt.src_x_cord = my_x_i;
   assign pkt.src_y_cord = my_y_i;

   wire  is_network_addr = is_global_addr | is_remote_addr | is_dram_addr ;
   assign v_o =  is_network_addr & v_i;

   // synopsys translate_off
   if (debug_p)
   always @(negedge clk_i)
     if (v_i)
       $display("%m encode pkt addr_i=%x data_i=%x mask_i=%x we_i=%x v_o=%x, data_o=%x, remote=%x bsg_manycore_addr_s size=%x",
                addr_i, data_i, mask_i, we_i, v_o, data_o, addr_decode.remote, $bits(bsg_manycore_addr_s));

//   always_ff @(negedge clk_i)
//     begin
//        if (addr_decode.remote & ~we_i & v_i)
//          begin
//             $error("%m load to remote address %x", addr_i);
//             $finish();
//          end
///*        if (addr_decode.remote & we_i & v_i & (|addr_i[1:0]))
//          begin
//             $error ("%m store to remote unaligned address %x", addr_i);
//          end*/
//     end
   always_ff @(negedge clk_i)
     begin
        if ( ~is_network_addr & (swap_aq_i | swap_rl_i ) & v_i)
          begin
             $error("%m swap with local memory address %x", addr_i);
             $finish();
          end
     end

   // synopsys translate_on

endmodule
