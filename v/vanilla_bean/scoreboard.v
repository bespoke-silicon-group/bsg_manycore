/**
 *  scoreboard.v
 *
 *  2020-05-08:  Tommy J - adding FMA support.
 *
 */


module scoreboard
  import bsg_vanilla_pkg::*;
  #(parameter els_p = RV32_reg_els_gp
    , parameter num_src_port_p="inv"
    , parameter num_clear_port_p=1
    , parameter x0_tied_to_zero_p = 0
    , parameter id_width_lp = `BSG_SAFE_CLOG2(els_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_src_port_p-1:0][id_width_lp-1:0] src_id_i
    , input [id_width_lp-1:0] dest_id_i

    , input [num_src_port_p-1:0] op_reads_rf_i
    , input op_writes_rf_i

    , input score_i
    , input [id_width_lp-1:0] score_id_i

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

  wire allow_zero = (x0_tied_to_zero_p == 0) | (score_id_i != '0);

  logic [els_p-1:0] score_bits;
  bsg_decode_with_v #(
    .num_out_p(els_p)
  ) score_demux (
    .i(score_id_i)
    ,.v_i(score_i & allow_zero)
    ,.o(score_bits)
  );

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
        if(score_bits[i]) begin
          scoreboard_r[i] <= 1'b1;
        end
        else if (clear_combined[i]) begin
          scoreboard_r[i] <= 1'b0;
        end
      end
    end
  end

 
  // dependency logic
  logic [num_src_port_p-1:0] depend_on_rs;
  logic depend_on_rd;

  for (genvar i = 0; i < num_src_port_p; i++) begin
    assign depend_on_rs[i] = (scoreboard_r[src_id_i[i]] | ((score_id_i == src_id_i[i]) & score_i))
                           & ~((clear_id_i == src_id_i[i]) & clear_i)
                           & op_reads_rf_i[i];
  end

  assign depend_on_rd = (scoreboard_r[dest_id_i] | ((score_id_i == dest_id_i) & score_i))
                      & ~((clear_id_i == dest_id_i) & clear_i)
                      & op_writes_rf_i;

  assign dependency_o = (|depend_on_rs) | depend_on_rd;


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      for (integer i = 0; i < num_clear_port_p; i++) begin
        if (score_i & clear_i[i]) begin
          assert(score_id_i != clear_id_i[i])
            else $error("score and clear on the same id cannot happen.");
        end
      end
    end
  end
  // synopsys translate_on


endmodule
