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
     ,parameter max_out_credits_p = "inv"
     ,parameter ep_fifo_els_p = "inv"
     ,parameter dpi_fifo_els_p = "inv"
     ,parameter rom_els_p = "inv"
     ,parameter rom_width_p = "inv"
     ,parameter fifo_width_p = "inv"
     ,parameter bit [rom_width_p-1:0] rom_arr_p [rom_els_p-1:0] = "inv"
     ,localparam link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
     ,parameter bit debug_p = 0
     ) 
   (
    input clk_i
    ,input reset_i
      
    // manycore link
    ,input [link_sif_width_lp-1:0] link_sif_i
    ,output [link_sif_width_lp-1:0] link_sif_o
      
    ,input [x_cord_width_p-1:0] my_x_i
    ,input [y_cord_width_p-1:0] my_y_i

    ,input reset_done_i
      
    ,output bit debug_o);
   
   logic [`BSG_WIDTH(max_out_credits_p)-1:0] ep_out_credits_lo;
   
   // Host -> Manycore Requests
   logic [fifo_width_p-1:0]                  host_req_data_lo;
   logic                                     host_req_v_lo;
   logic                                     host_req_ready_li;

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
      ,.ready_o(mc_req_ready_lo)
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
      ,.ready_o(mc_rsp_ready_lo)
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

   bsg_manycore_endpoint_to_fifos 
     #(
       .fifo_width_p     (fifo_width_p),
       .x_cord_width_p   (x_cord_width_p),
       .y_cord_width_p   (y_cord_width_p),
       .addr_width_p     (addr_width_p),
       .data_width_p     (data_width_p),
       .ep_fifo_els_p    (ep_fifo_els_p),
       .max_out_credits_p(max_out_credits_p)
       ) 
   mc_ep_to_fifos 
     (
      .clk_i           (clk_i),
      .reset_i         (reset_i),

      // fifo interface
      .mc_req_o        (mc_req_data_li),
      .mc_req_v_o      (mc_req_v_li),
      .mc_req_ready_i  (mc_req_ready_lo),

      .host_req_i      (host_req_data_lo),
      .host_req_v_i    (host_req_v_lo),
      .host_req_ready_o(host_req_ready_li),

      .mc_rsp_o        (mc_rsp_data_li),
      .mc_rsp_v_o      (mc_rsp_v_li),
      .mc_rsp_ready_i  (mc_rsp_ready_lo),

      // manycore link
      .link_sif_i      (link_sif_i),
      .link_sif_o      (link_sif_o),
      .my_x_i          (my_x_i),
      .my_y_i          (my_y_i),
      .out_credits_o   (ep_out_credits_lo)
      );

   // This module has DPI function calls, but no IO
   bsg_nonsynth_dpi_rom
     #(.els_p(rom_els_p)
       ,.width_p(rom_width_p)
       ,.arr_p(rom_arr_p))
   rom
     ();

   // We track the polarity of the current edge so that we can call
   // $fatal when credits_get_cur is called during the wrong phase
   // of clk_i.
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
      $display("BSG INFO:     Instantiation:     %M");
      $display("BSG INFO:     x_cord_width_p:    %d", x_cord_width_p);
      $display("BSG INFO:     y_cord_width_p:    %d", y_cord_width_p);
      $display("BSG INFO:     addr_width_p:      %d", addr_width_p);
      $display("BSG INFO:     data_width_p:      %d", data_width_p);
      $display("BSG INFO:     max_out_credits_p: %d", max_out_credits_p);
      $display("BSG INFO:     ep_fifo_els_p:     %d", ep_fifo_els_p);
      $display("BSG INFO:     dpi_fifo_els_p:    %d", dpi_fifo_els_p);
      $display("BSG INFO:     debug_p:           %d", debug_o);
   end

   export "DPI-C" function bsg_dpi_init;
   export "DPI-C" function bsg_dpi_fini;
   export "DPI-C" function bsg_dpi_debug;
   export "DPI-C" function bsg_dpi_tx_is_vacant;
   export "DPI-C" function bsg_dpi_is_window;
   export "DPI-C" function bsg_dpi_reset_is_done;
   export "DPI-C" function bsg_dpi_credits_get_cur;
   export "DPI-C" function bsg_dpi_credits_get_max;


   // Return true if the  number of credits available. This is used to
   // fence in the C++ API.
   function int bsg_dpi_credits_get_max();
      return max_out_credits_p;
   endfunction

   // Return the number of credits currently available for
   // host-originated requests. This value is advertised by the
   // endpoint.
   function int bsg_dpi_credits_get_cur();
      if(init_l === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_cur() called before init()");
      end

      if(reset_i === 1) begin
         $fatal(1, "BSG ERROR (%M): credits_get_cur() called while reset_i === 1");
      end      

      if(reset_done_i === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_cur() called while reset_done_i === 0");
      end      

      if(clk_i === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_cur() must be called when clk_i == 1");
      end

      if(edgepol_l === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_cur() must be called after the positive edge of clk_i has been evaluated");
      end
      
      return ep_out_credits_lo;
   endfunction 

   // Return the number of credits currently available for
   // host-originated requests. This value is advertised by the
   // endpoint.
   function bit bsg_dpi_tx_is_vacant();
      if(init_l === 0) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() called before init()");
      end

      if(reset_i === 1) begin
         $fatal(1, "BSG ERROR (%M): tx_is_vacant() called while reset_i === 1");
      end      

      if(reset_done_i === 0) begin
         $fatal(1, "BSG ERROR (%M): credits_get_cur() called while reset_done_i === 0");
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
   endfunction

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
