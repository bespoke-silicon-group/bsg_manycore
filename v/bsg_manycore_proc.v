`include "bsg_manycore_packet.vh"

`ifdef bsg_VANILLA
`include "definitions.v"
`endif

`ifdef bsg_FPU
 `include "float_definitions.v"
`endif

module bsg_manycore_proc #(x_cord_width_p   = "inv"
                           , y_cord_width_p = "inv"
                           , data_width_p   = 32
                           , addr_width_p   = "inv"
                           , debug_p        = 0
                           , bank_size_p    = "inv" // in words
                           , num_banks_p    = "inv"

                           , imem_size_p        = bank_size_p // in words
                           , imem_addr_width_lp = $clog2(imem_size_p)
                           // this credit counter is more for implementing memory fences
                           // than containing the number of outstanding remote stores

                           //, max_out_credits_p = (1<<13)-1  // 13 bit counter
                           , max_out_credits_p = 200  // 13 bit counter

                           // this is the size of the receive FIFO
                           , proc_fifo_els_p = 4
                           , num_nets_lp     = 2

                           , hetero_type_p   = 0
                           , packet_width_lp                = `bsg_manycore_packet_width       (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                           , return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p)
                           , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width     (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                          )
   (input   clk_i
    , input reset_i

   // input and output links
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

     // tile coordinates
    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i
`ifdef bsg_FPU
    , input  f_fam_out_s           fam_out_s_i
    , output f_fam_in_s            fam_in_s_o
`endif

    , output logic freeze_o
    );

   //paramter for memory port start index.if start from zero
   //there are imem and dmem. if start from 1, there are only
   //dmem. This mechanism is used to keep dmem port constant
   // to 1
   `ifdef bsg_VANILLA
        parameter    core_imem_portID_lp = 1;
   `else
        parameter    core_imem_portID_lp = 0;
   `endif


   wire freeze_r;
   assign freeze_o = freeze_r;

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s              out_packet_li;
   logic                              out_v_li;
   logic                              out_ready_lo;

   logic [data_width_p-1:0]      in_data_lo;
   logic [(data_width_p>>3)-1:0] in_mask_lo;
   logic [addr_width_p-1:0]      in_addr_lo;
   logic                         in_v_lo, in_yumi_li;
   logic [$clog2(max_out_credits_p+1)-1:0] out_credits_lo;

   bsg_manycore_endpoint_standard #(.x_cord_width_p (x_cord_width_p)
                                    ,.y_cord_width_p(y_cord_width_p)
                                    ,.fifo_els_p    (proc_fifo_els_p)
                                    ,.data_width_p  (data_width_p)
                                    ,.addr_width_p  (addr_width_p)
                                    ,.max_out_credits_p(max_out_credits_p)
                                    ,.debug_p(debug_p)
//                                    ,.debug_p(1)
                                    ) endp
   (.clk_i
    ,.reset_i

    ,.link_sif_i
    ,.link_sif_o

    ,.in_v_o   (in_v_lo)
    ,.in_yumi_i(in_yumi_li)
    ,.in_data_o(in_data_lo)
    ,.in_mask_o(in_mask_lo)
    ,.in_addr_o(in_addr_lo)

    // we feed the endpoint with the data we want to send out
    // it will get inserted into the above link_sif

    ,.out_packet_i(out_packet_li )
    ,.out_v_i     (out_v_li    )
    ,.out_ready_o (out_ready_lo)

    ,.out_credits_o(out_credits_lo)

    ,.my_x_i
    ,.my_y_i
    ,.freeze_r_o(freeze_r)
    );

   logic [1:core_imem_portID_lp]                         core_mem_v;
   logic [1:core_imem_portID_lp]                         core_mem_w;

   // this is coming from the vscale core; which has 32-bit addresses
   logic [1:core_imem_portID_lp] [32-1:0]                core_mem_addr;
   logic [1:core_imem_portID_lp] [data_width_p-1:0]      core_mem_wdata;
   logic [1:core_imem_portID_lp] [(data_width_p>>3)-1:0] core_mem_mask;
   logic [1:core_imem_portID_lp]                         core_mem_yumi;
   logic [1:core_imem_portID_lp]                         core_mem_rv;
   logic [1:core_imem_portID_lp] [data_width_p-1:0]      core_mem_rdata;

   logic core_mem_reserve_1, core_mem_reservation_r;

   logic [addr_width_p-1:0]      core_mem_reserve_addr_r;

   // implement LR (load word reserved)
   always_ff @(posedge clk_i)
     begin
        // if we commit a reserved memory access
        // to the interface, then the reservation takes place
        if (core_mem_v & core_mem_reserve_1 & core_mem_yumi[1])
          begin
             // copy address; ignore byte bits
             core_mem_reservation_r  <= 1'b1;
             core_mem_reserve_addr_r <= core_mem_addr[1][2+:addr_width_p];
             // synopsys translate_off
             $display("## x,y = %d,%d enabling reservation on %x",my_x_i,my_y_i,core_mem_addr[1] << 2);
             // synopsys translate_on
          end
        else
          // otherwise, we clear existing reservations if the corresponding
          // address is committed as a remote store
          begin
             if (in_v_lo && (core_mem_reserve_addr_r == in_addr_lo) && in_yumi_li)
               begin
                  core_mem_reservation_r  <= 1'b0;
                  // synopsys translate_off
                  $display("## x,y = %d,%d clearing reservation on %x",my_x_i,my_y_i,core_mem_reserve_addr_r);
                  // synopsys translate_on
               end
          end
     end

   //   wire launching_remote_store = v_o[0] & ready_i[0];
   wire launching_out = out_v_li & out_ready_lo;

`ifndef bsg_VANILLA
   bsg_vscale_core #(.x_cord_width_p (x_cord_width_p)
                     ,.y_cord_width_p(y_cord_width_p)
                     )
            core
     ( .clk_i   (clk_i)
       ,.reset_i (reset_i)
       ,.freeze_i (freeze_r) // from register

       ,.m_v_o          (core_mem_v)
       ,.m_w_o          (core_mem_w)
       ,.m_addr_o       (core_mem_addr)
       ,.m_data_o       (core_mem_wdata)
       ,.m_reserve_1_o  (core_mem_reserve_1)
       ,.m_reservation_i(core_mem_reservation_r) // from register
       ,.m_mask_o       (core_mem_mask)

       // for data port (1), either the network or the banked memory can
       // deque the item.
       ,.m_yumi_i    ({(launching_out) | core_mem_yumi[1] // aka ~dmem_wait
                       , core_mem_yumi[0]})               // aka ~imem_wait
       ,.m_v_i       (core_mem_rv)    // unused by module
       ,.m_data_i    (core_mem_rdata) // to register

       // whether there are any outstanding remote stores
       ,.outstanding_stores_i(out_credits_lo != max_out_credits_p)    // from register

       ,.my_x_i (my_x_i)
       ,.my_y_i (my_y_i)
       );
