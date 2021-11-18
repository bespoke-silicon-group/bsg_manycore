/**
 *  scoreboard.v
 *
 *  2020-05-08:  Tommy J - adding FMA support.
 *
 */

`include "bsg_defines.v"

module scoreboard
  import bsg_vanilla_pkg::*;
  #(parameter els_p = RV32_reg_els_gp
    , `BSG_INV_PARAM(num_src_port_p)
    , `BSG_INV_PARAM(num_banks_p)
    , parameter x0_tied_to_zero_p = 0
    , parameter reg_addr_width_lp = `BSG_SAFE_CLOG2(els_p)
    , parameter bank_reg_addr_width_lp = `BSG_SAFE_CLOG2(els_p/num_banks_p)
    , parameter bank_els_lp = (els_p/num_banks_p)
    , parameter bank_id_width_lp = `BSG_SAFE_CLOG2(num_banks_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_src_port_p-1:0][reg_addr_width_lp-1:0] src_id_i
    , input [reg_addr_width_lp-1:0] dest_id_i

    , input [num_src_port_p-1:0] op_reads_rf_i
    , input op_writes_rf_i

    , input score_i
    , input [reg_addr_width_lp-1:0] score_id_i

    , input [num_banks_p-1:0] clear_i
    , input [num_banks_p-1:0][bank_reg_addr_width_lp-1:0] clear_id_i

    , output logic dependency_o
  );

  // clear id decoder
  logic [num_banks_p-1:0][bank_els_lp-1:0] clear_decoded;
  logic [els_p-1:0] clear_combined;

  for (genvar j = 0 ; j < num_banks_p; j++) begin: clr_dv
    bsg_decode_with_v #(
      .num_out_p(bank_els_lp)
    ) clear_decode_v (
      .i(clear_id_i[j])
      ,.v_i(clear_i[j])
      ,.o(clear_decoded[j])
    );
  end

  for (genvar i = 0; i < els_p; i++) begin
    assign clear_combined[i] = clear_decoded[i%num_banks_p][i/num_banks_p];
  end


  // score id decoder
  wire allow_zero = (x0_tied_to_zero_p == 0) | (score_id_i != '0);
  logic [els_p-1:0] score_bits;

  bsg_decode_with_v #(
    .num_out_p(els_p)
  ) score_demux (
    .i(score_id_i)
    ,.v_i(score_i & allow_zero)
    ,.o(score_bits)
  );
  

  // Scoreboard registers
  logic [els_p-1:0] scoreboard_r;

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
  // As the register is scored (in EXE), the instruction in ID that has WAW or RAW dependency on this register stalls.
  // The register that is being cleared does not stall ID. 

  // find dependency on scoreboard.
  logic [num_src_port_p-1:0] rs_depend_on_sb;
  logic rd_depend_on_sb;

  for (genvar i = 0; i < num_src_port_p; i++) begin
    assign rs_depend_on_sb[i] = scoreboard_r[src_id_i[i]] & op_reads_rf_i[i];
  end
  
  assign rd_depend_on_sb = scoreboard_r[dest_id_i] & op_writes_rf_i;


  // find which matches on clear_id.
  logic [num_src_port_p-1:0] rs_on_clear;
  logic rd_on_clear;

  for (genvar j = 0; j < num_src_port_p; j++) begin
    wire [bank_id_width_lp-1:0] src_bank_id = bank_id_width_lp'(src_id_i[j] % num_banks_p);
    assign rs_on_clear[j] = clear_i[src_bank_id] & (clear_id_i[src_bank_id] == (src_id_i[j]/num_banks_p));
  end

  wire [bank_id_width_lp-1:0] dest_bank_id = bank_id_width_lp'(dest_id_i % num_banks_p);
  assign rd_on_clear = clear_i[dest_bank_id] & (clear_id_i[dest_bank_id] == (dest_id_i/num_banks_p));
  

  // find which could depend on score.
  logic [num_src_port_p-1:0] rs_depend_on_score;
  logic rd_depend_on_score;

  for (genvar i = 0; i < num_src_port_p; i++) begin
    assign rs_depend_on_score[i] = (src_id_i[i] == score_id_i) && op_reads_rf_i[i];
  end

  assign rd_depend_on_score = (dest_id_i == score_id_i) && op_writes_rf_i;


  // score_i arrives later than other signals, so we want to remove it from the long path.
  wire depend_on_sb = |({rd_depend_on_sb, rs_depend_on_sb} & ~{rd_on_clear, rs_on_clear});
  wire depend_on_score = |{rd_depend_on_score, rs_depend_on_score};

  assign dependency_o = depend_on_sb | (depend_on_score & score_i & allow_zero);


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      assert((score_bits & clear_combined) == '0)
        else $error("[BSG_ERROR] score and clear on the same id cannot happen.");
    end
  end
  // synopsys translate_on


endmodule

`BSG_ABSTRACT_MODULE(scoreboard)
