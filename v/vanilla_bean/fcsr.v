/**
 *    fcsr.v
 *
 */

`include "bsg_defines.v"

module fcsr
  import bsg_vanilla_pkg::*;
  #(parameter fflags_width_lp=$bits(fflags_s)
    , parameter frm_width_lp=$bits(frm_e)
    , parameter reg_addr_width_lp=RV32_reg_addr_width_gp
  )
  (
    input clk_i
    , input reset_i

    // csr write/set interface
    , input v_i
    , input [2:0] funct3_i
    , input [reg_addr_width_lp-1:0] rs1_i
    , input fcsr_s data_i
    , input [11:0] addr_i

    , output fcsr_s data_o // data that goes to rd.
    , output logic data_v_o      // 1, if addr_i matches fcsr addr.

    // exception accrue interface
    , input [1:0] fflags_v_i
    , input [1:0][fflags_width_lp-1:0] fflags_i
    
    , output frm_e frm_o // for dynamic rounding mode
  );

  logic [frm_width_lp-1:0] frm_r;
  logic [fflags_width_lp-1:0] fflags_r;

  logic [7:0] write_mask;
  logic [7:0] write_data;

  always_comb begin
    if (v_i) begin
      case (funct3_i)
        `RV32_CSRRW_FUN3: begin
          write_mask = {8{1'b1}};
          write_data = data_i;
        end
        `RV32_CSRRS_FUN3: begin
          write_mask = data_i;
          write_data = data_i;
        end
        `RV32_CSRRC_FUN3: begin
          write_mask = data_i;
          write_data = ~data_i;
        end
        `RV32_CSRRWI_FUN3: begin
          write_mask = {8{1'b1}};
          write_data = {3'b000, rs1_i};
        end
        `RV32_CSRRSI_FUN3: begin
          write_mask = {3'b000, rs1_i};
          write_data = {3'b000, rs1_i};
        end
        `RV32_CSRRCI_FUN3: begin
          write_mask = {3'b000, rs1_i};
          write_data = {3'b000, ~rs1_i};
        end
        default: begin
          write_mask = '0;
          write_data = '0;
        end
      endcase
    end
    else begin
      write_mask = '0;
      write_data = '0;
    end
  end

  logic [frm_width_lp-1:0] frm_write_mask;
  logic [frm_width_lp-1:0] frm_write_data;
  logic [fflags_width_lp-1:0] fflags_write_mask;
  logic [fflags_width_lp-1:0] fflags_write_data;


  // FRM
  always_comb begin
    case (addr_i)
      // frm
      `RV32_CSR_FRM_ADDR: begin
        frm_write_mask = write_mask[0+:frm_width_lp];
        frm_write_data = write_data[0+:frm_width_lp];
      end
      // fcsr
      `RV32_CSR_FCSR_ADDR: begin
        frm_write_mask = write_mask[fflags_width_lp+:frm_width_lp];
        frm_write_data = write_data[fflags_width_lp+:frm_width_lp];
      end
      default: begin
        frm_write_mask = '0;
        frm_write_data = '0;
      end
    endcase
  end


  // FFLAGS accrue logic
  logic [1:0][fflags_width_lp-1:0] filtered_fflags;
  always_comb begin
    for (integer i = 0; i < 2; i++) begin
      filtered_fflags[i] = {fflags_width_lp{fflags_v_i[i]}} & fflags_i[i];
    end
  end

  wire [fflags_width_lp-1:0] combined_fflags = filtered_fflags[0] | filtered_fflags[1];
  
  // fflags cannot be modified by fcsr instruction, when there are pending float ops that could modify fflags.
  always_comb begin
    
    if (v_i) begin
      case (addr_i)
        // fflags, fcsr
        `RV32_CSR_FFLAGS_ADDR,
        `RV32_CSR_FCSR_ADDR: begin
          fflags_write_mask = write_mask[0+:fflags_width_lp];
          fflags_write_data = write_data[0+:fflags_width_lp];
        end
        default: begin
          fflags_write_mask = '0;
          fflags_write_data = '0;
        end
      endcase
    end
    else begin
      fflags_write_mask = combined_fflags;
      fflags_write_data = combined_fflags;
    end
  end


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      frm_r <= '0;
      fflags_r <= '0;
    end
    else begin
      for (integer i = 0; i < frm_width_lp; i++) begin
        if (frm_write_mask[i])
          frm_r[i] <= frm_write_data[i];
      end
      for (integer i = 0; i < fflags_width_lp; i++) begin
        if (fflags_write_mask[i])
          fflags_r[i] <= fflags_write_data[i];
      end
    end
  end

  // output
  always_comb begin
    case (addr_i)
      `RV32_CSR_FFLAGS_ADDR: begin
        data_o = {3'b0, fflags_r};
        data_v_o = 1'b1;
      end
      `RV32_CSR_FRM_ADDR: begin
        data_o = {5'b0, frm_r};
        data_v_o = 1'b1;
      end
      `RV32_CSR_FCSR_ADDR: begin
         data_o = {frm_r, fflags_r};
        data_v_o = 1'b1;
      end
      default: begin
        data_o = '0;
        data_v_o = 1'b0;
      end
    endcase 
  end

  assign frm_o = frm_e'(frm_r);


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      if (v_i & data_v_o) begin
        assert(~(|fflags_v_i)) else $error("Exception cannot be accrued while being written by fcsr op.");
      end
    end
  end
  // synopsys translate_on

endmodule

