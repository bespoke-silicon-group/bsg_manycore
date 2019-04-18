//====================================================================
// rf_2r1w_sync_wrapper.v
// 11/02/2016, shawnless.xie@gmail.com
//====================================================================

// This module instantiate a 2r1w sync memory file and add a bypass
// register. When there is a write and read and the same time, it output
// the newly written value, which is "write through"

module rf_2r1w_sync_wrapper
  #(parameter width_p = "inv"
    , parameter els_p = "inv"

    , localparam addr_width_lp = `BSG_SAFE_CLOG2(els_p)
  )
  ( 
    input clk_i
    , input reset_i

    , input w_v_i
    , input [addr_width_lp-1:0] w_addr_i
    , input [width_p-1:0] w_data_i

    , input r0_v_i
    , input [addr_width_lp-1:0] r0_addr_i
    , output logic [width_p-1:0] r0_data_o

    , input r1_v_i
    , input [addr_width_lp-1:0] r1_addr_i
    , output logic [width_p-1:0] r1_data_o
  );

  // if we are reading and writing to the same register, we want to read the
  // value being written and prevent reading from rf_mem..
  // if we are reading or writing x0, then we don't want to do anything.

  logic r0_rw_same_addr;
  logic r1_rw_same_addr;
  logic r0_v_li;
  logic r1_v_li;
  logic w_v_li;
  logic [width_p-1:0] r0_data_lo;
  logic [width_p-1:0] r1_data_lo;

  assign r0_rw_same_addr = w_v_i & r0_v_i & (w_addr_i == r0_addr_i);
  assign r1_rw_same_addr = w_v_i & r1_v_i & (w_addr_i == r1_addr_i);

  assign r0_v_li = r0_rw_same_addr
    ? 1'b0
    : r0_v_i & (r0_addr_i != '0);

  assign r1_v_li = r1_rw_same_addr
    ? 1'b0
    : r1_v_i & (r1_addr_i != '0);

  assign w_v_li = w_v_i & (w_addr_i != '0);

  bsg_mem_2r1w_sync #(
    .width_p(width_p)
    ,.els_p(els_p)
    ,.addr_width_lp(addr_width_lp)
    ,.read_write_same_addr_p(1'b1)
  ) rf_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.w_v_i(w_v_li)
    ,.w_addr_i(w_addr_i)
    ,.w_data_i(w_data_i)

    ,.r0_v_i(r0_v_li)
    ,.r0_addr_i(r0_addr_i)
    ,.r0_data_o(r0_data_lo)

    ,.r1_v_i(r1_v_li)
    ,.r1_addr_i(r1_addr_i)
    ,.r1_data_o(r1_data_lo)
  );

  // we want to remember which registers we read last time, and we want to
  // hold the last read value until the new location is read, or the new value is
  // written to that location.

  logic [width_p-1:0] w_data_r, w_data_n;
  logic [width_p-1:0] r0_data_r, r0_data_n;
  logic [width_p-1:0] r1_data_r, r1_data_n;
  logic [addr_width_lp-1:0] r0_addr_r, r0_addr_n;
  logic [addr_width_lp-1:0] r1_addr_r, r1_addr_n;
  logic r0_rw_same_addr_r;
  logic r1_rw_same_addr_r;
  logic r0_v_r;
  logic r1_v_r;

  logic [width_p-1:0] r0_safe_data;
  logic [width_p-1:0] r1_safe_data;

  // combinational logic
  //
  assign r0_safe_data = r0_rw_same_addr_r
    ? w_data_r
    : r0_data_lo;

  assign r1_safe_data = r1_rw_same_addr_r
    ? w_data_r
    : r1_data_lo;

  assign r0_addr_n = r0_v_i
      ? r0_addr_i
      : r0_addr_r;

  assign r1_addr_n = r1_v_i
      ? r1_addr_i
      : r1_addr_r;

  assign r0_data_n = (w_v_i & (r0_addr_r == w_addr_i))
    ? w_data_i
    : (r0_v_r ? r0_safe_data : r0_data_r);

  assign r1_data_n = (w_v_i & (r1_addr_r == w_addr_i))
    ? w_data_i
    : (r1_v_r ? r1_safe_data : r1_data_r);
   
  assign w_data_n = (r0_rw_same_addr | r1_rw_same_addr)
    ? w_data_i
    : w_data_r;

  assign r0_data_o = (r0_addr_r == '0)
    ? '0
    : (r0_v_r ? r0_safe_data : r0_data_r);

  assign r1_data_o = (r1_addr_r == '0)
    ? '0
    : (r1_v_r ? r1_safe_data : r1_data_r);

  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      r0_rw_same_addr_r <= 1'b0;
      r1_rw_same_addr_r <= 1'b0;
      r0_v_r <= 1'b0;
      r1_v_r <= 1'b0;
      //r0_addr_r <= '0;
      //r1_addr_r <= '0;
    end
    else begin
      r0_rw_same_addr_r <= r0_rw_same_addr;
      r1_rw_same_addr_r <= r1_rw_same_addr;
      r0_v_r <= r0_v_i;
      r1_v_r <= r1_v_i;
      w_data_r <= w_data_n;
      r0_data_r <= r0_data_n;
      r1_data_r <= r1_data_n;
      r0_addr_r <= r0_addr_n;
      r1_addr_r <= r1_addr_n;
    end
  end

endmodule

