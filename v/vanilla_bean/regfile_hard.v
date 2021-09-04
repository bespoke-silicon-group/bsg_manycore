//====================================================================
// regfile_hard.v
// 11/02/2016, shawnless.xie@gmail.com
// 05/08/2020, Tommy J - Adding FMA support
//====================================================================

// This module instantiate a 2r1w (or 3r1w) sync memory file and add a bypass
// register. When there is a write and read and the same time, it output
// the newly written value, which is "write through"

`include "bsg_defines.v"

module regfile_hard
  #(`BSG_INV_PARAM(width_p )
    , `BSG_INV_PARAM(els_p )
    , `BSG_INV_PARAM(num_rs_p ) // number of read ports. only supports 2 and 3.
    , parameter x0_tied_to_zero_p=0
    , localparam addr_width_lp = `BSG_SAFE_CLOG2(els_p)
  )
  ( 
    input clk_i
    , input reset_i

    , input w_v_i
    , input [addr_width_lp-1:0] w_addr_i
    , input [width_p-1:0] w_data_i

    , input [num_rs_p-1:0] r_v_i
    , input [num_rs_p-1:0][addr_width_lp-1:0] r_addr_i
    , output logic [num_rs_p-1:0][width_p-1:0] r_data_o
  );

  // synopsys translate_off
  initial begin
    assert(num_rs_p == 2 || num_rs_p == 3)
      else $error("num_rs_p can be either 2 or 3 only.");
  end
  // synopsys translate_on


  // if we are reading and writing to the same register, we want to read the
  // value being written and prevent reading from rf_mem..
  // if we are reading or writing x0, then we don't want to do anything.

  logic [num_rs_p-1:0] rw_same_addr;
  logic [num_rs_p-1:0] r_v_li;
  logic [num_rs_p-1:0][width_p-1:0] r_data_lo;
  logic w_v_li;

  for (genvar i = 0; i < num_rs_p; i++) begin
    assign rw_same_addr[i] = w_v_i & r_v_i[i] & (w_addr_i == r_addr_i[i]);
    assign r_v_li[i] = rw_same_addr[i]
      ? 1'b0
      : r_v_i[i] & ((x0_tied_to_zero_p == 0) | r_addr_i[i] != '0);
  end

  assign w_v_li = w_v_i & ((x0_tied_to_zero_p == 0) | w_addr_i != '0);

  if (num_rs_p == 2) begin: rf2
    bsg_mem_2r1w_sync #(
      .width_p(width_p)
      ,.els_p(els_p)
    ) rf_mem2 (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.w_v_i(w_v_li)
      ,.w_addr_i(w_addr_i)
      ,.w_data_i(w_data_i)

      ,.r0_v_i(r_v_li[0])
      ,.r0_addr_i(r_addr_i[0])
      ,.r0_data_o(r_data_lo[0])

      ,.r1_v_i(r_v_li[1])
      ,.r1_addr_i(r_addr_i[1])
      ,.r1_data_o(r_data_lo[1])
    );
  end
  else if (num_rs_p == 3) begin: rf3
    bsg_mem_3r1w_sync #(
      .width_p(width_p)
      ,.els_p(els_p)
    ) rf_mem3 (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.w_v_i(w_v_li)
      ,.w_addr_i(w_addr_i)
      ,.w_data_i(w_data_i)

      ,.r0_v_i(r_v_li[0])
      ,.r0_addr_i(r_addr_i[0])
      ,.r0_data_o(r_data_lo[0])

      ,.r1_v_i(r_v_li[1])
      ,.r1_addr_i(r_addr_i[1])
      ,.r1_data_o(r_data_lo[1])

      ,.r2_v_i(r_v_li[2])
      ,.r2_addr_i(r_addr_i[2])
      ,.r2_data_o(r_data_lo[2])
    );
  end

  // we want to remember which registers we read last time, and we want to
  // hold the last read value until the new location is read, or the new value is
  // written to that location.

  logic [width_p-1:0] w_data_r, w_data_n;
  logic [num_rs_p-1:0][width_p-1:0] r_data_r, r_data_n;
  logic [num_rs_p-1:0][addr_width_lp-1:0] r_addr_r, r_addr_n;
  logic [num_rs_p-1:0] rw_same_addr_r;
  logic [num_rs_p-1:0] r_v_r;
  logic [num_rs_p-1:0][width_p-1:0] r_safe_data;
  

  // combinational logic
  //
  for (genvar i = 0; i < num_rs_p; i++) begin
    assign r_safe_data[i] = rw_same_addr_r[i]
      ? w_data_r
      : r_data_lo[i];

    assign r_addr_n[i] = r_v_i[i]
      ? r_addr_i[i]
      : r_addr_r[i];

    assign r_data_n[i] = (w_v_i & (r_addr_r[i] == w_addr_i))
      ? w_data_i
      : (r_v_r[i] ? r_safe_data[i] : r_data_r[i]);

    assign r_data_o[i] = ((r_addr_r[i] == '0) & (x0_tied_to_zero_p == 1))
      ? '0
      : (r_v_r[i] ? r_safe_data[i] : r_data_r[i]);
  end

  assign w_data_n = (|rw_same_addr)
    ? w_data_i
    : w_data_r;

  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
       rw_same_addr_r <= '0;
       r_v_r <= '0;

       // MBT: added to be more reset conservative
       w_data_r  <= '0;
       r_data_r <= '0;
       r_addr_r <= '0;
    end
    else begin
      rw_same_addr_r <= rw_same_addr;
      rw_same_addr_r <= rw_same_addr;
      r_v_r <= r_v_i;
      w_data_r <= w_data_n;
      r_data_r <= r_data_n;
      r_addr_r <= r_addr_n;
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(regfile_hard)

