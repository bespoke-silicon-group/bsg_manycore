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
                input                             clk,
                input                             reset,

`ifdef bsg_FPU
                fpi_alu_inter.alu_side            fpi_inter,
`endif
                input  ring_packet_s              net_packet_i,

                input  mem_out_s                  from_mem_i,
                output mem_in_s                   to_mem_o,
                input  logic                      reservation_i,
                output logic                      reserve_1_o,

                input  [x_cord_width_p-1:0]       my_x_i,
                input  [y_cord_width_p-1:0]       my_y_i,
                output debug_s                    debug_o
               );

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

//We have to buffer the returned data from memory
//if there is a non-memory stall at current cycle.
logic                               is_load_buffer_valid;
logic [RV32_reg_data_width_gp-1:0]  load_buffer_data;

//the memory valid signal may comes from memory of the buffer register
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

// stall due to data memory access
assign stall_mem = (exe.decode.is_mem_op & (~from_mem_i.yumi))
                   | (mem.decode.is_load_op & (~data_mem_valid))
                   | stall_lrw;

// Stall if LD/ST still active; or in non-RUN state
assign stall = (stall_non_mem | stall_mem);


//data depenecy stall
//only occurs when there is operation needs loaded data immediately
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
logic [RV32_reg_data_width_gp-1:0] jalr_addr;
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
        (~exe.instruction[RV32_instr_width_gp-1]) & jump_now;

// Over predicted flag (meaning that we predicted taken when not taken)
wire branch_over_predict =
        exe.instruction[RV32_instr_width_gp-1] & (~jump_now);

// Flag if a branch misptediction occured
wire branch_mispredict = exe.decode.is_branch_op
                           & (branch_under_predict | branch_over_predict);

// JALR mispredict (or just a JALR instruction in the single cycle because it
// follows the same logic as a JALR mispredict)
wire jalr_mispredict = (exe.instruction.op ==? `RV32_JALR_OP)
                         & (jalr_addr != jalr_prediction_rr);

// Flush the control signals in the execute and instr decode stages if there
// is a misprediciton and (only for the pipelined version of the core)
wire flush = (branch_mispredict | jalr_mispredict);

//+----------------------------------------------
//|
//|          PROGRAM COUNTER SIGNALS
//|
//+----------------------------------------------

// Program counter logic
logic [RV32_reg_data_width_gp-1:0] pc_n, pc_r, pc_plus4, pc_jump_addr, pc_long_jump_addr;
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
assign pc_plus4 = pc_r + 3'b100;

assign pc_jump_addr      = $signed(pc_r)
                           + (decode.is_branch_op
                              ? $signed(`RV32_signext_Bimm(instruction))
                              : $signed(`RV32_signext_Jimm(instruction))
                             );

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
        pc_n = RV32_reg_data_width_gp'(net_packet_r.header.addr[imem_addr_width_p-1:0]);

    // Fixing a branch misprediction (or single cycle branch will
    // follow a branch under prediction logic)
    else if (branch_mispredict)
        if (branch_under_predict)
            pc_n = exe.pc_jump_addr;
        else
            pc_n = exe.pc_plus4;

    // Fixing a JALR misprediction (or a signal cycle JALR instruction)
    else if (jalr_mispredict)
        pc_n = jalr_addr;

    // Predict taken branch or instrcution is a long jump
    else if ((decode.is_branch_op & instruction[RV32_instr_width_gp-1]) | (instruction.op == `RV32_JAL_OP))
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
                   : pc_n[2+:imem_addr_width_p];

