`include "definitions.vh"
`include "parameters.vh"


module testbench();


  logic clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(10)
  ) clock_gen ( 
    .o(clk)
  );
  
  logic reset;
  bsg_nonsynth_reset_gen #(
    .reset_cycles_lo_p(4)
    ,.reset_cycles_hi_p(4)
  ) reset_gen (
    .clk_i(clk)
    ,.async_reset_o(reset)
  );

  logic v_li;
  fp_decode_s fp_decode;
  logic [31:0] a_li, b_li;
  logic [4:0] rd_li;
  logic ready_lo;
  
  logic v_lo;
  logic [31:0] z_lo;
  logic [4:0] rd_lo;
  logic yumi_li;

  fpu_float DUT (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.v_i(v_li)
    ,.fp_decode_i(fp_decode)
    ,.a_i(a_li)
    ,.b_i(b_li)
    ,.rd_i(rd_li)
    ,.ready_o(ready_lo)

    ,.v_o(v_lo)
    ,.z_o(z_lo)
    ,.rd_o(rd_lo)
    ,.yumi_i(yumi_li)
  );

  // input:
  // fp_decode_i  = 18
  // rd_i         = 5
  // a_i          = 32
  // b_i          = 32
  //
  // output:
  // rd_o         = 5
  // z_o          = 32
  //
  localparam ring_width_p = 18+32+32+5;
  localparam rom_addr_width_p = 10;

  logic [ring_width_p-1:0] tr_data_li, tr_data_lo;
  logic tr_ready_lo;
  logic tr_v_lo;
  logic tr_yumi_li;

  logic [rom_addr_width_p-1:0] rom_addr;
  logic [ring_width_p+4-1:0] rom_data;
  logic tr_done_lo;

  bsg_fsb_node_trace_replay #(
    .ring_width_p(ring_width_p)
    ,.rom_addr_width_p(rom_addr_width_p)
  ) tr (
    .clk_i(clk)
    ,.reset_i(reset)
    ,.en_i(1'b1)

    ,.v_i(v_lo)
    ,.data_i(tr_data_li)
    ,.ready_o(tr_ready_lo)

    ,.v_o(tr_v_lo)
    ,.data_o(tr_data_lo)
    ,.yumi_i(tr_yumi_li)
    
    ,.rom_addr_o(rom_addr)
    ,.rom_data_i(rom_data)

    ,.done_o(tr_done_lo)
    ,.error_o()
  );

  assign v_li = tr_v_lo;
  assign tr_yumi_li = tr_v_lo & ready_lo;
  assign yumi_li = v_lo & tr_ready_lo;

  assign {fp_decode, rd_li, a_li, b_li} = tr_data_lo;
  assign tr_data_li = {{(ring_width_p-5-32){1'b0}}, rd_lo, z_lo};

  bsg_trace_rom #(
    .width_p(ring_width_p+4)
    ,.addr_width_p(rom_addr_width_p)
  ) trace_rom (
    .addr_i(rom_addr)
    ,.data_o(rom_data) 
  );


  initial begin
//    wait(tr_done_lo);
    for (integer i = 0; i < 200; i++) begin
      @(posedge clk);
    end
    $finish;
  end 




endmodule
