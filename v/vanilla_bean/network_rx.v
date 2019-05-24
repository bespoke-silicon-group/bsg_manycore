/**
 *    network_rx.v
 *
 */


module network_rx 
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter dmem_size_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter epa_byte_addr_width_p="inv"

    , parameter tgo_x_init_val_p = 0
    , parameter tgo_y_init_val_p = 1
    , parameter freeze_init_val_p = 1
    , parameter default_pc_init_val = 0

    , localparam epa_word_addr_width_lp=(epa_byte_addr_width_p-2)
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam dmem_addr_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam pc_width_lp=(icache_entries_p+icache_addr_width_lp)
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
    , output logic yumi_o

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
    , output logic [x_cord_width_p-1:0] tgo_x_o
    , output logic [y_cord_width_p-1:0] tgo_y_o 
    , output logic [pc_width_lp-1:0] pc_init_val_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );


  // address decoding
  //
  logic is_dmem_addr;
  logic is_icache_addr;

  logic is_csr_addr;
  logic is_freeze_addr;
  logic is_tgo_x_addr;
  logic is_tgo_y_addr;
  logic is_pc_init_val_addr;
  
  assign is_dmem_addr = addr_i[addr_width_p-1:dmem_addr_width_lp] == '1;
  assign is_icache_addr = addr_i[addr_width_p-1:pc_width_lp] == '1;

  assign is_csr_addr = addr_i[addr_width_p-1:epa_word_addr_width_lp-1] == '1;
  assign is_freeze_addr = is_csr_addr & (addr_i[epa_word_addr_width_lp-2:0] == '0);
  assign is_tgo_x_addr = is_csr_addr & (addr_i[epa_word_addr_width_lp-2:0] == '1);
  assign is_tgo_y_addr = is_csr_addr & (addr_i[epa_word_addr_width_lp-2:0] == '2);
  assign is_pc_init_val_addr = is_csr_addr & (addr_i[epa_word_addr_width_lp-2:0] == '3);


  // CSR registers
  //
  logic freeze_r;
  logic [x_cord_width_p-1:0] tgo_x_r;
  logic [y_cord_width_p-1:0] tgo_y_r;
  logic [pc_width_lp-1:0] pc_init_val_r;

  assign freeze_o = freeze_r;
  assign tgo_x_o = tgo_x_r;
  assign tgo_y_o = tgo_y_r;
  assign pc_init_val_o = pc_init_val_r;

  // incoming request handling logic
  //
  logic freeze_n;
  logic [x_cord_width_p-1:0] tgo_x_n;
  logic [y_cord_width_p-1:0] tgo_y_n;
  logic [pc_width_lp-1:0] pc_init_val_n;

  logic send_dmem_data_r, send_dmem_data_n;
  logic send_freeze_r, send_freeze_n;
  logic send_tgo_x_r, send_tgo_x_n;
  logic send_tgo_y_r, send_tgo_y_n;
  logic send_pc_init_val_r, send_pc_init_val_n;
  logic send_invalid_r, send_invalid_n;
  logic send_zero_r, send_zero_n;


  always_comb begin

    freeze_n = freeze_r;
    tgo_x_n = tgo_x_r;
    tgo_y_n = tgo_y_r;
    pc_init_val_n = pc_init_val_r;

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

    icache_v_o = 1'b0;
    icache_pc_o = addr_i[0+:pc_width_lp];
    icache_instr_o = data_i;
    
    yumi_o = 1'b0;


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
          tgo_x_n = data_i[0+:x_cord_width_p];
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else if (is_tgo_y_addr) begin
          tgo_y_n = data_i[0+:y_cord_width_p];
          yumi_o = 1'b1;
          send_zero_n = 1'b1;
        end
        else if (is_pc_init_val_addr) begin
          pc_init_val_n = data_i[2+:pc_width_lp];
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
        else begin
          yumi_o = 1'b1;
          send_invalid_n = 1'b1;
        end
      end
    end
  end

  // response logic
  //
  always_comb begin
    returning_data_v_o = send_dmem_data_r
      | send_freeze_r
      | send_tgo_x_r
      | send_tgo_y_r
      | send_pc_init_val_r
      | send_invalid_r
      | send_zero_r;
      
    if (send_dmem_data_r) begin
      returning_data_o = remote_dmem_data_i;
    end
    else if (send_freeze_r) begin
      returning_data_o = {{(data_width_p-1){1'b0}}, freeze_r};
    end
    else if (send_tgo_x_r) begin
      returning_data_o = {{(data_width_p-x_cord_width_p){1'b0}}, tgo_x_r};
    end
    else if (send_tgo_y_r) begin
      returning_data_o = {{(data_width_p-y_cord_width_p){1'b0}}, tgo_y_r};
    end
    else if (send_pc_init_val_r) begin
      returning_data_o = {{(data_width_p-pc_width_lp-2){1'b0}}, tgo_y_r, 2'b00};
    end
    else if (send_zero_r) begin
      returning_data_o = '0;
    end
    else if (send_invalid_r) begin
      returning_data_o = 'hdead_beef;
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
      tgo_x_r <= (x_cord_width_p)'(tgo_x_init_val_p);
      tgo_y_r <= (y_cord_width_p)'(tgo_y_init_val_p);
      pc_init_val_r <= (pc_width_lp)'(default_pc_init_val_p);

      send_dmem_data_r <= 1'b0;
      send_freeze_r <= 1'b0;
      send_tgo_x_r <= 1'b0;
      send_tgo_y_r <= 1'b0;
      send_pc_init_val_r <= 1'b0;
      send_invalid_r <= 1'b0;
      send_zero_r <= 1'b0;
    end
    else begin
      freeze_r <= freeze_n;
      tgo_x_r <= tgo_x_n;
      tgo_y_r <= tgo_y_n;
      pc_init_val_r <= pc_init_val_n;

      send_dmem_data_r <= send_dmem_data_n;
      send_freeze_r <= send_freeze_n;
      send_tgo_x_r <= send_tgo_x_n;
      send_tgo_y_r <= send_tgo_y_n;
      send_pc_init_val_r <= send_pc_init_val_n;
      send_invalid_r <= send_invalid_n;
      send_zero_r <= send_zero_n;
    end
  end


  // synopsys translate_off

  logic is_invalid_csr_addr;
  logic is_invalid_addr;

  assign is_invalid_csr_addr = is_csr_addr & 
    ~(is_freeze_addr | is_tgo_x_addr | is_tgo_y_addr | is_pc_init_val_addr);
  assign is_invalid_addr = ~(is_dmem_addr | is_icache_addr)  | is_invalid_csr_addr;

  always_ff @ (negedge clk_i) begin

    if (v_i & is_invalid_addr) begin
      $display("accessing invalid EPA. x=%d, y=%d, we=%d, addr=%h, data=%h",
        my_x_i, my_y_i, w_i, addr_i, data_i
      );
    end

  end
  // synopsys translate_on

endmodule
