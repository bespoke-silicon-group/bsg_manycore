`include "parameters.vh"
`include "definitions.vh"

module scoreboard
 #(parameter els_p      = 32
  ,parameter id_width_p = RV32_reg_addr_width_gp 
  )
  (input                         clk_i
  ,input                         reset_i

  ,input [id_width_p-1:0]        src1_id_i
  ,input [id_width_p-1:0]        src2_id_i
  ,input [id_width_p-1:0]        dest_id_i

  ,input                         op_reads_rf1
  ,input                         op_reads_rf2
  ,input                         op_writes_rf

  ,input                         score_i
  ,input                         clear_i
  ,input [id_width_p-1:0]        clear_id_i

  ,output logic                  dependency_o
  );

  logic [els_p-1:0] scoreboard;

  integer entry;
  always_ff @(posedge clk_i)
  begin
    for(entry=0; entry<els_p; entry=entry+1)
    begin
      if(reset_i) begin
        scoreboard[entry] <= 1'b0;
      end else begin
        // "score" takes priority over "clear" in case of 
        // simultaneous score and clear. But this
        // condition should not occur in general, as 
        // the pipeline should not allow a new dependency
        // on a register until the old dependency on that 
        // register is cleared.
        if(score_i && dest_id_i==entry && (dest_id_i!='0)) begin
          scoreboard[entry] <= 1'b1;
        end else if(clear_i && clear_id_i==entry) begin
          scoreboard[entry] <= 1'b0;
        end
      end
    end
  end

  always_comb
  begin
    if((scoreboard[src1_id_i] & ~(clear_i & (clear_id_i == src1_id_i) & op_reads_rf1))
       || (scoreboard[src2_id_i] & ~(clear_i & (clear_id_i == src2_id_i) & op_reads_rf2))
       || (scoreboard[dest_id_i] & ~(clear_i & (clear_id_i == dest_id_i) & op_writes_rf)))
      dependency_o = 1'b1;
    else
      dependency_o = 1'b0;
  end

endmodule
