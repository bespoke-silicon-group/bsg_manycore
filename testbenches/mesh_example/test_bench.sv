module test_bench;

localparam addr_width_lp        = 10;
localparam data_width_lp        = 32;
localparam load_id_width_lp     = 11;
localparam x_cord_width_lp      = 2 ;
localparam y_cord_width_lp      = 2 ;
localparam cycle_time_lp = 50;

//the clock and reset
logic clk_li, reset_li, finish_lo;

bsg_nonsynth_clock_gen
        #( .cycle_time_p(cycle_time_lp)
         ) clock_gen
        ( .o(clk_li)
        );

bsg_nonsynth_reset_gen #(  .num_clocks_p     (1)
                         , .reset_cycles_lo_p(1)
                         , .reset_cycles_hi_p(10)
                         )  reset_gen
                         (  .clk_i        (clk_li)
                          , .async_reset_o(reset_li)
                         );

mesh_top_example #(   .x_cord_width_p ( x_cord_width_lp         )
                     ,.y_cord_width_p ( y_cord_width_lp         )
                     ,.data_width_p   ( data_width_lp           )
                     ,.addr_width_p   ( addr_width_lp           )
                     ,.load_id_width_p( load_id_width_lp        )
                  )top
                  ( .clk_i     ( clk_li        )
                   ,.reset_i   ( reset_li      )
                   ,.finish_o  ( finish_lo     )
                  );

initial begin
        wait( finish_lo == 1'b1 );
        $finish();
end

endmodule
