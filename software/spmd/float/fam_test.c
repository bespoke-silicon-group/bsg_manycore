#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"


///////////////////////////////////////////////////////////////////////////////////////////////
//    FPI to ALU bypass
//    floating move --> alu addi 
float        fam_output[N]   = {0.0};
unsigned int fam_expect[N]  = {0x40400000,0xBF800000,0x40C00000,0x3F000000,0xBF800000,0x40C00000};

int fam(float *src, float *dst){

  __asm__ __volatile__ ("flw f11, 0(%0)" : :"r"(src) );  // 1.0
  __asm__ __volatile__ ("flw f12, 4(%0)" : :"r"(src) );  // 2.0

  __asm__ __volatile__ ("fadd.s  f2, f11, f12");  //3.0
  __asm__ __volatile__ ("fsub.s  f3, f11, f12");  //-1.0
  __asm__ __volatile__ ("fmul.s  f4, f2,  f12");  //6.0
  __asm__ __volatile__ ("fdiv.s  f5, f11, f12");  //0.50
  __asm__ __volatile__ ("fmin.s  f6, f2,  f3");   // -1.0
  __asm__ __volatile__ ("fmax.s  f7, f2,  f4");   // 6.0 

  __asm__ __volatile__ ("fsw f2, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f3, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f4, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f5, 12(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f6, 16(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f7, 20(%0)" : :"r"(dst) ); 

}


void fam_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    fam( input, fam_output);
    
    int_output = (unsigned int *) fam_output;
    for( i=0; i<6; i++){
        if ( int_output[i]  !=  fam_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, FAM_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, FAM_TESTID, ERROR_CODE );
        print_value( (unsigned int *) fam_output  );
        bsg_remote_ptr_io_store(0,0x0,0x11111111);
        print_value( fam_expect );
    }
}


