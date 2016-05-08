module bsg_vscale_core
import bsg_vscale_pkg::*;

  ( input clk_i
   ,input reset_i
   ,input stall_i

   // htif
   ,input                         htif_id_i
   ,input                         htif_pcr_req_valid_i
   ,output                        htif_pcr_req_ready_o
   ,input                         htif_pcr_req_rw_i
   ,input  [csr_addr_width_p-1:0] htif_pcr_req_addr_i
   ,input  [htif_pcr_width_p-1:0] htif_pcr_req_data_i
   ,output                        htif_pcr_resp_valid_o
   ,input                         htif_pcr_resp_ready_i
   ,output [htif_pcr_width_p-1:0] htif_pcr_resp_data_o
   ,input                         htif_ipi_req_ready_i
   ,output                        htif_ipi_req_valid_o
   ,output                        htif_ipi_req_data_o
   ,output                        htif_ipi_resp_ready_o
   ,input                         htif_ipi_resp_valid_i
   ,input                         htif_ipi_resp_data_i
   ,output                        htif_debug_stats_pcr_o

   // to banked crossbar
   ,output [1:0]                          m_v_o
   ,output [1:0]                          m_w_o
   ,output [1:0] [haddr_width_p-1:0]      m_addr_o
   ,output [1:0] [hdata_width_p-1:0]      m_data_o
   ,output [1:0] [(hdata_width_p>>3)-1:0] m_mask_o
   ,input  [1:0]                          m_yumi_i
   ,input  [1:0]                          m_v_i
   ,input  [1:0] [hdata_width_p-1:0]      m_data_i
  );

  // vscale core signals
  logic [1:0][haddr_width_p-1:0]  haddr,     haddr_r;
  logic [1:0]                     hwrite,    hwrite_r;
  logic [1:0][hsize_width_p-1:0]  hsize,     hsize_r;
  logic [1:0][hburst_width_p-1:0] hburst,    hburst_r;
  logic [1:0]                     hmastlock, hmastlock_r;
  logic [1:0][hprot_width_p-1:0]  hprot,     hprot_r;
  logic [1:0][htrans_width_p-1:0] htrans,    htrans_r;
  logic [1:0][hdata_width_p-1:0]  hwdata,    hwdata_r;
  logic [1:0][hdata_width_p-1:0]  hrdata,    hrdata_r;
  logic [1:0]                     hready,    hready_r;
  logic [1:0][hresp_width_p-1:0]  hresp,     hresp_r;

  logic stall_r;

  always_ff @(posedge clk_i)
  begin
    if(reset_i)
      stall_r <= 1'b0;
    else
      stall_r <= stall_i;

    if(stall_i & ~stall_r)
      begin
        haddr_r     <= haddr;
        hwrite_r    <= hwrite;
        hsize_r     <= hsize;
        hburst_r    <= hburst;
        hmastlock_r <= hmastlock;
        hprot_r     <= hprot;
        htrans_r    <= htrans;
        hwdata_r    <= hwdata;
        hrdata_r    <= hrdata;
        hready_r    <= hready;
        hresp_r     <= hresp;
      end
  end


   // synopsys translate off
   always_comb
	assert(hwrite[0] != 1) else $display("imem should never write");
   // synopsys translate on

  vscale_core vscale( .clk                   (clk_i)
                     ,.imem_haddr            (haddr[0])
                     ,.imem_hwrite           (hwrite[0])
                     ,.imem_hsize            (hsize[0])
                     ,.imem_hburst           (hburst[0])
                     ,.imem_hmastlock        (hmastlock[0])
                     ,.imem_hprot            (hprot[0])
                     ,.imem_htrans           (htrans[0])
                     ,.imem_hwdata           (hwdata[0])
                     ,.imem_hrdata           (stall_r ? hrdata_r[0] : hrdata[0])
                     ,.imem_hready           ((stall_r & ~stall_i) ? hready_r[0] : (~stall_i & hready[0]))
                     ,.imem_hresp            (stall_r ? hresp_r[0] : hresp[0])
                     ,.dmem_haddr            (haddr[1])
                     ,.dmem_hwrite           (hwrite[1])
                     ,.dmem_hsize            (hsize[1])
                     ,.dmem_hburst           (hburst[1])
                     ,.dmem_hmastlock        (hmastlock[1])
                     ,.dmem_hprot            (hprot[1])
                     ,.dmem_htrans           (htrans[1])
                     ,.dmem_hwdata           (hwdata[1])
                     ,.dmem_hrdata           (stall_r ? hrdata_r[1] : hrdata[1])
                     ,.dmem_hready           ((stall_r & ~stall_i) ? hready_r[1] : (~stall_i & hready[1]))
                     ,.dmem_hresp            (stall_r ? hresp_r[1] : hresp[1])
                     ,.htif_reset            (reset_i)
                     ,.htif_id               (htif_id_i)
                     ,.htif_pcr_req_valid    (htif_pcr_req_valid_i)
                     ,.htif_pcr_req_ready    (htif_pcr_req_ready_o)
                     ,.htif_pcr_req_rw       (htif_pcr_req_rw_i)
                     ,.htif_pcr_req_addr     (htif_pcr_req_addr_i)
                     ,.htif_pcr_req_data     (htif_pcr_req_data_i)
                     ,.htif_pcr_resp_valid   (htif_pcr_resp_valid_o)
                     ,.htif_pcr_resp_ready   (htif_pcr_resp_ready_i)
                     ,.htif_pcr_resp_data    (htif_pcr_resp_data_o)
                     ,.htif_ipi_req_ready    (htif_ipi_req_ready_i)
                     ,.htif_ipi_req_valid    (htif_ipi_req_valid_o)
                     ,.htif_ipi_req_data     (htif_ipi_req_data_o)
                     ,.htif_ipi_resp_ready   (htif_ipi_resp_ready_o)
                     ,.htif_ipi_resp_valid   (htif_ipi_resp_valid_i)
                     ,.htif_ipi_resp_data    (htif_ipi_resp_data_i)
                     ,.htif_debug_stats_pcr  (htif_debug_stats_pcr_o)
                    );

  bsg_vscale_hasti_converter hasti_converter
    ( .clk_i       (clk_i)
     ,.reset_i     (reset_i)
     ,.haddr_i     (stall_r ? haddr_r     : haddr)
     ,.hwrite_i    (stall_r ? hwrite_r    : hwrite)
     ,.hsize_i     (stall_r ? hsize_r     : hsize)
     ,.hburst_i    (stall_r ? hburst_r    : hburst)
     ,.hmastlock_i (stall_r ? hmastlock_r : hmastlock)
     ,.hprot_i     (stall_r ? hprot_r     : hprot)
     ,.htrans_i    (stall_i ? {2{htrans_idle_p}} : (stall_r ? htrans_r : htrans))
     ,.hwdata_i    (stall_r ? hwdata_r    : hwdata)
     ,.hrdata_o    (hrdata)
     ,.hready_o    (hready)
     ,.hresp_o     (hresp)
     ,.m_v_o       (m_v_o   )
     ,.m_w_o       (m_w_o   )
     ,.m_addr_o    (m_addr_o)
     ,.m_data_o    (m_data_o)
     ,.m_mask_o    (m_mask_o)
     ,.m_yumi_i    (m_yumi_i)
     ,.m_v_i       (m_v_i   )
     ,.m_data_i    (m_data_i)
    );

endmodule
