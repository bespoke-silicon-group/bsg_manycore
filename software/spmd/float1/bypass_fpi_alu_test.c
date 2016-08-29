#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"

extern float input[N];

///////////////////////////////////////////////////////////////////////////////////////////////
//    FPI to ALU bypass
//    floating move --> alu addi 
float        bypass_fpi_alu_output[N]   = {0.0};
unsigned int bypass_fpi_alu_expect[N]  = { 0x3F800004,0x40000004,0x40400004,0x40800004,0x40A00004};

int bypass_fpi_alu(float *src, float *dst){

  __asm__ __volatile__ ("flw f0, 0(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f1, 4(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f2, 8(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f3, 12(%0)": :"r"(src) ); 

  __asm__ __volatile__ ("fmv.x.s t0, f0" );    // *(int *) 1.0 +4 FPI.mem->rs1_to_alu 
  __asm__ __volatile__ ("addi    s2, t0, 0x4" ); 

  
  __asm__ __volatile__ ("fmv.x.s t1, f1" );    // *(int *) 2.0 +4 FPI.wb->rs1_to_alu 
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("addi    s3, t1, 0x4" ); 

  __asm__ __volatile__ ("fmv.x.s t2, f2" );    // *(int *) 3.0 +4 FPI.wb->rs1_to_exe 
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("addi    s4, t2, 0x4" ); 

  __asm__ __volatile__ ("fmv.x.s t3, f3" );    // *(int *) 4.0 +4  No bypass
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("addi    s5, t3, 0x4" ); 

  __asm__ __volatile__ ("sw s2, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s3, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s4, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s5, 12(%0)": :"r"(dst) ); 
}

void bypass_fpi_alu_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    bypass_fpi_alu( input, bypass_fpi_alu_output);
    
    int_output = (unsigned int *) bypass_fpi_alu_output;
    for( i=0; i<4; i++){
        if ( int_output[i]  !=  bypass_fpi_alu_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, BYPASS_FPI_ALU_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, BYPASS_FPI_ALU_TESTID, ERROR_CODE );
        print_value( (unsigned int *) bypass_fpi_alu_output  );
        bsg_remote_ptr_io_store(0,0x0,0x11111111);
        print_value( bypass_fpi_alu_expect );
    }
}


