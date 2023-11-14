
// This header file defines a DPI interface for the BSG Manycore
// Network. Three FIFOs (TX REQ, RX REQ, RX RSP) are used to transmit
// and receive packets.
module bsg_nonsynth_dpi_manycore
  import bsg_manycore_pkg::*;
   #(
     // these are endpoint parameters
     parameter x_cord_width_p = "inv"
     ,parameter y_cord_width_p = "inv"
     ,parameter addr_width_p = "inv"
     ,parameter data_width_p = "inv"
     ,parameter credit_counter_width_p = `BSG_WIDTH(32)
     ,parameter ep_fifo_els_p = "inv"
     ,parameter dpi_fifo_els_p = "inv" // Response capacity
     ,parameter rom_els_p = "inv"
     ,parameter rom_width_p = "inv"
     ,parameter fifo_width_p = "inv"
     ,parameter rev_fifo_els_p = "inv"
     ,parameter bit [rom_width_p-1:0] rom_arr_p [0:rom_els_p-1] = '{default: '0}
     ,parameter icache_block_size_in_words_p = "inv"

     ,localparam link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
     ,parameter bit debug_p = 0
     )
   (
    input clk_i
    ,input reset_i

    // manycore link
    ,input [link_sif_width_lp-1:0] link_sif_i
    ,output [link_sif_width_lp-1:0] link_sif_o

    ,input reset_done_i

    ,input [x_cord_width_p-1:0] global_x_i
    ,input [y_cord_width_p-1:0] global_y_i

    ,output bit debug_o);

   logic [credit_counter_width_p-1:0] out_credits_used_lo;

   // Host -> Manycore Requests
   logic [fifo_width_p-1:0]                  host_req_data_lo;
   logic                                     host_req_v_lo;
   logic                                     host_req_ready_li;

   // Host -> Manycore Responses
   logic [fifo_width_p-1:0]                  host_rsp_data_lo;
   logic                                     host_rsp_v_lo;
   logic                                     host_rsp_ready_li;

   logic [fifo_width_p-1:0]                  endpoint_rsp_data_lo;
   logic                                     endpoint_rsp_v_lo;
   logic                                     endpoint_rsp_ready_li;

   // Manycore -> Host Responses
   logic [fifo_width_p-1:0]                  mc_rsp_data_li;
   logic                                     mc_rsp_v_li;
   logic                                     mc_rsp_ready_lo;

   logic [fifo_width_p-1:0]                  f2d_rsp_data_li;
   logic                                     f2d_rsp_v_li;
   logic                                     f2d_rsp_yumi_lo;

   // Manycore -> Host Requests
   logic [fifo_width_p-1:0]                  mc_req_data_li;
   logic                                     mc_req_v_li;
   logic                                     mc_req_ready_lo;

   logic [fifo_width_p-1:0]                  f2d_req_data_li;
   logic                                     f2d_req_v_li;
   logic                                     f2d_req_yumi_lo;

   // ----------------------------------------------------------------------
   // FIFO - To - DPI: Manycore (Requests) -> Host
   // ----------------------------------------------------------------------
   bsg_nonsynth_dpi_from_fifo
     #(
       .width_p(fifo_width_p)
       ,.debug_p(debug_p))
   f2d_req_i
     (
      .yumi_o(f2d_req_yumi_lo)
      ,.debug_o()

      ,.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(f2d_req_v_li)
      ,.data_i(f2d_req_data_li));

   bsg_fifo_1r1w_small_unhardened
     #(
       .els_p(dpi_fifo_els_p)
       ,.width_p(fifo_width_p)
       )
   fifo_f2d_req_i
     (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.v_i(mc_req_v_li)
      ,.ready_param_o(mc_req_ready_lo)
      ,.data_i(mc_req_data_li)

      ,.v_o(f2d_req_v_li)
      ,.data_o(f2d_req_data_li)
      ,.yumi_i(f2d_req_yumi_lo));

   // ----------------------------------------------------------------------
   // FIFO - To - DPI: Manycore (Response) -> Host
   // ----------------------------------------------------------------------
   bsg_nonsynth_dpi_from_fifo
     #(
       .width_p(fifo_width_p)
       ,.debug_p(debug_p))
   f2d_rsp_i
     (
      .yumi_o(f2d_rsp_yumi_lo)
      ,.debug_o()

      ,.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(f2d_rsp_v_li)
      ,.data_i(f2d_rsp_data_li));

   bsg_fifo_1r1w_small_unhardened
     #(
       .els_p(dpi_fifo_els_p)
       ,.width_p(fifo_width_p)
       )
   fifo_f2d_rsp_i
     (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.v_i(mc_rsp_v_li)
      ,.ready_param_o(mc_rsp_ready_lo)
      ,.data_i(mc_rsp_data_li)

      ,.v_o(f2d_rsp_v_li)
      ,.data_o(f2d_rsp_data_li)
      ,.yumi_i(f2d_rsp_yumi_lo));

   // ----------------------------------------------------------------------
   // DPI - To - FIFO: Host (Requests) -> Manycore
   // ----------------------------------------------------------------------
   bsg_nonsynth_dpi_to_fifo
     #(
       .width_p(fifo_width_p)
       ,.debug_p(debug_p))
   d2f_req_i
     (
      .debug_o()
      ,.v_o(host_req_v_lo)
      ,.data_o(host_req_data_lo)

      ,.ready_i(host_req_ready_li)
      ,.clk_i(clk_i)
      ,.reset_i(reset_i));

   // ----------------------------------------------------------------------
   // DPI - To - FIFO: Host (Responses) -> Manycore
   // ----------------------------------------------------------------------
   bsg_nonsynth_dpi_to_fifo
     #(
       .width_p(fifo_width_p)
       ,.debug_p(debug_p))
   d2f_rsp_i
     (
      .debug_o()
      ,.v_o(host_rsp_v_lo)
      ,.data_o(host_rsp_data_lo)

      ,.ready_i(host_rsp_ready_li)
      ,.clk_i(clk_i)
      ,.reset_i(reset_i));

   bsg_manycore_endpoint_to_fifos
     #(.fifo_width_p(fifo_width_p)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.addr_width_p(addr_width_p)
       ,.data_width_p(data_width_p)
       ,.ep_fifo_els_p(ep_fifo_els_p)
       ,.credit_counter_width_p(credit_counter_width_p)
       ,.rev_fifo_els_p(rev_fifo_els_p)
       ,.icache_block_size_in_words_p(icache_block_size_in_words_p)
       )
   mc_ep_to_fifos
     (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      // fifo interface
      ,.mc_req_o(mc_req_data_li)
      ,.mc_req_v_o(mc_req_v_li)
      ,.mc_req_ready_i(mc_req_ready_lo)

      ,.endpoint_req_i(host_req_data_lo)
      ,.endpoint_req_v_i(host_req_v_lo)
      ,.endpoint_req_ready_o(host_req_ready_li)

      ,.endpoint_rsp_i(host_rsp_data_lo)
      ,.endpoint_rsp_v_i(host_rsp_v_lo)
      ,.endpoint_rsp_ready_o(host_rsp_ready_li)

      ,.mc_rsp_o(mc_rsp_data_li)
      ,.mc_rsp_v_o(mc_rsp_v_li)
      ,.mc_rsp_ready_i(mc_rsp_ready_lo)

      // manycore link
      ,.link_sif_i(link_sif_i)
      ,.link_sif_o(link_sif_o)

      ,.global_y_i(global_y_i)
      ,.global_x_i(global_x_i)

      ,.out_credits_used_o(out_credits_used_lo)
      );

   // This module has DPI function calls, but no IO
   bsg_nonsynth_dpi_rom
     #(.els_p(rom_els_p)
       ,.width_p(rom_width_p)
       ,.arr_p(rom_arr_p))
   rom
     ();

   // We track the polarity of the current edge so that we can call
   // $fatal when credits_get_used is called during the wrong phase of
   // clk_i.
   logic                                     edgepol_l;
   always @(posedge clk_i or negedge clk_i) begin
      edgepol_l <= clk_i;
   end

   // Print module parameters to the console and set the intial debug
   // value. We use init_l to track whether the module has been
   // initialized.
   logic init_l;
   initial begin
      debug_o = debug_p;
      init_l = 0;

      $display("BSG INFO: bsg_nonsynth_dpi_manycore (initial begin)");
      $display("BSG INFO:     Instantiation:          %M");
      $display("BSG INFO:     x_cord_width_p:         %d", x_cord_width_p);
      $display("BSG INFO:     y_cord_width_p:         %d", y_cord_width_p);
      $display("BSG INFO:     addr_width_p:           %d", addr_width_p);
      $display("BSG INFO:     data_width_p:           %d", data_width_p);
      $display("BSG INFO:     credit_counter_width_p: %d", credit_counter_width_p);
      $display("BSG INFO:     ep_fifo_els_p:          %d", ep_fifo_els_p);
      $display("BSG INFO:     dpi_fifo_els_p:         %d", dpi_fifo_els_p);
      $display("BSG INFO:     debug_p:                %d", debug_o);
   end

   export "DPI-C" function bsg_dpi_init;
   export "DPI-C" function bsg_dpi_fini;
   export "DPI-C" function bsg_dpi_debug;
   export "DPI-C" function bsg_dpi_tx_is_vacant;
   export "DPI-C" function bsg_dpi_is_window;
   export "DPI-C" function bsg_dpi_reset_is_done;
   export "DPI-C" function bsg_dpi_credits_get_used;
   export "DPI-C" function bsg_dpi_credits_get_max;
   export "DPI-C" function bsg_dpi_capacity_get_max;

   // Return true if the  number of credits available. This is used to
   // fence in the C++ API.
   function int bsg_dpi_credits_get_max();
      return (1 << credit_counter_width_p) - 1;
   endfunction

   function int bsg_dpi_capacity_get_max();
      return dpi_fifo_els_p;
   endfunction

   // Return the number of credits currently in use by the endpoint
   // credit tracking mechanism
   function int bsg_dpi_credits_get_used();
      if(init_l === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_used() called before init()");
      end

      if(reset_i === 1) begin
         $fatal(1, "BSG ERROR (%M): credits_get_used() called while reset_i === 1");
      end

      if(reset_done_i === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_used() called while reset_done_i === 0");
      end

      if(clk_i === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_used() must be called when clk_i == 1");
      end

      if(edgepol_l === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_used() must be called after the positive edge of clk_i has been evaluated");
      end

      return out_credits_used_lo;
   endfunction

   // Returns whether the TX Fifo is Vacant. Use this when fencing to
   // determine if there are additional packets in the Transmit FIFO
   // that have not been seen by the endpoint
   function bit bsg_dpi_tx_is_vacant();
      if(init_l === 0) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() called before init()");
      end

      if(reset_i === 1) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() called while reset_i === 1");
      end

      if(reset_done_i === 0) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() called while reset_done_i === 0");
      end

      if(clk_i === 0) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() must be called when clk_i == 1");
      end

      if(edgepol_l === 0) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() must be called after the positive edge of clk_i has been evaluated");
      end

      // There isn't a fifo between the host (DPI) interface and the
      // endpoint, so we simply need to make sure that there isn't an
      // ongoing transaction. IF THIS CHANGES, then check both
      // host_req_v_lo AND the v output of the FIFO.
      return ~host_req_v_lo;
   endfunction

   // The function is_window returns true if the interface is
   // in a valid time-window to call read_credits()
   function bit bsg_dpi_is_window();
      return (clk_i & edgepol_l & ~reset_i);
   endfunction

   // The function is_reset_done returns true if the clock is high,
   // and reset is done, and the module is no longer in reset.
   function bit bsg_dpi_reset_is_done();
      return (clk_i & edgepol_l & ~reset_i & reset_done_i);
   endfunction

   // Initialize this Manycore DPI Interface
   function void bsg_dpi_init();
      if(init_l)
        $fatal(1, "BSG ERROR (%M): init() already called");

      init_l = 1;
   endfunction

   // Terminate this Manycore DPI Interface
   function void bsg_dpi_fini();
      if(~init_l)
        $fatal(1, "BSG ERROR (%M): fini() already called");

      init_l = 0;
   endfunction

   // Set or unset the debug_o output bit. If a state change occurs
   // (0->1 or 1->0) then module will print DEBUG ENABLED / DEBUG
   // DISABLED. No messages are printed if a state change does not
   // occur.
   function void bsg_dpi_debug(input bit switch_i);
      if(!debug_o & switch_i)
        $display("BSG DBGINFO (%M@%t): DEBUG ENABLED", $time);
      else if (debug_o & !switch_i)
        $display("BSG DBGINFO (%M@%t): DEBUG DISABLED", $time);

      debug_o = switch_i;
   endfunction // bsg_dpi_debug

   always_ff @(negedge clk_i)
     if(reset_i === 0)
       assert(!(
               (host_req_v_lo === 1) && (host_req_ready_li === 1)
                &&
              (out_credits_used_lo == ((1 << credit_counter_width_p) - 1)))
              )
         else
           $fatal(1, "BSG ERROR (%M): Packet transmitted, and all endpoint credits used: %b %b %d %d", host_req_v_lo, host_req_ready_li, out_credits_used_lo, ((1 << credit_counter_width_p) - 1));

`ifndef VERILATOR
   // Evaluate the simulation, until the next clk_i positive edge.
   //
   // Call bsg_dpi_next in simulators where the C testbench does not
   // control the progression of time (i.e. NOT Verilator).
   //
   // The #1 statement guarantees that the positive edge has been
   // evaluated, which is necessary for ordering in all of the DPI
   // functions.
   export "DPI-C" task bsg_dpi_next;
   task bsg_dpi_next();
      @(posedge clk_i);
      #1;
   endtask // bsg_dpi_next
`endif

endmodule
