`include "bsg_manycore_packet.vh"
`include "definitions.vh"

`ifdef bsg_FPU
 `include "float_definitions.vh"
`endif

module bsg_manycore_proc_vanilla #(x_cord_width_p   = "inv"
                           , y_cord_width_p = "inv"
                           , data_width_p   = 32
                           , addr_width_p   = -1
                           , load_id_width_p = 5
                           , epa_byte_addr_width_p = -1 
                           , dram_ch_addr_width_p = -1
                           , dram_ch_start_col_p = 0
                           , debug_p        = 1

                           , icache_tag_width_p   = -1
                           , icache_entries_p     = 1024 // in words
                           , dmem_size_p          = 1024 // in words
                           , icache_addr_width_lp = $clog2(icache_entries_p)
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

                           , packet_width_lp                = `bsg_manycore_packet_width       (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
                           , return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p, data_width_p,load_id_width_p)
                           , bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width     (addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
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

   //-------------------------------------------------------------------------
   //  The CSR  Regsiter Declare
   logic                                CSR_FREEZE_r;
   logic [x_cord_width_p-1:0]           CSR_TGO_X_r;
   logic [y_cord_width_p-1:0]           CSR_TGO_Y_r;


   assign freeze_o = CSR_FREEZE_r;

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);

   bsg_manycore_packet_s out_packet_li;
   logic                 out_v_li;
   logic                 out_ready_lo;

   logic [load_id_width_p-1:0] returned_load_id_r_lo;
   logic [data_width_p-1:0]    returned_data_r_lo  ;
   logic [addr_width_p-1:0]    returned_addr_r_lo  ;
   logic                       returned_v_r_lo     ;
   logic                       returned_fifo_full_lo;
   logic                       returned_yumi_li;

   logic [data_width_p-1:0] load_returning_data, delayed_returning_data_r, returning_data;
   logic                    load_returning_v, delayed_returning_v_r, returning_v;

   logic                                   in_we_lo  ;
   logic [data_width_p-1:0]                in_data_lo;
   logic [(data_width_p>>3)-1:0]           in_mask_lo;
   logic [addr_width_p-1:0]                in_addr_lo;
   logic                                   in_v_lo, in_yumi_li;
   logic [$clog2(max_out_credits_p+1)-1:0] out_credits_lo;

   bsg_manycore_endpoint_standard #(.x_cord_width_p      (x_cord_width_p)
                                    ,.y_cord_width_p     (y_cord_width_p)
                                    ,.fifo_els_p         (proc_fifo_els_p)
                                    ,.returned_fifo_p    (1)
                                    ,.data_width_p       (data_width_p)
                                    ,.addr_width_p       (addr_width_p)
                                    ,.load_id_width_p    (load_id_width_p)
                                    ,.max_out_credits_p  (max_out_credits_p)
                                    ,.debug_p            (debug_p)
