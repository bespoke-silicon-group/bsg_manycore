import bsg_vscale_pkg::*;

module bsg_vscale_tile #
  ( parameter bank_size_p       = -1
   ,parameter num_banks_p       = -1
   ,parameter mem_addr_width_lp = $clog2(num_banks_p) + `BSG_SAFE_CLOG2(bank_size_p)

   ,parameter fifo_els_p        = -1

   ,parameter data_width_p      = hdata_width_p
   ,parameter addr_width_p      = haddr_width_p 
   ,parameter dirs_p            = 4 
   ,parameter lg_node_x_p       = 5
   ,parameter lg_node_y_p       = 5
   ,parameter packet_width_lp   = 6 + lg_node_x_p + lg_node_y_p
                                    + addr_width_p + data_width_p
  )
  ( input                                       clk_i
   ,input                                       reset_i

   // input fifo
   ,input   [dirs_p-1:0] [packet_width_lp-1:0]  data_i  
   ,input   [dirs_p-1:0]                        valid_i 
   ,output  logic [dirs_p-1:0]                  yumi_o  

   // output fifo
   ,input   [dirs_p-1:0]                        ready_i
   ,output  [dirs_p-1:0] [packet_width_lp-1:0]  data_o  
   ,output  logic [dirs_p-1:0]                  valid_o 

   // tile coordinates
   ,input   [lg_node_x_p-1:0]                   my_x_i 
   ,input   [lg_node_y_p-1:0]                   my_y_i

   // synopsys translate off
   ,output                        htif_pcr_resp_valid_o
   ,output [htif_pcr_width_p-1:0] htif_pcr_resp_data_o
   // synopsys translate on
  );

  typedef struct packed {
    logic [5:0]               op;
    logic [addr_width_p-1:0]  addr;
    logic [data_width_p-1:0]  data;
    logic [lg_node_y_p-1:0]   y_cord;
    logic [lg_node_x_p-1:0]   x_cord;
  } bsg_vscale_remote_packet_s;



  /* CORE */

  logic stall_r;

  // htif outputs
  logic                           htif_pcr_resp_valid;
  logic [htif_pcr_width_p-1:0]    htif_pcr_resp_data;

  // hasti covereter signals
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

  // router (to fifo) signals
  bsg_vscale_remote_packet_s rtr_rdata;
  logic                      rtr_rv;
  logic                      rtr_yumi;
  bsg_vscale_remote_packet_s rtr_wdata;
  logic                      rtr_wv;
  logic                      rtr_ready;

  bsg_mesh_router #( .dirs_p      (5)
                    ,.width_p     (packet_width_lp)
                    ,.lg_node_x_p (lg_node_x_p)
                    ,.lg_node_y_p (lg_node_y_p)
                   ) mesh_router
                   ( .clk_i    (clk_i)
                    ,.reset_i  (reset_i)
                    
                    ,.data_i   ({data_i , rtr_rdata})
                    ,.valid_i  ({valid_i, rtr_rv})
                    ,.yumi_o   ({yumi_o , rtr_yumi})

                    ,.ready_i  ({ready_i, rtr_ready})
                    ,.data_o   ({data_o , rtr_wdata})
                    ,.valid_o  ({valid_o, rtr_wv})

                    ,.my_x_i   (my_x_i)
                    ,.my_y_i   (my_y_i)
                   );

  // fifo (to core/mem) signals
  logic                         fifo_out_valid;
  bsg_vscale_remote_packet_s    fifo_out_data;
  logic                         fifo_yumi;
  logic                         fifo_in_valid;
  bsg_vscale_remote_packet_s    fifo_in_data;
  logic                         fifo_ready;

  bsg_fifo_1r1w_small # ( .width_p            (packet_width_lp)
                         ,.els_p              (fifo_els_p)
                         ,.ready_THEN_valid_p (1)
                        ) fifo_rtr_to_mem
                        ( .clk_i   (clk_i)
                         ,.reset_i (reset_i)

                         ,.data_i  (rtr_wdata)
                         ,.v_i     (rtr_wv)
                         ,.ready_o (rtr_ready)

                         ,.v_o     (fifo_out_valid)
                         ,.data_o  (fifo_out_data)
                         ,.yumi_i  (fifo_yumi)
                        );

  bsg_fifo_1r1w_small # ( .width_p            (packet_width_lp)
                         ,.els_p              (fifo_els_p)
                         ,.ready_THEN_valid_p (0)
                        ) fifo_core_to_rtr
                        ( .clk_i   (clk_i)
                         ,.reset_i (reset_i)

                         ,.data_i  (fifo_in_data)
                         ,.v_i     (fifo_in_valid)
                         ,.ready_o (fifo_ready)

                         ,.v_o     (rtr_rv)
                         ,.data_o  (rtr_rdata)
                         ,.yumi_i  (rtr_yumi)
                        );


  // stall logic
  always_ff @(posedge clk_i)
  begin
    if(reset_i)
      stall_r <= 1'b1;
    else
      if(fifo_out_data.op == 2 & (fifo_out_data.addr == 0 | fifo_out_data.addr == 1))
        stall_r <= fifo_out_data.addr;
  end

  
  // banked memory signals
  logic                           m_rv;
  logic [data_width_p-1:0]        m_rdata;
  logic [1:0]                     m_yumi;

  bsg_mem_banked_crossbar #
    ( .num_ports_p  (3)
     ,.num_banks_p  (num_banks_p)
     ,.bank_size_p  (bank_size_p)
     ,.data_width_p (data_width_p)
    ) banked_crossbar
    ( .clk_i   (clk_i)
     ,.reset_i (reset_i)
     ,.v_i     ({(fifo_out_valid ? (fifo_out_data.op == 6'(1)) : 1'b0)
                 , (~h2m_addr[1][addr_width_p-1] & h2m_v[1])
                 , (~h2m_addr[0][addr_width_p-1] & h2m_v[0])
                }
               )
     ,.w_i     ({1'b1, h2m_w})
     ,.addr_i  ({fifo_out_data.addr[2+:mem_addr_width_lp]
                 , h2m_addr[1][2+:mem_addr_width_lp]
                 , h2m_addr[0][2+:mem_addr_width_lp]
                }
               )
     ,.data_i  ({fifo_out_data.data, h2m_wdata})
     ,.mask_i  ({(data_width_p>>3)'(0), h2m_mask})
     ,.yumi_o  ({fifo_yumi, m_yumi})
     ,.v_o     ({m_rv, h2m_rv})
     ,.data_o  ({m_rdata, h2m_rdata})
    );


  genvar i;

  for(i=0; i<2; i=i+1)
  begin
    // synopsys translate off
    always_comb
      if(h2m_v[i] & ~h2m_w[i])
        assert (~h2m_addr[i][addr_width_p-1])
          else $error("memory access request by core is out of scope");
    // synopsys translate on
  end


  logic [1:0] remote_store_reqs;
  logic [1:0] remote_store_grants;

  assign remote_store_reqs = {h2m_addr[1][addr_width_p-1] & h2m_v[1] & h2m_w[1]
                              , h2m_addr[0][addr_width_p-1] & h2m_v[0] & h2m_w[0]
                             };

  bsg_round_robin_arb #(.inputs_p (2)
                       ) remote_store_arb
                       ( .clk_i    (clk_i)
                        ,.reset_i  (reset_i)
                        ,.ready_i  (1'b1)
                        ,.reqs_i   (remote_store_reqs)
                        ,.grants_o (remote_store_grants)
                       );


  // remote mem. signals
  logic                         rem_m_v    ;    
  logic                         rem_m_w    ;  
  logic [addr_width_p-1:0]      rem_m_addr ;  
  logic [data_width_p-1:0]      rem_m_wdata;  
  logic [(data_width_p>>3)-1:0] rem_m_mask ;  
  logic                         rem_m_yumi ;  
                                             
  bsg_mux_one_hot # ( .els_p (2)
                     ,.width_p (2 + data_width_p 
                                + (data_width_p>>3) + addr_width_p
                               )
                    ) remote_store_mux_one_hot
                    ( .data_i        ({ h2m_v
                                       ,h2m_w
                                       ,h2m_addr
                                       ,h2m_wdata
                                       ,h2m_mask
                                      }
                                     )
                     ,.sel_one_hot_i (remote_store_grants)
                     ,.data_o        ({ rem_m_v    
                                       ,rem_m_w    
                                       ,rem_m_addr 
                                       ,rem_m_wdata
                                       ,rem_m_mask 
                                      }
                                     )
                    );

  logic [data_width_p-1:0] bit_mask;

  for(i=0; i<(data_width_p>>3); i=i+1)
    assign bit_mask[i*8+:8] = {8{rem_m_mask[i]}};
  
  // core to fifo
  assign fifo_in_data.op     = 6'(rem_m_addr[addr_width_p-1]);
  assign fifo_in_data.addr   = { {(lg_node_x_p + lg_node_y_p){1'b0}}
                                 , rem_m_addr[0+:(addr_width_p-lg_node_x_p-lg_node_y_p)]
                               };
  assign fifo_in_data.data   = (~bit_mask) & rem_m_wdata;
  assign fifo_in_data.y_cord = rem_m_addr[(addr_width_p-lg_node_x_p-1)-:lg_node_y_p];
  assign fifo_in_data.x_cord = {1'b0, rem_m_addr[(addr_width_p-2)-:(lg_node_x_p-1)]};
  assign fifo_in_valid       = rem_m_v & rem_m_w;

  assign rem_m_yumi          = fifo_in_valid & fifo_ready;
  assign h2m_yumi            = {remote_store_grants[1] ? rem_m_yumi : m_yumi[1]
                                , remote_store_grants[0] ? rem_m_yumi : m_yumi[0]
                               };

endmodule
