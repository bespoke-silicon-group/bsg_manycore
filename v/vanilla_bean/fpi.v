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
                     fpi_alu_inter.fpi_side   alu_inter,
            input  f_fam_out_s                fam_out_s_i, 
            output f_fam_in_s                 fam_in_s_o 
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
// Forwarding signals
logic   frs1_in_mem, frs1_in_wb, frs1_in_wb1;
logic   frs2_in_mem, frs2_in_wb, frs2_in_wb1;

logic [RV32_reg_data_width_gp-1:0] frs1_to_exe, frs2_to_exe;
logic [RV32_reg_data_width_gp-1:0] frs1_to_fiu, frs2_to_fiu, fiu_result;
logic [RV32_reg_data_width_gp-1:0] frf_data;  

logic                              frs1_is_forward, frs2_is_forward;
logic [RV32_reg_data_width_gp-1:0] frs1_forward_val,frs2_forward_val;

//forwarding logic for fam
logic   fam_depend_stall;   // FAM data dependency stall

logic   fam_frs1_in_mem, fam_frs1_in_wb;
logic   fam_frs2_in_mem, fam_frs2_in_wb;
logic                              fam_frs1_is_forward, fam_frs2_is_forward;
logic [RV32_reg_data_width_gp-1:0] fam_frs1_forward_val,fam_frs2_forward_val;
logic [RV32_reg_data_width_gp-1:0] fam_frs1_to_exe, fam_frs2_to_exe;
// Data will be write back to the floating register file
logic [RV32_reg_data_width_gp-1:0] write_frf_data;

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

assign frf_wd =  write_frf_data;

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
    if (reset | (   alu_inter.alu_flush  
                  & (~ (alu_inter.alu_stall | fam_depend_stall) )
                )
       )
        id <= '0;
    else if (~ (alu_inter.alu_stall| fam_depend_stall) )
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
//



wire id_exe_rs1_match=    exe.f_decode.op_writes_frf
                      & ( id.f_instruction.rs1 == exe.f_instruction.rd);
wire id_exe_rs2_match=    exe.f_decode.op_writes_frf
                      & ( id.f_instruction.rs2 == exe.f_instruction.rd);

// 1.all units that need data in FAM exe will cause stall;
// 2 FAM needs data in EXE will always stall!
wire id_exe_stall_conds = exe.f_decode.is_fam_op | id.f_decode.is_fam_op;

wire fam_exe_dep1 = id_exe_rs1_match & id_exe_stall_conds;
wire fam_exe_dep2 = id_exe_rs2_match & id_exe_stall_conds;
                 
//Only needs data in FAM.mem will cause stall;
wire fam_mem_dep1 =mem.f_decode.op_writes_frf & mem.f_decode.is_fam_op
                &( id.f_instruction.rs1 == mem.frd_addr) ;

wire fam_mem_dep2 =mem.f_decode.op_writes_frf & mem.f_decode.is_fam_op
                &( id.f_instruction.rs2 == mem.frd_addr) ;

//Only needs data in FAM.wb will cause stall;
wire fam_wb_dep1  =wb.op_writes_frf & wb.is_fam_op
                &( id.f_instruction.rs1 == wb.frd_addr) ;

wire fam_wb_dep2  =wb.op_writes_frf & wb.is_fam_op
                &( id.f_instruction.rs2 == wb.frd_addr) ;

// combine all the stall source
wire fam_depend1 = id.f_decode.op_reads_frf1 
                 & ( fam_exe_dep1 | fam_mem_dep1 | fam_wb_dep1 );

wire fam_depend2 = id.f_decode.op_reads_frf2 
                 & ( fam_exe_dep2 | fam_mem_dep2 | fam_wb_dep2 );

assign fam_depend_stall = fam_depend1 | fam_depend2;

// The value forwarded to FAM frs1
assign  fam_frs1_in_mem  = mem.f_decode.op_writes_frf
                         & (id.f_instruction.rs1==mem.frd_addr);

assign  fam_frs1_in_wb  = wb.op_writes_frf & (id.f_instruction.rs1==wb.frd_addr);

assign  fam_frs1_forward_val  = fam_frs1_in_mem ? frf_data :  wb.frf_data;
assign  fam_frs1_is_forward   = fam_frs1_in_mem | fam_frs1_in_wb ;

// The value forwarded to FAM frs2
assign  fam_frs2_in_mem  = mem.f_decode.op_writes_frf
                         & (id.f_instruction.rs2==mem.frd_addr);

assign  fam_frs2_in_wb  = wb.op_writes_frf&(id.f_instruction.rs2==wb.frd_addr);

assign  fam_frs2_forward_val  = fam_frs2_in_mem ? frf_data :  wb.frf_data;
assign  fam_frs2_is_forward   = fam_frs2_in_mem | fam_frs2_in_wb ;


