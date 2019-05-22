/**
 *  hobbit.v
 *
 *  Vanilla-Bean Core
 *
 *  5 stage pipeline implementation of the vanilla core ISA.
 *
 */

`include "parameters.vh"
`include "definitions.vh"

module hobbit
  #(parameter icache_tag_width_p = "inv" 
    , parameter icache_addr_width_p = "inv"
    , parameter x_cord_width_p = "inv"
    , parameter y_cord_width_p = "inv"

    , parameter debug_p = 0
    , parameter trace_p = 0

    , localparam pc_width_lp = (icache_tag_width_p + icache_addr_width_p)
    , localparam icache_format_width_lp = `icache_format_width(icache_tag_width_p)

    // As all instructions will be resident in DRAM, we
    // need to pad the higher parts of the pc so it
    // points to DRAM.
    , localparam pc_high_padding_width_lp = (RV32_reg_data_width_gp-pc_width_lp-2)
    , localparam pc_high_padding_lp = {pc_high_padding_width_lp{1'b0}}
  
    // used to direct the icache miss address to dram.
    , localparam dram_addr_mapping_lp = 32'h8000_0000

    // position in recoded instruction memory of prediction bit
    // for branches. normally this would be bit 31 in RISCV ISA (branch ofs sign bit)
    // but we've partially evaluated the addresses so they are absolute. instead
    // we replicate that bit in bit 0 of the RISC-V instruction, which is unused
    , localparam pred_index_lp = 0
  )
  (
    input clk_i
    , input reset_i
  
    , input freeze_i
    
    // icache remote store interface 
    , input icache_v_i
    , input [pc_width_lp-1:0] icache_pc_i
    , input [RV32_instr_width_gp-1:0] icache_instr_i

    // load-response interface
    , input mem_out_s from_mem_i
    , input from_mem_v_i
    , output logic from_mem_yumi_o
    
    // load-store request interface
    , output mem_in_s to_mem_o
    , output logic to_mem_v_o
    , input to_mem_yumi_i

    // reservation
    , input logic reservation_i
    , output logic reserve_1_o

    , input outstanding_stores_i

    // for tracing
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

// Pipeline stage logic structures
//
id_signals_s id;
exe_signals_s exe;
mem_signals_s mem;
wb_signals_s wb;


//+----------------------------------------------
//|
//|     STALL AND EXCEPTION LOGIC SIGNALS
//|
//+----------------------------------------------
// Stall and exception logic
logic stall;
logic stall_non_mem;
logic stall_mem;
logic stall_lrw;
logic stall_md;
logic stall_ifetch;
logic stall_iwrite;
logic stall_mem_req;
logic stall_fence;
logic depend_stall;
logic stall_load_wb;

//We have to buffer the returned data from memory
//if there is a non-memory stall at current cycle.
logic is_load_buffer_valid;
logic [RV32_reg_data_width_gp-1:0]  load_buffer_info;

//the memory valid signal may come from memory or the buffer register
logic data_mem_valid;


// Signals for load write-back
logic current_load_arrived;
logic pending_load_arrived;
logic exe_free_for_load;
logic insert_load_in_exe;

// Decoded control signals logic
decode_s decode;
fp_decode_s fp_decode;

assign data_mem_valid = is_load_buffer_valid | current_load_arrived;
assign stall_fence = exe.decode.is_fence_op & (outstanding_stores_i);
assign stall_mem_req = (exe.decode.is_mem_op & (~to_mem_yumi_i));
assign stall_ifetch = (mem.decode.is_load_op & (~data_mem_valid) & mem.icache_miss);
assign stall_load_wb = pending_load_arrived & from_mem_i.buf_full & ~exe_free_for_load;

// stall due to data memory access
assign stall_mem = stall_mem_req
                 | stall_ifetch
                 | stall_fence
                 | stall_lrw
                 | stall_load_wb;

assign stall_iwrite = icache_v_i;
assign stall_non_mem = stall_iwrite | stall_md | freeze_i; 

// Stall if LD/ST still active; or in non-RUN state
assign stall = (stall_non_mem | stall_mem);

//+----------------------------------------------
//|
//|        EXTERNAL MODULE CONNECTIONS
//|
//+----------------------------------------------
// ALU logic
logic [RV32_reg_data_width_gp-1:0] rs1_to_alu, rs2_to_alu, basic_comp_result, alu_result;
logic [pc_width_lp-1:0] jalr_addr;
logic jump_now;

logic [RV32_reg_data_width_gp-1:0] mem_addr_send;
logic [RV32_reg_data_width_gp-1:0] store_data;
logic [3:0] mask;

mem_payload_u mem_payload;

// Data memory handshake logic

always_comb begin
  if (exe.decode.is_byte_op) begin
    store_data = {4{rs2_to_alu[7:0]}};
    mask = {mem_addr_send[1] & mem_addr_send[0],
            mem_addr_send[1] & ~mem_addr_send[0],
            ~mem_addr_send[1] & mem_addr_send[0],
            ~mem_addr_send[1] & ~mem_addr_send[0]};
  end
  else if (exe.decode.is_hex_op) begin
    store_data = {2{rs2_to_alu[15:0]}};
    mask = {{2{mem_addr_send[1]}}, {2{~mem_addr_send[1]}}};
  end
  else begin
    store_data = rs2_to_alu;
    mask = 4'b1111;
  end
end

//compute the address for mem operation
wire is_amo_op = id.decode.op_is_load_reservation
               | id.decode.op_is_swap_aq
               | id.decode.op_is_swap_rl;

wire [RV32_reg_data_width_gp-1:0] mem_addr_op2 =
        is_amo_op                ? 'b0 :
        id.decode.is_store_op    ? `RV32_signext_Simm(id.instruction)
                                 : `RV32_signext_Iimm(id.instruction);

wire [RV32_reg_data_width_gp-1:0] ld_st_addr   = rs1_to_alu +  exe.mem_addr_op2;

// We need to set the MSB of miss_pc to 1'b1 so it will be interpreted as DRAM
// address
wire [RV32_reg_data_width_gp-1:0] miss_pc       = (exe.pc_plus4 - 'h4) | dram_addr_mapping_lp; 

assign mem_addr_send= exe.icache_miss? miss_pc : ld_st_addr ;

// Store op sends store data as the payload while
// a load op sends destination register as the payload
// to distinguish multiple non-blocking load requests
always_comb begin
  if(exe.decode.is_load_op) begin
    mem_payload.read_info = '{rsvd      : '0
                             ,load_info : '{icache_fetch   : exe.icache_miss
                                           ,is_unsigned_op : exe.decode.is_load_unsigned
                                           ,is_byte_op     : exe.decode.is_byte_op
                                           ,is_hex_op      : exe.decode.is_hex_op
                                           ,part_sel       : mem_addr_send[1:0]
                                           ,reg_id         : exe.instruction.rd
                                           ,is_float_wb    : 1'b0
                                           }
                             };
  end else begin
    mem_payload.write_data = store_data;
  end
end

assign to_mem_o = '{
    payload       : mem_payload,
    wen           : exe.decode.is_store_op,
    swap_aq       : exe.decode.op_is_swap_aq,
    swap_rl       : exe.decode.op_is_swap_rl,
    mask          : mask,
    addr          : mem_addr_send
};

//+----------------------------------------------
//|
//|     BRANCH AND JUMP PREDICTION SIGNALS
//|
//+----------------------------------------------

// Branch and jump predictions
logic [RV32_reg_data_width_gp-1:0] jalr_prediction_n, jalr_prediction_r;

// Under predicted flag (meaning that we predicted not taken when taken)
wire branch_under_predict =
        (~exe.instruction[pred_index_lp]) & jump_now;

// Over predicted flag (meaning that we predicted taken when not taken)
wire branch_over_predict =
        exe.instruction[pred_index_lp] & (~jump_now);

// Flag if a branch misprediction occured
wire branch_mispredict = exe.decode.is_branch_op
                           & (branch_under_predict | branch_over_predict);

// JALR mispredict (or just a JALR instruction in the single cycle because it
// follows the same logic as a JALR mispredict)
wire jalr_mispredict = (exe.instruction.op ==? `RV32_JALR_OP)
                         & (jalr_addr != exe.pred_or_jump_addr[2+:pc_width_lp]);