`else
    //////////////////////////////////////////////////////
    //  The vanilla core version
   `ifdef bsg_FPU

       fpi_alu_inter fpi_alu();

       fpi riscv_fpi (
                .clk        (clk_i         )
               ,.reset      (reset_i       )
               ,.alu_inter  (fpi_alu       )
               ,.fam_in_s_o (fam_in_s_o    )
               ,.fam_out_s_i(fam_out_s_i   )
           );
   `endif
   //////////////////////////////////////////////////////////
   //
   wire  remote_store_imem_not_dmem =
          (in_v_lo
             & (~|in_addr_lo[addr_width_p-1:imem_addr_width_lp])
          );

   // Logic detecting the falling edge of freeze_r signal
   logic freeze_r_r;

   always_ff@( posedge clk_i)
   if( reset_i ) freeze_r_r <= 1'b0;
   else          freeze_r_r <= freeze_r;

   wire pkt_unfreeze = (freeze_r == 1'b0 ) && ( freeze_r_r == 1'b1);
   wire pkt_freeze   = (freeze_r == 1'b1 ) && ( freeze_r_r == 1'b0);

   // The memory and network interface
   ring_packet_s            core_net_pkt;
   mem_in_s                 core_to_mem;
   mem_out_s                mem_to_core;
   //////////////////////////////////////
   hobbit #
     ( .imem_addr_width_p(imem_addr_width_lp)
      ,.gw_ID_p          (0)
      ,.ring_ID_p        (0)
      ,.x_cord_width_p   (x_cord_width_p)
      ,.y_cord_width_p   (y_cord_width_p)
      ,.debug_p          (debug_p)
     ) vanilla_core
     ( .clk            (clk_i)
      ,.reset          (reset_i | pkt_freeze) // pkt_freeze pushes core to IDLE state

      ,.net_packet_i   (core_net_pkt)

      ,.from_mem_i     (mem_to_core)
      ,.to_mem_o       (core_to_mem)
      ,.reserve_1_o    (core_mem_reserve_1)
      ,.reservation_i  (core_mem_reservation_r)

`ifdef bsg_FPU
      ,.fpi_inter      (fpi_alu)
