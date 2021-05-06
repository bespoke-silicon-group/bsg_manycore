/**
 *    mcsr.v
 *
 *    machine CSR
 */

//  this contains the following.
//  - mstatus (MIE, MPIE) (read-write)
//  - mie and mip (read-write)
//  - mepc (read-write)


module mcsr
  import bsg_vanilla_pkg::*;
  #(parameter reg_addr_width_lp = RV32_reg_addr_width_gp
    , parameter reg_data_width_lp = RV32_reg_data_width_gp
    , parameter pc_width_p="inv"
    , parameter credit_limit_default_val_p = 32
    , parameter credit_counter_width_p=`BSG_WIDTH(32)
  )
  (
    input clk_i
    , input reset_i

    // remote interrupt set/clear (from network_rx)
    , input remote_interrupt_set_i
    , input remote_interrupt_clear_i


    // csr instruction writes to this when moving from ID to EXE.
    , input we_i
    , input [11:0] addr_i
    , input [2:0] funct3_i
    , input [reg_data_width_lp-1:0] data_i  // rs1 data
    , input [reg_addr_width_lp-1:0] rs1_i   // for immediate val write
    , output logic [reg_data_width_lp-1:0] data_o

    // from between ID and EXE
    , input instr_executed_i

    // from EXE
    , input interrupt_entered_i
    , input mret_called_i
    , input [pc_width_p-1:0] npc_r_i
    
    // output
    , output csr_mstatus_s mstatus_r_o
    , output csr_interrupt_vector_s mip_r_o
    , output csr_interrupt_vector_s mie_r_o
    , output logic [pc_width_p-1:0] mepc_r_o
    , output logic [credit_counter_width_p-1:0] credit_limit_o
  );

  csr_mstatus_s mstatus_n, mstatus_r;
  csr_interrupt_vector_s mie_n, mie_r;
  csr_interrupt_vector_s mip_n, mip_r;
  logic [pc_width_p-1:0] mepc_r, mepc_n;
  logic [credit_counter_width_p-1:0] credit_limit_r, credit_limit_n;

  assign mstatus_r_o = mstatus_r;
  assign mip_r_o = mip_r;
  assign mie_r_o = mie_r;
  assign mepc_r_o = mepc_r;
  assign credit_limit_o = credit_limit_r;

  // mstatus
  // priority (high to low)
  // 1) mret
  // 2) interrupt taken
  // 3) csr instr
  // *1,2 are mutually exclusive events.
  always_comb begin
    mstatus_n = mstatus_r;

    if (mret_called_i) begin
      mstatus_n.mie = mstatus_r.mpie;
      mstatus_n.mpie = 1'b0;
    end
    else if (interrupt_entered_i) begin
      mstatus_n.mie = 1'b0;
      mstatus_n.mpie = mstatus_r.mie;
    end
    else if (we_i & (addr_i == `RV32_CSR_MSTATUS_ADDR)) begin
      case (funct3_i)
        `RV32_CSRRW_FUN3: begin
          mstatus_n.mpie = data_i[`RV32_MSTATUS_MPIE_BIT_IDX];
          mstatus_n.mie = data_i[`RV32_MSTATUS_MIE_BIT_IDX];
        end
        `RV32_CSRRS_FUN3: begin
          mstatus_n.mpie = data_i[`RV32_MSTATUS_MPIE_BIT_IDX]
            ? 1'b1
            : mstatus_r.mpie;
          mstatus_n.mie = data_i[`RV32_MSTATUS_MIE_BIT_IDX]
            ? 1'b1
            : mstatus_r.mie;
        end
        `RV32_CSRRC_FUN3: begin
          mstatus_n.mpie = data_i[`RV32_MSTATUS_MPIE_BIT_IDX]
            ? 1'b0
            : mstatus_r.mpie;
          mstatus_n.mie = data_i[`RV32_MSTATUS_MIE_BIT_IDX]
            ? 1'b0
            : mstatus_r.mie;
        end
        `RV32_CSRRWI_FUN3: begin
          mstatus_n.mie = rs1_i[`RV32_MSTATUS_MIE_BIT_IDX];
        end
        `RV32_CSRRSI_FUN3: begin
          mstatus_n.mie = rs1_i[`RV32_MSTATUS_MIE_BIT_IDX]
            ? 1'b1
            : mstatus_r.mie;
        end
        `RV32_CSRRCI_FUN3: begin
          mstatus_n.mie = rs1_i[`RV32_MSTATUS_MIE_BIT_IDX]
            ? 1'b0
            : mstatus_r.mie;
        end
        default: begin
          mstatus_n = mstatus_r;
        end
      endcase
    end
  end


  // mie 
  // this can be only modified by csr instr. 
  always_comb begin
    mie_n = mie_r;
    if (we_i & (addr_i == `RV32_CSR_MIE_ADDR)) begin
      case (funct3_i)
        `RV32_CSRRW_FUN3: begin
          mie_n = data_i[17:16];
        end
        `RV32_CSRRS_FUN3: begin
          mie_n.trace = data_i[17]
            ? 1'b1
            : mie_r.trace;
          mie_n.remote = data_i[16]
            ? 1'b1
            : mie_r.remote;
        end
        `RV32_CSRRC_FUN3: begin
          mie_n.trace = data_i[17]
            ? 1'b0
            : mie_r.trace;
          mie_n.remote = data_i[16]
            ? 1'b0
            : mie_r.remote;
        end
        default: mie_n = mie_r;
      endcase
    end
  end


  // mip
  // mip.trace is set when an instruction is executed (ID->EXE), while outside interrupt.
  // mip.remote can be set/clear by remote packet.
  // Both can be modified by CSR instr, which has lower priority.
  always_comb begin
    mip_n = mip_r;

    // trace
    // if trace enable bit is low, then execute instruction signal does not set the trace pending bit.
    if (instr_executed_i & mie_r.trace) begin
      mip_n.trace = 1'b1;
    end
    else if (we_i & (addr_i == `RV32_CSR_MIP_ADDR)) begin
      case (funct3_i)
        `RV32_CSRRW_FUN3: begin
          mip_n.trace = data_i[17];
        end
        `RV32_CSRRS_FUN3: begin
          mip_n.trace = data_i[17]
            ? 1'b1
            : mip_r.trace;
        end
        `RV32_CSRRC_FUN3: begin
          mip_n.trace = data_i[17]
            ? 1'b0
            : mip_r.trace;
        end
        default: mip_n = mip_r;
      endcase
    end

    // remote
    if (remote_interrupt_set_i) begin
      mip_n.remote = 1'b1;
    end
    else if (remote_interrupt_clear_i) begin
      mip_n.remote = 1'b0;
    end
    else if (we_i & (addr_i == `RV32_CSR_MIP_ADDR)) begin
      case (funct3_i)
        `RV32_CSRRW_FUN3: begin
          mip_n.remote = data_i[16];
        end
        `RV32_CSRRS_FUN3: begin
          mip_n.remote = data_i[16]
            ? 1'b1
            : mip_r.remote;
        end
        `RV32_CSRRC_FUN3: begin
          mip_n.remote = data_i[16]
            ? 1'b0
            : mip_r.remote;
        end
        default: mip_n = mip_r;
      endcase
    end
  end

  
  // mepc
  // mepc is set when the interrupt is taken.
  // when the interrupt is taken, ID stage will be flushed, so CSR instr in ID will not get a chance to modify.
  always_comb begin
    mepc_n = mepc_r;
    
    if (interrupt_entered_i) begin
      mepc_n = npc_r_i;
    end
    else if (we_i & (addr_i == `RV32_CSR_MEPC_ADDR)) begin
      case (funct3_i)
        `RV32_CSRRW_FUN3: begin
          mepc_n = data_i[2+:pc_width_p];
        end
        `RV32_CSRRS_FUN3: begin
          for (integer i = 0; i < pc_width_p; i++) begin
            mepc_n[i] = data_i[2+i]
              ? 1'b1
              : mepc_r[i];
          end
        end
        `RV32_CSRRC_FUN3: begin
          for (integer i = 0; i < pc_width_p; i++) begin
            mepc_n[i] = data_i[2+i]
              ? 1'b0
              : mepc_r[i];
          end
        end
        default: mepc_n = mepc_r;
      endcase
    end
  end


  // credit limit
  always_comb begin
    credit_limit_n = credit_limit_r;

    if (we_i & (addr_i == `RV32_CSR_CREDIT_LIMIT_ADDR) & (funct3_i == `RV32_CSRRW_FUN3)) begin
      credit_limit_n = data_i[0+:credit_counter_width_p];
    end
  end


  // reading CSR values
  always_comb begin
    data_o = '0;
    case (addr_i)
      `RV32_CSR_MSTATUS_ADDR: begin
        data_o[`RV32_MSTATUS_MPIE_BIT_IDX] = mstatus_r.mpie;
        data_o[`RV32_MSTATUS_MIE_BIT_IDX] = mstatus_r.mie;
      end
      `RV32_CSR_MIE_ADDR: begin
        data_o[17:16] = mie_r;
      end
      `RV32_CSR_MIP_ADDR: begin
        data_o[17:16] = mip_r;
      end
      `RV32_CSR_MEPC_ADDR: begin
        data_o[2+:pc_width_p] = mepc_r;
      end
      `RV32_CSR_CREDIT_LIMIT_ADDR: begin
        data_o[0+:credit_counter_width_p] = credit_limit_r;
      end
      default: data_o = '0;
    endcase
  end


  // sequential logic
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      mstatus_r <= '0;
      mie_r <= '0;
      mip_r <= '0;
      mepc_r <= '0;
      credit_limit_r <= (credit_counter_width_p)'(credit_limit_default_val_p);
    end
    else begin
      mstatus_r <= mstatus_n;
      mie_r <= mie_n;
      mip_r <= mip_n;
      mepc_r <= mepc_n;
      credit_limit_r <= credit_limit_n;
    end
  end


endmodule
