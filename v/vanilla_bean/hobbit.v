`include "parameters.v"
`include "definitions.v"

`ifdef bsg_FPU
`include "float_definitions.v"
`endif
//`include "bsg_defines.v"

/**
 *  Vanilla-Bean Core
 *
 *  5 stage pipeline implementation of the vanilla core ISA.
 */
module hobbit #(parameter imem_addr_width_p = -1,
                          gw_ID_p           = -1,
                          ring_ID_p         = -1,
                          x_cord_width_p    = -1,
                          y_cord_width_p    = -1,
                          debug_p           = 0)
               (
                input                             clk
               ,input                             reset

`ifdef bsg_FPU
               ,fpi_alu_inter.alu_side            fpi_inter
`endif
               ,input  ring_packet_s              net_packet_i

               ,input  mem_out_s                  from_mem_i
               ,output mem_in_s                   to_mem_o
               ,input  logic                      reservation_i
               ,output logic                      reserve_1_o

               ,input  [x_cord_width_p-1:0]       my_x_i
               ,input  [y_cord_width_p-1:0]       my_y_i

               ,input                             outstanding_stores_i
               );


//localparam trace_lp = 1'b1;
   localparam trace_lp = 1'b0;

//the imem size constraints, which are limited by the instruction encoding space
localparam   imem_addr_width_limit_lp  = 12;
localparam   imem_addr_width_margin_lp = imem_addr_width_limit_lp - imem_addr_width_p;

// position in recoded instruction memory of prediction bit
// for branches. normally this would be bit 31 in RISCV ISA (branch ofs sign bit)
// but we've partially evaluated the addresses so they are absolute. instead
// we replicate that bit in bit 0 of the RISC-V instruction, which is unused

localparam pred_index_lp = 0;

// Pipeline stage logic structures
id_signals_s  id;
exe_signals_s exe;
mem_signals_s mem;
wb_signals_s  wb;

//+----------------------------------------------
//|
//|         NETWORK PACKET SIGNALS
//|
//+----------------------------------------------

// Network signals logic
ring_packet_s net_packet_r;
logic         net_id_match_valid, net_pc_write_cmd,  net_imem_write_cmd,
              net_reg_write_cmd, net_pc_write_cmd_idle,
              exec_net_packet;

// Detect a valid packet for this core (vaild and IDs match)
assign net_id_match_valid = (net_packet_r.header.ring_ID == ring_ID_p)
                       // & (net_packet_r.header.gw_ID == gw_ID_p)
                          & (~net_packet_r.header.external)
                          & (net_packet_r.valid);

// Detect if this network packet should be executed by this core. Two cases:
//  1) IDs match and not a broadcast (if ID matches a broadcast, this core sent it)
//  2) ID doesn't match but the packet is a broadcast
assign exec_net_packet    = (net_id_match_valid & ~net_packet_r.header.bc)
                            | ((~net_id_match_valid) & net_packet_r.header.bc &
                            net_packet_r.valid & (~net_packet_r.header.external));

// Network command control signals
// State machine logic
state_e state_n, state_r;

assign net_pc_write_cmd      = exec_net_packet  & (net_packet_r.header.net_op == PC);
assign net_imem_write_cmd    = exec_net_packet  & (net_packet_r.header.net_op == INSTR);
assign net_reg_write_cmd     = exec_net_packet  & (net_packet_r.header.net_op == REG);
assign net_pc_write_cmd_idle = net_pc_write_cmd & (state_r == IDLE);

//+----------------------------------------------
//|
//|     STALL AND EXCEPTION LOGIC SIGNALS
//|
//+----------------------------------------------
// Stall and exception logic
logic stall, stall_non_mem, stall_mem, stall_lrw, stall_md;
logic stall_fence;

//We have to buffer the returned data from memory
//if there is a non-memory stall at current cycle.
logic                               is_load_buffer_valid;
logic [RV32_reg_data_width_gp-1:0]  load_buffer_data;

//the memory valid signal may come from memory of the buffer register
logic                               data_mem_valid;

// Decoded control signals logic
decode_s decode;

assign data_mem_valid = is_load_buffer_valid | from_mem_i.valid;

assign stall_non_mem = (net_imem_write_cmd)
                     | (net_reg_write_cmd & wb.op_writes_rf)
                     | (net_reg_write_cmd)
                     | (state_r != RUN)
`ifdef bsg_FPU
                     | fpi_inter.fam_contend_stall
`endif
                     | stall_md;
// stall due to fence instruction
assign stall_fence = exe.decode.is_fence_op & (outstanding_stores_i);

// stall due to data memory access
assign stall_mem = (exe.decode.is_mem_op & (~from_mem_i.yumi))
                   | (mem.decode.is_load_op & (~data_mem_valid))
                   | stall_fence
                   | stall_lrw;

// Stall if LD/ST still active; or in non-RUN state
assign stall = (stall_non_mem | stall_mem);


