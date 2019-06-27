#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"

extern float input[N];
int int_input[9] = {0x1,0x1,0x25  }; 

///////////////////////////////////////////////////////////////////////////////////////////////
float        fcsr_output[N]   = {0.0};
unsigned int fcsr_expect[N]  = { 0x0,0x0,0x21,0x1,0x5,0x25};

int fcsr(float *src, float *dst, int* int_input){
  //000_00000
  __asm__ __volatile__ ("lw t0, 0(%0)" : :"r"(int_input) ); //00001
  __asm__ __volatile__ ("fsflags t1, t0");  //000_00001
  __asm__ __volatile__ ("sw t1, 0(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("lw t0, 4(%0)" : :"r"(int_input) ); //001
  __asm__ __volatile__ ("fsrm t1, t0");  // 001_00001
  __asm__ __volatile__ ("sw t1, 4(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("lw t0, 8(%0)" : :"r"(int_input) ); //001_01001
  __asm__ __volatile__ ("fscsr t1, t0");  //001_01001
  __asm__ __volatile__ ("sw t1, 8(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("frrm t1");  //001
  __asm__ __volatile__ ("sw t1, 12(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("frflags t1");  //01001
  __asm__ __volatile__ ("sw t1, 16(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("frcsr t1");  //001_01001
  __asm__ __volatile__ ("sw t1, 20(%0)" : :"r"(dst) ); 
   return 0;
}

void fcsr_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    fcsr( input, fcsr_output,int_input);
    
    int_output = (unsigned int *) fcsr_output;
    for( i=0; i<6; i++){
        if ( int_output[i]  !=  fcsr_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, FCSR_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, FCSR_TESTID, ERROR_CODE );
        print_value( (unsigned int *) fcsr_output  );
        print_value( fcsr_expect );
    }
}


