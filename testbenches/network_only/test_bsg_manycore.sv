
module test_bsg_manycore;

  // clock and reset generation
  wire clk;
  wire reset;
   localparam cycle_time_lp = 50;

   bsg_nonsynth_clock_gen #( .cycle_time_p(cycle_time_lp)
                             ) clock_gen
     ( .o(clk)
       );

  bsg_nonsynth_reset_gen #(  .num_clocks_p     (1)
                           , .reset_cycles_lo_p(1)
                           , .reset_cycles_hi_p(10)
                          )  reset_gen
                          (  .clk_i        (clk)
                           , .async_reset_o(reset)
                          );

   // instantiate synthesizeable ADN example

   adn_example adn (.clk_i(clk)
                    ,.reset_i(reset)
                    );

   // terminate if things are running too long
   initial
     begin
        #500000
       $finish;

     end
endmodule
