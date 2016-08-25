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
logic [RV32_freg_data_width_gp-1:0]  frf_rs1_out, frf_rs2_out, frf_rs3_out, 
                                     frf_wd;

logic [RV32_reg_addr_width_gp-1:0]   frf_wa;
logic                                frf_wen, frf_cen;

// The FCSR register
f_fcsr_s                             fcsr_r;
f_fcsr_s                             fiu_fcsr_o;//outputs from fiu

// Value forwarding logic
// Forwarding signals
logic   frs1_in_mem, frs1_in_wb, frs1_in_wb1;
logic   frs2_in_mem, frs2_in_wb, frs2_in_wb1;

logic [RV32_freg_data_width_gp-1:0] frs1_to_exe, frs2_to_exe, frs3_to_exe ;
logic [RV32_freg_data_width_gp-1:0] frs1_to_fiu, frs2_to_fiu, fiu_result;
logic [RV32_freg_data_width_gp-1:0] frf_data;  

logic                               frs1_is_forward, frs2_is_forward;
logic [RV32_freg_data_width_gp-1:0] frs1_forward_val,frs2_forward_val;


//forwarding logic for fam
logic   fam_depend_stall;   // FAM data dependency stall

logic   fam_frs1_in_mem, fam_frs1_in_wb;
logic   fam_frs2_in_mem, fam_frs2_in_wb;
logic   fam_frs3_in_mem, fam_frs3_in_wb;

logic   fam_frs1_is_forward, fam_frs2_is_forward, fam_frs3_is_forward;

logic [RV32_freg_data_width_gp-1:0] 
      fam_frs1_forward_val,fam_frs2_forward_val, fam_frs3_forward_val;
logic [RV32_freg_data_width_gp-1:0] 
      fam_frs1_to_exe, fam_frs2_to_exe, fam_frs3_to_exe;
// Data will be write back to the floating register file
logic [RV32_freg_data_width_gp-1:0] write_frf_data;

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
bsg_mem_3r1w #( .width_p                (RV32_freg_data_width_gp)
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

   ,.r2_v_i    (frf_cen)
   ,.r2_addr_i (id.f_instruction[31:27])
   ,.r2_data_o (frf_rs3_out)
  );

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

//If there is a fcsr instruction and there are instructions in
//pipestages that will update fflags, we should stall!
wire fcsr_fflags_stall = id.f_decode.is_fcsr_op 
                &( exe.f_decode.op_writes_fflags
                 | mem.f_decode.op_writes_fflags
                 | wb.op_writes_fflags
                 | wb1.op_writes_fflags
                 );

//If there is a fam instruction which need frm resgiter value and 
//there is a fcsr instruction value in exe updating frm, we should stall
wire fcsr_frm_stall = id.f_decode.is_fam_op & exe.f_decode.is_fcsr_op;

wire fcsr_stall = fcsr_fflags_stall | fcsr_frm_stall;



wire id_exe_rs1_match=    exe.f_decode.op_writes_frf
                      & ( id.f_instruction.rs1 == exe.f_instruction.rd);

wire id_exe_rs2_match=    exe.f_decode.op_writes_frf
                      & ( id.f_instruction.rs2 == exe.f_instruction.rd);

wire id_exe_rs3_match=    exe.f_decode.op_writes_frf
                      & ( id.f_instruction[31:27] == exe.f_instruction.rd);

// 1.all units that need data in FAM exe will cause stall;
// 2 FAM needs data in EXE will always stall!
wire id_exe_stall_conds = exe.f_decode.is_fam_op | id.f_decode.is_fam_op;

wire fam_exe_dep1 = id_exe_rs1_match & id_exe_stall_conds;
wire fam_exe_dep2 = id_exe_rs2_match & id_exe_stall_conds;
wire fam_exe_dep3 = id_exe_rs3_match & id_exe_stall_conds;
                 
//Only needs data in FAM.mem will cause stall;
wire fam_mem_dep1 =mem.f_decode.op_writes_frf & mem.f_decode.is_fam_op
                &( id.f_instruction.rs1 == mem.frd_addr) ;

wire fam_mem_dep2 =mem.f_decode.op_writes_frf & mem.f_decode.is_fam_op
                &( id.f_instruction.rs2 == mem.frd_addr) ;

