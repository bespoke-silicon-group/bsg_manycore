//====================================================================
// bsg_manycore_ram_model.v
// 11/14/2018, shawnless.xie@gmail.com
//====================================================================
// This module serves a generic 1rw ram module that can connect to bsg_manycore
// directly.
`include "bsg_manycore_packet.vh"

module bsg_manycore_ram_model#(
  parameter x_cord_width_p= "inv"
  , parameter y_cord_width_p= "inv"
  , parameter data_width_p= 32
  , parameter addr_width_p= 26 
  , parameter load_id_width_p= 5
  , parameter els_p= 1024 //els_p must <= 2**addr_width_p

  , parameter self_reset_p = 0

  , localparam mask_width_lp=(data_width_p>>3)
  , localparam packet_width_lp=
    `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  , localparam return_packet_width_lp=
    `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p,load_id_width_p)
  , localparam bsg_manycore_link_sif_width_lp=
    `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    // mesh network
    , input [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output logic [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  localparam  mem_addr_width_lp = $clog2(els_p);
  ////////////////////////////////////////////////////////////////
  // instantiate the endpoint standard

  logic in_yumi_li;
  logic returning_v_r, returning_v_n;
  logic [data_width_p-1:0] read_data_r;

  logic in_v_lo;
  logic [data_width_p-1:0] in_data_lo;
  logic [mask_width_lp-1:0] in_mask_lo;
  logic [addr_width_p-1:0] in_addr_lo;
  logic in_we_lo;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.fifo_els_p(4)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.max_out_credits_p(16)
  ) ram_endpoint (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    // mesh network
    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)
    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)

    // local incoming data interface
    ,.in_v_o         ( in_v_lo    )
    ,.in_yumi_i      ( in_yumi_li )
    ,.in_data_o      ( in_data_lo )
    ,.in_mask_o      ( in_mask_lo ) 
    ,.in_addr_o      ( in_addr_lo )
    ,.in_we_o        ( in_we_lo   )
    ,.in_src_x_cord_o(            )
    ,.in_src_y_cord_o(            )

    // The memory read value
    ,.returning_data_i  ( read_data_r   )
    ,.returning_v_i     ( returning_v_r )

    // local outgoing data interface (does not include credits)
    // Tied up all the outgoing signals
    ,.out_v_i           ( 1'b0                )
    ,.out_packet_i      ( packet_width_lp'(0) )
    ,.out_ready_o       (                     )
   // local returned data interface
   // Like the memory interface, processor should always ready be to
   // handle the returned data
    ,.returned_data_r_o     (    )
    ,.returned_load_id_r_o  (    )
    ,.returned_v_r_o        (    )
    ,.returned_fifo_full_o  (    )
    ,.returned_yumi_i       (1'b0)

    ,.out_credits_o()
  );

  logic mem_v_li;
  logic mem_w_li;
  logic [mem_addr_width_lp-1:0] mem_addr_li;
  logic [data_width_p-1:0] mem_data_li;
  logic [mask_width_lp-1:0] mem_mask_li;

  bsg_mem_1rw_sync_mask_write_byte #(
    .els_p(els_p)
    ,.data_width_p(data_width_p)
  ) mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(mem_v_li)
    ,.w_i(mem_w_li)

    ,.addr_i(mem_addr_li)
    ,.data_i(mem_data_li)
    ,.write_mask_i(mem_mask_li)

    ,.data_o(read_data_r)
  );
//in_addr_lo[0+:mem_addr_width_lp]
  typedef enum logic [1:0] {
    RESET
    ,CLEAR_MEM
    ,READY
  } dram_state_e;

  dram_state_e dram_state_r, dram_state_n;
  logic [mem_addr_width_lp-1:0] clear_mem_count_r, clear_mem_count_n;

  always_comb begin
    mem_v_li = 1'b0;
    mem_w_li = 1'b0;
    in_yumi_li = 1'b0;
    mem_addr_li = '0;
    mem_data_li = '0;
    mem_mask_li = '0;
    clear_mem_count_n = clear_mem_count_r;
    dram_state_n = dram_state_r;
    returning_v_n = returning_v_r;

    case (dram_state_r)
      RESET: begin
        dram_state_n = CLEAR_MEM;
        clear_mem_count_n = '0;
      end
  
      CLEAR_MEM: begin
        mem_v_li = 1'b1;
        mem_w_li = 1'b1;
        mem_addr_li = clear_mem_count_r;
        mem_data_li = '0;
        mem_mask_li = {mask_width_lp{1'b1}};
        clear_mem_count_n = clear_mem_count_r + 1;
        dram_state_n = (clear_mem_count_r == els_p-1)
          ? READY
          : CLEAR_MEM;
      end
    
      READY: begin
        mem_v_li = in_v_lo;
        mem_w_li = in_we_lo;
        mem_addr_li = in_addr_lo[0+:mem_addr_width_lp];
        mem_data_li = in_data_lo;
        mem_mask_li = in_mask_lo;
        dram_state_n = READY;
        in_yumi_li = in_v_lo;
        returning_v_n = in_v_lo;
      end

      default: begin
        dram_state_n = self_reset_p
          ? RESET
          : READY;
      end
    endcase
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      returning_v_r <= 1'b0;
      dram_state_r <= self_reset_p
        ? RESET
        : READY;
      clear_mem_count_r <= '0;
    end
    else begin
      returning_v_r <= returning_v_n;
      dram_state_r <= dram_state_n;
      clear_mem_count_r <= clear_mem_count_n;
    end
  end
        
  //synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (in_addr_lo >= els_p) begin
      $error("Address exceed the memory range: in_addr =%h (words), mem range:%x, %m", in_addr_lo, els_p);
      $finish();
    end
  end
  //synopsys translate_on

endmodule
