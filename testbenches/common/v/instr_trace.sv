
module instr_trace
  import bsg_vanilla_pkg::*;
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
  )
  (
    input clk_i
    , input reset_i

    , input trace_en_i

    , input stall_all
    , input stall_id
    , input flush
    , input id_signals_s id_r
    , input exe_signals_s exe_n

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  integer fd;

  initial begin
    fd = $fopen("instr.log", "w");
    $fwrite(fd, "");
    $fclose(fd);
  end

   always @(negedge clk_i) begin
      if (my_x_i == 1'b0 & my_y_i == 2'b01 & ~reset_i && (trace_en_i == 1)) begin //

        fd = $fopen("instr.log", "a");
        if (~stall_all & ~(stall_id | flush | id_r.decode.is_fp_op) & ~exe_n.icache_miss
            & ~(exe_n.pc_plus4 == '0)) begin
          $fwrite(fd, "t=%08t pc=%08x instr=%08x\n",
            $time,
            (exe_n.pc_plus4-'d4),
            exe_n.instruction
          ); 
        end    
    
        $fclose(fd);

      end
   end
   
endmodule