`endif

      ,.my_x_i
      ,.my_y_i
      ,.debug_o        ()
     );

   always_comb
   begin
     // remote stores to imem and initial pc value sent over vanilla core's network
     core_net_pkt.valid     = remote_store_imem_not_dmem | pkt_unfreeze;
     //Shaolin Xie: To supress the 'Undriven' warning.
     core_net_pkt.header.reserved  = 2'b0;

     core_net_pkt.header.bc       = 1'b0;
     core_net_pkt.header.external = 1'b0;
     core_net_pkt.header.gw_ID    = 3'(0);
     core_net_pkt.header.ring_ID  = 5'(0);
     if (remote_store_imem_not_dmem)
       begin // remote store to imem
         core_net_pkt.header.net_op = INSTR;
         core_net_pkt.header.mask   = in_mask_lo;
         // this address alread stripped the byte bits
         // We have to add them for compatibility
         core_net_pkt.header.addr   = {in_addr_lo[11:0], 2'b0};
       end
     else
       begin // initiates pc pushing core to RUN state
         core_net_pkt.header.net_op   = PC;
         core_net_pkt.header.mask     = (data_width_p>>3)'(0);
         core_net_pkt.header.addr     = 13'h200;
       end

    core_net_pkt.data   = remote_store_imem_not_dmem ? in_data_lo : 32'(0);
  end

  //convert the core_to_mem structure to signals.
  assign core_mem_v    [1] = core_to_mem.valid     ;
  assign core_mem_wdata[1] = core_to_mem.write_data;
  assign core_mem_addr [1] = core_to_mem.addr      ;
  assign core_mem_w    [1] = core_to_mem.wen       ;
  assign core_mem_mask [1] = core_to_mem.mask      ;
  //the core_to_mem yumi signal is not used.

  assign mem_to_core.valid      = core_mem_rv[1]   ;
  assign mem_to_core.read_data  = core_mem_rdata[1];
`endif

   wire out_request;

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
      ,.my_x_i (my_x_i)
      ,.my_y_i (my_y_i)
      // directly out to the network!
      ,.v_o    (out_request)
      ,.data_o (out_packet_li)
      );

   // we only request to send a remote store if it would not overflow the remote store credit counter
   assign out_v_li = out_request & (|out_credits_lo);

   // synopsys translate_off

   bsg_manycore_packet_s data_o_debug;
   assign data_o_debug = out_packet_li;

   if (debug_p)
   // you can use this format to log packets coming from a node
     always @(negedge clk_i)
       begin
          if (launching_out)
            $display("# y,x=(%x,%x) PROC sending packet (addr=%b, op=%b, op_ex=%b, data=%b, return_pkt=%b, y_cord=%b, x_cord=%b\n%b"
                     , my_y_i
                     , my_x_i
                     , data_o_debug.addr
                     , data_o_debug.op
                     , data_o_debug.op_ex
                     , data_o_debug.data
                     , data_o_debug.return_pkt
                     , data_o_debug.y_cord
                     , data_o_debug.x_cord
                     , out_packet_li
                     );
       end

   // synopsys translate_on

   wire [data_width_p-1:0] unused_data;
   wire                    unused_valid;

