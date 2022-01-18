/**
 *  icache.v
 *
 *  Instruction cache for manycore. 
 *
 *  05/11/2018, shawnless.xie@gmail.com
 *
 *  Diagram on branch target pre-computation logic:
 *  https://docs.google.com/presentation/d/1ZeRHYhqMHJQ0mRgDTilLuWQrZF7On-Be_KNNosgeW0c/edit#slide=id.g10d2e6febb9_1_0
 */

`include "bsg_vanilla_defines.vh"

module icache
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(icache_tag_width_p)
    , `BSG_INV_PARAM(icache_entries_p)
    , `BSG_INV_PARAM(icache_block_size_in_words_p) // block size is power of 2.
    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p/icache_block_size_in_words_p)
    , pc_width_lp=(icache_tag_width_p+`BSG_SAFE_CLOG2(icache_entries_p))
    , icache_block_offset_width_lp=`BSG_SAFE_CLOG2(icache_block_size_in_words_p)
  )
  (
    input clk_i
    , input network_reset_i
    , input reset_i

    // ctrl signal
    , input v_i
    , input w_i
    , input flush_i
    , input read_pc_plus4_i

    // icache write
    , input [pc_width_lp-1:0] w_pc_i
    , input [RV32_instr_width_gp-1:0] w_instr_i

    // icache read (by processor)
    , input [pc_width_lp-1:0] pc_i
    , input [pc_width_lp-1:0] jalr_prediction_i
    , output [RV32_instr_width_gp-1:0] instr_o
    , output [pc_width_lp-1:0] pred_or_jump_addr_o
    , output [pc_width_lp-1:0] pc_r_o
    , output icache_miss_o
    , output icache_flush_r_o
    , output logic branch_predicted_taken_o
  );

  // localparam
  //
  localparam branch_pc_low_width_lp = (RV32_Bimm_width_gp+1);
  localparam jal_pc_low_width_lp    = (RV32_Jimm_width_gp+1);

  localparam branch_pc_high_width_lp = (pc_width_lp+2) - branch_pc_low_width_lp; 
  localparam jal_pc_high_width_lp    = (pc_width_lp+2) - jal_pc_low_width_lp;

  localparam icache_format_width_lp = `icache_format_width(icache_tag_width_p, icache_block_size_in_words_p);

  // declare icache entry struct.
  //
  `declare_icache_format_s(icache_tag_width_p, icache_block_size_in_words_p);

  // address decode
  //
  logic [icache_tag_width_p-1:0] w_tag;
  logic [icache_addr_width_lp-1:0] w_addr;
  logic [icache_block_offset_width_lp-1:0] w_block_offset;
  assign {w_tag, w_addr, w_block_offset} = w_pc_i;
  

  // Instantiate icache memory 
  //
  logic v_li;
  icache_format_s icache_data_li, icache_data_lo;
  logic [icache_addr_width_lp-1:0] icache_addr_li;

  bsg_mem_1rw_sync #(
    .width_p(icache_format_width_lp)
    ,.els_p(icache_entries_p/icache_block_size_in_words_p)
    ,.latch_last_read_p(1)
  ) imem_0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.v_i(v_li)
    ,.w_i(w_i)
    ,.addr_i(icache_addr_li)
    ,.data_i(icache_data_li)
    ,.data_o(icache_data_lo)
  );

  assign icache_addr_li = w_i
    ? w_addr
    : pc_i[icache_block_offset_width_lp+:icache_addr_width_lp];


  //  Pre-compute the lower part of the jump address for JAL and BRANCH
  //  instruction
  //
  //  The width of the adder is defined by the Imm width +1.
  //
  //  For the branch op, we are saving the sign of an imm13 value, in the LSB
  //  of instruction opcode, to use it later when making branch prediction.
  //
  instruction_s w_instr;
  assign w_instr = w_instr_i;
  wire write_branch_instr = w_instr.op ==? `RV32_BRANCH;
  wire write_jal_instr    = w_instr.op ==? `RV32_JAL_OP;
  
  // BYTE address computation
  wire [branch_pc_low_width_lp-1:0] branch_imm_val = `RV32_Bimm_13extract(w_instr);
  wire [branch_pc_low_width_lp-1:0] branch_pc_val = branch_pc_low_width_lp'({w_pc_i, 2'b0}); 
  
  wire [jal_pc_low_width_lp-1:0] jal_imm_val = `RV32_Jimm_21extract(w_instr);
  wire [jal_pc_low_width_lp-1:0] jal_pc_val = jal_pc_low_width_lp'({w_pc_i, 2'b0}); 
  
  logic [branch_pc_low_width_lp-1:0] branch_pc_lower_res;
  logic branch_pc_lower_cout;
  logic [jal_pc_low_width_lp-1:0] jal_pc_lower_res;
  logic jal_pc_lower_cout;
  
  assign {branch_pc_lower_cout, branch_pc_lower_res} = {1'b0, branch_imm_val} + {1'b0, branch_pc_val};
  assign {jal_pc_lower_cout,    jal_pc_lower_res   } = {1'b0, jal_imm_val}    + {1'b0, jal_pc_val   };
  
  
  // Inject the 2-BYTE (half) address, the LSB is ignored.
  wire [RV32_instr_width_gp-1:0] injected_instr = write_branch_instr
    ? `RV32_Bimm_12inject1(w_instr, branch_pc_lower_res)
    : (write_jal_instr
      ? `RV32_Jimm_20inject1(w_instr, jal_pc_lower_res)
      : w_instr);

  wire imm_sign = write_branch_instr
    ? branch_imm_val[RV32_Bimm_width_gp] 
    : jal_imm_val[RV32_Jimm_width_gp];

  wire pc_lower_cout = write_branch_instr
    ? branch_pc_lower_cout
    : jal_pc_lower_cout;


  // buffered writes
  logic [icache_block_size_in_words_p-2:0] imm_sign_r;
  logic [icache_block_size_in_words_p-2:0] pc_lower_cout_r;
  logic [icache_block_size_in_words_p-2:0][RV32_instr_width_gp-1:0] buffered_instr_r;

  assign icache_data_li = '{
    lower_sign : {imm_sign, imm_sign_r},
    lower_cout : {pc_lower_cout, pc_lower_cout_r},
    tag        : w_tag,
    instr      : {injected_instr, buffered_instr_r}
  };


  // icache write counter
  logic [icache_block_offset_width_lp-1:0] write_count_r;
  always_ff @ (posedge clk_i) begin
    if (network_reset_i) begin
      write_count_r <= '0;
    end
    else begin
      if (v_i & w_i) begin
        write_count_r <= write_count_r + 1'b1;
      end
    end
  end

  logic write_en_buffer;
  logic write_en_icache;
  always_ff @ (posedge clk_i) begin
    if (write_en_buffer) begin
      imm_sign_r[write_count_r] <= imm_sign;
      pc_lower_cout_r[write_count_r] <= pc_lower_cout;
      buffered_instr_r[write_count_r] <= injected_instr;
    end
  end

  always_comb begin
    if (write_count_r == icache_block_size_in_words_p-1) begin
      write_en_buffer = 1'b0;
      write_en_icache = v_i & w_i;
    end
    else begin
      write_en_buffer = v_i & w_i;
      write_en_icache = 1'b0;
    end
  end

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if ((network_reset_i === 1'b0) & v_i & w_i) begin
      assert(write_count_r == w_block_offset) else $error("icache being written not in sequence.");
    end
  end
  // synopsys translate_on

  // Program counter
  logic [pc_width_lp-1:0] pc_r; 
  logic icache_flush_r;
  // Since imem has one cycle delay and we send next cycle's address, pc_n,
  // if the PC is not written, the instruction must not change.

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      pc_r <= '0;
      icache_flush_r <= 1'b0;
    end
    else begin

      if (v_i & ~w_i) begin
        pc_r <= pc_i;
        icache_flush_r <= 1'b0;
      end
      else begin
        icache_flush_r <= flush_i;
      end
    end
  end

  assign icache_flush_r_o = icache_flush_r;


  // Energy-saving logic
  // - Don't read the icache if the current pc is not at the last word of the block, and 
  //   there is a hint from the next-pc logic that it is reading pc+4 next (no branch or jump).
  assign v_li = w_i
    ? write_en_icache
    : (v_i & ((&pc_r[0+:icache_block_offset_width_lp]) | ~read_pc_plus4_i));


  // Merge the PC lower part and high part
  // BYTE operations
  instruction_s instr_out;
  assign instr_out = icache_data_lo.instr[pc_r[0+:icache_block_offset_width_lp]];
  wire lower_sign_out = icache_data_lo.lower_sign[pc_r[0+:icache_block_offset_width_lp]];
  wire lower_cout_out = icache_data_lo.lower_cout[pc_r[0+:icache_block_offset_width_lp]];
  wire sel_pc    = ~(lower_sign_out ^ lower_cout_out); 
  wire sel_pc_p1 = (~lower_sign_out) & lower_cout_out; 

  logic [branch_pc_high_width_lp-1:0] branch_pc_high;
  logic [jal_pc_high_width_lp-1:0] jal_pc_high;

  assign branch_pc_high = pc_r[(branch_pc_low_width_lp-2)+:branch_pc_high_width_lp];
  assign jal_pc_high = pc_r[(jal_pc_low_width_lp-2)+:jal_pc_high_width_lp];

  logic [branch_pc_high_width_lp-1:0] branch_pc_high_out;
  logic [jal_pc_high_width_lp-1:0] jal_pc_high_out;


  // We are saving the carry-out when we are partially computing the
  // lower-portion jump addr, as we write to the icache.
  // When we are calculating the full jump addr, as we read back from the icache,
  // we decide how to propagate the carry to the upper portion of the jump
  // addr, using this table.
  // -------------------------------------------------------------
  // pc_lower_sign  pc_lower_cout  | pc_high-1  pc_high  pc_high+1
  // ------------------------------+------------------------------
  //   0              0            |            1                   
  //   0              1            |                     1
  //   1              0            | 1                                     
  //   1              1            |            1 
  // ------------------------------+------------------------------
  //
  always_comb begin
    if (sel_pc) begin
      branch_pc_high_out = branch_pc_high;
      jal_pc_high_out = jal_pc_high;
    end
    else if (sel_pc_p1) begin
      branch_pc_high_out = branch_pc_high + 1'b1;
      jal_pc_high_out = jal_pc_high + 1'b1;
    end
    else begin // sel_pc_n1
      branch_pc_high_out = branch_pc_high - 1'b1;
      jal_pc_high_out = jal_pc_high - 1'b1;
    end
  end

  wire is_jal_instr =  instr_out.op == `RV32_JAL_OP;
  wire is_jalr_instr = instr_out.op == `RV32_JALR_OP;

  // these are bytes address
  logic [pc_width_lp+2-1:0] jal_pc;
  logic [pc_width_lp+2-1:0] branch_pc;
   
  assign branch_pc = {branch_pc_high_out, `RV32_Bimm_13extract(instr_out)};
  assign jal_pc = {jal_pc_high_out, `RV32_Jimm_21extract(instr_out)};

  // assign outputs.
  assign instr_o = instr_out;
  assign pc_r_o = pc_r;

  // this is word addr.
  assign pred_or_jump_addr_o = is_jal_instr
    ? jal_pc[2+:pc_width_lp]
    : (is_jalr_instr
      ? jalr_prediction_i
      : branch_pc[2+:pc_width_lp]);

  // the icache miss logic
  assign icache_miss_o = icache_data_lo.tag != pc_r[icache_block_offset_width_lp+icache_addr_width_lp+:icache_tag_width_p];
 
  // branch imm sign
  assign branch_predicted_taken_o = lower_sign_out;

 
endmodule

`BSG_ABSTRACT_MODULE(icache)
