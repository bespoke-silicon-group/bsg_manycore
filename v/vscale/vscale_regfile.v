`include "rv32_opcodes.vh"

module vscale_regfile(
                      input                       clk,
                      input [`REG_ADDR_WIDTH-1:0] ra1,
                      output [`XPR_LEN-1:0]       rd1,
                      input [`REG_ADDR_WIDTH-1:0] ra2,
                      output [`XPR_LEN-1:0]       rd2,
                      input                       wen,
                      input [`REG_ADDR_WIDTH-1:0] wa,
                      input [`XPR_LEN-1:0]        wd
                      );

   wire [`XPR_LEN-1:0]                            rd1_lo, rd2_lo;

   assign rd1 = |ra1 ? rd1_lo : 0;
   assign rd2 = |ra2 ? rd2_lo : 0;

   bsg_mem_2r1w #(.width_p(`XPR_LEN)
                  ,.els_p(32)
                  ,.read_write_same_addr_p(1)
                  ) rf
     (.w_clk_i(clk)
      ,.w_reset_i(1'b0)

      ,.w_v_i   (wen & (|wa))
      ,.w_addr_i(wa)
      ,.w_data_i(wd)

      ,.r0_v_i   (|ra1)
      ,.r0_addr_i(ra1)
      ,.r0_data_o(rd1_lo)

      ,.r1_v_i   (|ra2)
      ,.r1_addr_i(ra2)
      ,.r1_data_o(rd2_lo)
      );

endmodule // vscale_regfile
