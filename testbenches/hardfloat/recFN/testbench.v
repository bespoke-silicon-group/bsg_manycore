module testbench();
  
  logic [31:0] in;
  logic [32:0] result;

  fNToRecFN #(
    .expWidth(8)
    ,.sigWidth(24)
  ) DUT (
    .in(in) // canonical NaN
    ,.out(result)
  );

  logic [32:0] in1;
  logic [31:0] result1;
  recFNToFN #(
    .expWidth(8)
    ,.sigWidth(24)
  ) DUT0 (
    .in(in1) // canonical NaN
    ,.out(result1)
  );

  initial begin
    in = 32'h7fc00000;
    in1 = 33'h0bfff_ffff;
    #100;
    $display("canonical NaN = %h", result);

    in = 32'h3f800000;
    #100;
    $display("one = %h", result);

    in = 32'h0;
    #100;
    $display("zero = %h", result);

    #100;
  end

endmodule