//                                    ,.debug_p(1)
                                    ) endp
   (.clk_i
    ,.reset_i

    ,.link_sif_i
    ,.link_sif_o

    ,.in_v_o         (in_v_lo)
    ,.in_yumi_i      (in_yumi_li)
    ,.in_data_o      (in_data_lo)
    ,.in_mask_o      (in_mask_lo)
    ,.in_addr_o      (in_addr_lo)
    ,.in_we_o        (in_we_lo  )
    ,.in_src_x_cord_o()
    ,.in_src_y_cord_o()

    // we feed the endpoint with the data we want to send out
    // it will get inserted into the above link_sif

    ,.out_packet_i(out_packet_li )
    ,.out_v_i     (out_v_li    )
    ,.out_ready_o (out_ready_lo)

    ,.returned_data_r_o    (returned_data_r_lo )
    ,.returned_load_id_r_o (returned_load_id_r_lo)
    ,.returned_v_r_o       (returned_v_r_lo    )
    ,.returned_fifo_full_o (returned_fifo_full_lo)
    ,.returned_yumi_i      (returned_yumi_li)

    ,.returning_data_i ( returning_data )
    ,.returning_v_i    ( returning_v    )

    ,.out_credits_o(out_credits_lo)

    ,.my_x_i
    ,.my_y_i
    //,.CSR_FREEZE_r_o(CSR_FREEZE_r)
    //,.reverse_arb_pr_o( reverse_arb_pr )
    );

   // register to hold to IDs of local loads
   logic [load_id_width_p-1:0] local_load_id_r;

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

   // configuration  in_addr_lo = { 1 ------ } 2'b00
   localparam  epa_word_addr_width_lp = epa_byte_addr_width_p-2;

   wire is_config_op      = in_v_lo & in_addr_lo[epa_word_addr_width_lp-1] ;
   wire is_dmem_addr      = `MC_IS_DMEM_ADDR(in_addr_lo, addr_width_p);
   wire is_icache_addr    = `MC_IS_ICACHE_ADDR(in_addr_lo, addr_width_p);

   wire remote_store_icache = in_v_lo & is_icache_addr;
   wire remote_access_dmem  = in_v_lo & is_dmem_addr;
   wire remote_invalid_addr = in_v_lo & ( ~( is_dmem_addr | is_icache_addr | is_config_op ) );

   // Logic detecting the falling edge of CSR_FREEZE_r signal
   logic CSR_FREEZE_r_r;

   always_ff@( posedge clk_i)
   if( reset_i ) CSR_FREEZE_r_r <= 1'b0;
   else          CSR_FREEZE_r_r <= CSR_FREEZE_r;

   wire pkt_unfreeze = (CSR_FREEZE_r == 1'b0 ) && ( CSR_FREEZE_r_r == 1'b1);
   wire pkt_freeze   = (CSR_FREEZE_r == 1'b1 ) && ( CSR_FREEZE_r_r == 1'b0);

   // The memory and network interface
   ring_packet_s            core_net_pkt;
   mem_in_s                 core_to_mem;
   mem_out_s                mem_to_core;
   //////////////////////////////////////
   hobbit #
     (
       .icache_tag_width_p (icache_tag_width_p) 
      ,.icache_addr_width_p(icache_addr_width_lp)
      ,.gw_ID_p            (0)
      ,.ring_ID_p          (0)
      ,.x_cord_width_p     (x_cord_width_p)
      ,.y_cord_width_p     (y_cord_width_p)
      ,.debug_p            (0)
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
     core_net_pkt.valid     = remote_store_icache | pkt_unfreeze;
     //Shaolin Xie: To supress the 'Undriven' warning.
     core_net_pkt.header.reserved  = 2'b0;

     core_net_pkt.header.bc       = 1'b0;
     core_net_pkt.header.external = 1'b0;
     core_net_pkt.header.gw_ID    = 3'(0);
     core_net_pkt.header.ring_ID  = 5'(0);
     if (remote_store_icache)
       begin // remote store to imem
         core_net_pkt.header.net_op = INSTR;
         core_net_pkt.header.mask   = in_mask_lo;
         // this address alread stripped the byte bits
         // We have to add them for compatibility
         core_net_pkt.header.addr   = {in_addr_lo, 2'b0};
       end
     else
       begin // initiates pc pushing core to RUN state
         core_net_pkt.header.net_op   = PC;
         core_net_pkt.header.mask     = (data_width_p>>3)'(0);
         //1.  We don't support exceptions, and we don't want to waste the
         //    instruction memory so the starting address of the first instruction
         //    is ZERO
         core_net_pkt.header.addr     = 'b0;
       end

    core_net_pkt.data   = remote_store_icache? in_data_lo : 32'(0);
  end

  //convert the core_to_mem structure to signals.
  assign core_mem_v        = core_to_mem.valid     ;
  assign core_mem_wdata    = core_to_mem.payload   ;
  assign core_mem_addr     = core_to_mem.addr      ;
  assign core_mem_w        = core_to_mem.wen       ;
  assign core_mem_mask     = core_to_mem.mask      ;


  //+-----------------------------------------------------
  //|Returned data arbitration between the local memory 
  //|and the network.
  //+-----------------------------------------------------

  // Returned buffer signals
  logic                       returned_buf_v;
  logic [data_width_p-1:0]    returned_data_buf;
  logic [load_id_width_p-1:0] returned_load_id_buf;

  // Buffer full signal to the core. Core immediately yummies 
  // when this signal is high.
  logic buf_full_to_core;
  assign buf_full_to_core = (returned_fifo_full_lo | returned_buf_v);

  // Yumi to the network and not local memory
  logic yumi_to_network;
  assign yumi_to_network = core_to_mem.yumi & ~core_mem_rv;

  logic buffer_returned_data;
  assign buffer_returned_data = returned_fifo_full_lo & (core_mem_rv | returned_buf_v);

  // Yumi to returned fifo
  assign returned_yumi_li = buffer_returned_data 
                              | (yumi_to_network & ~returned_buf_v);
                                                            
  // Returned data buffer
  always_ff @(posedge clk_i)                                  
  begin                                                     
    if(reset_i) begin                                       
      returned_buf_v       <= 1'b0;
      returned_data_buf    <= data_width_p'(0);
      returned_load_id_buf <= load_id_width_p'(0);
    end else begin
      // Buffer the data when returned fifo is full and local mem
      // or returend data is valid as they have higher priority. 
      // One level of buffering is sufficient because core will not
      // issue new local requests when buf_full_to_core is asserted.
      if(buffer_returned_data) begin
        returned_buf_v       <= 1'b1;
        returned_data_buf    <= returned_data_r_lo;
        returned_load_id_buf <= returned_load_id_r_lo;
      end else if (yumi_to_network) begin
        returned_buf_v <= 1'b0;
      end
    end
  end

  always_comb
  begin
    mem_to_core.buf_full = buf_full_to_core;

    // local mem has the highest priority
    if(core_mem_rv) begin
      mem_to_core.valid     = 1'b1;
      mem_to_core.read_data = core_mem_rdata;
      mem_to_core.load_info = local_load_id_r;
    end else if(returned_buf_v) begin
      mem_to_core.valid     = 1'b1;
      mem_to_core.read_data = returned_data_buf;
      mem_to_core.load_info = returned_load_id_buf;
    end else begin
      mem_to_core.valid     = returned_v_r_lo;
      mem_to_core.read_data = returned_data_r_lo;
      mem_to_core.load_info = returned_load_id_r_lo;
    end
  end

  // synopsys translate_off
  always @(negedge clk_i)
  begin
    if(~reset_i) begin
      assert(~(core_mem_rv & returned_buf_v & buf_full_to_core))
      else begin
        $error("# ERROR data lost due to contention between local and remote loads");
      end
    end
  end
  // synopsys translate_on
      

   wire out_request;

   bsg_manycore_pkt_encode #(.x_cord_width_p (x_cord_width_p)
                             ,.y_cord_width_p(y_cord_width_p)
                             ,.data_width_p (data_width_p )
                             ,.addr_width_p (addr_width_p )
                             ,.epa_word_addr_width_p( epa_byte_addr_width_p -2 )
                             ,.dram_ch_addr_width_p ( dram_ch_addr_width_p)
                             ,.dram_ch_start_col_p  ( dram_ch_start_col_p )
                             ) pkt_encode
     (.clk_i(clk_i)

      // the memory request, from the core's data memory port
      ,.v_i       (core_mem_v    )
      ,.data_i    (core_mem_wdata)
      ,.addr_i    (core_mem_addr )
      ,.we_i      (core_mem_w    )
      ,.swap_aq_i (core_to_mem.swap_aq )
      ,.swap_rl_i (core_to_mem.swap_rl )
      ,.mask_i    (core_mem_mask )
      ,.tile_group_x_i ( CSR_TGO_X_r  )
      ,.tile_group_y_i ( CSR_TGO_Y_r  )
      ,.my_x_i    (my_x_i)
      ,.my_y_i    (my_y_i)

      // directly out to the network!
      ,.v_o    (out_request)
      ,.data_o (out_packet_li)
      );

   // we only request to send a remote store if it would not overflow the remote store credit counter
   assign out_v_li = out_request & (|out_credits_lo);

  // store load id of a local load
  always_ff @(posedge clk_i)
  begin
    if (reset_i)
      local_load_id_r <= load_id_width_p'(0);
    else
      if (~out_request & core_mem_v & ~core_mem_w) // if local read
        local_load_id_r <= core_to_mem.payload.read_info.load_info;
  end
    
   // synopsys translate_off

   bsg_manycore_packet_s data_o_debug;
   assign data_o_debug = out_packet_li;

   if (debug_p)
   // you can use this format to log packets coming from a node
     always @(negedge clk_i)
       begin
          if (launching_out)
            $display("# y,x=(%x,%x) PROC sending packet (addr=%x, op=%x, op_ex=%x, data=%x, y_cord=%x, x_cord=%x\n%b"
                     , my_y_i
                     , my_x_i
                     , data_o_debug.addr
                     , data_o_debug.op
                     , data_o_debug.op_ex
                     , data_o_debug.payload
                     , data_o_debug.y_cord
                     , data_o_debug.x_cord
                     , out_packet_li
                     );
       end

   // synopsys translate_on

   wire local_epa_request = core_mem_v & (~ out_request);// not a remote packet
   wire [1:0]              xbar_port_v_in = { local_epa_request ,  remote_access_dmem};

   localparam mem_width_lp    = $clog2(dmem_size_p) ;

   wire [1:0]                    xbar_port_we_in   = { core_mem_w, in_we_lo};
   wire [1:0]                    xbar_port_yumi_out;
   wire [1:0] [data_width_p-1:0] xbar_port_data_in = { core_mem_wdata, in_data_lo};

   // synopsys translate_off

   always @(negedge clk_i)
     begin
        if ( remote_invalid_addr)
              begin
                 $error("# ERROR y,x=(%x,%x) remote access addr (%x) is invalid",my_y_i,my_x_i,in_addr_lo*4);
                 $finish();
              end
     end


   always @(negedge clk_i)
     begin
        if (xbar_port_v_in[1])
          assert (core_mem_addr[30:2] < ((1 << icache_addr_width_lp) + (dmem_size_p)))
            else
              begin
                 $error("# ERROR y,x=(%x,%x) local store addr (%x) past end of data memory (%x)"
                        ,my_y_i,my_x_i,core_mem_addr,4*((1 << icache_addr_width_lp)+(dmem_size_p)));
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
   assign   in_yumi_li      = xbar_port_yumi_out[0] | remote_store_icache | is_config_op ;

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
     ,.num_banks_p  (1)
     ,.bank_size_p  (dmem_size_p )
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
                                         
   wire  is_freeze_addr = {1'b0, in_addr_lo[epa_word_addr_width_lp-2:0]} == epa_word_addr_width_lp'(`CSR_FREEZE);
   wire  is_tgo_x_addr  = {1'b0, in_addr_lo[epa_word_addr_width_lp-2:0]} == epa_word_addr_width_lp'(`CSR_TGO_X);
   wire  is_tgo_y_addr  = {1'b0, in_addr_lo[epa_word_addr_width_lp-2:0]} == epa_word_addr_width_lp'(`CSR_TGO_Y);
   wire  is_config_decoded = is_freeze_addr | is_tgo_x_addr | is_tgo_y_addr;

   // freeze register
   wire  freeze_op     = is_config_op & is_freeze_addr & in_data_lo[0] ;
   wire  unfreeze_op   = is_config_op & is_freeze_addr & (~in_data_lo[0]);

   always_ff @(posedge clk_i)
     if (reset_i) CSR_FREEZE_r <= freeze_init_p;
     else if (freeze_op | unfreeze_op) begin
            // synopsys translate_off
            $display("## CSR_FREEZE_r <= %x (%m)", in_data_lo[0]);
            // synopsys translate_on
            CSR_FREEZE_r <= in_data_lo[0];
     end
   
   always_ff@(posedge clk_i) if( is_config_op & is_tgo_x_addr & in_we_lo )
                                CSR_TGO_X_r <= x_cord_width_p'(in_data_lo);  

   always_ff@(posedge clk_i) if( is_config_op & is_tgo_y_addr & in_we_lo )
                                CSR_TGO_Y_r <= y_cord_width_p'(in_data_lo);  

  // synopsys translate_off
  always_ff@(negedge clk_i)
        if ( is_config_op  & (~is_config_decoded)) begin
                $error("## Accessing Non-existing CSR Address = %h", in_addr_lo );
                $finish();
        end

   // synopsys translate_on
   // ----------------------------------------------------------------------------------------
   // Handle the returning data/credit back to the network
   // ----------------------------------------------------------------------------------------
   wire                   store_yumi      = in_yumi_li & in_we_lo;
   wire                   CSR_load_yumi   = in_v_lo & is_config_decoded & (~in_we_lo);
   wire[data_width_p-1:0] CSR_load_data   = is_tgo_x_addr ? CSR_TGO_X_r : CSR_TGO_Y_r;
   //delay the response for store for 1 cycle
   always_ff@(posedge clk_i) 
        if( reset_i )   delayed_returning_v_r   <= 1'b0;
        else            delayed_returning_v_r   <= store_yumi | CSR_load_yumi;
   always_ff@(posedge clk_i)    delayed_returning_data_r<= CSR_load_yumi ? CSR_load_data :  in_data_lo;

   assign       returning_v     = load_returning_v | delayed_returning_v_r;
   assign       returning_data  = delayed_returning_v_r? delayed_returning_data_r : load_returning_data;

  // synopsys translate_off
  always_ff@(negedge clk_i)
        if ( (delayed_returning_v_r & load_returning_v) == 1'b1 ) begin
                $error(" Store returning and Load returning happens at the same time!" );
                $finish();
        end
  // synopsys translate_on
endmodule