`ifdef bsg_VANILLA
   wire [1:0]              xbar_port_v_in = { core_mem_v[1] & ~core_mem_addr[1][31]
                                              , in_v_lo
                                              };

   // fixme: not quite right for banks=1
   localparam mem_width_lp    = $clog2(bank_size_p) + $clog2(num_banks_p);

   wire [1:0]                    xbar_port_we_in   = { core_mem_w[1], 1'b1};
   wire [1:0]                    xbar_port_yumi_out;
   wire [1:0] [data_width_p-1:0] xbar_port_data_in = { core_mem_wdata[1], in_data_lo};
   wire [1:0] [mem_width_lp-1:0] xbar_port_addr_in = { core_mem_addr[1][2+:mem_width_lp]
//                                                     remote stores already have bottom two bits snipped
                                                     , mem_width_lp ' ( in_addr_lo )
                                                     };
   wire [1:0] [(data_width_p>>3)-1:0] xbar_port_mask_in = { core_mem_mask[1], in_mask_lo};

`else
   // we create dedicated signals for these wires to allow easy access for "bind" statements
   wire [2:0]              xbar_port_v_in = {
                                              // request to write only if we are not sending a remote store packet
                                              // we check the high bit only for performance
                                               core_mem_v[1] & ~core_mem_addr[1][31]
                                              , in_v_lo
                                              , core_mem_v[0]
                                              };

   // fixme: not quite right for banks=1
   localparam mem_width_lp    = $clog2(bank_size_p) + $clog2(num_banks_p);

   // proc data port sometimes writes, the network port always writes, proc inst port never writes
   wire [2:0]                    xbar_port_we_in   = { core_mem_w[1], 1'b1, 1'b0};
   wire [2:0]                    xbar_port_yumi_out;
   wire [2:0] [data_width_p-1:0] xbar_port_data_in = { core_mem_wdata [1], in_data_lo, core_mem_wdata[0]};
   wire [2:0] [mem_width_lp-1:0] xbar_port_addr_in = {   core_mem_addr[1]  [2+:mem_width_lp]
//                                                       , in_addr [2+:mem_width_lp]
//                                                     remote stores already have bottom two bits snipped
                                                       , mem_width_lp ' ( in_addr_lo )
                                                       , core_mem_addr[0]  [2+:mem_width_lp]
                                                       };
   wire [2:0] [(data_width_p>>3)-1:0] xbar_port_mask_in = { core_mem_mask[1], in_mask_lo, core_mem_mask[0] };


   // synopsys translate_off
   always @(negedge clk_i)
     if (0)
     begin
       if (~freeze_r)
        if (|xbar_port_v_in)
          $display("x=%x y=%x xbar_v_i=%b xbar_w_i=%b xbar_port_yumi_out=%b xbar_addr_i[2,1,0]=%x,%x,%x, xbar_data_i[2,1,0]=%x,%x,%x, xbar_data_o[1,0]=%x,%x"
                   ,my_x_i
                   ,my_y_i
                   ,xbar_port_v_in
                   ,xbar_port_we_in
                   ,xbar_port_yumi_out
                   ,xbar_port_addr_in[2]*4,xbar_port_addr_in[1]*4,xbar_port_addr_in[0]*4
                   ,xbar_port_data_in[2], xbar_port_data_in[1], xbar_port_data_in[0]
                   ,core_mem_rdata[1], core_mem_rdata[0]
                   );
     end
   // synopsys translate_on