assign write_frf_data = wb1.is_fam_op? fam_out_s_i.data_o : wb1.frf_data;


// The value send to FPI
always_comb
begin
    if (|id.f_instruction.rs1 // RISC-V: no bypass for reg 0
        & (id.f_instruction.rs1 == wb1.frd_addr) 
        & wb1.op_writes_frf
       )
        frs1_to_exe = write_frf_data;

    // RD in general purpose register file
    else
        frs1_to_exe = frf_rs1_out;
end

always_comb
begin
    if (|id.f_instruction.rs2 // RISC-V: no bypass for reg 0
        & (id.f_instruction.rs2 == wb1.frd_addr) 
        & wb1.op_writes_frf
       )
        frs2_to_exe = write_frf_data;

    // RD in general purpose register file
    else
        frs2_to_exe = frf_rs2_out;
end

//The value sends to FAM
assign fam_frs1_to_exe = fam_frs1_is_forward ? fam_frs1_forward_val : 
                                                   frs1_to_exe      ;
assign fam_frs2_to_exe = fam_frs2_is_forward ? fam_frs2_forward_val : 
                                                   frs2_to_exe      ;
// Synchronous stage shift
always_ff @ (posedge clk)
begin
    if (reset | (alu_inter.alu_flush & (~alu_inter.alu_stall)))
        exe <= '0;
    else if ( fam_depend_stall & ~alu_inter.alu_stall)
        exe <= '0; //insert a bubble into the pipeline.
    else if (~alu_inter.alu_stall)
        exe <= '{
            f_instruction: id.f_instruction,
            f_decode     : id.f_decode,
            frs1_val     : frs1_to_exe,
            frs2_val     : frs2_to_exe
        };
end

//+----------------------------------------------
//|
//|          EXECUTE TO MEMORY SHIFT
//|
//+----------------------------------------------
// RS1 register forwarding
assign  frs1_in_mem      = mem.f_decode.op_writes_frf
                         & (exe.f_instruction.rs1==mem.frd_addr);
assign  frs1_in_wb       = wb.op_writes_frf 
                         & (exe.f_instruction.rs1== wb.frd_addr);
assign  frs1_in_wb1      = wb1.op_writes_frf 
                         & (exe.f_instruction.rs1== wb1.frd_addr);

assign  frs1_forward_val  = frs1_in_mem ? frf_data :
                           (frs1_in_wb  ?   wb.frf_data: write_frf_data) ;
assign  frs1_is_forward   = (frs1_in_mem | frs1_in_wb | frs1_in_wb1 );

assign  frs1_to_fiu   = exe.f_decode.op_reads_rf1 ? alu_inter.rs1_of_alu:
                       (frs1_is_forward ?frs1_forward_val : exe.frs1_val);

// RS2 register forwarding
assign  frs2_in_mem      = mem.f_decode.op_writes_frf
                         & (exe.f_instruction.rs2==mem.frd_addr);
assign  frs2_in_wb       = wb.op_writes_frf 
                         & (exe.f_instruction.rs2== wb.frd_addr);
assign  frs2_in_wb1      = wb1.op_writes_frf 
                         & (exe.f_instruction.rs2== wb1.frd_addr);

assign  frs2_forward_val  = frs2_in_mem ?  frf_data :
                           (frs2_in_wb  ?  wb.frf_data: write_frf_data) ;
assign  frs2_is_forward   = (frs2_in_mem | frs2_in_wb | frs2_in_wb1 );
assign  frs2_to_fiu       = frs2_is_forward ?frs2_forward_val : exe.frs2_val;

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
//   Output to alu
assign alu_inter.fiu_result     = fiu_result;
assign alu_inter.frs2_to_fiu    = frs2_to_fiu;
assign alu_inter.exe_fpi_store_op   = exe.f_decode.is_store_op;
assign alu_inter.exe_fpi_writes_rf  = exe.f_decode.op_writes_rf;
assign alu_inter.fam_depend_stall   = fam_depend_stall;
assign alu_inter.fam_contend_stall  = (~fam_out_s_i.ready_o) 
                                     & id.f_decode.is_fam_op;

//   Output to fam
wire   no_stall_flush      = (~alu_inter.alu_flush) 
                            &(~fam_depend_stall)
                            &(~alu_inter.alu_stall) ;
assign fam_in_s_o.v_i      =  id.f_decode.is_fam_op & no_stall_flush; 


assign fam_in_s_o.data_s_i  =   '{
           f_instruction   :  id.f_instruction,
           frs1_to_exe     :  fam_frs1_to_exe,
           frs2_to_exe     :  fam_frs2_to_exe
        };


assign fam_in_s_o.yumi_i =  (~alu_inter.alu_stall )  
                         & wb1.op_writes_frf
                         & wb1.is_fam_op;


endmodule