//data dependency stall
//only occurs when the is operation needs loaded data immediately
wire id_exe_rs1_match = id.decode.op_reads_rf1 & ( id.instruction.rs1 == exe.instruction.rd );
wire id_exe_rs2_match = id.decode.op_reads_rf2 & ( id.instruction.rs2 == exe.instruction.rd );
wire depend_stall      = (id_exe_rs1_match | id_exe_rs2_match)
                       & exe.decode.is_load_op
                       & exe.decode.op_writes_rf; //FPU load won't write rf


//+----------------------------------------------
//|
//|        EXTERNAL MODULE CONNECTIONS
//|
//+----------------------------------------------
// ALU logic
logic [RV32_reg_data_width_gp-1:0] rs1_to_alu, rs2_to_alu, basic_comp_result, alu_result;
logic [imem_addr_width_p-1:0]      jalr_addr;
logic                              jump_now;

logic [RV32_reg_data_width_gp-1:0] mem_addr_send;
logic [RV32_reg_data_width_gp-1:0] store_data;
logic [3:0]                        mask;

// Data memory handshake logic
logic valid_to_mem_c, yumi_to_mem_c;

// RISC-V edit: support for byte and hex stores
always_comb
begin
  if (exe.decode.is_byte_op) // byte op
    begin
     // store_data = (32'(rs2_to_alu[7:0])) << ((5'(mem_addr_send[1:0])) << 3);
     // mask       = (4'b0001 << mem_addr_send[1:0]);
     store_data = (32'(rs2_to_alu[7:0])) << ((5'(mem_addr_send[1:0])) << 3);
      mask       = (4'b0001 << mem_addr_send[1:0]);
    end
  else if(exe.decode.is_hex_op) // hex op
    begin
      store_data = (32'(rs2_to_alu[15:0])) << ((5'(mem_addr_send[1:0])) << 3);
      mask       = (4'b0011 << mem_addr_send[1:0]);
    end
  else
    begin
`ifdef bsg_FPU
      store_data = fpi_inter.exe_fpi_store_op ? fpi_inter.frs2_to_fiu: rs2_to_alu;
`else
      store_data = rs2_to_alu;
`endif
      mask       = 4'b1111;
    end
end

//compute the address for mem operation
wire [RV32_reg_data_width_gp-1:0] mem_addr_op2 =
        id.decode.op_is_load_reservation ? 'b0 :
        id.decode.is_store_op            ? `RV32_signext_Simm(id.instruction)
                                         : `RV32_signext_Iimm(id.instruction);

assign mem_addr_send= rs1_to_alu +  exe.mem_addr_op2;

assign to_mem_o = '{
    write_data    : store_data,
    valid         : valid_to_mem_c,
    wen           : exe.decode.is_store_op,
    mask          : mask,
    yumi          : yumi_to_mem_c,
    addr          : mem_addr_send
};

//+----------------------------------------------
//|
//|     BRANCH AND JUMP PREDICTION SIGNALS
//|
//+----------------------------------------------

// Branch and jump predictions
logic [RV32_reg_data_width_gp-1:0] jalr_prediction_n, jalr_prediction_r,
                                   jalr_prediction_rr;

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
                         & (jalr_addr != jalr_prediction_rr);

// Flush the control signals in the execute and instr decode stages if there
// is a misprediction
wire flush = (branch_mispredict | jalr_mispredict);

//+----------------------------------------------
//|
//|          PROGRAM COUNTER SIGNALS
//|
//+----------------------------------------------

// Program counter logic
logic [imem_addr_width_p-1:0] pc_n, pc_r, pc_plus4, pc_jump_addr, pc_long_jump_addr;
logic                              pc_wen, pc_wen_r, imem_cen;

// Instruction memory logic
logic [imem_addr_width_p-1:0] imem_addr;
instruction_s                 imem_out, instruction, instruction_r;

// PC write enable. This stops the CPU updating the PC
`ifdef bsg_FPU
assign pc_wen = net_pc_write_cmd_idle | (~(stall | fpi_inter.fam_depend_stall | depend_stall));
`else
assign pc_wen = net_pc_write_cmd_idle | (~(stall | depend_stall));
`endif

// Next PC under normal circumstances
assign pc_plus4 = pc_r + 1'b1;
// Extract the WORD address,
wire  [imem_addr_width_limit_lp-1:0] BImm_extract =`RV32_Bimm_12extract(instruction);
wire  [imem_addr_width_limit_lp-1:0] JImm_extract =`RV32_Jimm_12extract(instruction);

assign pc_jump_addr      = decode.is_branch_op
                         ? BImm_extract[0+:imem_addr_width_p]
                         : JImm_extract[0+:imem_addr_width_p];

// Determine what the next PC should be
always_comb
begin
    // Update the JALR prediction register
    if (exe.decode.is_jump_op)
        jalr_prediction_n = exe.pc_plus4;
    else
        jalr_prediction_n = jalr_prediction_r;

    // Network setting PC (highest priority)
    if (net_pc_write_cmd_idle)
        pc_n = net_packet_r.header.addr[2+:imem_addr_width_p];

    // Fixing a branch misprediction (or single cycle branch will
    // follow a branch under prediction logic)
    else if (branch_mispredict)
        if (branch_under_predict)
            pc_n = exe.pc_jump_addr[2+:imem_addr_width_p];
        else
            pc_n = exe.pc_plus4[2+:imem_addr_width_p];

    // Fixing a JALR misprediction (or a signal cycle JALR instruction)
    else if (jalr_mispredict)
        pc_n = jalr_addr;

    // Predict taken branch or instruction is a long jump
    else if ((decode.is_branch_op & instruction[pred_index_lp]) | (instruction.op == `RV32_JAL_OP))
        pc_n = pc_jump_addr;

    // Predict jump to previous linked location
    else if (decode.is_jump_op) // equivalent to (instruction ==? `RV32_JALR)
        pc_n = jalr_prediction_n;

    // Standard operation or predict not taken branch
    else
        pc_n = pc_plus4;
end

//+----------------------------------------------
//|
//|         INSTRUCTION MEMORY SIGNALS
//|
//+----------------------------------------------


// Selection between network and core for instruction address
assign imem_addr = (net_imem_write_cmd)
                   ? net_packet_r.header.addr[2+:imem_addr_width_p]
                   : pc_n;

// Instruction memory chip enable signal
`ifdef bsg_FPU
assign imem_cen = (~( stall | fpi_inter.fam_depend_stall | depend_stall ))
                | (net_imem_write_cmd | net_pc_write_cmd_idle);
`else
assign imem_cen = (~ (stall | depend_stall) ) | (net_imem_write_cmd | net_pc_write_cmd_idle);
`endif
//Pre-calculate the jump and branch address.
//As imem is only 2K words in this design ,the jump and branch address can be
//encoded entirly in the imm field of the instruction.
//The address is encoded with WORD address
//synopsys translate_off
initial begin
assert( imem_addr_width_p <= imem_addr_width_limit_lp )
else $error("the imem_addr_width is too large");
end
//synopsys translate_on

wire  [RV32_instr_width_gp-1:0] BImm_sign_ext =`RV32_signext_Bimm(net_packet_r.data);
wire  [RV32_instr_width_gp-1:0] JImm_sign_ext =`RV32_signext_Jimm(net_packet_r.data);

instruction_s  instr_cast;
assign instr_cast  = net_packet_r.data;

wire  write_branch_instr = ( instr_cast.op    ==? `RV32_BRANCH );
wire  write_jal_instr    = ( instr_cast       ==? `RV32_JAL    );

wire [imem_addr_width_p-1:0] inject_pc_rel = write_branch_instr
              ? $signed(BImm_sign_ext[2+:imem_addr_width_p])
              : $signed(JImm_sign_ext[2+:imem_addr_width_p]);

//The computed address is WORD address
wire  [imem_addr_width_p-1:0] inject_pc_value  =
             $signed(net_packet_r.header.addr[2+:imem_addr_width_p])
            +$signed(inject_pc_rel);

//index starting from 1, for consistent with the instruction coding.
wire [imem_addr_width_limit_lp:1] inject_addr =
                             { {imem_addr_width_margin_lp{1'b0}}, inject_pc_value};
//Inject the WORD address
wire [RV32_instr_width_gp-1:0] imem_w_data =
        write_branch_instr ? `RV32_Bimm_12inject1( net_packet_r.data, inject_addr)
                           :  write_jal_instr    ? `RV32_Jimm_12inject1( net_packet_r.data, inject_addr)
                                                 : net_packet_r.data;
// RISC-V edit: reserved bits in network packet header
//              used as mask input

  bsg_mem_1rw_sync #
    ( .width_p (32)
     ,.els_p   (2**imem_addr_width_p)
    ) imem_0
    ( .clk_i  (clk)
     ,.reset_i(reset)
     ,.v_i    (imem_cen)
//     ,.w_i    (net_imem_write_cmd & net_packet_r.header.mask[i])
     ,.w_i    (net_imem_write_cmd)
     ,.addr_i (imem_addr)
     ,.data_i (imem_w_data)
     ,.data_o (imem_out)
    );

   // synopsys translate_off
   logic reset_r;

   always @(posedge clk) reset_r <= reset;
   always @(negedge clk)
     begin
          assert ( (reset_r !== 0 ) | ~net_imem_write_cmd | (&net_packet_r.header.mask))
          else $error("## byte write to instruction memory (%m)");
     end
   // synopsys translate_on

// Since imem has one cycle delay and we send next cycle's address, pc_n,
// if the PC is not written, the instruction must not change.
assign instruction = (pc_wen_r) ? imem_out : instruction_r;

//+----------------------------------------------
//|
//|         DECODE CONTROL SIGNALS
//|
//+----------------------------------------------

// Instantiate the instruction decoder
cl_decode cl_decode_0
(
    .instruction_i(instruction),
    .decode_o(decode)
);

//+----------------------------------------------
//|
//|           REGISTER FILE SIGNALS
//|
//+----------------------------------------------

// Register file logic
logic [RV32_reg_data_width_gp-1:0] rf_rs1_val, rf_rs2_val, rf_rs1_out, rf_rs2_out, rf_wd;
logic [RV32_reg_addr_width_gp-1:0] rf_wa;
logic                              rf_wen, rf_cen;

// Register write could be from network or the controller
// FPU depend stall will not affect register file write back
// MEM load depend stall will not affect register file write back
assign rf_wen = (net_reg_write_cmd) | (wb.op_writes_rf & (~stall));

// Selection between network 0and address included in the instruction which is
// exeuted Address for Reg. File is shorter than address of Ins. memory in network
// data Since network can write into immediate registers, the address is wider
// but for the destination register in an instruction the extra bits must be zero
assign rf_wa = (net_reg_write_cmd ? net_packet_r.header.addr[RV32_reg_addr_width_gp-1:0]
                                  : wb.rd_addr);

// Choose if the data is from the netword of the write-back stage
assign rf_wd = (net_reg_write_cmd ? net_packet_r.data : wb.rf_data);

// Register file chip enable signal
// FPU depend stall will not affect register file write back
// MEM load depend stall will not affect register file write back
// assign rf_cen = (~ stall ) | (net_reg_write_cmd);
 assign rf_cen= ~(stall | depend_stall );
//   assign rf_cen=  ~stall ;

// Instantiate the general purpose register file
// This register file is write through, which means when read/write
// The same address, the read gets the newly written value.
rf_2r1w_sync_wrapper #( .width_p                (RV32_reg_data_width_gp)
                       ,.els_p                  (32)
                      ) rf_0
  ( .clk_i   (clk)
   ,.reset_i (reset)
   ,.w_v_i     (rf_wen)
   ,.w_addr_i  (rf_wa)
   ,.w_data_i  (rf_wd)
   ,.r0_v_i    (rf_cen)
   ,.r0_addr_i (instruction.rs1)
   ,.r0_data_o (rf_rs1_val)
   ,.r1_v_i    (rf_cen)
   ,.r1_addr_i (instruction.rs2)
   ,.r1_data_o (rf_rs2_val)
  );


//+----------------------------------------------
//|
//|     RISC-V edit: "M" STANDARD EXTENSION
//|
//+----------------------------------------------
// MUL/DIV signals
logic        md_ready, md_resp_valid;
logic [31:0] md_result;

wire   md_valid    = exe.decode.is_md_instr & md_ready;
assign stall_md    = exe.decode.is_md_instr & ~md_resp_valid;

imul_idiv_iterative  md_0
    (.reset_i   (reset)
        ,.clk_i     (clk)

        ,.v_i       (md_valid)//there is a request
    ,.ready_o   (md_ready)//imul_idiv_module is idle

    ,.opA_i     (rs1_to_alu)
        ,.opB_i     (rs2_to_alu)
    ,.funct3    (exe.instruction.funct3)

        ,.v_o       (md_resp_valid )//result is valid
        ,.result_o  (md_result     )
    //if there is a stall issued at MEM stage, we can't receive the mul/div
    //result.
    ,.yumi_i    (~stall_non_mem)
    );
//+----------------------------------------------
//|
//|                ALU SIGNALS
//|
//+----------------------------------------------

// Value forwarding logic
logic [RV32_reg_data_width_gp-1:0] rs1_forward_val, rs2_forward_val;

//We only forword the non loaded data in mem stage.
//assign  rs1_forward_val  = rs1_in_mem ? mem.alu_result : wb.rf_data;
bsg_mux  #( .width_p    ( RV32_reg_data_width_gp )
           ,.els_p      ( 2                      )
          ) rs1_forward_mux
          ( .data_i     ( { mem.alu_result, wb.rf_data  }   )
           ,.sel_i      ( exe.rs1_in_mem                    )
           ,.data_o     ( rs1_forward_val                   )
          );

wire  rs1_is_forward   = (exe.rs1_in_mem | exe.rs1_in_wb);

//assign  rs2_forward_val  = rs2_in_mem ? mem.alu_result : wb.rf_data;
bsg_mux  #( .width_p    ( RV32_reg_data_width_gp )
           ,.els_p      ( 2                      )
          ) rs2_forward_mux
          ( .data_i     ( { mem.alu_result, wb.rf_data  }   )
           ,.sel_i      ( exe.rs2_in_mem                    )
           ,.data_o     ( rs2_forward_val                   )
          );

wire  rs2_is_forward   = (exe.rs2_in_mem | exe.rs2_in_wb);

// RISC-V edit: Immediate values handled in alu
//assign rs1_to_alu = ((rs1_is_forward) ? rs1_forward_val : exe.rs1_val);
bsg_mux  #( .width_p    ( RV32_reg_data_width_gp )
           ,.els_p      ( 2                      )
          ) rs1_alu_mux
          ( .data_i     ( { rs1_forward_val, exe.rs1_val }  )
           ,.sel_i      ( rs1_is_forward                    )
           ,.data_o     ( rs1_to_alu                        )
          );

//assign rs2_to_alu = ((rs2_is_forward) ? rs2_forward_val : exe.rs2_val);
bsg_mux  #( .width_p    ( RV32_reg_data_width_gp )
           ,.els_p      ( 2                      )
          ) rs2_alu_mux
          ( .data_i     ( { rs2_forward_val, exe.rs2_val }  )
           ,.sel_i      ( rs2_is_forward                    )
           ,.data_o     ( rs2_to_alu                        )
          );

// Instantiate the ALU
alu #(.imem_addr_width_p(imem_addr_width_p) )
   alu_0 (
    .rs1_i      (   rs1_to_alu          )
   ,.rs2_i      (   rs2_to_alu          )
   ,.pc_plus4_i (   exe.pc_plus4        )
   ,.op_i       (   exe.instruction     )
   ,.result_o   (   basic_comp_result   )
   ,.jalr_addr_o(   jalr_addr           )
   ,.jump_now_o (   jump_now            )
);

assign alu_result = exe.decode.is_md_instr ? md_result : basic_comp_result;

//+----------------------------------------------
//|
//|            STATE MACHINE SIGNALS
//|
//+----------------------------------------------

// Instantiate the state machine
cl_state_machine state_machine
(
    .instruction_i(exe.instruction),
    .state_i(state_r),
    .net_pc_write_cmd_idle_i(net_pc_write_cmd_idle),
    .stall_i(stall),
    .state_o(state_n)
);

//+----------------------------------------------
//|
//|        DATA MEMORY HANDSHAKE SIGNALS
//|
//+----------------------------------------------
assign valid_to_mem_c = exe.decode.is_mem_op & (~stall_non_mem) & (~stall_lrw); // don't present address if we are stalling

//We should always accept the returned data even there is a non memory stall
//assign yumi_to_mem_c  = mem.decode.is_mem_op & from_mem_i.valid & (~stall_non_mem);
assign yumi_to_mem_c  = mem.decode.is_mem_op & from_mem_i.valid ;

// RISC-V edit: add reservation
//lr.acq will stall until the reservation is cleared;
assign stall_lrw    = exe.decode.op_is_lr_acq & reservation_i;

//lr instrution will load the data and reserve the address
// NB: lr_acq is a type of load reservation, hence the check
assign reserve_1_o  = exe.decode.op_is_load_reservation
                   &(~exe.decode.op_is_lr_acq)  ;

//+----------------------------------------------
//|
//|        SEQUENTIAL LOGIC SIGNALS
//|
//+----------------------------------------------

// All sequental logic signals are set in this statement. The
// active high reset signal is what causes all signals to be
// reset to zero.
always_ff @ (posedge clk)
begin
    if (reset) begin
        state_r            <= IDLE;
        pc_wen_r           <= '0;
    end else begin
        state_r            <= state_n;
        pc_wen_r           <= pc_wen;
    end
end

   bsg_dff_reset #(.width_p(RV32_reg_data_width_gp), .harden_p(1)) jalr_prediction_r_reg
     (.clock_i(clk)
      ,.reset_i(reset)
      ,.data_i(jalr_prediction_n)
      ,.data_o(jalr_prediction_r)
      );

   bsg_dff_reset #(.width_p(RV32_reg_data_width_gp), .harden_p(1)) jalr_prediction_rr_reg
     (.clock_i(clk)
      ,.reset_i(reset)
      ,.data_i(jalr_prediction_r)
      ,.data_o(jalr_prediction_rr)
      );

   // mbt: unharden to reduce congestion
   bsg_dff_reset #(.width_p($bits(ring_packet_s)), .harden_p(0)) net_packet_r_reg
     (.clock_i(clk)
      ,.reset_i(reset)
      ,.data_i(net_packet_i)
      ,.data_o(net_packet_r)
      );

   bsg_dff_reset #(.width_p($bits(instruction_s)), .harden_p(1)) instruction_r_reg
     (.clock_i(clk)
      ,.reset_i(reset)
      ,.data_i(instruction)
      ,.data_o(instruction_r)
      );

   bsg_dff_reset_en #(.width_p(imem_addr_width_p),.harden_p(1)) pc_r_reg
     (.clock_i (clk)
      ,.reset_i(reset)
      ,.en_i   (pc_wen)
      ,.data_i (pc_n)
      ,.data_o (pc_r)
      );


   // synopsys translate_off
  debug_s debug_if, debug_id, debug_exe, debug_mem, debug_wb;

   localparam squashed_lp = 1'b1;

  // 1 indicates unsquashed
  assign debug_if = '{
                      PC_r : pc_r,
                      instruction_i: instruction,
                      state_r: state_r,
                      squashed: 1'b0
                      };

   // synopsys translate_on

//+----------------------------------------------
//|
//|     INSTR FETCH TO INSTR DECODE SHIFT
//|
//+----------------------------------------------

// Synchronous stage shift

// synopsys sync_set_reset  "reset, net_pc_write_cmd_idle, flush, stall, depend_stall"
always_ff @ (posedge clk)
begin
`ifdef bsg_FPU
    if (reset | net_pc_write_cmd_idle |
            (flush & (~(stall|fpi_inter.fam_depend_stall | depend_stall )))
       )
`else
    if (reset | net_pc_write_cmd_idle | (flush & (~   (stall | depend_stall)  ) ) )
`endif
      begin
         id <= '0;
   // synopsys translate_off
         debug_id <= debug_if | squashed_lp ;
   // synopsys translate_on
      end
`ifdef bsg_FPU
    else if (~(stall|fpi_inter.fam_depend_stall | depend_stall ))
`else
    else if (~ ( stall | depend_stall) )
`endif
      begin
   // synopsys translate_off
        debug_id <= debug_if;
   // synopsys translate_on
        id <= '{
            pc_plus4     : {pc_plus4,2'b0},
            pc_jump_addr : {pc_jump_addr,2'b0},
            instruction  : instruction,
            decode       : decode
        };
      end
end

//+----------------------------------------------
//|
//|        INSTR DECODE TO EXECUTE SHIFT
//|
//+----------------------------------------------

//WB to ID forwarding logic
wire id_wb_rs1_forward = id.decode.op_reads_rf1 & ( id.instruction.rs1 == wb.rd_addr)
                       & wb.op_writes_rf
                       & (| id.instruction.rs1) ; //should not forward r0
wire id_wb_rs2_forward = id.decode.op_reads_rf2 & ( id.instruction.rs2 == wb.rd_addr)
                       & wb.op_writes_rf
                       & (| id.instruction.rs2); //should not forward r0

wire [RV32_reg_data_width_gp-1:0]  rf_rs1_index0_fix = (~|id.instruction.rs1) ?
                                        RV32_reg_data_width_gp'(0) : rf_rs1_val;

wire [RV32_reg_data_width_gp-1:0]  rf_rs2_index0_fix = (~|id.instruction.rs2) ?
                                        RV32_reg_data_width_gp'(0) : rf_rs2_val;

wire [RV32_reg_data_width_gp-1:0] rs1_to_exe    = id_wb_rs1_forward ?
                                        wb.rf_data : rf_rs1_index0_fix;
wire [RV32_reg_data_width_gp-1:0] rs2_to_exe    = id_wb_rs2_forward ?
                                        wb.rf_data : rf_rs2_index0_fix;

// Pre-Compute the forwarding control signal for ALU in EXE
// RS register forwarding
wire    exe_rs1_in_mem     = exe.decode.op_writes_rf
                           & (id.instruction.rs1 == exe.instruction.rd)
                           & (|id.instruction.rs1);
wire    exe_rs1_in_wb      = mem.decode.op_writes_rf
                           & (id.instruction.rs1  == mem.rd_addr)
                           & (|id.instruction.rs1);

wire    exe_rs2_in_mem     = exe.decode.op_writes_rf
                           & (id.instruction.rs2 == exe.instruction.rd)
                           & (|id.instruction.rs2);
wire    exe_rs2_in_wb      = mem.decode.op_writes_rf
                           & (id.instruction.rs2  == mem.rd_addr)
                           & (|id.instruction.rs2);
// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle | (flush & (~ (stall | depend_stall ))))
      begin
   // synopsys translate_off
         debug_exe <= debug_id | squashed_lp;
   // synopsys translate_on
        exe       <= '0;
      end
`ifdef bsg_FPU
    else if(    ( fpi_inter.fam_depend_stall | depend_stall )
              & (~stall)
           )
`else
    else if ( depend_stall & (~stall) )
`endif
      begin
   // synopsys translate_off
         debug_exe <= debug_id | squashed_lp;
   // synopsys translate_on
         exe       <= '0; //insert a bubble to the pipeline
      end
    else if (~ stall)
      begin
         // synopsys translate_off
         debug_exe <= debug_id;
         // synopsys translate_on
         exe <= '{
                  pc_plus4     : id.pc_plus4,
                  pc_jump_addr : id.pc_jump_addr,
                  instruction  : id.instruction,
                  decode       : id.decode,
                  rs1_val      : rs1_to_exe,
                  rs2_val      : rs2_to_exe,
                  mem_addr_op2 : mem_addr_op2,
                  rs1_in_mem   : exe_rs1_in_mem,
                  rs1_in_wb    : exe_rs1_in_wb,
                  rs2_in_mem   : exe_rs2_in_mem,
                  rs2_in_wb    : exe_rs2_in_wb
                  };
      end
end

//+----------------------------------------------
//|
//|          EXECUTE TO MEMORY SHIFT
//|
//+----------------------------------------------


logic [RV32_reg_data_width_gp-1:0] fiu_alu_result;

`ifdef bsg_FPU
//The combined decode signal to MEM stages.
decode_s  fpi_alu_decode;

always_comb
begin
    fpi_alu_decode = exe.decode;
    if( fpi_inter.exe_fpi_writes_rf )
        fpi_alu_decode.op_writes_rf = 1'b1;
end

assign fiu_alu_result = fpi_inter.exe_fpi_writes_rf
                       ?fpi_inter.fiu_result
                       :alu_result;
`else
assign fiu_alu_result = alu_result;

`endif


// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle)
      begin
   // synopsys translate_off
         debug_mem <= squashed_lp;
   // synopsys translate_on
         mem       <= '0;
      end
    else if (~stall)
      begin
   // synopsys translate_off
         debug_mem <= debug_exe;
   // synopsys translate_on

        mem <= '{
            rd_addr    : exe.instruction.rd,
`ifdef bsg_FPU
            decode     : fpi_alu_decode,
`else
            decode     : exe.decode,
`endif
            alu_result : fiu_alu_result,

            mem_addr_send: mem_addr_send
        };
      end