// Flush the control signals in the execute and instr decode stages if there
// is a misprediction
wire icache_miss_in_pipe = id.icache_miss | exe.icache_miss | mem.icache_miss | wb.icache_miss;
wire flush = (branch_mispredict | jalr_mispredict );

//+----------------------------------------------
//|
//|          PROGRAM COUNTER SIGNALS
//|
//+----------------------------------------------

logic freeze_r;
always_ff @ (posedge clk_i) begin
  freeze_r <= freeze_i;
end

logic freeze_down;
assign freeze_down = freeze_r & ~freeze_i;

// Program counter logic
logic [pc_width_lp-1:0] pc_n, pc_r, pc_plus4, pred_or_jump_addr;
logic pc_wen, icache_cen;

// Instruction memory logic
instruction_s instruction;

// PC write enable. This stops the CPU updating the PC
assign pc_wen = (~(stall | depend_stall));

// Next PC under normal circumstances
assign pc_plus4 = pc_r + 1'b1;


// Determine what the next PC should be

always_comb begin
    // Network setting PC (highest priority)
    if (freeze_down)
        pc_n = '0;
    // cache miss
    else if (wb.icache_miss)
        pc_n = wb.icache_miss_pc[2+:pc_width_lp];

    // Fixing a branch misprediction (or single cycle branch will
    // follow a branch under prediction logic)
    else if (branch_mispredict)
        if (branch_under_predict)
            pc_n = exe.pred_or_jump_addr[2+:pc_width_lp];
        else
            pc_n = exe.pc_plus4[2+:pc_width_lp];

    // Fixing a JALR misprediction (or a signal cycle JALR instruction)
    else if (jalr_mispredict)
        pc_n = jalr_addr;

    // Predict taken branch or instruction is a long jump
    else if ((decode.is_branch_op & instruction[pred_index_lp]) | (instruction.op == `RV32_JAL_OP))
        pc_n = pred_or_jump_addr;

    // Predict jump to previous linked location
    else if (decode.is_jump_op) // equivalent to (instruction ==? `RV32_JALR)
        pc_n = pred_or_jump_addr;

    // Standard operation or predict not taken branch
    else
        pc_n = pc_plus4;
end

//+----------------------------------------------
//|
//|         INSTRUCTION MEMORY SIGNALS
//|
//+----------------------------------------------

// Instruction memory chip enable signal
logic [RV32_reg_data_width_gp-1:0] mem_data;
logic [RV32_reg_data_width_gp-1:0] loaded_pc;

assign icache_cen = (~stall & ~depend_stall) | (icache_v_i);

wire icache_w_en  = icache_v_i | (mem.icache_miss & data_mem_valid);

wire [icache_addr_width_p-1:0] icache_w_addr = icache_v_i
  ? icache_pc_i[0+:icache_addr_width_p]
  : loaded_pc[2+:icache_addr_width_p];

wire [icache_tag_width_p-1:0] icache_w_tag = icache_v_i
  ? icache_pc_i[icache_addr_width_p+:icache_tag_width_p]
  : loaded_pc[(icache_addr_width_p+2) +: icache_tag_width_p] ; 

wire [RV32_instr_width_gp-1:0] icache_w_instr = icache_v_i
  ? icache_instr_i
  : mem_data;

logic icache_miss_lo;

icache #(
  .icache_tag_width_p(icache_tag_width_p)
  ,.icache_addr_width_p(icache_addr_width_p) //word address
) icache_0 (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.icache_cen_i(icache_cen)
  ,.icache_w_en_i(icache_w_en)
  ,.icache_w_addr_i(icache_w_addr)
  ,.icache_w_tag_i(icache_w_tag) 
  ,.icache_w_instr_i(icache_w_instr)

  ,.flush_i(flush | icache_miss_in_pipe)
  ,.pc_i(pc_n)
  ,.pc_wen_i(pc_wen)
  ,.pc_r_o(pc_r)
  ,.jalr_prediction_i(jalr_prediction_n[2+:pc_width_lp])
  ,.instruction_o(instruction)
  ,.pred_or_jump_addr_o(pred_or_jump_addr)
  ,.icache_miss_o(icache_miss_lo)
);