`endif
`ifdef bsg_VANILLA
   // the swizzle function changes how addresses are mapped to banks
   wire [1:0] [mem_width_lp-1:0] xbar_port_addr_in_swizzled;
   genvar                        i;

   for (i = 0; i < 2; i=i+1)
     begin: port
        assign xbar_port_addr_in_swizzled[i] = { xbar_port_addr_in  [i][(mem_width_lp-1)-:1]   // top bit is inst/data
                                                 , xbar_port_addr_in[i][0]                 // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][1]                 // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][2+:(mem_width_lp-2)]
                                                 };
     end

   // local mem yumi the data from the core
   assign  core_mem_yumi[1]    = xbar_port_yumi_out[1];
   // local mem yumi the data from the network
   assign in_yumi_li   = xbar_port_yumi_out[0] | remote_store_imem_not_dmem;

   //the local memory or network can consume the store data
   assign mem_to_core.yumi  = (xbar_port_yumi_out[1] | launching_out);

`else
   // the swizzle function changes how addresses are mapped to banks
   wire [2:0] [mem_width_lp-1:0] xbar_port_addr_in_swizzled;
   genvar                        i;

   for (i = 0; i < 3; i=i+1)
     begin: port
        assign xbar_port_addr_in_swizzled[i] = { xbar_port_addr_in  [i][(mem_width_lp-1)-:1]   // top bit is inst/data
                                                 , xbar_port_addr_in[i][0]                 // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][1]                 // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][2+:(mem_width_lp-2)]
                                                 };

     end

   assign { core_mem_yumi[1], in_yumi_li, core_mem_yumi[0] } = xbar_port_yumi_out;

`endif
   // potentially, we could get better bandwidth if we demultiplexed the remote store input port
   // into four two-element fifos, one per bank. then, the arb could arbitrate for
   // each bank using those fifos. this allows for reordering of remote_stores across
   // banks, eliminating head-of-line blocking on a bank conflict. however, this would eliminate our
   // guaranteed in-order delivery and violate sequential consistency; so it would require some
   // extra hw to enforce that; and tagging of memory fences inside packets.
   // we could most likely get rid of the cgni input fifo in this case.

  bsg_mem_banked_crossbar #
`ifdef bsg_VANILLA
    (.num_ports_p  (2)
`else
    (.num_ports_p  (3)
`endif
     ,.num_banks_p  (num_banks_p)
     ,.bank_size_p  (bank_size_p)
     ,.data_width_p (data_width_p)
//     ,.rr_lo_hi_p   (2'b10) // round robin
//     ,.rr_lo_hi_p   (2'b01) // deadlock
     ,.rr_lo_hi_p(0)          // local dmem has priority
//     ,.debug_p(debug_p*4)  // mbt: debug, multiply addresses by 4.
     ,.debug_p(0*4)  // mbt: debug, multiply addresses by 4.
//      ,.debug_p(4)
//     ,.debug_reads_p(0)
    ) banked_crossbar
    ( .clk_i    (clk_i)
     ,.reset_i  (reset_i)
      ,.v_i     (xbar_port_v_in)

      ,.w_i     (xbar_port_we_in)
      ,.addr_i  (xbar_port_addr_in_swizzled)
      ,.data_i  (xbar_port_data_in)
      ,.mask_i  (xbar_port_mask_in)

      // whether the crossbar accepts the input
     ,.yumi_o  ( xbar_port_yumi_out                                     )
`ifdef bsg_VANILLA
     ,.v_o     ({ core_mem_rv    [1], unused_valid})
     ,.data_o  ({ core_mem_rdata [1], unused_data })
`else
     ,.v_o     ({ core_mem_rv    [1], unused_valid, core_mem_rv    [0] })
     ,.data_o  ({ core_mem_rdata [1], unused_data,  core_mem_rdata [0] })
`endif
    );
endmodule
