`include "parameters.v"
`include "definitions.v"
`include "float_parameters.v"
`include "float_definitions.v"

/**
 *
 *  6 stage float pipeline implementation of the RISC-V F ISA.
 */
module fpi (
            input                             clk,
            input                             reset,
            fpi_alu_inter.fpi_side            alu_inter 
);

// Pipeline stage logic structures
f_id_signals_s      id;
f_exe_signals_s     exe;
f_mem_signals_s     mem;
f_wb_signals_s      wb;
f_wb1_signals_s     wb1;


// Register file logic
logic [RV32_reg_data_width_gp-1:0]  frf_rs1_val, frf_rs2_val, frf_rs1_out,
                                    frf_rs2_out, frf_wd;
logic [RV32_reg_addr_width_gp-1:0]  frf_wa;
logic                               frf_wen, frf_cen;

// Value forwarding logic
logic [RV32_reg_data_width_gp-1:0] frs1_to_exe, frs2_to_exe;
logic [RV32_reg_data_width_gp-1:0] frs1_to_fiu, frs2_to_fiu, fiu_result;

//+----------------------------------------------
//|
//|         DECODE CONTROL SIGNALS
//|
//+----------------------------------------------

// Decoded control signals logic
f_decode_s f_decode;
// Instantiate the instruction decoder
float_decode float_decode_0
(
    .f_instruction_i(alu_inter.f_instruction),
    .f_decode_o(f_decode)
);

//+----------------------------------------------
//|
//|           REGISTER FILE SIGNALS
//|
//+----------------------------------------------

// We only write back to floating register file on WB1 stage
assign frf_wen = wb1.op_writes_frf &( ~alu_inter.alu_stall ) ;

assign frf_wa =  wb1.frd_addr;

assign frf_wd =  wb1.frf_data;

// Register file chip enable signal
assign frf_cen = (~alu_inter.alu_stall) ;

// Instantiate the general purpose floating register file
bsg_mem_2r1w #( .width_p                (RV32_reg_data_width_gp)
               ,.els_p                  (32)
               ,.read_write_same_addr_p (1)
              ) frf_0
  ( .w_clk_i   (clk)
   ,.w_v_i     (frf_cen & frf_wen)
   ,.w_addr_i  (frf_wa)
   ,.w_data_i  (frf_wd)
   ,.r0_v_i    (frf_cen)
   ,.r0_addr_i (id.f_instruction.rs1)
   ,.r0_data_o (frf_rs1_out)
   ,.r1_v_i    (frf_cen)
   ,.r1_addr_i (id.f_instruction.rs2)
   ,.r1_data_o (frf_rs2_out)
  );

always @( negedge clk ) 
begin
    if(frf_wen & frf_cen) 
        $display("FRF write:addr %d, value=%X\n",frf_wa, frf_wd);
end
//+----------------------------------------------
//|
//|     INSTR FETCH TO INSTR DECODE SHIFT
//|
//+----------------------------------------------

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | ( alu_inter.alu_flush & (~ alu_inter.alu_stall)))
        id <= '0;
    else if (~alu_inter.alu_stall)
        id <= '{
            f_instruction  : alu_inter.f_instruction,
            f_decode       : f_decode
        };
end

//+----------------------------------------------
//|
//|        INSTR DECODE TO EXECUTE SHIFT
//|
//+----------------------------------------------

// Determine what rs1 value should be passed to the exe stage of the pipeline
always_comb
begin
    if(id.f_decode.op_reads_rf1 )
    begin
        frs1_to_exe = alu_inter.rf_rs1_out;
    end 
    else 
        frs1_to_exe = frf_rs1_out;
end

// Determine what rs2 value should be passed to the exe stage of the pipeine
always_comb
begin
       frs2_to_exe = frf_rs2_out;
end

// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | (alu_inter.alu_flush & (~alu_inter.alu_stall)))
        exe <= '0;
    else if (~alu_inter.alu_stall)
        exe <= '{
            f_instruction   : id.f_instruction,
            f_decode        : id.f_decode,
            frs1_val        : frs1_to_exe,
            frs2_val        : frs2_to_exe
        };
end

//+----------------------------------------------
//|
//|          EXECUTE TO MEMORY SHIFT
//|
//+----------------------------------------------
assign frs1_to_fiu = exe.frs1_val;
assign frs2_to_fiu = exe.frs2_val;


fiu fiu_0 ( .frs1_i         ( frs1_to_fiu       ),
            .frs2_i         ( frs2_to_fiu       ),
            .op_i           ( exe.f_instruction ),
            .result_o       ( fiu_result        )
           );
// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset )
        mem <= '0;
    else if (~alu_inter.alu_stall)
        mem <= '{
            frd_addr        : exe.f_instruction.rd,
            f_decode        : exe.f_decode,
            fiu_result      : fiu_result
        };
end

//+----------------------------------------------
//|
//|       MEMORY TO RF WRITE BACK SHIFT
//|
//+----------------------------------------------

// Determine what data to send to the write back stage
// that will end up being writen to the register file
logic [RV32_reg_data_width_gp-1:0] frf_data;  
always_comb
begin
    frf_data = mem.f_decode.is_load_op? alu_inter.flw_data:
                                        mem.fiu_result;
end

// Synchronous wb stage shift
always_ff @ (posedge clk)
begin
    if (reset )
        wb <= '0;
    else if (~alu_inter.alu_stall)
        wb <= '{
            op_writes_frf : mem.f_decode.op_writes_frf,
            is_fam_op     : mem.f_decode.is_fam_op,
            is_fpi_op     : mem.f_decode.is_fpi_op,
            frd_addr      : mem.frd_addr,
            frf_data      : frf_data
        };
end


// Synchronous wb1 stage shift
always_ff @ (posedge clk)
begin
    if (reset )
        wb1 <= '0;
    else if (~alu_inter.alu_stall)
        wb1 <= '{
            op_writes_frf : wb.op_writes_frf,
            is_fam_op     : wb.is_fam_op,
            is_fpi_op     : wb.is_fpi_op,
            frd_addr      : wb.frd_addr,
            frf_data      : wb.frf_data
        };
end

///////////////////////////////////////////////////////////
//
//   Figure out the output signal
//
assign alu_inter.fiu_result     = exe.frs1_val;
assign alu_inter.frs2_to_fiu    = exe.frs2_val;
assign alu_inter.exe_store_op   = exe.f_decode.is_store_op;
assign alu_inter.exe_writes_rf  = exe.f_decode.op_writes_rf;

endmodule
