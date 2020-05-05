/**
 *  icache.v
 *
 *  Instruction cache for manycore. 
 *
 *  05/11/2018, shawnless.xie@gmail.com
 *
 */


module icache
  import bsg_vanilla_pkg::*;
  #(parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"

    , parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
  )
  (
    input clk_i
    , input reset_i

    // ctrl signal
    , input v_i
    , input w_i
    , input flush_i

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
  );

  // localparam
  //
  localparam icache_format_width_lp = `icache_format_width(icache_tag_width_p);

  localparam branch_pc_low_width_lp = (RV32_Bimm_width_gp+1);
  localparam jal_pc_low_width_lp    = (RV32_Jimm_width_gp+1);

  localparam branch_pc_high_width_lp = (pc_width_lp+2) - branch_pc_low_width_lp; 
  localparam jal_pc_high_width_lp    = (pc_width_lp+2) - jal_pc_low_width_lp;

  // declare icache entry struct.
  //
  `declare_icache_format_s(icache_tag_width_p);

  // address decode
  //
  logic [icache_addr_width_lp-1:0] w_addr;
  logic [icache_tag_width_p-1:0] w_tag;

  assign w_addr = w_pc_i[0+:icache_addr_width_lp]; 
  assign w_tag = w_pc_i[icache_addr_width_lp+:icache_tag_width_p];
  

  // Instantiate icache memory 
  //
  icache_format_s icache_data_li;
  icache_format_s icache_data_lo;
  logic [icache_addr_width_lp-1:0] icache_addr_li;

  bsg_mem_1rw_sync #(
    .width_p(icache_format_width_lp)
    ,.els_p(icache_entries_p)
    ,.latch_last_read_p(1)
  ) imem_0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.v_i(v_i)
    ,.w_i(w_i)
    ,.addr_i(icache_addr_li)
    ,.data_i(icache_data_li)
    ,.data_o(icache_data_lo)
  );

  assign icache_addr_li = (v_i & w_i)
    ? w_addr
    : pc_i[0+:icache_addr_width_lp];


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

  logic write_branch_instr;
  logic write_jal_instr;

  assign write_branch_instr = w_instr.op ==? `RV32_BRANCH;
  assign write_jal_instr    = w_instr.op ==? `RV32_JAL_OP;
  
  // BYTE address computation

  wire [branch_pc_low_width_lp-1:0] branch_imm_val = `RV32_Bimm_13extract(w_instr);
  wire [branch_pc_low_width_lp-1:0] branch_pc_val = branch_pc_low_width_lp'({w_tag, w_addr, 2'b0}); 
  
  wire [jal_pc_low_width_lp-1:0] jal_imm_val = `RV32_Jimm_21extract(w_instr);
  wire [jal_pc_low_width_lp-1:0] jal_pc_val = jal_pc_low_width_lp'({w_tag, w_addr, 2'b0}); 
  
  logic [branch_pc_low_width_lp-1:0] branch_pc_lower_res;
  logic branch_pc_lower_cout;
  logic [jal_pc_low_width_lp-1:0] jal_pc_lower_res;
  logic jal_pc_lower_cout;
  
  assign {branch_pc_lower_cout, branch_pc_lower_res} = {1'b0, branch_imm_val} + {1'b0, branch_pc_val};
  assign {jal_pc_lower_cout,    jal_pc_lower_res   } = {1'b0, jal_imm_val}    + {1'b0, jal_pc_val   };
  
  
  // Inject the 2-BYTE (half) address, the LSB is ignored.
  logic [RV32_instr_width_gp-1:0] injected_instr;
  logic imm_sign;
  logic pc_lower_cout;

  assign injected_instr = write_branch_instr
    ? `RV32_Bimm_12inject1(w_instr, branch_pc_lower_res)
    : (write_jal_instr
      ? `RV32_Jimm_20inject1(w_instr, jal_pc_lower_res)
      : w_instr);

  assign imm_sign = write_branch_instr
    ? branch_imm_val[RV32_Bimm_width_gp] 
    : jal_imm_val[RV32_Jimm_width_gp];

  assign pc_lower_cout = write_branch_instr
    ? branch_pc_lower_cout
    : jal_pc_lower_cout;

  
  assign icache_data_li = '{
    lower_sign : imm_sign,
    lower_cout : pc_lower_cout,
    tag        : w_tag,
    instr      : injected_instr
  };
                             
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


  // Merge the PC lower part and high part
  // BYTE operations
  wire sel_pc    = ~(icache_data_lo.lower_sign ^ icache_data_lo.lower_cout); 
  wire sel_pc_p1 = (~icache_data_lo.lower_sign) & icache_data_lo.lower_cout; 

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

  wire is_jal_instr = icache_data_lo.instr.op == `RV32_JAL_OP;
  wire is_jalr_instr = icache_data_lo.instr.op == `RV32_JALR_OP;

  // these are bytes address
  logic [pc_width_lp+2-1:0] jal_pc;
  logic [pc_width_lp+2-1:0] branch_pc;
   
  assign branch_pc = {branch_pc_high_out, `RV32_Bimm_13extract(icache_data_lo.instr)};
  assign jal_pc = {jal_pc_high_out, `RV32_Jimm_21extract(icache_data_lo.instr)};

  // assign outputs.
  assign instr_o = icache_data_lo.instr;
  assign pc_r_o = pc_r;

  // this is word addr.
  assign pred_or_jump_addr_o = is_jal_instr
    ? jal_pc[2+:pc_width_lp]
    : (is_jalr_instr
      ? jalr_prediction_i
      : branch_pc[2+:pc_width_lp]);

  // the icache miss logic
  assign icache_miss_o = icache_data_lo.tag != pc_r[icache_addr_width_lp+:icache_tag_width_p];
  
endmodule
