`include "bsg_manycore_packet.vh"
`include "definitions.v"

`ifdef bsg_FPU
 `include "float_definitions.v"
`endif
module bsg_manycore_proc #(x_cord_width_p   = "inv"
                           , y_cord_width_p = "inv"
                           , data_width_p   = 32
                           , addr_width_p   = 32
                           , packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

                           , debug_p           = 0

                           , bank_size_p        = "inv" // dmem size in words
                           , num_banks_p        = "inv"
                           , imem_size_p        = 4*bank_size_p // in words
                           , imem_addr_width_lp = $clog2(imem_size_p)
                           , mem_width_lp = $clog2(bank_size_p) + $clog2(num_banks_p)

                           // this is the size of the receive FIFO
                           , proc_fifo_els_p = 4
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
    , input   [x_cord_width_p-1:0] my_x_i
    , input   [y_cord_width_p-1:0] my_y_i

`ifdef bsg_FPU
    , input  f_fam_out_s           fam_out_s_i 
    , output f_fam_in_s            fam_in_s_o 
`endif

    , output logic freeze_o
    );

`ifdef bsg_FPU
    //Instantiate the ALU/FPU interface
    fpi_alu_inter fpi_alu();
 
`endif


  // synopsys translate off
  initial
    assert((imem_size_p & imem_size_p-1) == 0)
      else $error("imem_size_p must be a power of 2");
  // synopsys translate on

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
   logic                         pkt_freeze, pkt_unfreeze, pkt_remote_store, pkt_unknown;
   logic [data_width_p-1:0]      remote_store_data;
   logic [(data_width_p>>3)-1:0] remote_store_mask;
   logic [addr_width_p-1:0]      remote_store_addr;
   logic                         remote_store_v, remote_store_yumi;
   logic                         remote_store_imem_not_dmem;

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
      ,.mask_o             (remote_store_mask)
      );
   
   assign remote_store_imem_not_dmem = (remote_store_v 
                                        & (~|remote_store_addr[addr_width_p-1:(imem_addr_width_lp+2)])
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
   
   // vanilla core signals
   ring_packet_s            core_net_pkt;
   mem_in_s                 core_to_mem;
   mem_out_s                mem_to_core;
   logic                    core_mem_reservation_r;
   logic [addr_width_p-1:0] core_mem_reserve_addr_r;

   // implement LR (load word reserved)
   always_ff @(posedge clk_i)
     begin
        // if we commit a reserved memory access
        // to the interface, then the reservation takes place
        if (core_to_mem.valid & core_mem_reserve_1 & mem_to_core.yumi)
          begin
             // copy address
             core_mem_reservation_r  <= 1'b1;
             core_mem_reserve_addr_r <= core_to_mem.addr;
	     $display("## x,y = %d,%d enabling reservation on %x",my_x_i,my_y_i,core_to_mem.addr);
          end
        else
          // otherwise, we clear existing reservations if the corresponding
          // address is committed as a remote store
          begin
             if (remote_store_v && (core_mem_reserve_addr_r == remote_store_addr) && remote_store_yumi)
	       begin
		  core_mem_reservation_r  <= 1'b0;
		  $display("## x,y = %d,%d clearing reservation on %x",my_x_i,my_y_i,core_mem_reserve_addr_r);
	       end
          end
     end

///////////////////////////////////////////////////////////////
//
// Instantiate the FPI instatnce.
//
`ifdef bsg_FPU

    fpi riscv_fpi
        (
             .clk        (clk_i         )
            ,.reset      (reset_i       )
            ,.alu_inter  (fpi_alu       )
            ,.fam_in_s_o (fam_in_s_o    )
            ,.fam_out_s_i(fam_out_s_i   )
        );
