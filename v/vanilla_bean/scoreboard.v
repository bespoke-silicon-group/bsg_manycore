/**
 *  scoreboard.v
 *
 */

`include "parameters.vh"
`include "definitions.vh"

module scoreboard
  #(parameter els_p = 32
    , localparam reg_id_width_lp = RV32_reg_addr_width_gp 
  )
  (
    input clk_i
    , input reset_i

    , input [reg_id_width_lp-1:0] src1_id_i
    , input [reg_id_width_lp-1:0] src2_id_i
    , input [reg_id_width_lp-1:0] dest_id_i

    , input op_reads_rf1_i
    , input op_reads_rf2_i
    , input op_writes_rf_i

    , input score_i
    , input clear_i
    , input [reg_id_width_lp-1:0] clear_id_i

    , output logic dependency_o
  );

  // scoreboard logic
  //
  logic [els_p-1:0] scoreboard_r;
  logic [els_p-1:0] scoreboard_n;
  logic [els_p-1:0] score_en;
  logic [els_p-1:0] clear_en;

  bsg_decode_with_v #(
    .num_out_p(els_p)
  ) score_decode (
    .i(dest_id_i)
    ,.v_i(score_i)
    ,.o(score_en)
  );
  
  bsg_decode_with_v #(
    .num_out_p(els_p)
  ) clear_decode (
    .i(clear_id_i)
    ,.v_i(clear_i)
    ,.o(clear_en)
  );

  always_comb begin
    for (integer i = 0; i < els_p; i++) begin
      if (i == 0) begin
        scoreboard_n[i] = 1'b0; // x0 is hard-wired zero, so no dependency can be created.
      end
      else begin
        if (score_en[i]) begin
          scoreboard_n[i] = 1'b1;
        end
        else if (clear_en[i]) begin
          scoreboard_n[i] = 1'b0;
        end
        else begin
          scoreboard_n[i] = scoreboard_r[i];
        end
      end
    end
  end

  // dependency check
  //
  logic src1_depend;
  logic src2_depend;
  logic dest_depend;

  assign src1_depend = op_reads_rf1_i & scoreboard_r[src1_id_i] & ~clear_en[src1_id_i]; // tommy: can scoreboard be cleared when it's zero?
  assign src2_depend = op_reads_rf2_i & scoreboard_r[src2_id_i] & ~clear_en[src2_id_i];
  assign dest_depend = op_writes_rf_i & scoreboard_r[dest_id_i] & ~clear_en[dest_id_i];

  assign dependency_o = src1_depend | src2_depend | dest_depend;

  // sequential logic
  //
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      scoreboard_r <= '0;
    end
    else begin
      scoreboard_r <= scoreboard_n;
    end
  end

  // synopsys translate_off
  always_ff @ (posedge clk_i) begin

    // "score" takes priority over "clear" in case of
    // simultaneous score and clear. But this contition should not occur in
    // general, as the pipeline should not allow a new dependency on
    // a register until the old dependency on that register in cleared.
    assert((|(score_en & clear_en)) == 0)
      else $error("[scoreboard] clear_en and score_en both asserted at the same time. clear_en: %32b, score_en:%32b",
                  clear_en, score_en);

  end
  // synopsys translate_on

endmodule