wire fam_mem_dep3 =mem.f_decode.op_writes_frf & mem.f_decode.is_fam_op
                &( id.f_instruction[31:27] == mem.frd_addr) ;

//Only needs data in FAM.wb will cause stall;
wire fam_wb_dep1  =wb.op_writes_frf & wb.is_fam_op
                &( id.f_instruction.rs1 == wb.frd_addr) ;

wire fam_wb_dep2  =wb.op_writes_frf & wb.is_fam_op
                &( id.f_instruction.rs2 == wb.frd_addr) ;

wire fam_wb_dep3  =wb.op_writes_frf & wb.is_fam_op
                &( id.f_instruction[31:27] == wb.frd_addr) ;

// combine all the stall source
wire fam_depend1 = id.f_decode.op_reads_frf1 
                 & ( fam_exe_dep1 | fam_mem_dep1 | fam_wb_dep1 );

wire fam_depend2 = id.f_decode.op_reads_frf2 
                 & ( fam_exe_dep2 | fam_mem_dep2 | fam_wb_dep2 );

wire fam_depend3 = id.f_decode.op_reads_frf3 
                 & ( fam_exe_dep3 | fam_mem_dep3 | fam_wb_dep3 );

assign fam_depend_stall = fam_depend1 | fam_depend2 | fam_depend3 | fcsr_stall;

///////////////////////////////////////////////////////////////////
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

// The value forwarded to FAM frs3
assign  fam_frs3_in_mem  = mem.f_decode.op_writes_frf
                         & (id.f_instruction[31:27]==mem.frd_addr);

assign  fam_frs3_in_wb  = wb.op_writes_frf&(id.f_instruction[31:27]==wb.frd_addr);

assign  fam_frs3_forward_val  = fam_frs3_in_mem ? frf_data :  wb.frf_data;
assign  fam_frs3_is_forward   = fam_frs3_in_mem | fam_frs3_in_wb ;

// value write back to the register file
assign write_frf_data = wb1.is_fam_op? fam_out_s_i.data_o.result : wb1.frf_data;


// The value send to FPI
always_comb
begin
    if (  (id.f_instruction.rs1 == wb1.frd_addr) 
        & wb1.op_writes_frf
       )
        frs1_to_exe = write_frf_data;
    // RD in general purpose register file
    else
        frs1_to_exe = frf_rs1_out;
end

always_comb
begin
    if (  (id.f_instruction.rs2 == wb1.frd_addr) 
        & wb1.op_writes_frf
       )
        frs2_to_exe = write_frf_data;
    // RD in general purpose register file
    else
        frs2_to_exe = frf_rs2_out;
end

always_comb
begin
    if (  (id.f_instruction[31:27] == wb1.frd_addr) 
        & wb1.op_writes_frf
       )
        frs3_to_exe = write_frf_data;
    // RD in general purpose register file
    else
        frs3_to_exe = frf_rs3_out;
end

//The value sends to FAM
assign fam_frs1_to_exe = fam_frs1_is_forward ? fam_frs1_forward_val : 
                                                   frs1_to_exe      ;

assign fam_frs2_to_exe = fam_frs2_is_forward ? fam_frs2_forward_val : 
                                                   frs2_to_exe      ;

assign fam_frs3_to_exe = fam_frs3_is_forward ? fam_frs3_forward_val : 
                                                   frs3_to_exe      ;
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

//Handle the FCSR writing in EXE stage.
//write enable condition ,please refer to 
// RISCV-V Instruction set Mannual Volumn I, Version2.1
wire fcsrrw_write_en    =  (exe.f_instruction.rd !=0)
       &(   ( exe.f_instruction.funct3 == `RV32_CSRRW_FUN3 )
         || ( exe.f_instruction.funct3 == `RV32_CSRRWI_FUN3)
        );
