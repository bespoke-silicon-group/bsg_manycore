module
 bsg_vscale_core

import bsg_vscale_pkg::*;

   #(parameter x_cord_width_p = "inv"
     , y_cord_width_p = "inv")
  ( input clk_i
   ,input reset_i
   ,input freeze_i

   // to banked crossbar
   ,output [1:0]                          m_v_o
   ,output [1:0]                          m_w_o
   ,output [1:0] [haddr_width_p-1:0]      m_addr_o // this is 32 bits
   ,output [1:0] [hdata_width_p-1:0]      m_data_o
   ,output logic [1:0] [(hdata_width_p>>3)-1:0] m_mask_o
   ,input  [1:0]                          m_yumi_i
   ,input  [1:0]                          m_v_i
   ,input  [1:0] [hdata_width_p-1:0]      m_data_i

   ,output                                m_reserve_1_o
   ,input                                 m_reservation_i

   ,input                                 outstanding_stores_i

   ,input   [x_cord_width_p-1:0] my_x_i
   ,input   [y_cord_width_p-1:0] my_y_i
  );

   // synopsys translate_off
   if (0)
     always @(negedge clk_i)
       if (~freeze_i)
         $display("%m v=%x addr=%x mask=%b yumi=%b vi=%x, data_i=%x "
                  ,m_v_o[0], m_addr_o[0], m_mask_o[0], m_yumi_i[0], m_v_i[0], m_data_i[0]);
   // synopsys translate_on

   assign m_data_o[0] = 0;

   logic freeze_r;

   always_ff @(posedge clk_i)
     freeze_r <= freeze_i;

   // always be fetching, apparently;
   // may be better to be more precise about this signal
   // based on more outputs from vscale pipeline

   assign m_v_o    [0] = ~freeze_r;
   assign m_w_o    [0] = 1'b0;
   assign m_mask_o [0] = 4'b1111;

   wire [`HASTI_SIZE_WIDTH-1:0]                    dmem_size;

   // generate byte write mask
   always_comb
     begin
        m_mask_o[1] = 4'b0000;

        case (dmem_size)
          2: m_mask_o[1] = 4'b1111;
          1: m_mask_o[1] = { m_addr_o[1][1],    m_addr_o[1][1], ~m_addr_o[1][1], ~m_addr_o[1][1] };
          0: m_mask_o[1] = { &m_addr_o[1][1:0]
                             ,  m_addr_o[1][1] & ~m_addr_o[1][0]
                             , ~m_addr_o[1][1] &  m_addr_o[1][0]
                             , ~(|m_addr_o[1][1:0])
                             };
         default:
           m_mask_o[1] = 4'bX;

        endcase // unique case dmem_size
     end // always_comb

   // synopsys translate_off
   always @(negedge clk_i)
     if (m_v_o[1] & (dmem_size > 2))
       $error("%m unhandled dmem size %x", dmem_size);

   always @(negedge clk_i)
     if (~reset_i & m_v_o[1] )
       assert (~(dmem_size == 2 && (|m_addr_o[1][1:0]))
               && ~(dmem_size == 1 && (|m_addr_o[1][0])))
         else $error("%m unaligned access to %x",m_addr_o[1]);
   // synopsys translate_on

   // the vscale_pipeline wants a _ready signal
   // but the crossbar requires a yumi signal

   logic imem_wait;

   assign imem_wait = ~m_yumi_i[0];

   vscale_pipeline #(.x_cord_width_p(x_cord_width_p)
                     ,.y_cord_width_p(y_cord_width_p))
                     vscale
                     (.clk  (clk_i)
                      ,.reset(reset_i)
                      ,.freeze(freeze_i)

                      ,.imem_wait     (imem_wait) // i

                      ,.imem_addr     (m_addr_o[0])  // o
                      ,.imem_rdata    (m_data_i[0])  // i
                      ,.imem_badmem_e (1'b0)         // i

                      ,.dmem_wait      (~m_yumi_i[1]) // i
                      ,.dmem_en        (m_v_o[1])     // o
                      ,.dmem_wen       (m_w_o[1])     // o
                      ,.dmem_reserve_en   (m_reserve_1_o  ) // o
                      ,.dmem_reservation_i(m_reservation_i)
                      ,.dmem_size     (dmem_size)    // o
                      ,.dmem_addr     (m_addr_o[1])  // o
                      ,.dmem_wdata    (m_data_o[1])  // o
                      ,.dmem_rdata    (m_data_i[1])  // i
                      ,.dmem_badmem_e(1'b0)          // i

                      ,.htif_reset         (reset_i)
                      ,.htif_pcr_req_valid (1'b0)
                      ,.htif_pcr_req_ready ()
                      ,.htif_pcr_req_rw    (1'b0)
                      ,.htif_pcr_req_addr  ()
                      ,.htif_pcr_req_data  ()
                      ,.htif_pcr_resp_valid()
                      ,.htif_pcr_resp_ready(1'b1)
                      ,.htif_pcr_resp_data ()

                      ,.outstanding_stores_i(outstanding_stores_i)
                      ,.my_x_i(my_x_i)
                      ,.my_y_i(my_y_i)
    );


endmodule