//+----------------------------------------------
//|
//|         DECODE CONTROL SIGNALS
//|
//+----------------------------------------------

// Instantiate the instruction decoder
cl_decode cl_decode_0
(
  .instruction_i(instruction)
  ,.decode_o(decode)
  ,.fp_decode_o(fp_decode)
);

  //+----------------------------------------------
  //|
  //|           REGISTER FILE SIGNALS
  //|
  //+----------------------------------------------

  
  // INT regfile
  //
  logic [RV32_reg_data_width_gp-1:0] rf_rs1_val, rf_rs2_val, rf_wd;
  logic [RV32_reg_addr_width_gp-1:0] rf_wa;
  logic rf_wen;
  logic id_r0_v_li, id_r1_v_li;

  logic [RV32_reg_data_width_gp-1:0] mem_loaded_data;

  assign id_r0_v_li = decode.op_reads_rf1 & ~(stall | depend_stall);
  assign id_r1_v_li = decode.op_reads_rf2 & ~(stall | depend_stall);

  regfile #(
    .width_p(RV32_reg_data_width_gp)
    ,.els_p(32)
    ,.is_float_p(0)
  ) rf_int (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.w_v_i(rf_wen)
    ,.w_addr_i(rf_wa)
    ,.w_data_i(rf_wd)

    ,.r0_v_i(id_r0_v_li)
    ,.r0_addr_i(instruction.rs1)
    ,.r0_data_o(rf_rs1_val)

    ,.r1_v_i(id_r1_v_li)
    ,.r1_addr_i(instruction.rs2)
    ,.r1_data_o(rf_rs2_val)
  );

  always_comb begin
    rf_wa = wb.rd_addr;
    rf_wd = wb.rf_data;

    if (stall & pending_load_arrived) begin
      rf_wen = 1'b1;
      rf_wa  = from_mem_i.load_info.reg_id;
      rf_wd  = mem_loaded_data;
    end else if (wb.op_writes_rf & (~stall)) begin
      rf_wen = 1'b1;
    end else begin
      rf_wen = 1'b0;
    end
  end

  // FP regfile
  //
  logic fp_rf_wen;
  logic [RV32_reg_addr_width_gp-1:0] fp_rf_wa;
  logic [RV32_reg_data_width_gp-1:0] fp_rf_wd;
  
  logic fp_rs1_read, fp_rs2_read;
  logic [RV32_reg_data_width_gp-1:0] fp_rf_rs1_val, fp_rf_rs2_val;

  regfile #(
    .width_p(RV32_reg_data_width_gp)
    ,.els_p(32)
    ,.is_float_p(1)
  ) rf_float (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.w_v_i(fp_rf_wen)
    ,.w_addr_i(fp_rf_wa)
    ,.w_data_i(fp_rf_wd)

    ,.r0_v_i(fp_rs1_read)
    ,.r0_addr_i(instruction.rs1)
    ,.r0_data_o(fp_rf_rs1_val)

    ,.r1_v_i(fp_rs2_read)
    ,.r1_addr_i(instruction.rs2)
    ,.r1_data_o(fp_rf_rs2_val)
  );