wire fcsrrsc_write_en   =  (exe.f_instruction.rs1!=0)
       &(   ( exe.f_instruction.funct3 != `RV32_CSRRW_FUN3 )
         && ( exe.f_instruction.funct3 != `RV32_CSRRWI_FUN3)
         && ( exe.f_instruction.funct3 != 3'b0             )
        );

wire fcsr_write_en = exe.f_decode.is_fcsr_op 
                   & ( fcsrrw_write_en | fcsrrsc_write_en );

wire fcsr_frm_write_en = fcsr_write_en
                   &(  (exe.f_instruction[31:20] == RV32_csr_addr_frm  ) 
                     | (exe.f_instruction[31:20] == RV32_csr_addr_fcsr )
                    );  
wire fcsr_fflags_write_en = fcsr_write_en
                   &(  (exe.f_instruction[31:20] == RV32_csr_addr_fflags) 
                     | (exe.f_instruction[31:20] == RV32_csr_addr_fcsr  )
                    );  
wire fflags_write_en = fcsr_fflags_write_en | wb1.op_writes_fflags ;
                     
wire [RV32_fflags_width_gp-1:0] 
fflags_write_value = fcsr_fflags_write_en     ?   fiu_fcsr_o.fflags
                    :(wb1.is_fam_op   ?   fam_out_s_i.data_o.fflags :   wb1.fflags);
                                  

always_ff @ (posedge clk)
begin
    if (reset )
        fcsr_r.frm <= '0;
    else if ( fcsr_frm_write_en & (~alu_inter.alu_stall) )
        fcsr_r.frm <= fiu_fcsr_o.frm;
end

always_ff @ (posedge clk)
begin
    if (reset )
        fcsr_r.fflags <= '0;
    else if ( fflags_write_en & (~alu_inter.alu_stall) )
        fcsr_r.fflags <= fflags_write_value;
end

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

// The data from ALU is definitely the integer value, so no data convertion 
// is needed.
assign  frs1_to_fiu   = exe.f_decode.op_reads_rf1 ? {1'b0,alu_inter.rs1_of_alu}:
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

//The FIU takes 33bit input and 33bit output.
//The data format depends on specific instruction
fiu fiu_0 ( .frs1_i         ( frs1_to_fiu       ),
            .frs2_i         ( frs2_to_fiu       ),
            .op_i           ( exe.f_instruction ),
            .f_fcsr_s_i     ( fcsr_r            ),
            .f_fcsr_s_o     ( fiu_fcsr_o        ),
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
            fiu_result      : fiu_result,
            fflags          : fiu_fcsr_o.fflags
        };
end

//+----------------------------------------------
//|
//|       MEMORY TO RF WRITE BACK SHIFT
//|
//+----------------------------------------------

// Determine what data to send to the write back stage
// that will end up being writen to the register file

// Convert the loaded data format to Record Float
logic [RV32_freg_data_width_gp-1:0]  flw_data_RecF;
bsg_recFNFromFN flw_data_to_RecF(  
                .io_a   (  alu_inter.flw_data   )
               ,.io_out (  flw_data_RecF        )
                 );

always_comb
begin
    frf_data = mem.f_decode.is_load_op? flw_data_RecF:
                                        mem.fiu_result;
end

// Synchronous wb stage shift
always_ff @ (posedge clk)
begin
    if (reset )
        wb <= '0;
    else if (~alu_inter.alu_stall)
        wb <= '{
            op_writes_frf   : mem.f_decode.op_writes_frf,
            op_writes_fflags: mem.f_decode.op_writes_fflags,
            fflags          : mem.fflags,
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
            op_writes_frf   : wb.op_writes_frf,
            op_writes_fflags: wb.op_writes_fflags,
            fflags          : wb.fflags,
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


// FIU should be responsible for converting the data format.
// CVT, MV, etc.
assign alu_inter.fiu_result = fiu_result[RV32_reg_data_width_gp-1:0];

//used for float sotre instruction.
logic [RV32_reg_data_width_gp-1:0]  frs2_to_fiu_FN;
bsg_fNFromRecFN frs2_to_fiu_to_FN(  
                .io_a   ( frs2_to_fiu    )
               ,.io_out ( frs2_to_fiu_FN )
                 );
assign alu_inter.frs2_to_fiu    = frs2_to_fiu_FN;

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
           frs2_to_exe     :  fam_frs2_to_exe,
           frs3_to_exe     :  fam_frs3_to_exe,
           frm             :  fcsr_r.frm
        };


assign fam_in_s_o.yumi_i =  (~alu_inter.alu_stall )  
                         & wb1.op_writes_frf
                         & wb1.is_fam_op;

endmodule

