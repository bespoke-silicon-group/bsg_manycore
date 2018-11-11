`include "bsg_manycore_packet.vh"
`include "definitions.v"

`ifdef bsg_FPU
 `include "float_definitions.v"
`endif

module bsg_manycore_proc_vanilla #(x_cord_width_p   = "inv"
                           , y_cord_width_p = "inv"
                           , data_width_p   = 32
                           , addr_width_p   = -1
                           , epa_addr_width_p = -1 
                           , dram_ch_addr_width_p = -1
                           , dram_ch_start_col_p = 0
                           , debug_p        = 0
                           , bank_size_p    = -1// in words
                           , num_banks_p    = "inv"

                           , icache_tag_width_p = -1
                           , imem_size_p        = bank_size_p // in words
                           , imem_addr_width_lp = $clog2(imem_size_p)
                           // this credit counter is more for memory fences
                           // than containing the number of outstanding remote stores

                           //, max_out_credits_p = (1<<13)-1  // 13 bit counter
                           , max_out_credits_p = 200  // 13 bit counter

                           // this is the size of the receive FIFO
                           , proc_fifo_els_p = 4
                           , num_nets_lp     = 2

                           , hetero_type_p   = 0
                           //do we run immediately after reset?
                           , freeze_init_p  = 1'b1

                           , packet_width_lp                = `bsg_manycore_packet_width       (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                           , return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p, data_width_p)
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

     // FPU interface