`endif

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
     
      ,.my_x_i         (my_x_i)
      ,.my_y_i         (my_y_i)
      ,.debug_o        () 
     );
   
   always_comb
   begin
     // remote stores to imem and initial pc value sent over vanilla core's network
     core_net_pkt.valid  = remote_store_imem_not_dmem | pkt_unfreeze;
     
     core_net_pkt.header.bc       = 1'b0;
     core_net_pkt.header.external = 1'b0;
     core_net_pkt.header.gw_ID    = 3'(0);
     core_net_pkt.header.ring_ID  = 5'(0);
     if (remote_store_imem_not_dmem)
       begin // remote store to imem
         core_net_pkt.header.net_op = INSTR;
         core_net_pkt.header.mask   = remote_store_mask;
         core_net_pkt.header.addr   = remote_store_addr[13:0];
       end
     else
       begin // initiates pc pushing core to RUN state
         core_net_pkt.header.net_op   = PC;
         core_net_pkt.header.mask     = (data_width_p>>3)'(0);
         core_net_pkt.header.addr     = 13'h200;
       end

    core_net_pkt.data   = remote_store_imem_not_dmem ? remote_store_data : 32'(0);
  end

   bsg_manycore_pkt_encode #(.x_cord_width_p (x_cord_width_p)
                             ,.y_cord_width_p(y_cord_width_p)
                             ,.data_width_p (data_width_p )
                             ,.addr_width_p (addr_width_p )
                             ) pkt_encode
     (.clk_i(clk_i)

      // the memory request, from the core's data memory port
      ,.v_i    (core_to_mem.valid)
      ,.data_i (core_to_mem.write_data)
      ,.addr_i (core_to_mem.addr)
      ,.we_i   (core_to_mem.wen)
      ,.mask_i (core_to_mem.mask)

      // directly out to the network!
      ,.v_o    (v_o   )
      ,.data_o (data_o)
      );

   // synopsys translate off
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

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
                     , core_to_mem.mask
                     , core_to_mem.write_data
                     , core_to_mem.addr
                     );
       end
   // synopsys translate on

   wire [data_width_p-1:0] unused_data;
   wire                    unused_valid;

   // we create dedicated signals for these wires to allow easy access for "bind" statements
   wire [1:0]              xbar_port_v_in = { core_to_mem.valid & ~core_to_mem.addr[31]
                                             ,remote_store_v & (|remote_store_addr[addr_width_p-1:(2+imem_addr_width_lp)])
                                            };

   // proc data port sometimes writes, the network port always writes, proc inst port never writes
   wire [1:0]                          xbar_port_we_in   = { core_to_mem.wen, 1'b1};
   wire [1:0]                          xbar_port_yumi_out;
   wire [1:0] [data_width_p-1:0]       xbar_port_data_in = { core_to_mem.write_data, remote_store_data};
   wire [1:0] [mem_width_lp-1:0] xbar_port_addr_in = { core_to_mem.addr  [2+:mem_width_lp]
                                                            ,remote_store_addr [2+:mem_width_lp]
                                                           };
   wire [1:0] [(data_width_p>>3)-1:0] xbar_port_mask_in = {core_to_mem.mask, remote_store_mask};

   always @(negedge clk_i)
     if (0)
     begin
        if (~freeze_r)
          $display("x=%x y=%x xbar_v_i=%b xbar_w_i=%b xbar_port_yumi_out=%b xbar_addr_i[1,0]=%x,%x, xbar_data_i[1,0]=%x,%x, xbar_mask_i[1,0]:%b,%b xbar_data_o=%x"
                   ,my_x_i
                   ,my_y_i
                   ,xbar_port_v_in
                   ,xbar_port_we_in
                   ,xbar_port_yumi_out
                   ,xbar_port_addr_in[1]*4,xbar_port_addr_in[0]*4
                   ,xbar_port_data_in[1], xbar_port_data_in[0]
                   ,xbar_port_mask_in[1], xbar_port_mask_in[0]
                   ,mem_to_core.read_data
                   );
     end

   // the swizzle function changes how addresses are mapped to banks
   wire [1:0] [mem_width_lp-1:0] xbar_port_addr_in_swizzled;

   genvar                        i;

   for (i = 0; i < 2; i=i+1)
     begin: port
//      assign xbar_port_addr_in_swizzled[i] = { xbar_port_addr_in[i] };

        assign xbar_port_addr_in_swizzled[i] = { xbar_port_addr_in  [i][(mem_width_lp-1)-:1]   // top bit is inst/data
                                                 , xbar_port_addr_in[i][0]                 // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][1]                 // and lowest bit determines bank						 
                                                 , xbar_port_addr_in[i][2+:(mem_width_lp-2)]
                                                 };

     end

   assign mem_to_core.yumi  = (xbar_port_yumi_out[1] | (v_o & ready_i));
   assign remote_store_yumi = (xbar_port_yumi_out[0] | remote_store_imem_not_dmem);

   // potentially, we could get better bandwidth if we demultiplexed the remote store input port
   // into four two-element fifos, one per bank. then, the arb could arbitrate for
   // each bank using those fifos. this allows for reordering of remote_stores across
   // banks, eliminating head-of-line blocking on a bank conflict. however, this would eliminate our
   // guaranteed in-order delivery and violate sequential consistency; so it would require some
   // extra hw to enforce that; and tagging of memory fences inside packets.
   // we could most likely get rid of the cgni input fifo in this case.
   
  bsg_mem_banked_crossbar #
    (.num_ports_p  (2)
     ,.num_banks_p  (num_banks_p)
     ,.bank_size_p  (bank_size_p)
     ,.data_width_p (data_width_p)
//     ,.rr_lo_hi_p   (2'b10) // round robin
//     ,.rr_lo_hi_p   (2'b01) // deadlock
     ,.rr_lo_hi_p(0)          // local dmem has priority
     ,.debug_p(debug_p*4)  // mbt: debug, multiply addresses by 4.
//      ,.debug_p(4)
//     ,.debug_reads_p(0)
    ) banked_crossbar
    ( .clk_i   (clk_i)
     ,.reset_i (reset_i)
      ,.v_i    (xbar_port_v_in)

      ,.w_i     (xbar_port_we_in)
      ,.addr_i  (xbar_port_addr_in_swizzled)
      ,.data_i  (xbar_port_data_in)
      ,.mask_i  (xbar_port_mask_in)

      // whether the crossbar accepts the input
     ,.yumi_o  ( xbar_port_yumi_out                                     )
     ,.v_o     ({mem_to_core.valid, unused_valid})
     ,.data_o  ({mem_to_core.read_data, unused_data})
    );




endmodule