// Instruction memory chip enable signal
`ifdef bsg_FPU
assign imem_cen = (~( stall | fpi_inter.fam_depend_stall | depend_stall ))
                | (net_imem_write_cmd | net_pc_write_cmd_idle);
`else
assign imem_cen = (~ (stall | depend_stall) ) | (net_imem_write_cmd | net_pc_write_cmd_idle);
`endif
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
     ,.data_i (net_packet_r.data)
     ,.data_o (imem_out)
    );

   // synopsys translate_off
   always @(negedge clk)
     begin
	assert (~net_imem_write_cmd | (&net_packet_r.header.mask))
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
//assign rf_cen = (~ stall ) | (net_reg_write_cmd);
   assign rf_cen= ~(stall | depend_stall );

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
//|     RISC-V edit: "M" STANDARAD EXTENSION
//|
//+----------------------------------------------
// MUL/DIV signals
logic        md_ready, md_resp_valid;
logic [31:0] md_result;

wire   md_valid    = exe.decode.is_md_instr & md_ready;
assign stall_md    = exe.decode.is_md_instr & ~md_resp_valid;

vscale_mul_div md_0
  ( .clk             (clk)
   ,.reset           (reset)
   ,.req_valid       (md_valid)
   ,.req_ready       (md_ready)
   ,.req_in_1_signed (exe.decode.md_rs1_signed)
   ,.req_in_2_signed (exe.decode.md_rs2_signed)
   ,.req_op          (exe.decode.md_op)
   ,.req_out_sel     (exe.decode.md_out_sel)
   ,.req_in_1        (rs1_to_alu)
   ,.req_in_2        (rs2_to_alu)
   ,.resp_valid      (md_resp_valid)
   ,.resp_result     (md_result)
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
alu alu_0
(
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
assign valid_to_mem_c = exe.decode.is_mem_op & (~stall_non_mem) & (~stall_lrw);

//We should always accept the returned data even there is a non memory stall
//assign yumi_to_mem_c  = mem.decode.is_mem_op & from_mem_i.valid & (~stall_non_mem);
assign yumi_to_mem_c  = mem.decode.is_mem_op & from_mem_i.valid ;

// RISC-V edit: add reservation
always_comb
begin
  reserve_1_o = 1'b0;
  stall_lrw   = 1'b0;

  if(exe.instruction ==? `RV32_LR_W)
    begin
      reserve_1_o = ~exe.instruction[26];
      // stall until reseervation is cleared
      stall_lrw   = exe.instruction[26] & reservation_i;
    end
end

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

   bsg_dff_reset #(.width_p($bits(ring_packet_s)), .harden_p(1)) net_packet_r_reg
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

   bsg_dff_reset_en #(.width_p(RV32_reg_data_width_gp),.harden_p(1)) pc_r_reg
     (.clock_i (clk)
      ,.reset_i(reset)
      ,.en_i   (pc_wen)
      ,.data_i (pc_n)
      ,.data_o (pc_r)
      );


//+----------------------------------------------
//|
//|     INSTR FETCH TO INSTR DECODE SHIFT
//|
//+----------------------------------------------

// Synchronous stage shift
always_ff @ (posedge clk)
begin
`ifdef bsg_FPU
    if (reset | net_pc_write_cmd_idle |
            (flush & (~(stall|fpi_inter.fam_depend_stall | depend_stall )))
       )
`else
    if (reset | net_pc_write_cmd_idle | (flush & (~   (stall | depend_stall)  ) ) )
`endif

        id <= '0;

`ifdef bsg_FPU
    else if (~(stall|fpi_inter.fam_depend_stall | depend_stall ))
`else
    else if (~ ( stall | depend_stall) )
`endif

        id <= '{
            pc_plus4     : pc_plus4,
            pc_jump_addr : pc_jump_addr,
            instruction  : instruction,
            decode       : decode
        };
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
        exe <= '0;
`ifdef bsg_FPU
    else if(    ( fpi_inter.fam_depend_stall | depend_stall )
              & (~stall)
           )
`else
    else if ( depend_stall & (~stall) )
`endif
        exe <= '0; //insert a bubble to the pipeline
    else if (~ stall)
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
        mem <= '0;
    else if (~stall)
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
    else if( stall_non_mem & mem.decode.is_load_op & from_mem_i.valid )
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
      00:       loaded_byte = loaded_data[0+:8];
      01:       loaded_byte = loaded_data[8+:8];
      10:       loaded_byte = loaded_data[16+:8];
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
        wb <= '0;
    else if (~stall)
        wb <= '{
            op_writes_rf : mem.decode.op_writes_rf,
            rd_addr      : mem.rd_addr,
            rf_data      : rf_data
        };
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
//synopsys translate_on


`endif


// DEBUG Struct
assign debug_o = {pc_r, instruction, state_r};
//synopsys translate_off
if(debug_p)
  always_ff @(negedge clk)
  begin
    if ((~|my_x_i & ~|my_y_i) & state_r==RUN)
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
        $display(" MEM: pc+4:%x rd_addr:%x wrf:%b ld:%b st:%b mem:%b byte:%b hex:%b branch:%b jmp:%b reads_rf1:%b reads_rf2:%b auipc:%b alu:%x"
                 ,mem.pc_plus4
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
        $display("  WB: wrf:%b rd_addr:%x, rf_data:%x"
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
        $display("  MD: stall_md:%b md_vlaid:%b md_op:%b md_out_sel:%b md_resp_valid:%b md_result:%x"
                 ,stall_md
                 ,md_valid
                 ,exe.decode.md_op
                 ,exe.decode.md_out_sel
                 ,md_resp_valid
                 ,md_result
                );
      end

  end
//synopsys translate_on



endmodule
