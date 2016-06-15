/**
 *  This module describes a 2R1W register file with asynchronous
 *  read and synchronous write. The width of the register file is
 *  parameterized (which is the log of the size).
 */
module reg_file #(parameter addr_width_p = -1)
(
    input                     clk,
    input  [addr_width_p-1:0] rs_addr_i,
    input  [addr_width_p-1:0] rd_addr_i,
    input                     wen_i,
    input                     cen_i,
    input  [addr_width_p-1:0] write_addr_i,
    input  [31:0]             write_data_i,
    output logic [31:0]       rs_val_o,
    output logic [31:0]       rd_val_o
);

logic [31:0] RF [2**addr_width_p-1:0];

always_comb
begin
    if (cen_i) begin
        // RISC-V edit: reg 0 hardwired to 0
        rs_val_o = (|rs_addr_i) ? RF [rs_addr_i] : 32'(0);
        rd_val_o = (|rd_addr_i) ? RF [rd_addr_i] : 32'(0);
    end else begin
        rs_val_o = 32'bx;
        rd_val_o = 32'bx;
    end
end

always_ff @ (posedge clk)
begin
    if (wen_i & cen_i)
        RF [write_addr_i] <= write_data_i;
end

//synopsys translate_off
assert property (@(posedge clk) disable iff (~cen_i)
    ((rs_addr_i || (rs_addr_i==0)) && (rd_addr_i || (rd_addr_i==0))))
  else $error ("undetermined address for register file: %h and %h",rs_addr_i,rd_addr_i);
//synopsys translate_on

// synopsys translate off
// RISC-V edit: Initialize regs with random values
initial
begin
  integer i;
  for(i=0; i<32; i=i+1)
    RF[i] = $random;
end
// synopsys translate on

endmodule