//+----------------------------------------------
//|
//|     SCOREBOARD of load dependencies
//|
//+----------------------------------------------
// Scoreboard keeps track of load dependencies to support
// non-blocking loads. A load instruction creates a dependency
// on it's destination register when transitioning to EXE stage. 
// Any instruction depending on that register is stalled in ID
// stage until the loaded value is written back to RF.

logic record_load;

// Record a load in the scoreboard when a load instruction is moved to exe stage.
assign record_load = id.decode.is_load_op & id.decode.op_writes_rf
  & ~(flush | stall | depend_stall);

logic dependency;

scoreboard #(
  .els_p(32)
  ,.is_float_p(0)
) sb_int (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.src1_id_i(id.instruction.rs1)
  ,.src2_id_i(id.instruction.rs2)
  ,.dest_id_i(id.instruction.rd)

  ,.op_reads_rf1_i(id.decode.op_reads_rf1)
  ,.op_reads_rf2_i(id.decode.op_reads_rf2)
  ,.op_writes_rf_i(id.decode.op_writes_rf)

  ,.score_i(record_load)
  ,.clear_i(from_mem_yumi_o)
  ,.clear_id_i(from_mem_i.load_info.reg_id)

  ,.dependency_o(dependency)
);


  // FP scoreboard
  //
  logic fp_dependency;
  logic fp_score;
  logic fp_clear;
  logic [RV32_reg_addr_width_gp-1:0] fp_clear_id;

  scoreboard #(
    .els_p(32)
    ,.is_float_p(1)
  ) sb_float (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.src1_id_i(id.instruction.rs1)
    ,.src2_id_i(id.instruction.rs2)
    ,.dest_id_i(id.instruction.rd)

    ,.op_reads_rf1_i(id.decode.op_reads_fp_rf1)
    ,.op_reads_rf2_i(id.decode.op_reads_fp_rf2)
    ,.op_writes_rf_i(id.decode.op_writes_fp_rf)

    ,.score_i(fp_score)
    ,.clear_i(fp_clear)
    ,.clear_id_i(fp_clear_id)

    ,.dependency_o(fp_dependency)
  );

