
module bsg_1hold#( parameter data_width_p = "inv")
        (
          input                         clk_i
         ,input                         v_i
         ,input[data_width_p-1:0]       data_i

         ,input                         hold_i

         ,output                        v_o
         ,output[data_width_p-1:0]      data_o
        );

    logic                       hold_r;
    logic                       v_r   ;
    logic [data_width_p-1:0]    data_r;

    always_ff@( posedge clk_i ) hold_r <= hold_i;

    assign data_o   = hold_r ? data_r : data_i;
    assign v_o      = hold_r ? v_r    : v_i;

    always_ff@(posedge clk_i ) begin
        data_r  <= data_o;
        v_r     <= v_o;
    end
    //synopsys translate_off
    always@(negedge clk_i) begin
        if( v_i !== 1'bX  && hold_r !== 1'bX && (v_i & hold_r) ) begin
            $error("Inputing data while still holding value !  %m, %t", $time);
            $finish;
        end
    end
    //synopsys translate_on

endmodule