`ifdef bsg_FPU
    , input  f_fam_out_s           fam_out_s_i
    , output f_fam_in_s            fam_in_s_o
`endif

    , output logic freeze_o
    );

   logic freeze_r;
   assign freeze_o = freeze_r;

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s              out_packet_li;
   logic                              out_v_li;
   logic                              out_ready_lo;

   logic [data_width_p-1:0]           returned_data_r_lo  ;
   logic [addr_width_p-1:0]           returned_addr_r_lo  ;
   logic                              returned_v_r_lo     ;

   logic [data_width_p-1:0]           load_returning_data, store_returning_data_r, returning_data;
   logic                              load_returning_v, store_returning_v_r, returning_v;

   logic                         in_we_lo  ;
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
    ,.in_we_o  (in_we_lo  )

    // we feed the endpoint with the data we want to send out
    // it will get inserted into the above link_sif

    ,.out_packet_i(out_packet_li )
    ,.out_v_i     (out_v_li    )
    ,.out_ready_o (out_ready_lo)

    ,.returned_data_r_o ( returned_data_r_lo )
    ,.returned_addr_r_o ( returned_addr_r_lo )
    ,.returned_v_r_o    ( returned_v_r_lo    )

    ,.returning_data_i ( returning_data )
    ,.returning_v_i    ( returning_v    )

    ,.out_credits_o(out_credits_lo)

    ,.my_x_i
    ,.my_y_i
    //,.freeze_r_o(freeze_r)
    //,.reverse_arb_pr_o( reverse_arb_pr )
    );

   logic core_mem_v;
   logic core_mem_w;

   logic [32-1:0]                core_mem_addr;
   logic [data_width_p-1:0]      core_mem_wdata;
   logic [(data_width_p>>3)-1:0] core_mem_mask;
   logic                         core_mem_yumi;
   logic                         core_mem_rv;
   logic [data_width_p-1:0]      core_mem_rdata;

   logic core_mem_reserve_1, core_mem_reservation_r;

   logic [addr_width_p-1:0]      core_mem_reserve_addr_r;

   // implement LR (load word reserved)
   // synopsys sync_set_reset "core_mem_v, core_mem_reserve_1, core_mem_yumi, in_v_lo, core_mem_reserve_addr_r, in_addr_lo, in_yumi_li"
   always_ff @(posedge clk_i)
     begin
        // if we commit a reserved memory access
        // to the interface, then the reservation takes place
        if (core_mem_v & core_mem_reserve_1 & core_mem_yumi)
          begin
             // copy address; ignore byte bits
             core_mem_reservation_r  <= 1'b1;
             core_mem_reserve_addr_r <= core_mem_addr[2+:(addr_width_p-2)];
             // synopsys translate_off
             $display("## x,y = %d,%d enabling reservation on %x",my_x_i,my_y_i,core_mem_addr);
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
                  $display("## x,y = %d,%d clearing reservation on %x",my_x_i,my_y_i,core_mem_reserve_addr_r << 2);
                  // synopsys translate_on
               end
          end
     end

   wire launching_out = out_v_li & out_ready_lo;

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
   wire is_config_op      = in_v_lo & in_addr_lo[epa_addr_width_p-1] & in_we_lo;
   wire non_imem_bits_set = | in_addr_lo[addr_width_p-1:imem_addr_width_lp];

   wire remote_store_imem_not_dmem = in_v_lo & ~non_imem_bits_set;
   wire remote_access_dmem_not_imem = in_v_lo & non_imem_bits_set & (~is_config_op);

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
     (
       .icache_tag_width_p (icache_tag_width_p) 
      ,.icache_addr_width_p(imem_addr_width_lp)
      ,.gw_ID_p          (0)
      ,.ring_ID_p        (0)
      ,.x_cord_width_p   (x_cord_width_p)
      ,.y_cord_width_p   (y_cord_width_p)
//      ,.debug_p          (debug_p)
//,.debug_p(1)
     ) vanilla_core
     ( .clk_i          (clk_i)
      ,.reset_i        (reset_i | pkt_freeze) // pkt_freeze pushes core to IDLE state

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
      ,.outstanding_stores_i(out_credits_lo != max_out_credits_p)    // from register
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
         //1.  We don't support exceptions, and we don't want to waste the
         //    instruction memory so the starting address of the first instruction
         //    is ZERO
         core_net_pkt.header.addr     = 13'h0;
       end

    core_net_pkt.data   = remote_store_imem_not_dmem ? in_data_lo : 32'(0);
  end

  //convert the core_to_mem structure to signals.
  assign core_mem_v        = core_to_mem.valid     ;
  assign core_mem_wdata    = core_to_mem.write_data;
  assign core_mem_addr     = core_to_mem.addr      ;
  assign core_mem_w        = core_to_mem.wen       ;
  assign core_mem_mask     = core_to_mem.mask      ;
  //the core_to_mem yumi signal is not used.

  //The data can either from local memory or from the network.
  assign mem_to_core.valid           = core_mem_rv | returned_v_r_lo  ;
  assign mem_to_core.info.read_data  = core_mem_rv ? core_mem_rdata
                                                   : returned_data_r_lo ;

  localparam addr_fill_lp = 32 - 2 - addr_width_p;
  assign mem_to_core.info.returned_addr = { {addr_fill_lp{1'b0}}, returned_addr_r_lo, 2'b0} ;

   wire out_request;

   bsg_manycore_pkt_encode #(.x_cord_width_p (x_cord_width_p)
                             ,.y_cord_width_p(y_cord_width_p)
                             ,.data_width_p (data_width_p )
                             ,.addr_width_p (addr_width_p )
                             ,.epa_addr_width_p( epa_addr_width_p)
                             ,.dram_ch_addr_width_p ( dram_ch_addr_width_p)
                             ,.dram_ch_start_col_p  ( dram_ch_start_col_p )
                             ,.remote_addr_prefix_p( 2'b01  )
                             ) pkt_encode
     (.clk_i(clk_i)

      // the memory request, from the core's data memory port
      ,.v_i    (core_mem_v    )
      ,.data_i (core_mem_wdata)
      ,.addr_i (core_mem_addr )
      ,.we_i   (core_mem_w    )
      ,.swap_aq_i ( core_to_mem.swap_aq )
      ,.swap_rl_i ( core_to_mem.swap_rl )
      ,.mask_i (core_mem_mask )
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

   wire local_epa_request = core_mem_v & (~ out_request);// not a remote packet
   wire [1:0]              xbar_port_v_in = { local_epa_request ,  remote_access_dmem_not_imem};

   localparam mem_width_lp    = $clog2(bank_size_p) + $clog2(num_banks_p);

   wire [1:0]                    xbar_port_we_in   = { core_mem_w, in_we_lo};
   wire [1:0]                    xbar_port_yumi_out;
   wire [1:0] [data_width_p-1:0] xbar_port_data_in = { core_mem_wdata, in_data_lo};

   // synopsys translate_off

   always @(negedge clk_i)
     begin
        if (remote_access_dmem_not_imem)
          assert (in_addr_lo < ((1 << imem_addr_width_lp) + (bank_size_p*num_banks_p)))
            else
              begin
                 $error("# ERROR y,x=(%x,%x) remote access addr (%x) past end of data memory (%x)"
                        ,my_y_i,my_x_i,in_addr_lo*4,4*((1 << imem_addr_width_lp)+(bank_size_p*num_banks_p)));
                 $finish();
              end
     end

   //initial
   //   $display("imem_addr_width_lp %d, bank_size_p %d, num_banks_p %d\n",imem_addr_width_lp,bank_size_p,num_banks_p);

   always @(negedge clk_i)
     begin
        if (xbar_port_v_in[1])
          assert (core_mem_addr[30:2] < ((1 << imem_addr_width_lp) + (bank_size_p*num_banks_p)))
            else
              begin
                 $error("# ERROR y,x=(%x,%x) local store addr (%x) past end of data memory (%x)"
                        ,my_y_i,my_x_i,core_mem_addr,4*((1 << imem_addr_width_lp)+(bank_size_p*num_banks_p)));
                 $finish();
              end
     end

   // synopsys translate_on

   wire [1:0] [mem_width_lp-1:0] xbar_port_addr_in = { core_mem_addr[2+:mem_width_lp]
//                                                     remote stores already have bottom two bits snipped
                                                     , mem_width_lp ' ( in_addr_lo )
                                                     };
   wire [1:0] [(data_width_p>>3)-1:0] xbar_port_mask_in = { core_mem_mask, in_mask_lo};

   // the swizzle function changes how addresses are mapped to banks
   wire [1:0] [mem_width_lp-1:0] xbar_port_addr_in_swizzled;
   genvar                        i;

   for (i = 0; i < 2; i=i+1)
     begin: port
        assign xbar_port_addr_in_swizzled[i] = { xbar_port_addr_in[i]

/*                                                   xbar_port_addr_in[i][0]                     // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][1]                     // and lowest bit determines bank
                                                 , xbar_port_addr_in[i][mem_width_lp-1:2]
*/
                                                  };
     end

   // local mem yumi the data from the core
   assign   core_mem_yumi   = xbar_port_yumi_out[1];
   // local mem yumi the data from the network
   assign   in_yumi_li      = xbar_port_yumi_out[0] | remote_store_imem_not_dmem | is_config_op ;

   //the local memory or network can consume the store data
   assign mem_to_core.yumi  = (xbar_port_yumi_out[1] | launching_out);

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
     ,.rr_lo_hi_p   ( 5 ) // dynmaic priority based on FIFO status
//     ,.rr_lo_hi_p   ( 4 ) // round robin reset
//     ,.rr_lo_hi_p   (2'b10) // round robin
//     ,.rr_lo_hi_p   (2'b01) // deadlock
//     ,.rr_lo_hi_p(0)          // local dmem has priority
//     ,.debug_p(debug_p*4)  // mbt: debug, multiply addresses by 4.
//     ,.debug_p(0*4)  // mbt: debug, multiply addresses by 4.
//      ,.debug_p(4)
//     ,.debug_reads_p(0)
    ) bnkd_xbar
    ( .clk_i    (clk_i)
     ,.reset_i  (reset_i)
//    SHX: DEPRECATED FUNCTION
//    the reverse the priority for the dynamic scheme
//      ,.reverse_pr_i( reverse_arb_pr  )
      ,.reverse_pr_i( 1'b0)
      ,.v_i     (xbar_port_v_in)

      ,.w_i     (xbar_port_we_in)
      ,.addr_i  (xbar_port_addr_in_swizzled)
      ,.data_i  (xbar_port_data_in)
      ,.mask_i  (xbar_port_mask_in)

      // whether the crossbar accepts the input
     ,.yumi_o  ( xbar_port_yumi_out                    )
     ,.v_o     ({ core_mem_rv    , load_returning_v}   )
     ,.data_o  ({ core_mem_rdata , load_returning_data})
    );


   // ----------------------------------------------------------------------------------------
   // Handle the control registers
   // ----------------------------------------------------------------------------------------

   wire  is_freeze_addr = {1'b0, in_addr_lo[epa_addr_width_p-2:0]} == epa_addr_width_p'(0);

   wire  freeze_op     = is_config_op & is_freeze_addr & in_data_lo[0] ;
   wire  unfreeze_op   = is_config_op & is_freeze_addr & (~in_data_lo[0]);

   always_ff @(posedge clk_i)
     if (reset_i) freeze_r <= freeze_init_p;
     else if (freeze_op | unfreeze_op) begin
            // synopsys translate_off
            $display("## freeze_r <= %x (%m)",pkt_freeze);
            // synopsys translate_on
            freeze_r <= pkt_freeze;
     end
   
  // synopsys translate_off
  always_ff@(negedge clk_i)
        if ( is_config_op  & (~is_freeze_addr )) begin
                $error(" Wrong Tile Configuation Address = %h", in_addr_lo );
                $finish();
        end

   // synopsys translate_on
   // ----------------------------------------------------------------------------------------
   // Handle the returning data/credit back to the network
   // ----------------------------------------------------------------------------------------
   wire         store_yumi      = in_yumi_li & in_we_lo;
   //delay the response for store for 1 cycle
   always_ff@(posedge clk_i)    store_returning_v_r   <= store_yumi;
   always_ff@(posedge clk_i)    store_returning_data_r<= in_data_lo;

   assign       returning_v     = load_returning_v | store_returning_v_r;
   assign       returning_data  = store_returning_v_r? store_returning_data_r : load_returning_data;

  // synopsys translate_off
  always_ff@(negedge clk_i)
        if ( (store_returning_v_r & load_returning_v) == 1'b1 ) begin
                $error(" Store returning and Load returning happens at the same time!" );
                $finish();
        end
  // synopsys translate_on
endmodule
