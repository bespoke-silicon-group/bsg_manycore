/**
 *  icache.v
 *
 *  Instruction cache for manycore.
 *
 *  05/11/2018, shawnless.xie@gmail.com
 *
 *  Diagram on branch target pre-computation logic:
 *  https://docs.google.com/presentation/d/1ZeRHYhqMHJQ0mRgDTilLuWQrZF7On-Be_KNNosgeW0c/edit#slide=id.g10d2e6febb9_1_0
 *
 *  Set associativity:
 *
 *  icache_ways_p ways (a power of 2) split icache_entries_p words between them,
 *  one bsg_mem_1rw_sync per way. Every fetch reads all ways of a set, and the
 *  way whose tag matches supplies the instruction. Each way stores the PC bits
 *  above the set index, so the stored tag is icache_tag_width_p+log2(ways) bits.
 *  One way is today's direct-mapped cache, with the same RAM and logic.
 *
 *  There are no valid bits. The loader writes every slot before the tile
 *  leaves reset, and the way it writes is the low bits of the stored tag, so
 *  words 0 to icache_entries_p-1 fill each (set, way) slot exactly once.
 *  Network writes are for initialization only: one to a block that a refill
 *  already placed in another way would leave the block in two ways.
 *
 *  Replacement is least recently filled (round robin per set). Each RAM row
 *  keeps a log2(ways)-bit fill count; the victim is the sum of the set's
 *  counts mod ways, and a refill increments the count of the way it fills, so
 *  the next refill of the set takes the next way. The core does not read the
 *  icache between a miss and the end of its refill, so when the refill writes
 *  the block the RAM outputs still hold the missing set's counts.
 */

