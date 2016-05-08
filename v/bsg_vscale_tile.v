module bsg_vscale_tile

import bsg_vscale_pkg::*
       , bsg_noc_pkg::*; // {P=0, W, E, N, S}

 #( parameter dirs_p            = 4
   ,parameter stub_p            = {dirs_p{1'b0}} // {s,n,e,w}
   ,parameter xcord_width_p       = 5
   ,parameter ycord_width_p       = 5

   ,parameter fifo_els_p        = -1

   ,parameter bank_size_p       = -1
   ,parameter num_banks_p       = -1
   ,parameter data_width_p      = hdata_width_p
   ,parameter addr_width_p      = haddr_width_p
   ,parameter mem_addr_width_lp = $clog2(num_banks_p) + `BSG_SAFE_CLOG2(bank_size_p)
   ,parameter packet_width_lp   = 6 + xcord_width_p + ycord_width_p
                                    + addr_width_p + data_width_p
   ,parameter debug_p = 0
  )
  ( input                                       clk_i
   ,input                                       reset_i

   // input fifos
   ,input   [dirs_p-1:0] [packet_width_lp-1:0]  packet_i
   ,input   [dirs_p-1:0]                        valid_i
   ,output  [dirs_p-1:0]                        ready_o

   // output fifos
   ,output  [dirs_p-1:0] [packet_width_lp-1:0]  packet_o
   ,output  [dirs_p-1:0]                        valid_o
   ,input   [dirs_p-1:0]                        yumi_i

   // tile coordinates
   ,input   [xcord_width_p-1:0]                   my_x_i
   ,input   [ycord_width_p-1:0]                   my_y_i

   // synopsys translate off
   ,output                        htif_pcr_resp_valid_o
   ,output [htif_pcr_width_p-1:0] htif_pcr_resp_data_o
   // synopsys translate on
  );

  typedef struct packed {
    logic [5:0]               op;
    logic [addr_width_p-1:0]  addr;
    logic [data_width_p-1:0]  data;
    logic [ycord_width_p-1:0]   y_cord;
    logic [xcord_width_p-1:0]   x_cord;
  } bsg_vscale_remote_packet_s;



  /* CORE */

  logic stall_r;

  // htif outputs
  logic                           htif_pcr_resp_valid;
  logic [htif_pcr_width_p-1:0]    htif_pcr_resp_data;

  // hasti converter signals
  logic [1:0]                           h2m_v;
  logic [1:0]                           h2m_w;
  logic [1:0] [addr_width_p-1:0]        h2m_addr;
  logic [1:0] [data_width_p-1:0]        h2m_wdata;
  logic [1:0] [(data_width_p>>3)-1:0]   h2m_mask;
  logic [1:0]                           h2m_yumi;
  logic [1:0]                           h2m_rv;
  logic [1:0] [data_width_p-1:0]        h2m_rdata;

  bsg_vscale_core core
    ( .clk_i   (clk_i)
     ,.reset_i (reset_i)
     ,.stall_i (stall_r)

     ,.htif_id_i              (1'b0)
     ,.htif_pcr_req_valid_i   (1'b1)
     ,.htif_pcr_req_ready_o   ()
     ,.htif_pcr_req_rw_i      (1'b0)
     ,.htif_pcr_req_addr_i    (`CSR_ADDR_TO_HOST)
     ,.htif_pcr_req_data_i    (htif_pcr_width_p'(0))
     ,.htif_pcr_resp_valid_o  (htif_pcr_resp_valid)
     ,.htif_pcr_resp_ready_i  (1'b1)
     ,.htif_pcr_resp_data_o   (htif_pcr_resp_data)
     ,.htif_ipi_req_ready_i   (1'b0)
     ,.htif_ipi_req_valid_o   ()
     ,.htif_ipi_req_data_o    ()
     ,.htif_ipi_resp_ready_o  ()
     ,.htif_ipi_resp_valid_i  (1'b0)
     ,.htif_ipi_resp_data_i   (1'b0)
     ,.htif_debug_stats_pcr_o ()

     ,.m_v_o       (h2m_v)
     ,.m_w_o       (h2m_w)
     ,.m_addr_o    (h2m_addr)
     ,.m_data_o    (h2m_wdata)
     ,.m_mask_o    (h2m_mask)
     ,.m_yumi_i    (h2m_yumi)
     ,.m_v_i       (h2m_rv)
     ,.m_data_i    (h2m_rdata)
    );

  // synopsys translate off
  assign htif_pcr_resp_valid_o = htif_pcr_resp_valid;
  assign htif_pcr_resp_data_o  = htif_pcr_resp_data;
  // synopsys translate on


  /* ROUTER & FIFOS */

  // router signals
  bsg_vscale_remote_packet_s [dirs_p:0] rtr_rdata;
  logic                      [dirs_p:0] rtr_rv;
  logic                      [dirs_p:0] rtr_yumi;
  bsg_vscale_remote_packet_s [dirs_p:0] rtr_wdata;
  logic                      [dirs_p:0] rtr_wv;
  logic                      [dirs_p:0] rtr_ready;



  bsg_mesh_router #( .dirs_p      (5)
                    ,.width_p     (packet_width_lp)
                    ,.xcord_width_p(xcord_width_p)
                    ,.ycord_width_p(ycord_width_p)
                    ,.debug_p(debug_p)
                   ) mesh_router
                   ( .clk_i    (clk_i)
                    ,.reset_i  (reset_i)

                    ,.data_i   (rtr_rdata)
                    ,.valid_i  (rtr_rv)
                    ,.yumi_o   (rtr_yumi)

                    ,.ready_i  (rtr_ready)
                    ,.data_o   (rtr_wdata)
                    ,.valid_o  (rtr_wv)

                    ,.my_x_i   (my_x_i)
                    ,.my_y_i   (my_y_i)
                   );

  // fifo signals
  logic                      [dirs_p:0] fifo_out_valid;
  bsg_vscale_remote_packet_s [dirs_p:0] fifo_out_data;
  logic                      [dirs_p:0] fifo_yumi;
  logic                      [dirs_p:0] fifo_in_valid;
  bsg_vscale_remote_packet_s [dirs_p:0] fifo_in_data;
  logic                      [dirs_p:0] fifo_ready;

  genvar i;

  for(i=P; i<=S; i=i+1)
  begin: fifo_gen
    if ((i==P) || !((stub_p >> (i-1)) & 1'b1))
      begin
        bsg_fifo_1r1w_small # ( .width_p            (packet_width_lp)
                               ,.els_p              (fifo_els_p)
                               ,.ready_THEN_valid_p (0)
                              ) fifo_from_rtr
                              ( .clk_i   (clk_i)
                               ,.reset_i (reset_i)

                               ,.data_i  (rtr_wdata[i])
                               ,.v_i     (rtr_wv[i])
                               ,.ready_o (rtr_ready[i])

                               ,.v_o     (fifo_out_valid[i])
                               ,.data_o  (fifo_out_data[i])
                               ,.yumi_i  (fifo_yumi[i])
                              );

        bsg_fifo_1r1w_small # ( .width_p            (packet_width_lp)
                               ,.els_p              (fifo_els_p)
                               ,.ready_THEN_valid_p (0)
                              ) fifo_to_rtr
                              ( .clk_i   (clk_i)
                               ,.reset_i (reset_i)

                               ,.data_i  (fifo_in_data[i])
                               ,.v_i     (fifo_in_valid[i])
                               ,.ready_o (fifo_ready[i])

                               ,.v_o     (rtr_rv[i])
                               ,.data_o  (rtr_rdata[i])
                               ,.yumi_i  (rtr_yumi[i])
                              );
      end
  end


  for(i=W; i<=S; i=i+1)
  begin
    if(!((stub_p >> (i-1)) & 1'b1))
      begin
        assign fifo_in_data  [i]   = packet_i       [i-1];
        assign fifo_in_valid [i]   = valid_i        [i-1];
        assign fifo_yumi     [i]   = yumi_i         [i-1];
        assign packet_o      [i-1] = fifo_out_data  [i];
        assign valid_o       [i-1] = fifo_out_valid [i];
        assign ready_o       [i-1] = fifo_ready     [i];
      end
    else
      begin
        assign rtr_rdata [i]   = packet_width_lp'(0);
        assign rtr_rv    [i]   = 1'b0;
        assign rtr_ready [i]   = 1'b0;
        assign packet_o  [i-1] = packet_width_lp'(0);
        assign valid_o   [i-1] = 1'b0;
        assign ready_o   [i-1] = 1'b0;
      end
  end

   logic proc_freeze_pkt;
   logic remote_store_pkt;
   logic unknown_pkt;

   always_comb
     begin
        proc_freeze_pkt  = 1'b0;
        remote_store_pkt = 1'b0;
        unknown_pkt      = 1'b0;

        if (fifo_out_valid[0])
          unique case (fifo_out_data[0].op)
            6'd2: if (~|fifo_out_data[0].addr[addr_width_p-1:1])
              proc_freeze_pkt = 1'b1;
            6'd1: remote_store_pkt = 1'b1;
            default:
              unknown_pkt = 1'b1;
          endcase // unique case (fifo_out_data[0].op)
     end

  // stall logic
  always_ff @(posedge clk_i)
  begin
    if(reset_i)
      stall_r <= 1'b1;
    else
      if(proc_freeze_pkt)
        stall_r <= fifo_out_data[0].addr[0];
  end



  wire [1:0] remote_req = h2m_v &   {  h2m_addr[1][addr_width_p-1],  h2m_addr[0][addr_width_p-1] };
  wire [1:0] local_req  = h2m_v &   { ~h2m_addr[1][addr_width_p-1], ~h2m_addr[0][addr_width_p-1] };

  // banked memory signals
  logic                           m_rv;
  logic [data_width_p-1:0]        m_rdata;
  logic [1:0]                     m_yumi;

  logic                           fifo_yumi_temp;

  bsg_mem_banked_crossbar #
    ( .num_ports_p  (3)
     ,.num_banks_p  (num_banks_p)
     ,.bank_size_p  (bank_size_p)
     ,.data_width_p (data_width_p)
// mbt: debug, multiply addresses by 4.
     ,.debug_p(debug_p*4)
    ) banked_crossbar
    ( .clk_i   (clk_i)
     ,.reset_i (reset_i)
      ,.v_i     ({ remote_store_pkt
                  , local_req[1]
                  , local_req[0]
                }
               )
     ,.w_i     ({1'b1, h2m_w})
     ,.addr_i  ({fifo_out_data[0].addr[2+:mem_addr_width_lp]
                 , h2m_addr[1][2+:mem_addr_width_lp]
                 , h2m_addr[0][2+:mem_addr_width_lp]
                }
               )
     ,.data_i  ({fifo_out_data[0].data, h2m_wdata})
     ,.mask_i  ({(data_width_p>>3)'(0), h2m_mask})
     ,.yumi_o  ({fifo_yumi_temp, m_yumi})
     ,.v_o     ({m_rv, h2m_rv})
     ,.data_o  ({m_rdata, h2m_rdata})
    );

   assign fifo_yumi[0] = fifo_yumi_temp | proc_freeze_pkt ;


  // synopsys translate off
   for(i=0; i<2; i=i+1)
     begin
        always_ff @(negedge clk_i)
          if (remote_req[i] & ~h2m_w[i])
            begin
               $error("%m load to remote address %x by core on port %x", h2m_addr[i],i);
               $finish();
            end
     end

   if (debug_p)
     always_ff @(negedge clk_i)
       if (fifo_out_valid[0])
         $display("%m data waiting op=%x,addr=%x,data=%x",fifo_out_data[0].op,fifo_out_data[0].addr,fifo_out_data[0].data);

  // synopsys translate on


  // remote mem. signals
  wire                          rem_m_v     = h2m_v    [1];
  wire                          rem_m_w     = h2m_w    [1];
  wire  [addr_width_p-1:0]      rem_m_addr  = h2m_addr [1];
  wire  [data_width_p-1:0]      rem_m_wdata = h2m_wdata[1];
  wire  [(data_width_p>>3)-1:0] rem_m_mask  = h2m_mask [1];

  logic [data_width_p-1:0] bit_mask;

  // mbt fixme: to support byte writes, we would
  // have to include that as part of the remote store packet

  for(i=0; i<(data_width_p>>3); i=i+1)
    assign bit_mask[i*8+:8] = {8{rem_m_mask[i]}};

  // core to fifo
  assign fifo_in_data[0].op     = 6'(rem_m_addr[addr_width_p-1]);
  assign fifo_in_data[0].addr   = { {(xcord_width_p + ycord_width_p){1'b0}}
                                  , rem_m_addr[0+:(addr_width_p-xcord_width_p-ycord_width_p)]
                                  };
  assign fifo_in_data[0].data   = (~bit_mask) & rem_m_wdata;
  assign fifo_in_data[0].y_cord = rem_m_addr[(addr_width_p-2)-:ycord_width_p];
  assign fifo_in_data[0].x_cord = rem_m_addr[(addr_width_p-2-ycord_width_p)-:xcord_width_p];
  assign fifo_in_valid[0]       = remote_req[1];

   // if the fifo was ready, and we asserted valid, then a transfer occurred.
  wire   rem_m_yumi          = fifo_in_valid[0] & fifo_ready[0];

   assign h2m_yumi[1] = rem_m_yumi | m_yumi[1];
   assign h2m_yumi[0] = m_yumi[0];

   // synopsys translate off
   if (debug_p)
   always @(negedge clk_i)
     begin
        if (rem_m_yumi)
          $display("sending packet %x (op=%x, addr=%x, data=%x, y_cord=%x, x_cord=%x), bit_mask=%x, rem_m_wdata=%x, rem_m_addr=%x"
                   , fifo_in_data[0]
                   , fifo_in_data[0].op
                   , fifo_in_data[0].addr << 2
                   , fifo_in_data[0].data
                   , fifo_in_data[0].y_cord
                   , fifo_in_data[0].x_cord
                   , bit_mask
                   , rem_m_wdata
                   , rem_m_addr
                   );
     end

   // synopsys translate on


endmodule