assign depend_stall = dependency & (~branch_mispredict);

//+----------------------------------------------
//|
//|           Load write-back logic
//|
//+----------------------------------------------

// Singal to detect remote load in exe
logic remote_load_in_exe;

assign current_load_arrived = from_mem_v_i 
                                & (mem.icache_miss 
                                    ? from_mem_i.load_info.icache_fetch
                                    : (from_mem_i.load_info.reg_id == mem.rd_addr)
                                  );
assign pending_load_arrived = from_mem_v_i & ~current_load_arrived;

// Since remote load takes more than one cycle to fetch, and as loads are
// non-blocking, write-back wouldn't happen when the instrucion is still
// in the pipeline
assign exe_free_for_load = (~exe.decode.op_writes_rf | remote_load_in_exe)
                             & ~exe.icache_miss;
assign insert_load_in_exe = pending_load_arrived
                              & exe_free_for_load
                              & ~stall;

//+----------------------------------------------
//|
//|     RISC-V edit: "M" STANDARD EXTENSION
//|
//+----------------------------------------------

// MUL/DIV signals
logic md_ready, md_resp_valid;
logic [31:0] md_result;

wire   md_valid    = exe.decode.is_md_instr & md_ready;
assign stall_md    = exe.decode.is_md_instr & ~md_resp_valid;

imul_idiv_iterative md_0 (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.v_i(md_valid)
  ,.ready_o(md_ready)

  ,.opA_i(rs1_to_alu)
  ,.opB_i(rs2_to_alu)
  ,.funct3(exe.instruction.funct3)

  ,.v_o(md_resp_valid)
  ,.result_o(md_result)

  //if there is a stall issued at MEM stage, we can't receive the mul/div
  //result.
  ,.yumi_i(~stall_non_mem)
);


//+----------------------------------------------
//|
//|                ALU SIGNALS
//|
//+----------------------------------------------

// Value forwarding logic
logic [RV32_reg_data_width_gp-1:0] rs1_forward_val;
logic [RV32_reg_data_width_gp-1:0] rs2_forward_val;

//We only forword the non loaded data in mem stage.
bsg_mux #(
  .width_p(RV32_reg_data_width_gp)
  ,.els_p(2)
) rs1_forward_mux (
  .data_i({ mem.exe_result, wb.rf_data })
  ,.sel_i(exe.rs1_in_mem)
  ,.data_o(rs1_forward_val)
);

wire rs1_is_forward = (exe.rs1_in_mem | exe.rs1_in_wb);

bsg_mux #(
  .width_p(RV32_reg_data_width_gp)
  ,.els_p(2)
) rs2_forward_mux (
  .data_i({ mem.exe_result, wb.rf_data })
  ,.sel_i(exe.rs2_in_mem)
  ,.data_o(rs2_forward_val)
);

wire rs2_is_forward = (exe.rs2_in_mem | exe.rs2_in_wb);

// RISC-V edit: Immediate values handled in alu
bsg_mux #(
  .width_p(RV32_reg_data_width_gp)
  ,.els_p(2)
) rs1_alu_mux (
  .data_i({ rs1_forward_val, exe.rs1_val })
  ,.sel_i(rs1_is_forward)
  ,.data_o(rs1_to_alu)
);

bsg_mux #(
  .width_p(RV32_reg_data_width_gp)
  ,.els_p(2)
) rs2_alu_mux (
  .data_i({ rs2_forward_val, exe.rs2_val })
  ,.sel_i(rs2_is_forward)
  ,.data_o(rs2_to_alu)
);

