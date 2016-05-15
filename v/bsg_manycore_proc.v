module bsg_manycore_proc #(x_cord_width_p   = "inv"
                           , y_cord_width_p = "inv"
                           , data_width_p   = 32
                           , addr_width_p   = 32
                           , packet_width_lp = 6 + x_cord_width_p + y_cord_width_p + data_width_p + addr_width_p

                           , debug_p        = 0
                           , bank_size_p    = 2048 // in words
                           , num_banks_p    = 4

                           // this is the size of the receive FIFO
                           , proc_fifo_els_p = 4
                           , mem_width_lp    = $clog2(bank_size_p) + $clog2(num_banks_p)
                           )
   (input   clk_i
    , input reset_i

    , input v_i
    , input [packet_width_lp-1:0] data_i
    , output ready_o

    , output v_o
    , output [packet_width_lp-1:0] data_o
    , input ready_i

    // tile coordinates
    , input   [x_cord_width_p-1:0]                 my_x_i
    , input   [y_cord_width_p-1:0]                 my_y_i

    , output logic freeze_o
    );

   // input fifo from network

   logic cgni_v, cgni_yumi;
   logic [packet_width_lp-1:0] cgni_data;

   // this fifo buffers incoming remote store requests
   // it is a little bigger than the standard twofer to accomodate
   // bank conflicts

   bsg_fifo_1r1w_small #(.width_p(packet_width_lp)
                        ,.els_p (proc_fifo_els_p)
                        ) cgni
     (.clk_i   (clk_i  )
      ,.reset_i(reset_i)

      ,.v_i     (v_i    )
      ,.data_i  (data_i )
      ,.ready_o (ready_o)

      ,.v_o    (cgni_v   )
      ,.data_o (cgni_data)
      ,.yumi_i (cgni_yumi)
      );

   // decode incoming packet
   logic                       pkt_freeze, pkt_unfreeze, pkt_remote_store, pkt_unknown;
   logic [data_width_p-1:0]    remote_store_data;
   logic [addr_width_p-1:0]    remote_store_addr;
   logic                       remote_store_v, remote_store_yumi;

   if (debug_p)
   always_ff @(negedge clk_i)
     if (v_o)
       $display("%m attempting remote store of data %x, ready_i = %x",data_o,ready_i);

   if (debug_p)
     always_ff @(negedge clk_i)
       if (cgni_v)
         $display("%m data %x avail on cgni (cgni_yumi=%x,remote_store_v=%x, remote_store_addr=%x, remote_store_data=%x, remote_store_yumi=%x)",cgni_data,cgni_yumi,remote_store_v,remote_store_addr, remote_store_data, remote_store_yumi);

   bsg_manycore_pkt_decode #(.x_cord_width_p (x_cord_width_p)
                             ,.y_cord_width_p(y_cord_width_p)
                             ,.data_width_p  (data_width_p )
                             ,.addr_width_p  (addr_width_p )
                             ) pkt_decode
     (.v_i                 (cgni_v)
      ,.data_i             (cgni_data)
      ,.pkt_freeze_o       (pkt_freeze)
      ,.pkt_unfreeze_o     (pkt_unfreeze)
      ,.pkt_unknown_o      (pkt_unknown)

      ,.pkt_remote_store_o (remote_store_v)
      ,.data_o             (remote_store_data)
      ,.addr_o             (remote_store_addr)
      );

   // deque if we successfully do a remote store, or if it's
   // either kind of packet freeze instruction
   assign cgni_yumi = remote_store_yumi | pkt_freeze | pkt_unfreeze;

   // create freeze gate
   logic                       freeze_r;
   assign freeze_o = freeze_r;

   always_ff @(posedge clk_i)
     if (reset_i)
       freeze_r <= 1'b1;
     else
       if (pkt_freeze | pkt_unfreeze)
         begin
            $display("## freeze_r <= %x",pkt_freeze);
            freeze_r <= pkt_freeze;
         end

   logic [1:0]                  core_mem_v;
   logic [1:0]                  core_mem_w;
   logic [1:0] [addr_width_p-1:0] core_mem_addr;
   logic [1:0] [data_width_p-1:0] core_mem_wdata;
   logic [1:0] [(data_width_p>>3)-1:0] core_mem_mask;
   logic [1:0]                         core_mem_yumi;
   logic [1:0]                         core_mem_rv;
   logic [1:0] [data_width_p-1:0]      core_mem_rdata;

   bsg_vscale_core #(.x_cord_width_p (x_cord_width_p)
                     ,.y_cord_width_p(y_cord_width_p)
                     )
            core
     ( .clk_i   (clk_i)
       ,.reset_i (reset_i)
       ,.freeze_i (freeze_r)

       ,.m_v_o       (core_mem_v)
       ,.m_w_o       (core_mem_w)
       ,.m_addr_o    (core_mem_addr)
       ,.m_data_o    (core_mem_wdata)
       ,.m_mask_o    (core_mem_mask)

       // for data port (1), either the network or the banked memory can
       // deque the item.
       ,.m_yumi_i    ({(v_o & ready_i) | core_mem_yumi[1]
                       , core_mem_yumi[0]})
       ,.m_v_i       (core_mem_rv)
       ,.m_data_i    (core_mem_rdata)
       ,.my_x_i (my_x_i)
       ,.my_y_i (my_y_i)
       );

   bsg_manycore_pkt_encode #(.x_cord_width_p (x_cord_width_p)
                             ,.y_cord_width_p(y_cord_width_p)
                             ,.data_width_p (data_width_p )
                             ,.addr_width_p (addr_width_p )
                             ) pkt_encode
     (.clk_i(clk_i)

      // the memory request, from the core's data memory port
      ,.v_i    (core_mem_v    [1])
      ,.data_i (core_mem_wdata[1])
      ,.addr_i (core_mem_addr [1])
      ,.we_i   (core_mem_w    [1])
      ,.mask_i (core_mem_mask [1])

      // directly out to the network!
      ,.v_o    (v_o   )
      ,.data_o (data_o)
      );

   // synopsys translate off

   typedef struct packed {
      logic [5:0] op;
      logic [addr_width_p-1:0] addr;
      logic [data_width_p-1:0] data;
      logic [y_cord_width_p-1:0] y_cord;
      logic [x_cord_width_p-1:0] x_cord;
   } bsg_manycore_packet_s;

   bsg_manycore_packet_s data_o_debug;
   assign data_o_debug = data_o;

   if (debug_p)
     always @(negedge clk_i)
       begin
          if (v_o & ready_o)
            $display("proc sending packet %x (op=%x, addr=%x, data=%x, y_cord=%x, x_cord=%x), bit_mask=%x, core_mem_wdata=%x, core_mem_addr=%x"
                     , data_o_debug
                     , data_o_debug.op
                     , data_o_debug.addr
                     , data_o_debug.data
                     , data_o_debug.y_cord
                     , data_o_debug.x_cord
                     , core_mem_mask [1]
                     , core_mem_wdata[1]
                     , core_mem_addr [1]
                     );
       end

   // synopsys translate on



   wire [data_width_p-1:0] unused_data;
   wire                    unused_valid;

   // we create dedicated signals for these wires to allow easy access for "bind" statements
   wire [2:0]              xbar_port_v_in = { remote_store_v
                                              // request to write only if we are not sending a remote store packet
                                              // we check the high bit only for performance
                                              , core_mem_v[1] & ~core_mem_addr[1][31]
                                              , core_mem_v[0]
                                              };
   wire [2:0]                    xbar_port_we_in   = {1'b1, core_mem_w[1], 1'b0};
   wire [2:0]                    xbar_port_yumi_out;
   wire [2:0] [data_width_p-1:0] xbar_port_data_in = {remote_store_data,    core_mem_wdata};
   wire [2:0] [mem_width_lp-1:0] xbar_port_addr_in = { remote_store_addr  [2+:mem_width_lp]
                                                       , core_mem_addr[1] [2+:mem_width_lp]
                                                       , core_mem_addr[0] [2+:mem_width_lp]
                                                       };

   assign {remote_store_yumi, core_mem_yumi } = xbar_port_yumi_out;

  bsg_mem_banked_crossbar #
    ( .num_ports_p  (3)
     ,.num_banks_p  (num_banks_p)
     ,.bank_size_p  (bank_size_p)
     ,.data_width_p (data_width_p)
      ,.debug_p(debug_p*4)  // mbt: debug, multiply addresses by 4.
//      ,.debug_p(4)
//     ,.debug_reads_p(0)
    ) banked_crossbar
    ( .clk_i   (clk_i)
     ,.reset_i (reset_i)
      ,.v_i    (xbar_port_v_in)
      // the network port always writes, proc data port sometimes writes, proc inst port never writes
      ,.w_i     (xbar_port_we_in)
      ,.addr_i  (xbar_port_addr_in)
      ,.data_i  (xbar_port_data_in)
      ,.mask_i  ({(data_width_p>>3)'(0), core_mem_mask})
      // whether the crossbar accepts the input
     ,.yumi_o  (xbar_port_yumi_out)
     ,.v_o     ({unused_valid,      core_mem_rv      })
     ,.data_o  ({unused_data,       core_mem_rdata   })
    );




endmodule