end

//+----------------------------------------------
//|
//|       MEMORY TO RF WRITE BACK SHIFT
//|
//+----------------------------------------------


always_ff @ (posedge clk)
begin
    if ( reset )
    begin
        is_load_buffer_valid <= 'b0;
        load_buffer_data     <= 'b0;
    end
    //set the buffered value
    else if( stall & mem.decode.is_load_op & from_mem_i.valid )
    //else if( stall_non_mem & mem.decode.is_load_op & from_mem_i.valid )
    begin
        is_load_buffer_valid <= 1'b1;
        load_buffer_data     <= from_mem_i.read_data;
    end
    //we should clear the buffer if not stalled
    else if( ~stall )
    begin
        is_load_buffer_valid <= 'b0;
        load_buffer_data     <= 'b0;
    end
end


logic [RV32_reg_data_width_gp-1:0] loaded_data;
assign loaded_data =  is_load_buffer_valid ? load_buffer_data:
                                             from_mem_i.read_data;

logic [RV32_reg_data_width_gp-1:0] loaded_byte;
always_comb
begin
//    unique casez (mem.mem_addr_send[1:0])
    unique casez (mem.mem_addr_send[1:0])
      2'b00:    loaded_byte = loaded_data[0+:8];
      2'b01:    loaded_byte = loaded_data[8+:8];
      2'b10:    loaded_byte = loaded_data[16+:8];
      default:  loaded_byte = loaded_data[24+:8];
    endcase
