`include "bsg_manycore_packet.vh"

module bsg_manycore_tile

import bsg_vscale_pkg::*
       , bsg_noc_pkg::*; // {P=0, W, E, N, S}

 #( parameter dirs_p            = 4
   ,parameter stub_p            = {dirs_p{1'b0}} // {s,n,e,w}
   ,parameter x_cord_width_p       = 5
   ,parameter y_cord_width_p       = 5

   ,parameter bank_size_p       = "inv"
   ,parameter num_banks_p       = "inv"
   ,parameter data_width_p      = hdata_width_p
   ,parameter addr_width_p      = haddr_width_p
   ,parameter mem_addr_width_lp = $clog2(num_banks_p) + `BSG_SAFE_CLOG2(bank_size_p)
   ,parameter packet_width_lp        = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
   ,parameter return_packet_width_lp = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
   ,parameter num_nets_lp            = 2 // 1=return network, 0=data network
   ,parameter debug_p = 0
  )
  ( input                                       clk_i
   ,input                                       reset_i

   // input fifos
   ,input   [dirs_p-1:0] [packet_width_lp-1:0]                data_i
   ,input   [dirs_p-1:0] [return_packet_width_lp-1:0]  return_data_i  // separate, because it is a different size
   ,input   [num_nets_lp-1:0][dirs_p-1:0]                        v_i
   ,output  [num_nets_lp-1:0][dirs_p-1:0]                    ready_o

   // output channels
   ,output  [dirs_p-1:0] [packet_width_lp-1:0]                data_o
   ,output  [dirs_p-1:0] [return_packet_width_lp-1:0]  return_data_o
   ,output  [num_nets_lp-1:0][dirs_p-1:0]                        v_o
   ,input   [num_nets_lp-1:0][dirs_p-1:0]                    ready_i

   // tile coordinates
   ,input   [x_cord_width_p-1:0]                my_x_i
   ,input   [y_cord_width_p-1:0]                my_y_i
  );

   logic [packet_width_lp-1:0]        proc_to_router_data,        router_to_proc_data;
   logic [return_packet_width_lp-1:0] proc_to_router_return_data, router_to_proc_return_data;
   logic [num_nets_lp-1:0]            proc_to_router_ready,       router_to_proc_ready,
                                      proc_to_router_v,           router_to_proc_v;

   genvar                      i;

   for (i = 0; i < num_nets_lp; i=i+1)
     begin: rof
        logic [4:0][(i ? return_packet_width_lp : packet_width_lp)-1:0] outpacket;
        logic [4:0][(i ? return_packet_width_lp : packet_width_lp)-1:0] data_tmp;

        if (i)
          begin
             assign { return_data_o, router_to_proc_return_data } = outpacket;
             assign data_tmp = { return_data_i, proc_to_router_return_data };
          end
        else
          begin
             assign {        data_o, router_to_proc_data        } = outpacket;
             assign data_tmp = { data_i, proc_to_router_data };
          end

        bsg_mesh_router_buffered #(.width_p(i ? return_packet_width_lp : packet_width_lp)
                                   ,.x_cord_width_p(x_cord_width_p)
                                   ,.y_cord_width_p(y_cord_width_p)
                                   ,.debug_p(debug_p)
                                   // adding proc into stub
                                   ,.stub_p({stub_p, 1'b0})
                                   // needed for doing I/O to south edge of array
                                   ,.allow_S_to_EW_p(1'b1)
                                   ) bmrb
            (.clk_i    (clk_i)
             ,.reset_i (reset_i)

             ,.v_i     ({ v_i    [i], proc_to_router_v    [i]})
             ,.ready_o ({ ready_o[i], proc_to_router_ready[i]})

             ,.v_o     ({ v_o    [i], router_to_proc_v    [i]})
             ,.ready_i ({ ready_i[i], router_to_proc_ready[i]})

             ,.data_i  (data_tmp)

             ,.data_o  (outpacket)

             ,.my_x_i
             ,.my_y_i
             );
     end

   logic                       freeze;

   bsg_manycore_proc #(
                       .x_cord_width_p (x_cord_width_p)
                       ,.y_cord_width_p(y_cord_width_p)
                       ,.debug_p       (debug_p       )
                       ,.bank_size_p   (bank_size_p   )
                       ,.num_banks_p   (num_banks_p   )
                       ,.data_width_p  (data_width_p  )
                       ,.addr_width_p  (addr_width_p  )
                       ) proc
   (.clk_i   (clk_i)
    ,.reset_i(reset_i)

    ,.v_i          (router_to_proc_v          )
    ,.data_i       (router_to_proc_data       )
    ,.return_data_i(router_to_proc_return_data)
    ,.ready_o      (router_to_proc_ready      )

    ,.v_o          (proc_to_router_v          )
    ,.data_o       (proc_to_router_data       )
    ,.return_data_o(proc_to_router_return_data)
    ,.ready_i      (proc_to_router_ready      )

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)

    ,.freeze_o(freeze)
    );


endmodule