// Instantiate the ALU
alu #(
  .pc_width_p(pc_width_lp)
) alu_0 (
  .rs1_i(rs1_to_alu)
  ,.rs2_i(rs2_to_alu)
  ,.pc_plus4_i(exe.pc_plus4)
  ,.op_i(exe.instruction)
  ,.result_o(basic_comp_result)
  ,.jalr_addr_o(jalr_addr)
  ,.jump_now_o(jump_now)
);

assign alu_result = exe.decode.is_md_instr ? md_result : basic_comp_result;

//+----------------------------------------------
//|
//|        DATA MEMORY HANDSHAKE SIGNALS
//|
//+----------------------------------------------
// we are waiting memory response in case of a cache miss.
// Normal loads are non-blocking and hence execution would
// continue even without the response
wire wait_mem_rsp     = mem.decode.is_load_op & (~data_mem_valid) & mem.icache_miss;

// don't present the request if we are stalling because of non-load/store reason
wire non_ld_st_stall  = stall_non_mem | stall_lrw;     

//icache miss is also decoded as mem op
assign to_mem_v_o = exe.decode.is_mem_op 
                          & (~wait_mem_rsp) 
                          & (~non_ld_st_stall) 
                          & (~stall_load_wb)
                          // Below condition means there is a contention between the network 
                          // and local memory. Hence issue no more local load requests.
                          & (~(current_load_arrived & from_mem_i.buf_full) | remote_load_in_exe); 

//We should always accept the returned data even there is a non memory stall
assign from_mem_yumi_o = from_mem_v_i 
                          & (stall 
                              | current_load_arrived
                              | insert_load_in_exe
                            );

// RISC-V edit: add reservation
//lr.acq will stall until the reservation is cleared;
assign stall_lrw    = exe.decode.op_is_lr_acq & reservation_i;

//lr instrution will load the data and reserve the address
// NB: lr_acq is a type of load reservation, hence the check
assign reserve_1_o  = exe.decode.op_is_load_reservation & (~exe.decode.op_is_lr_acq);



// Update the JALR prediction register
assign jalr_prediction_n = exe.decode.is_jump_op
  ? exe.pc_plus4
  : jalr_prediction_r;

bsg_dff_reset #(
  .width_p(RV32_reg_data_width_gp)
) jalr_prediction_r_reg (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.data_i(jalr_prediction_n)
  ,.data_o(jalr_prediction_r)
);



//+----------------------------------------------
//|
//|     INSTR FETCH TO INSTR DECODE SHIFT
//|
//+----------------------------------------------

// Synchronous stage shift
id_signals_s  id_s;
// We set the icache miss as a remote load without read/write registers.
decode_s     id_decode;

always_comb begin
    id_decode =  'b0;
    if( icache_miss_lo) begin
        id_decode.is_load_op   = 1'b1;
        id_decode.is_mem_op    = 1'b1;
        id_decode.op_writes_rf = 1'b0;
    end else begin
        id_decode = decode;
    end
end

wire [RV32_instr_width_gp-1:0] id_instr = icache_miss_lo
  ? 'b0
  : instruction;

