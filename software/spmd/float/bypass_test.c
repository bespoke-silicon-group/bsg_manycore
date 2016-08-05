#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"

/////////////////////////////////////////
//    ALU to FPI bypass
//    FPI to FPI bypass
//    FPI to ALU bypass
extern float input[N];

///////////////////////////////////////////////////////////////////////////////////////////////
float        bypass_output[N]   = {0.0};
unsigned int bypass_expect[N]  = { 0x0,0x1,0x1};

int bypass(float *src, float *dst){


  __asm__ __volatile__ ("flw f0,12(%0)": :"r"(src)  ); 
  __asm__ __volatile__ ("flw f1,16(%0)": :"r"(src)  ); 
  __asm__ __volatile__ ("flw f2,20(%0)": :"r"(src)  ); 

  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 

  __asm__ __volatile__ ("feq.s t0, f0, f1"  ); 
  __asm__ __volatile__ ("fle.s t1, f0, f0"  ); 
  __asm__ __volatile__ ("flt.s t2, f0, f1"  ); 

  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 

  __asm__ __volatile__ ("sw t0, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t1, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t2, 8(%0)" : :"r"(dst) ); 

}

void bypass_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    bypass( input, bypass_output);
    
    int_output = (unsigned int *) bypass_output;
    for( i=0; i<3; i++){
        if ( int_output[i]  !=  bypass_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, BYPASS_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, BYPASS_TESTID, ERROR_CODE );
        print_value( (unsigned int *) bypass_output  );
        print_value( bypass_expect );
    }
}


