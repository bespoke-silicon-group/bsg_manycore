/**
 *  scoreboard.v
 *
 */


module scoreboard
  import bsg_vanilla_pkg::*;
  #(parameter els_p = RV32_reg_els_gp
    , parameter is_float_p = 0
    , parameter num_clear_port_p=1
    , parameter id_width_lp = `BSG_SAFE_CLOG2(els_p)
  )
  (
    input clk_i
    , input reset_i

    , input [id_width_lp-1:0] src1_id_i
    , input [id_width_lp-1:0] src2_id_i
    , input [id_width_lp-1:0] dest_id_i

    , input op_reads_rf1_i
    , input op_reads_rf2_i
    , input op_writes_rf_i

    , input score_i
    , input [num_clear_port_p-1:0] clear_i
    , input [num_clear_port_p-1:0][id_width_lp-1:0] clear_id_i

    , output logic dependency_o
  );

  logic [els_p-1:0] scoreboard_r;

  // multi-port clear logic
  //
  logic [num_clear_port_p-1:0][els_p-1:0] clear_by_port;
  logic [els_p-1:0][num_clear_port_p-1:0] clear_by_port_t; // transposed
  logic [els_p-1:0] clear_combined;

  bsg_transpose #(
    .els_p(num_clear_port_p)
    ,.width_p(els_p)
  ) tranposer (
    .i(clear_by_port)
    ,.o(clear_by_port_t)
  );

  for (genvar j = 0 ; j < num_clear_port_p; j++) begin: clr_dcode_v
    bsg_decode_with_v #(
      .num_out_p(els_p)
    ) clear_decode_v (
      .i(clear_id_i[j])
      ,.v_i(clear_i[j])
      ,.o(clear_by_port[j])
    );
  end

  always_comb begin
    for (integer i = 0; i < els_p; i++) begin
      clear_combined[i] = |clear_by_port_t[i];
    end
  end


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      for (integer i = 0; i < els_p; i++) begin
        assert($countones(clear_by_port_t[i]) <= 1) else
          $error("[ERROR][SCOREBOARD] multiple clear on the same id. t=%0t", $time);
      end
    end
  end
  // synopsys translate_on


  always_ff @ (posedge clk_i) begin
    for (integer i = 0; i < els_p; i++) begin
      if(reset_i) begin
        scoreboard_r[i] <= 1'b0;
      end
      else begin
        // "score" takes priority over "clear" in case of 
        // simultaneous score and clear. But this
        // condition should not occur in general, as 
        // the pipeline should not allow a new dependency
        // on a register until the old dependency on that 
        // register is cleared.
        if(score_i && dest_id_i==i && ((is_float_p != 0) | (dest_id_i!='0))) begin
          scoreboard_r[i] <= 1'b1;
        end
        else if (clear_combined[i]) begin
          scoreboard_r[i] <= 1'b0;
        end
      end
    end
  end

  logic depend_on_rs1;
  logic depend_on_rs2;
  logic depend_on_rd;

  assign depend_on_rs1 =
    scoreboard_r[src1_id_i] & ~(clear_combined[src1_id_i]) & op_reads_rf1_i;

  assign depend_on_rs2 = 
    scoreboard_r[src2_id_i] & ~(clear_combined[src2_id_i]) & op_reads_rf2_i;

  assign depend_on_rd = 
    scoreboard_r[dest_id_i] & ~(clear_combined[dest_id_i]) & op_writes_rf_i;

  assign dependency_o = depend_on_rs1 | depend_on_rs2 | depend_on_rd;

endmodule