assign id_s = '{
  pc_plus4     : {pc_high_padding_lp, pc_plus4    ,2'b0}  ,
  pred_or_jump_addr : {pc_high_padding_lp, pred_or_jump_addr, 2'b0}  ,
  instruction  : id_instr                                 ,
  decode       : id_decode                                ,
  icache_miss  : icache_miss_lo 
};

always_ff @ (posedge clk_i) begin
  if (reset_i | freeze_i | flush | (icache_miss_in_pipe & (~ (stall | depend_stall)))) begin
    id <= '0;
  end
  else if (~stall & ~depend_stall) begin
    id <= id_s;
  end
end


//+----------------------------------------------
//|
//|        INSTR DECODE TO EXECUTE SHIFT
//|
//+----------------------------------------------
logic [RV32_reg_addr_width_gp-1:0] exe_rd_addr;
logic exe_op_writes_rf;

//WB to ID forwarding logic
wire id_wb_rs1_forward = id.decode.op_reads_rf1
                       & (id.instruction.rs1 == wb.rd_addr)
                       & wb.op_writes_rf
                       & (id.instruction.rs1 != '0); //should not forward r0

wire id_wb_rs2_forward = id.decode.op_reads_rf2
                       & (id.instruction.rs2 == wb.rd_addr)
                       & wb.op_writes_rf
                       & (id.instruction.rs2 != '0); //should not forward r0

wire [RV32_reg_data_width_gp-1:0] rs1_to_exe = id_wb_rs1_forward
  ? wb.rf_data
  : rf_rs1_val;

wire [RV32_reg_data_width_gp-1:0] rs2_to_exe = id_wb_rs2_forward
  ? wb.rf_data
  : rf_rs2_val;

// Pre-Compute the forwarding control signal for ALU in EXE
// RS register forwarding
wire  exe_rs1_in_mem     = exe_op_writes_rf
                           & (id.instruction.rs1 == exe_rd_addr)
                           & (|id.instruction.rs1);
//Ratify this logic with load buffer
wire  exe_rs1_in_wb      = ( mem.decode.op_writes_rf | is_load_buffer_valid)
                           & (id.instruction.rs1  == mem.rd_addr)
                           & (|id.instruction.rs1);
wire  exe_rs2_in_mem     = exe_op_writes_rf
                           & (id.instruction.rs2 == exe_rd_addr)
                           & (|id.instruction.rs2);
wire  exe_rs2_in_wb      = ( mem.decode.op_writes_rf | is_load_buffer_valid )
                           & (id.instruction.rs2  == mem.rd_addr)
                           & (|id.instruction.rs2);

// Synchronous stage shift
always_ff @ (posedge clk_i) begin
  if (reset_i | flush | freeze_i) begin
    exe <= '0;
  end
  else if (depend_stall & (~stall)) begin
    exe <= '0; //insert a bubble to the pipeline
  end
  else if (~stall) begin
    exe <= '{
      pc_plus4     : id.pc_plus4,
      pred_or_jump_addr : id.pred_or_jump_addr,
      instruction  : id.instruction,
      decode       : id.decode,
      rs1_val      : rs1_to_exe,
      rs2_val      : rs2_to_exe,
      mem_addr_op2 : mem_addr_op2,
      rs1_in_mem   : exe_rs1_in_mem,
      rs1_in_wb    : exe_rs1_in_wb,
      rs2_in_mem   : exe_rs2_in_mem,
      rs2_in_wb    : exe_rs2_in_wb,
      icache_miss  : id.icache_miss
    };
  end
end


//+----------------------------------------------
//|
//|          EXECUTE TO MEMORY SHIFT
//|
//+----------------------------------------------

logic [RV32_reg_data_width_gp-1:0] exe_result;

// dram addr                    : 1xxxxxxxx
// out-group remote addr        : 01xxxxxxx
// in-group remote addr         : 001xxxxxx
wire is_dram_addr   = mem_addr_send [ (RV32_reg_data_width_gp-1) -: 1 ] == 1'b1;
wire is_global_addr = mem_addr_send [ (RV32_reg_data_width_gp-1) -: 2 ] == 2'b01;
wire is_group_addr  = mem_addr_send [ (RV32_reg_data_width_gp-1) -: 3 ] == 3'b001;

assign remote_load_in_exe = exe.decode.is_load_op 
                         & (is_global_addr | is_group_addr | is_dram_addr)
                         & (~exe.icache_miss); 

// Loded data is inserted into the exe stage along
// with an instruction that doesn't write to RF
always_comb begin
  if (insert_load_in_exe) begin
    exe_result         = mem_loaded_data;
    exe_rd_addr        = from_mem_i.load_info.reg_id;
    exe_op_writes_rf   = 1'b1;
  end
  else begin
    exe_result         = alu_result;
    exe_rd_addr        = exe.instruction.rd;
    exe_op_writes_rf   = exe.decode.op_writes_rf & ~remote_load_in_exe;
  end
end

// Synchronous stage shift
always_ff @ (posedge clk_i) begin
  if (reset_i | freeze_i) begin
    mem <= '0;
  end
  else if (~stall) begin
    mem <= '{
      rd_addr       : exe_rd_addr,
      decode        : exe.decode,
      exe_result    : exe_result,
      mem_addr_send : mem_addr_send,
      remote_load   : remote_load_in_exe,
      icache_miss   : exe.icache_miss
    };

    mem.decode.op_writes_rf <= exe_op_writes_rf;
  end
end


//+----------------------------------------------
//|
//|       MEMORY TO RF WRITE BACK SHIFT
//|
//+----------------------------------------------

always_ff @ (posedge clk_i) begin
  if (reset_i | freeze_i) begin
    is_load_buffer_valid <= 'b0;
    load_buffer_info     <= 'b0;
  end
  // During a stall buffer the loaded data if the corresponding instruction is still
  // in the MEM stage.
  else if(stall & current_load_arrived) begin
    is_load_buffer_valid <= 1'b1;
    load_buffer_info     <= from_mem_i.read_data;
  end
  // we should clear the buffer if not stalled
  else if(~stall) begin
    is_load_buffer_valid <= 'b0;
    load_buffer_info     <= 'b0;
  end
end

// load data for icache & fpu
assign mem_data  = (is_load_buffer_valid & ~stall)
  ? load_buffer_info
  : from_mem_i.read_data;

assign loaded_pc =  mem.mem_addr_send;

// byte or hex pack data from memory
load_packer mem_load_packer
  (.mem_data_i      (from_mem_i.read_data)
  ,.unsigned_load_i (from_mem_i.load_info.is_unsigned_op)
  ,.byte_load_i     (from_mem_i.load_info.is_byte_op)
  ,.hex_load_i      (from_mem_i.load_info.is_hex_op)
  ,.part_sel_i      (from_mem_i.load_info.part_sel)
  ,.load_data_o     (mem_loaded_data)
  );

logic [RV32_reg_data_width_gp-1:0] buf_loaded_data;

// byte or hex pack data from load buffer
load_packer buf_load_packer
  (.mem_data_i      (load_buffer_info)
  ,.unsigned_load_i (mem.decode.is_load_unsigned)
  ,.byte_load_i     (mem.decode.is_byte_op)
  ,.hex_load_i      (mem.decode.is_hex_op)
  ,.part_sel_i      (mem.mem_addr_send[1:0])
  ,.load_data_o     (buf_loaded_data)
  );

logic [RV32_reg_data_width_gp-1:0] rf_data;
logic [RV32_reg_addr_width_gp-1:0] rd_addr_to_wb;
logic op_writes_rf_to_wb;

always_comb begin
  //remote or local load can both be buffered
  if (mem.decode.is_load_op & ((~mem.remote_load) | is_load_buffer_valid)) begin
    rf_data = is_load_buffer_valid
      ? buf_loaded_data
      : mem_loaded_data;
    op_writes_rf_to_wb = (is_load_buffer_valid | current_load_arrived) & ~mem.icache_miss;
    rd_addr_to_wb = mem.rd_addr;
  end else begin
    rf_data            = mem.exe_result;
    op_writes_rf_to_wb = mem.decode.op_writes_rf;
    rd_addr_to_wb      = mem.rd_addr;
  end
end

always_ff @ (posedge clk_i) begin
  if (reset_i | freeze_i) begin
    wb <= '0;
  end
  else if (~stall) begin

    wb <= '{
      op_writes_rf  : op_writes_rf_to_wb,
      rd_addr       : rd_addr_to_wb,
      rf_data       : rf_data,
      icache_miss   : mem.icache_miss,
      icache_miss_pc: loaded_pc
    };
  end
end



//synopsys translate_off

//FENCE_I instruction
//
always_ff @ (negedge clk_i ) begin
  if (id.decode.is_fence_i_op) begin
    $error("FENCE_I instruction not supported yet!");
  end
end

//-----------------------------------------------------
// SP overflow checking.
// sp                           : x2
// _bsg_data_end_addr           : defined in Makefile and passed to VCS
localparam bsg_data_end_lp =  `_bsg_data_end_addr ;

always_ff @ (negedge clk_i) begin
  if (~reset_i & rf_wen & rf_wa == 2 & rf_wd < bsg_data_end_lp ) begin
    $display("##---------------------------------------------");
    $display("## Warning: SP underflow:  local memory data end =%x, sp=%h,%t,%m",
      bsg_data_end_lp, rf_wd, $time); 
    $display("##---------------------------------------------");
  end
end


//synopsys translate_on

endmodule