end

//wire [RV32_reg_data_width_gp-1:0] loaded_hex = (|mem.mem_addr_send[1:0])
wire [RV32_reg_data_width_gp-1:0] loaded_hex = (|mem.mem_addr_send[1:0])
                                             ? loaded_data[16+:16]
                                             : loaded_data[0+:16];

logic [RV32_reg_data_width_gp-1:0] mem_loaded_data;
always_comb
begin
    if (mem.decode.is_byte_op)
        mem_loaded_data = (mem.decode.is_load_unsigned)
                        ? 32'(loaded_byte[7:0])
                        : {{24{loaded_byte[7]}}, loaded_byte[7:0]};
    else if(mem.decode.is_hex_op)
        mem_loaded_data = (mem.decode.is_load_unsigned)
                        ? 32'(loaded_hex[15:0])
                        : {{24{loaded_hex[15]}}, loaded_hex[15:0]};
    else
        mem_loaded_data = loaded_data;
end

wire [RV32_reg_data_width_gp-1:0]  rf_data = mem.decode.is_load_op ?
                                             mem_loaded_data : mem.alu_result;

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | net_pc_write_cmd_idle)
      begin
         wb       <= '0;
   // synopsys translate_off
         debug_wb <= squashed_lp;
   // synopsys translate_on
      end
    else if (~stall)
      begin
   // synopsys translate_off
         debug_wb <= debug_mem;
   // synopsys translate_on
         wb       <= '{
                       op_writes_rf : mem.decode.op_writes_rf,
                       rd_addr      : mem.rd_addr,
                       rf_data      : rf_data
                       };
      end
