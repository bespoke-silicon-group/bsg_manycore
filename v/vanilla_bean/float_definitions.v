`ifndef _float_definitions_v_
`define _float_definitions_v_

`include "float_parameters.v"
/**
 *  This file defines the structs and macros
 *  used through out the vallina core with floating point unit.
 */
/////////////////////////////////////////////////////////////
// 
//    SIGNALS OF DIFFERENT STAGES
//
/////////////////////////////////////////////////////////////
// Define the single precision floationg point bit pattern
typedef struct packed
{
    logic           sign;
    logic[7:0]      exp;
    logic[22:0]     mant;
}f_bit_s;

//the exception flags.
typedef struct packed{
    logic                               NV;
    logic                               DZ;
    logic                               OF;
    logic                               UF;
    logic                               NX;
}f_flags_s;


// Decode control signals structures
typedef struct packed
{
    logic op_writes_rf;     // Op writes to the register file
    logic op_reads_rf1;     // Op needs data from integer RF
    logic is_load_op;       // Op loads data from memory
    logic is_store_op;      // Op stores data to memory
    logic is_mem_op;        // Op modifies data memory

    logic is_fam_op;	    //Should be send to FAM unit.
    logic is_fpi_op;        //is a FPI operation 
    logic is_fcsr_op;       //is a FCSR operation
    logic op_writes_frf;    // write to the floating point regsiter file
    logic op_reads_frf1;    // OP reads from first port of register file
    logic op_reads_frf2;    // OP reads from second port of register file
    logic op_reads_frf3;    // OP reads from third port of register file

//    logic op_reads_frm;     // Op needs the rounding mode register
    logic op_writes_fflags; // Op will writes the fflags
} f_decode_s;

// Instruction decode stage signals

// Instruction decode stage signals
typedef struct packed
{
    instruction_s                      f_instruction;  // Instruction being executed
    f_decode_s                         f_decode;       // Decode signals
} f_id_signals_s;

// Execute stage signals
typedef struct packed
{
    instruction_s                       f_instruction;  // Instruction being executed
    f_decode_s                          f_decode;       // Decode signals
    logic [RV32_freg_data_width_gp-1:0] frs1_val;     // RF output data from RS1 address
    logic [RV32_freg_data_width_gp-1:0] frs2_val;     // RF output data from RS2 address
} f_exe_signals_s;

// Memory stage signals
typedef struct packed
{
    logic [RV32_reg_addr_width_gp-1:0]  frd_addr;    // Destination address
    f_decode_s                          f_decode;   // Decode signal 
    //We only stores FMV.S.W and FCVT.S.W result. The result that write to
    //integre Regfile will be write to ALU pipeline register.
    logic [RV32_freg_data_width_gp-1:0] fiu_result; // the FIU outpout 

    f_flags_s                           fflags;
} f_mem_signals_s;

// RF write back stage signals
typedef struct packed
{
    logic                               op_writes_frf; // Op writes to the FALU register file
    logic                               is_fam_op;     // Op executed in FAM
    logic                               is_fpi_op;     // OP executed in FPI
    logic                               op_writes_fflags; // Op will writes the fflags
    f_flags_s                           fflags;
    logic [RV32_reg_addr_width_gp-1:0]  frd_addr;      // Register file write address
    logic [RV32_freg_data_width_gp-1:0] frf_data;      // Register file write data
} f_wb_signals_s;

// RF write back stage signals
typedef struct packed
{
    logic                               op_writes_frf; // Op writes to the FALU register file
    logic                               op_writes_fflags; // Op will writes the fflags
    f_flags_s                           fflags;
    logic                               is_fam_op;     // Op executed in FAM
    logic                               is_fpi_op;     // OP executed in FPI
    logic [RV32_reg_addr_width_gp-1:0]  frd_addr;       // Register file write address
    logic [RV32_freg_data_width_gp-1:0] frf_data;       // Register file write data
} f_wb1_signals_s;

/////////////////////////////////////////////////////////////
// 
//    INTERFACE DEFINITION
//
/////////////////////////////////////////////////////////////

//The interface between FPI and ALU pipleline
interface  fpi_alu_inter;

    //the interface in FE stage
    logic [RV32_instr_width_gp-1:0]         f_instruction; //the instrucitons
    
    //the interface in EXE stage
    //all the data fromat will be converted by FPI
    logic [RV32_reg_data_width_gp-1:0]      rs1_of_alu; //values used for FCVT, FMV
    logic [RV32_reg_data_width_gp-1:0]      frs2_to_fiu;//values will stored to mem
    logic [RV32_reg_data_width_gp-1:0]      fiu_result; //fiu_result write to RF 

    logic                                   exe_fpi_store_op;// FPI store in EX    
    logic                                   exe_fpi_writes_rf;//FPI writes I RF
    
    logic  [RV32_reg_addr_width_gp-1:0]     mem_alu_rd_addr;// 
    logic                                   mem_alu_writes_rf;//FPI writes I RF
    //the interface in MEM stage
    //all the data fromat will be converted by FPI
    logic [RV32_reg_data_width_gp-1:0]      flw_data;  //the loaded data 
    
    //The control signals
    logic                                   alu_flush; //alu pipeline flushes
    logic                                   alu_stall; //alu pipeline stalls.
    logic                                   fam_depend_stall; //dependency stall
    logic                                   fam_contend_stall; //contend  stall
    modport alu_side( 
                output  f_instruction, 
                output  rs1_of_alu,
                input   frs2_to_fiu,
                input   fiu_result,
                input   exe_fpi_store_op, exe_fpi_writes_rf, 
                output  mem_alu_rd_addr,  mem_alu_writes_rf, 
                output  flw_data,
                output  alu_flush,
                output  alu_stall,
                input   fam_depend_stall,
                input   fam_contend_stall
                );  
    
    modport fpi_side( 
                input   f_instruction,
                input   rs1_of_alu,
                output  frs2_to_fiu,
                output  fiu_result,
                output  exe_fpi_store_op,   exe_fpi_writes_rf, 
                input   mem_alu_rd_addr,    mem_alu_writes_rf, 
                input   flw_data,
                input   alu_flush,
                input   alu_stall,
                output  fam_depend_stall,
                output  fam_contend_stall
                );  

endinterface


// The FIFO contents send to and get from FAM
typedef struct packed{
    instruction_s                            f_instruction; //the instrucitons
    logic [RV32_freg_data_width_gp-1:0]      frs1_to_exe;   //the first operans
    logic [RV32_freg_data_width_gp-1:0]      frs2_to_exe;   //the second operans
    logic [RV32_freg_data_width_gp-1:0]      frs3_to_exe;   //the third operans
    logic [RV32_frm_width_gp   -1:0]         frm;           //the rounding mode bits
} f_fam_in_data_s; 

localparam RV32_mac_input_width_gp =  RV32_instr_width_gp    
                                  +3*RV32_freg_data_width_gp
                                  +  RV32_frm_width_gp;

typedef struct packed{
    logic [RV32_freg_data_width_gp-1:0] result;//the first operans
    f_flags_s                           fflags;
}f_mac_out_s;

localparam RV32_mac_output_width_gp =  RV32_freg_data_width_gp +  RV32_fflags_width_gp;

//pipleline registers in FAM
typedef struct packed{
    f_mac_out_s                         mac_out;//the first operans
    logic                               fam_in_from;//data come from which tile 
    logic                               op_writes_frf;//data should write to frf 
} f_fam_pipe_regs_s; 

// Interface between FPI and FAM
typedef struct packed{
    logic                              v_i;
    f_fam_in_data_s                    data_s_i;    
    logic                              yumi_i; 
}f_fam_in_s;

// Interface between FPI and FAM
typedef struct packed{
    logic                               ready_o;
    logic                               v_o;    
    f_mac_out_s                         data_o; 
}f_fam_out_s;

//the FSR register
typedef struct packed{
    logic [RV32_frm_width_gp   -1:0]    frm;
    f_flags_s                           fflags;
}f_fcsr_s;

`endif
