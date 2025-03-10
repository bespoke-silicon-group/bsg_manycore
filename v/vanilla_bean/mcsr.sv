/**
 *    mcsr.sv
 *
 *    machine CSR
 */

//  this contains the following.
//  - mstatus (MIE, MPIE) (read-write)
//  - mie and mip (read-write)
//  - mepc (read-write)

`include "bsg_vanilla_defines.svh"

module mcsr
  import bsg_vanilla_pkg::*;
  #(localparam reg_addr_width_lp = reg_addr_width_gp
    , reg_data_width_lp = reg_data_width_gp
    , parameter `BSG_INV_PARAM(pc_width_p)
    , `BSG_INV_PARAM(barrier_dirs_p)
    , localparam barrier_lg_dirs_lp=`BSG_SAFE_CLOG2(barrier_dirs_p+1)
    , parameter credit_limit_default_val_p = 32
    , credit_counter_width_p=`BSG_WIDTH(32)
    , cfg_pod_width_p=32
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

    , input  [cfg_pod_width_p-1:0] cfg_pod_reset_val_i
    , output [cfg_pod_width_p-1:0] cfg_pod_r_o
   
    // from between ID and EXE
    , input instr_executed_i

    // from EXE
    , input interrupt_entered_i
    , input mret_called_i
    , input [pc_width_p-1:0] npc_r_i
    
    // barrier interface
    , input barsend_i
    , input barrier_data_i        // (Po)
    , output logic barrier_data_o // (Pi)

    // output
    , output csr_mstatus_s mstatus_r_o
    , output csr_interrupt_vector_s mip_r_o
    , output csr_interrupt_vector_s mie_r_o
    , output logic [pc_width_p-1:0] mepc_r_o
    , output logic [credit_counter_width_p-1:0] credit_limit_o
    , output logic [barrier_dirs_p-1:0] barrier_src_r_o
    , output logic [barrier_lg_dirs_lp-1:0] barrier_dest_r_o
    
  );

  csr_mstatus_s mstatus_n, mstatus_r;
  csr_interrupt_vector_s mie_n, mie_r;
  csr_interrupt_vector_s mip_n, mip_r;
  logic [pc_width_p-1:0] mepc_r, mepc_n;
  logic [credit_counter_width_p-1:0] credit_limit_r, credit_limit_n;
  logic [cfg_pod_width_p-1:0] 	     cfg_pod_r;
  logic [barrier_dirs_p-1:0] barrier_src_r;
  logic [barrier_lg_dirs_lp-1:0] barrier_dest_r;


  assign mstatus_r_o = mstatus_r;
  assign mip_r_o = mip_r;
  assign mie_r_o = mie_r;
  assign mepc_r_o = mepc_r;
  assign credit_limit_o = credit_limit_r;
  assign cfg_pod_r_o = cfg_pod_r;
  assign barrier_src_r_o = barrier_src_r;
  assign barrier_dest_r_o = barrier_dest_r;  


  // mstatus
  // Not used in Vanilla ISA Manycore. RISCV uses a seperate mcsr.v files in
  // bsg_manycore_ISA.
  always_comb begin
    mstatus_n = mstatus_r;
    mstatus_n.mie = 1'b0;
    mstatus_n.mpie = 1'b0;
  end


  // mie : Do nothing for vanilla ISA 
  always_comb begin
    mie_n = mie_r;
  end


  // mip : Do nothing for vanilla ISA
  always_comb begin
    mip_n = mip_r;
  end

  
  // mepc : Do nothing for vanilla ISA
  always_comb begin
    mepc_n = mepc_r;
  end


  // credit limit
  always_comb begin
    credit_limit_n = credit_limit_r;

    if (we_i & (addr_i == `VANILLA_CSR_CREDIT_LIMIT_ADDR) & (funct3_i == `VANILLA_CSRRW_FUN3)) begin
      credit_limit_n = data_i[0+:credit_counter_width_p];
    end
  end


  // pod config
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
	    cfg_pod_r <= cfg_pod_reset_val_i;
    end
    else begin
      if (we_i && (addr_i == `VANILLA_CSR_CFG_POD_ADDR) && (funct3_i == `VANILLA_CSRRW_FUN3)) begin
	      cfg_pod_r <= data_i[0+:cfg_pod_width_p];
      end
    end
  end



  // Barrier configuration register (barcfg)
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      {barrier_src_r, barrier_dest_r} <= '0;
    end
    else begin
      if (we_i && (addr_i == `VANILLA_CSR_BARCFG_ADDR) && (funct3_i == `VANILLA_CSRRW_FUN3)) begin
        barrier_src_r <= data_i[0+:barrier_dirs_p];
        barrier_dest_r <= data_i[16+:barrier_lg_dirs_lp];
      end
    end
  end

  
  // Barrier switch register (Pi)
  // This can be modified by CSR instruction or barsend. They are mutually exclusive events.
  logic barrier_data_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      barrier_data_r <= 1'b0;
    end
    else begin
      if (we_i && (addr_i == `VANILLA_CSR_BAR_PI_ADDR)) begin
        case (funct3_i)
          `VANILLA_CSRRW_FUN3:   barrier_data_r <= data_i[0];
          `VANILLA_CSRRS_FUN3:   barrier_data_r <= data_i[0] ? 1'b1 : barrier_data_r;
          `VANILLA_CSRRC_FUN3:   barrier_data_r <= data_i[0] ? 1'b0 : barrier_data_r;
          `VANILLA_CSRRWI_FUN3:  barrier_data_r <= rs1_i[0];
          `VANILLA_CSRRSI_FUN3:  barrier_data_r <= rs1_i[0] ? 1'b1 : barrier_data_r;
          `VANILLA_CSRRCI_FUN3:  barrier_data_r <= rs1_i[0] ? 1'b0 : barrier_data_r;
        endcase
      end
      else if (barsend_i) begin
        barrier_data_r <= ~barrier_data_r;
      end
    end
  end
  
  assign barrier_data_o = barrier_data_r;


  // reading CSR values
  always_comb begin
    data_o = '0;
    case (addr_i)
      `VANILLA_CSR_CREDIT_LIMIT_ADDR: begin
        data_o[0+:credit_counter_width_p] = credit_limit_r;
      end
      `VANILLA_CSR_CFG_POD_ADDR: begin
	data_o[0+:cfg_pod_width_p] = cfg_pod_r;
      end
      `VANILLA_CSR_BARCFG_ADDR: begin
        data_o[0+:barrier_dirs_p] = barrier_src_r;
        data_o[16+:barrier_lg_dirs_lp] = barrier_dest_r;
      end
      `VANILLA_CSR_BAR_PO_ADDR: begin
        data_o[0] = barrier_data_i;
      end
      `VANILLA_CSR_BAR_PI_ADDR: begin
        data_o[0] = barrier_data_r;
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

`BSG_ABSTRACT_MODULE(mcsr)