end

///////////////////////////////////////////////////////////////////
// Assign the outputs to FPI
`ifdef bsg_FPU

assign fpi_inter.alu_stall              = stall;
assign fpi_inter.alu_flush              = flush;
assign fpi_inter.rs1_of_alu             = rs1_to_alu;
assign fpi_inter.flw_data               = loaded_data;
assign fpi_inter.f_instruction          = instruction;
assign fpi_inter.mem_alu_writes_rf      = mem.decode.op_writes_rf;
assign fpi_inter.mem_alu_rd_addr        = mem.rd_addr;
/////////////////////////////////////////////////////////////////////
// Some instruction validation check.
//synopsys translate_off

//Double Precision Floating Point Load/Store
always@(negedge clk )
begin
    unique casez( id.instruction.op )
        `RV32_STORE_FP, `RV32_LOAD_FP:
        if(  id.instruction.funct3 == `RV32_FDLS_FUN3 )
        begin
            if(  id.instruction.rs1  != 5'd2 )
                $error("Double Precision Load/Store With register other than SP: PC=%08x, INSTRUCTION:=%08x",
                   id.pc_plus4, id.instruction);
            else
                $warning("Double Precision Load/Store With SP: PC=%08x, INSTRUCTION:=%08x",
                   id.pc_plus4-4, id.instruction);
        end
        default:
        begin
        end
    endcase
end

//FENCE_I instruction
always@(negedge clk ) begin
    if( id.decode.is_fence_i_op ) begin
        $error("FENCE_I instruction not supported yet!");
    end
end
//synopsys translate_on


`endif

//synopsys translate_off

   if (trace_lp)
//if (0)
     always_ff @(negedge clk)
       begin
          if (~(debug_wb.squashed  & (debug_wb.PC_r == 0)))
            begin
               $write("X,Y=(%x,%x) PC=%x (%x)"
                      ,my_x_i, my_y_i
                      , (debug_wb.PC_r <<2)
                      ,debug_wb.instruction_i
                      );
               if (debug_wb.squashed)
                 $write(" <squashed>");
               if (stall)
                 $write(" <stall>");

               if (wb.op_writes_rf)
                 $write(" r[%d] <= %x", wb.rd_addr, wb.rf_data);

               $write("\n");
            end
       end

if(debug_p)
  always_ff @(negedge clk)
  begin
    if ((my_x_i == 1) & (my_y_i == 0) & (state_r==RUN))
      begin
        $display("\n%0dns (%d,%d):", $time, my_x_i, my_y_i);
        $display("  IF: pc  :%x instr:{%x_%x_%x_%x_%x_%x} state:%b net_pkt:{%x_%x_%x}"
                 ,pc_r
                 ,instruction.funct7
                 ,instruction.rs2
                 ,instruction.rs1
                 ,instruction.funct3
                 ,instruction.rd
                 ,instruction.op
                 ,state_r
                 ,net_packet_r.valid
                 ,net_packet_r.header.addr
                 ,net_packet_r.data
                );
        $display("  ID: pc+4:%x instr:{%x_%x_%x_%x_%x_%x} j_addr:%x wrf:%b ld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b"
                 ,id.pc_plus4
                 ,id.instruction.funct7
                 ,id.instruction.rs2
                 ,id.instruction.rs1
                 ,id.instruction.funct3
                 ,id.instruction.rd
                 ,id.instruction.op
                 ,id.pc_jump_addr
                 ,id.decode.op_writes_rf
                 ,id.decode.is_load_op
                 ,id.decode.is_store_op
                 ,id.decode.is_mem_op
                 ,id.decode.is_byte_op
                 ,id.decode.is_hex_op
                 ,id.decode.is_branch_op
                 ,id.decode.is_jump_op
                 ,id.decode.op_reads_rf1
                 ,id.decode.op_reads_rf2
                 ,id.decode.op_is_auipc
                );
        $display(" EXE: pc+4:%x instr:{%x_%x_%x_%x_%x_%x} j_addr:%x wrf:%b ld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b rs1:%0x rs2:%0x"
                 ,exe.pc_plus4
                 ,exe.instruction.funct7
                 ,exe.instruction.rs2
                 ,exe.instruction.rs1
                 ,exe.instruction.funct3
                 ,exe.instruction.rd
                 ,exe.instruction.op
                 ,exe.pc_jump_addr
                 ,exe.decode.op_writes_rf
                 ,exe.decode.is_load_op
                 ,exe.decode.is_store_op
                 ,exe.decode.is_mem_op
                 ,exe.decode.is_byte_op
                 ,exe.decode.is_hex_op
                 ,exe.decode.is_branch_op
                 ,exe.decode.is_jump_op
                 ,exe.decode.op_reads_rf1
                 ,exe.decode.op_reads_rf2
                 ,exe.decode.op_is_auipc
                 ,exe.rs1_val
                 ,exe.rs2_val
                );
        $display(" MEM:  rd_addr:%x wrf:%b ld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b alu:%x"
//                 ,mem.pc_plus4
                 ,mem.rd_addr
                 ,mem.decode.op_writes_rf
                 ,mem.decode.is_load_op
                 ,mem.decode.is_store_op
                 ,mem.decode.is_mem_op
                 ,mem.decode.is_byte_op
                 ,mem.decode.is_hex_op
                 ,mem.decode.is_branch_op
                 ,mem.decode.is_jump_op
                 ,mem.decode.op_reads_rf1
                 ,mem.decode.op_reads_rf2
                 ,mem.decode.op_is_auipc
                 ,mem.alu_result
                );

        $display(" WB: wrf:%b rd_addr:%x, rf_data:%x"
                 ,wb.op_writes_rf
                 ,wb.rd_addr
                 ,wb.rf_data
                );

        $display("MISC: stall:%b stall_mem:%b stall_non_mem:%b stall_lrw:%b reservation:%b valid_to_mem:%b alu_result:%x st_data:%x mask:%b jump_now:%b flush:%b"
                 ,stall
                 ,stall_mem
                 ,stall_non_mem
                 ,stall_lrw
                 ,reservation_i
                 ,valid_to_mem_c
                 ,alu_result
                 ,store_data
                 ,mask
                 ,jump_now
                 ,flush
                );
        $display("  MD: stall_md:%b md_vlaid:%b md_resp_valid:%b md_result:%x"
                 ,stall_md
                 ,md_valid
//                 ,exe.decode.md_op
//                 ,exe.decode.md_out_sel
                 ,md_resp_valid
                 ,md_result
                );
      end

  end
//synopsys translate_on



endmodule