`include "bsg_vanilla_defines.svh"

module icache
  import bsg_vanilla_pkg::*;
  #(`BSG_INV_PARAM(icache_tag_width_p)
    , `BSG_INV_PARAM(icache_entries_p) // in words, across all ways
    , `BSG_INV_PARAM(icache_block_size_in_words_p) // block size is power of 2.
    , parameter icache_ways_p = 1 // associativity, a power of 2
    , localparam icache_sets_lp=(icache_entries_p/icache_block_size_in_words_p/icache_ways_p)
    , icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_sets_lp)
    , pc_width_lp=(icache_tag_width_p+`BSG_SAFE_CLOG2(icache_entries_p))
    , icache_block_offset_width_lp=`BSG_SAFE_CLOG2(icache_block_size_in_words_p)
    , icache_stored_tag_width_lp=(pc_width_lp-icache_addr_width_lp-icache_block_offset_width_lp)
    , lg_icache_ways_lp=`BSG_SAFE_CLOG2(icache_ways_p)
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
    , input w_refill_i // the write is a refill after a miss, not a network write

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

  localparam icache_format_width_lp = `icache_format_width(icache_stored_tag_width_lp, icache_block_size_in_words_p);

  // replacement state stored beside each block; none for one way
  localparam fill_cnt_width_lp = (icache_ways_p > 1) ? lg_icache_ways_lp : 0;
  localparam ram_width_lp = icache_format_width_lp + fill_cnt_width_lp;

  // declare icache entry struct.
  //
  `declare_icache_format_s(icache_stored_tag_width_lp, icache_block_size_in_words_p);

  // address decode
  //
  logic [icache_stored_tag_width_lp-1:0] w_tag;
  logic [icache_addr_width_lp-1:0] w_addr;
  logic [icache_block_offset_width_lp-1:0] w_block_offset;
  assign {w_tag, w_addr, w_block_offset} = w_pc_i;


  // Instantiate icache memory, one RAM per way
  //
  logic read_v_li;
  logic [icache_ways_p-1:0] write_way_v_li;
  icache_format_s icache_data_li;
  icache_format_s [icache_ways_p-1:0] icache_data_lo;
  logic [lg_icache_ways_lp-1:0] fill_cnt_li;
  logic [icache_ways_p-1:0][lg_icache_ways_lp-1:0] fill_cnt_lo;
  logic [icache_addr_width_lp-1:0] icache_addr_li;

  for (genvar i = 0; i < icache_ways_p; i++) begin: way
    logic [ram_width_lp-1:0] ram_data_li, ram_data_lo;

    bsg_mem_1rw_sync #(
      .width_p(ram_width_lp)
      ,.els_p(icache_sets_lp)
      ,.latch_last_read_p(1)
    ) imem (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(w_i ? write_way_v_li[i] : read_v_li)
      ,.w_i(w_i)
      ,.addr_i(icache_addr_li)
      ,.data_i(ram_data_li)
      ,.data_o(ram_data_lo)
    );

    if (icache_ways_p == 1) begin: dm
      assign ram_data_li = icache_data_li;
      assign icache_data_lo[i] = ram_data_lo;
      assign fill_cnt_lo[i] = '0;
    end
    else begin: sa
      assign ram_data_li = {fill_cnt_li, icache_data_li};
      assign {fill_cnt_lo[i], icache_data_lo[i]} = ram_data_lo;
    end
  end

  assign icache_addr_li = w_i
    ? w_addr
    : pc_i[icache_block_offset_width_lp+:icache_addr_width_lp];


  //  Pre-compute the lower part of the jump address for JAL and BRANCH
  //  instruction
  //
  //  The width of the adder is defined by the Imm width +1.
  //
  //  Each entry keeps instruction bits [31:2] plus two bits for the target
  //  computed here: the sign of the branch/JAL immediate (also the branch
  //  prediction) and the carry-out of the lower sum. They replace bits [1:0],
  //  which are 2'b11 in every 32-bit RV32 instruction; reads restore 2'b11.
  //
  //  Refills and the loader also write words that are not instructions
  //  (padding, data), so force bits [1:0] to 2'b11 on the way in too. The
  //  branch/JAL check below then classifies the same word the decoder sees.
  //
  instruction_s w_instr;
  assign w_instr = {w_instr_i[RV32_instr_width_gp-1:2], 2'b11};
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
  instruction_s injected_instr;
  assign injected_instr = write_branch_instr
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

  // the word stored in the icache
  icache_instr_s w_icache_instr;
  assign w_icache_instr = '{
    instr31to2:  injected_instr[RV32_instr_width_gp-1:2]
    ,lower_sign: imm_sign
    ,lower_cout: pc_lower_cout
  };

  // buffered writes
  icache_instr_s [icache_block_size_in_words_p-2:0] buffered_instr_r;

  assign icache_data_li = '{
    tag: w_tag
    ,instr: {w_icache_instr, buffered_instr_r}
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
      buffered_instr_r[write_count_r] <= w_icache_instr;
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
  assign read_v_li = v_i & ((&pc_r[0+:icache_block_offset_width_lp]) | ~read_pc_plus4_i);


  // Tag compare and way select
  //
  // Each way selects its word by the PC offset in parallel with the tag
  // compare, then the hitting way is picked. The select is a priority mux
  // (way 0 first), which for two ways is hit[0] ? way 0 : way 1.
  wire [icache_stored_tag_width_lp-1:0] pc_tag = pc_r[icache_block_offset_width_lp+icache_addr_width_lp+:icache_stored_tag_width_lp];
  wire [icache_block_offset_width_lp-1:0] pc_block_offset = pc_r[0+:icache_block_offset_width_lp];

  logic [icache_ways_p-1:0] hit;
  icache_instr_s [icache_ways_p-1:0] way_instr;
  for (genvar i = 0; i < icache_ways_p; i++) begin: lookup
    assign hit[i] = (icache_data_lo[i].tag == pc_tag);
    assign way_instr[i] = icache_data_lo[i].instr[pc_block_offset];
  end

  icache_instr_s read_instr;
  always_comb begin
    read_instr = way_instr[icache_ways_p-1];
    for (integer i = icache_ways_p-2; i >= 0; i--) begin
      if (hit[i]) begin
        read_instr = way_instr[i];
      end
    end
  end


  // Replacement
  //
  // A refill writes the victim way and advances that way's fill count, so the
  // set's next victim is the following way. A network write goes to the way
  // named by the low stored-tag bits and clears its count.
  logic [lg_icache_ways_lp-1:0] victim_way;
  always_comb begin
    victim_way = '0;
    for (integer i = 0; i < icache_ways_p; i++) begin
      victim_way = victim_way + fill_cnt_lo[i];
    end
  end

  wire [lg_icache_ways_lp-1:0] write_way = (icache_ways_p == 1)
    ? '0
    : (w_refill_i ? victim_way : w_tag[0+:lg_icache_ways_lp]);

  assign fill_cnt_li = w_refill_i
    ? lg_icache_ways_lp'(fill_cnt_lo[victim_way] + 1'b1)
    : '0;

  for (genvar i = 0; i < icache_ways_p; i++) begin: wv
    assign write_way_v_li[i] = write_en_icache & (write_way == lg_icache_ways_lp'(i));
  end


  // Merge the PC lower part and high part
  // BYTE operations
  instruction_s instr_out;
  // bits [1:0] were forced to 2'b11 on write and are not stored
  assign instr_out = {read_instr.instr31to2,2'b11};
  wire lower_sign_out = read_instr.lower_sign;
  wire lower_cout_out = read_instr.lower_cout;
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
  assign icache_miss_o = ~(|hit);

  // branch imm sign
  assign branch_predicted_taken_o = lower_sign_out;


  // synopsys translate_off
  initial begin
    assert ((icache_ways_p > 0) && ((icache_ways_p & (icache_ways_p-1)) == 0))
      else $error("[BSG_ERROR][ICACHE] icache_ways_p (%0d) must be a power of 2.", icache_ways_p);
    assert (icache_sets_lp >= 2)
      else $error("[BSG_ERROR][ICACHE] icache needs at least 2 sets: entries=%0d, block=%0d, ways=%0d.",
        icache_entries_p, icache_block_size_in_words_p, icache_ways_p);
  end

  if (icache_ways_p > 1) begin: sa_check
    // The index of the last RAM read: the set the outputs hold.
    logic last_read_v_r;
    logic [icache_addr_width_lp-1:0] last_read_addr_r;
    always_ff @ (posedge clk_i) begin
      if (reset_i) begin
        last_read_v_r <= 1'b0;
      end
      else if (~w_i & read_v_li) begin
        last_read_v_r <= 1'b1;
        last_read_addr_r <= icache_addr_li;
      end
    end

    always_ff @ (negedge clk_i) begin
      if (reset_i === 1'b0) begin
        // A refill uses the outputs to pick its victim, so they must hold
        // the set being refilled, and that set must not hold the block.
        if (write_en_icache & w_refill_i) begin
          assert (last_read_v_r && (last_read_addr_r == w_addr))
            else $error("[BSG_ERROR][ICACHE] refill of set %0d, but the RAM outputs hold set %0d.",
              w_addr, last_read_addr_r);
          assert (~(|hit))
            else $error("[BSG_ERROR][ICACHE] refill of a block already in the cache. pc=%h", {pc_r, 2'b00});
        end
        // A block must never be in two ways.
        if (~w_i & last_read_v_r) begin
          assert ($countones(hit) <= 1)
            else $error("[BSG_ERROR][ICACHE] pc=%h hits in more than one way (%b).", {pc_r, 2'b00}, hit);
        end
      end
    end
  end
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(icache)
