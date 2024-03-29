/**
 *    network_rx.v
 *
 *    This handles receiving remote packets, and sending out responses.
 */

`include "bsg_manycore_defines.svh"

module network_rx 
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(dmem_size_p)
    , `BSG_INV_PARAM(icache_tag_width_p)
    , `BSG_INV_PARAM(icache_entries_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(x_subcord_width_p)
    , `BSG_INV_PARAM(y_subcord_width_p)

    , tgo_x_init_val_p = 0
    , tgo_y_init_val_p = 0
    , freeze_init_val_p = 1
    , default_pc_init_val_p = 0

    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
  )
  (
    input clk_i
    , input reset_i

    // network side
    , input v_i
    , input w_i
    , input [addr_width_p-1:0] addr_i
    , input [data_width_p-1:0] data_i
    , input [data_mask_width_lp-1:0] mask_i
    , input bsg_manycore_load_info_s load_info_i
    , output logic yumi_o
    , input [x_cord_width_p-1:0] src_x_cord_debug_i
    , input [y_cord_width_p-1:0] src_y_cord_debug_i   
   
    , output logic [data_width_p-1:0] returning_data_o
    , output logic returning_data_v_o

    // core side
    , output logic remote_dmem_v_o
    , output logic remote_dmem_w_o
    , output logic [dmem_addr_width_lp-1:0] remote_dmem_addr_o
    , output logic [data_mask_width_lp-1:0] remote_dmem_mask_o
    , output logic [data_width_p-1:0] remote_dmem_data_o
    , input [data_width_p-1:0] remote_dmem_data_i
    , input remote_dmem_yumi_i

    , output logic icache_v_o
    , output logic [pc_width_lp-1:0] icache_pc_o
    , output logic [data_width_p-1:0] icache_instr_o
    , input icache_yumi_i

    , output logic freeze_o
    , output logic [x_subcord_width_p-1:0] tgo_x_o
    , output logic [y_subcord_width_p-1:0] tgo_y_o 
    , output logic [pc_width_lp-1:0] pc_init_val_o

    // remote interrupt to core
    , output logic remote_interrupt_set_o
    , output logic remote_interrupt_clear_o

    // remote interrupt from core
    , input remote_interrupt_pending_bit_i

    // for debugging
    , input [x_cord_width_p-1:0] global_x_i
    , input [y_cord_width_p-1:0] global_y_i
  );

  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);


  // address decoding
  // dmem addr space starts from EPA = 0
  wire is_dmem_addr = (addr_i[addr_width_p-1:dmem_addr_width_lp] == '0);
  // icache addr space (1024-entry, 12-bit tag):
  // EPA = 0000_01tt_tttt_tttt_tt??_????_???? (word addr)
  wire is_icache_addr = addr_i[pc_width_lp] & (addr_i[addr_width_p-1:pc_width_lp+1] == '0);

  wire is_csr_addr = addr_i[epa_word_addr_width_gp-1]
    & (addr_i[addr_width_p-1:epa_word_addr_width_gp] == '0);
  wire is_freeze_addr = is_csr_addr & (addr_i[epa_word_addr_width_gp-2:0] == 'd0);
  wire is_tgo_x_addr = is_csr_addr & (addr_i[epa_word_addr_width_gp-2:0] == 'd1);
  wire is_tgo_y_addr = is_csr_addr & (addr_i[epa_word_addr_width_gp-2:0] == 'd2);
  wire is_pc_init_val_addr = is_csr_addr & (addr_i[epa_word_addr_width_gp-2:0] == 'd3);
  

  // Remote interrupt pending bit (mip.remote)
  // For write, the write enable signal is sent to the core for one cycle.
  // writing 1 sets the mip.remote.
  // writing 0 clears the mip.remote.
  // This can be also read by the remote packet.
  // This bit can also be modified by the vanilla core using csr instructions.
  // When a remote packet and csr instr both tries to modify mip.remote, the remote packet has higher priority.
  // EPA (word) = 3fff
  wire is_remote_interrupt_addr = (addr_i == 'h3fff);


  // CSR registers
  //
  logic freeze_r;
  logic [x_subcord_width_p-1:0] tgo_x_r;
  logic [y_subcord_width_p-1:0] tgo_y_r;
  logic [pc_width_lp-1:0] pc_init_val_r;

  assign freeze_o = freeze_r;
  assign tgo_x_o = tgo_x_r;
  assign tgo_y_o = tgo_y_r;
  assign pc_init_val_o = pc_init_val_r;

  // clock gated CSR dff
  logic pc_init_val_en;
  logic tgo_x_en;
  logic tgo_y_en;

  bsg_dff_reset_en #(
    .width_p(pc_width_lp)
    ,.reset_val_p(default_pc_init_val_p)
  ) pc_init_val_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(pc_init_val_en)
    ,.data_i(data_i[0+:pc_width_lp])
    ,.data_o(pc_init_val_r)
  );

  bsg_dff_reset_en #(
    .width_p(x_subcord_width_p)
    ,.reset_val_p(tgo_x_init_val_p)
  ) tgo_x_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(tgo_x_en)
    ,.data_i(data_i[0+:x_subcord_width_p])
    ,.data_o(tgo_x_r)
  );

  bsg_dff_reset_en #(
    .width_p(y_subcord_width_p)
    ,.reset_val_p(tgo_y_init_val_p)
  ) tgo_y_dff (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(tgo_y_en)
    ,.data_i(data_i[0+:y_subcord_width_p])
    ,.data_o(tgo_y_r)
  );

  // incoming request handling logic
  //
  logic freeze_n;
  logic send_dmem_data_r, send_dmem_data_n;
  logic send_freeze_r, send_freeze_n;
  logic send_tgo_x_r, send_tgo_x_n;
  logic send_tgo_y_r, send_tgo_y_n;
  logic send_pc_init_val_r, send_pc_init_val_n;
  logic send_invalid_r, send_invalid_n;
  logic send_zero_r, send_zero_n;
  logic send_remote_interrupt_r, send_remote_interrupt_n;


  bsg_manycore_load_info_s load_info_r, load_info_n;

  always_comb begin

    freeze_n = freeze_r;

    send_dmem_data_n = 1'b0;
    send_freeze_n = 1'b0;
    send_tgo_x_n = 1'b0;
    send_tgo_y_n = 1'b0;
    send_pc_init_val_n = 1'b0;
    send_invalid_n = 1'b0;
    send_zero_n = 1'b0;

    remote_dmem_v_o = 1'b0;
    remote_dmem_w_o = 1'b0;
    remote_dmem_data_o = data_i;
    remote_dmem_addr_o = addr_i[0+:dmem_addr_width_lp];
    remote_dmem_mask_o = mask_i;

    load_info_n = load_info_r;

    icache_v_o = 1'b0;
    icache_pc_o = addr_i[0+:pc_width_lp];
    icache_instr_o = data_i;
    
    remote_interrupt_clear_o = 1'b0;
    remote_interrupt_set_o = 1'b0;
    send_remote_interrupt_n = 1'b0;
    yumi_o = 1'b0;

    pc_init_val_en = 1'b0;
    tgo_x_en = 1'b0;
    tgo_y_en = 1'b0;


    if (v_i) begin
      if (w_i) begin
        if (is_dmem_addr) begin
          remote_dmem_v_o = 1'b1;
          remote_dmem_w_o = 1'b1;
          yumi_o = remote_dmem_yumi_i;
          send_zero_n = remote_dmem_yumi_i;
        end
        else if (is_icache_addr) begin
          icache_v_o = 1'b1;
          yumi_o = icache_yumi_i;
          send_zero_n = icache_yumi_i;
        end
        else if (is_freeze_addr) begin
          freeze_n = data_i[0];
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else if (is_tgo_x_addr) begin
          tgo_x_en = 1'b1;
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else if (is_tgo_y_addr) begin
          tgo_y_en = 1'b1;
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else if (is_pc_init_val_addr) begin
          pc_init_val_en = 1'b1;
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else if (is_remote_interrupt_addr) begin
          remote_interrupt_clear_o = ~data_i[0];
          remote_interrupt_set_o = data_i[0];
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else begin
          yumi_o = 1'b1;
          send_invalid_n = 1'b1;
        end
      end
      else begin
        if (is_dmem_addr) begin
          remote_dmem_v_o = 1'b1;
          remote_dmem_w_o = 1'b0;
          yumi_o = remote_dmem_yumi_i;
          send_dmem_data_n = remote_dmem_yumi_i;
          load_info_n = remote_dmem_yumi_i
            ? load_info_i
            : load_info_r;
        end
        else if (is_freeze_addr) begin
          yumi_o = 1'b1;
          send_freeze_n = 1'b1;
        end
        else if (is_tgo_x_addr) begin
          yumi_o = 1'b1;
          send_tgo_x_n = 1'b1;
        end
        else if (is_tgo_y_addr) begin
          yumi_o = 1'b1;
          send_tgo_y_n = 1'b1;
        end
        else if (is_pc_init_val_addr) begin
          yumi_o = 1'b1;
          send_pc_init_val_n = 1'b1;
        end
        else if (is_remote_interrupt_addr) begin
          yumi_o = 1'b1;
          send_remote_interrupt_n = 1'b1;
        end
        else begin
          yumi_o = 1'b1;
          send_invalid_n = 1'b1;
        end
      end
    end
  end

  // response logic
  //
  logic [data_width_p-1:0] load_data_lo;
  load_packer lp0 (
    .mem_data_i(remote_dmem_data_i)
    ,.unsigned_load_i(load_info_r.is_unsigned_op)
    ,.byte_load_i(load_info_r.is_byte_op)
    ,.hex_load_i(load_info_r.is_hex_op)
    ,.part_sel_i(load_info_r.part_sel)
    ,.load_data_o(load_data_lo)
  );


  always_comb begin
    returning_data_v_o = send_dmem_data_r
      | send_freeze_r
      | send_tgo_x_r
      | send_tgo_y_r
      | send_pc_init_val_r
      | send_invalid_r
      | send_zero_r
      | send_remote_interrupt_r;
      
    if (send_dmem_data_r) begin
      returning_data_o = load_data_lo;
    end
    else if (send_freeze_r) begin
      returning_data_o = {{(data_width_p-1){1'b0}}, freeze_r};
    end
    else if (send_tgo_x_r) begin
      returning_data_o = {{(data_width_p-x_subcord_width_p){1'b0}}, tgo_x_r};
    end
    else if (send_tgo_y_r) begin
      returning_data_o = {{(data_width_p-y_subcord_width_p){1'b0}}, tgo_y_r};
    end
    else if (send_pc_init_val_r) begin
      returning_data_o = {{(data_width_p-pc_width_lp){1'b0}}, pc_init_val_r};
    end
    else if (send_zero_r) begin
      returning_data_o = '0;
    end
    else if (send_invalid_r) begin
      returning_data_o = 'hdead_beef;
    end
    else if (send_remote_interrupt_r) begin
      returning_data_o = {{(data_width_p-1){1'b0}}, remote_interrupt_pending_bit_i};
    end
    else begin
      returning_data_o = '0;
    end
  end


  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      freeze_r <= (1)'(freeze_init_val_p);

      send_dmem_data_r <= 1'b0;
      send_freeze_r <= 1'b0;
      send_tgo_x_r <= 1'b0;
      send_tgo_y_r <= 1'b0;
      send_pc_init_val_r <= 1'b0;
      send_invalid_r <= 1'b0;
      send_zero_r <= 1'b0;
      send_remote_interrupt_r <= 1'b0;
      load_info_r <= '0;
    end
    else begin
      freeze_r <= freeze_n;

      send_dmem_data_r <= send_dmem_data_n;
      send_freeze_r <= send_freeze_n;
      send_tgo_x_r <= send_tgo_x_n;
      send_tgo_y_r <= send_tgo_y_n;
      send_pc_init_val_r <= send_pc_init_val_n;
      send_invalid_r <= send_invalid_n;
      send_zero_r <= send_zero_n;
      send_remote_interrupt_r <= send_remote_interrupt_n;
      load_info_r <= load_info_n;
    end
  end


  // synopsys translate_off

  logic is_valid_csr_addr;
  logic is_invalid_addr;

  assign is_valid_csr_addr = is_csr_addr & 
    (is_freeze_addr | is_tgo_x_addr | is_tgo_y_addr | is_pc_init_val_addr);
  assign is_invalid_addr = ~(is_dmem_addr | is_icache_addr | is_valid_csr_addr | is_remote_interrupt_addr);

  always_ff @ (negedge clk_i) begin
    if (~reset_i & v_i & is_invalid_addr) begin
      $display("[ERROR][RX] Invalid EPA Access. t=%0t, x=%d, y=%d, src_x=%d, src_y=%d, we=%d, addr=%h, data=%h",
        $time, global_x_i, global_y_i, src_x_cord_debug_i, src_y_cord_debug_i, w_i, addr_i, data_i);
    end

     /*
          // uncomment to trace packets between tiles 
    if (~reset_i & v_i & ~is_invalid_addr) begin
      $display("[INFO][RX] EPA Access. t=%0t, x=%d, y=%d, src_x=%d, src_y=%d, we=%d, addr=%h, data=%h mask=%h",
        $time, global_x_i, global_y_i, src_x_cord_debug_i, src_y_cord_debug_i, w_i, addr_i, data_i, mask_i);
    end
     */
     
    // FREEZE / UNFREEZE 
    if (~reset_i) begin
      if (freeze_n & ~freeze_r)
        $display("[INFO][RX] Freezing tile t=%0t, x=%d, y=%d", $time, global_x_i, global_y_i);
      if (~freeze_n & freeze_r)
        $display("[INFO][RX] Unfreezing tile t=%0t, x=%d, y=%d", $time, global_x_i, global_y_i);
    end


  end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(network_rx)
