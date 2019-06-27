#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"

extern float input[N];

///////////////////////////////////////////////////////////////////////////////////////////////
float        move_output[N]   = {0.0};
unsigned int move_expect[N]  = { 0x40400000,0x40000000,0x3F800000,\
                                 0x40800000,0x40A00000,0x40C00000};

int move(float *src, float *dst){

  __asm__ __volatile__ ("lw t0, 0(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("lw t1, 4(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("lw t2, 8(%0)" : :"r"(src) ); 

  __asm__ __volatile__ ("flw f3,12(%0)": :"r"(src)  ); 
  __asm__ __volatile__ ("flw f4,16(%0)": :"r"(src)  ); 
  __asm__ __volatile__ ("flw f5,20(%0)": :"r"(src)  ); 
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 

//Reverse the order, and move it to the f0,f1,f2; 
  __asm__ __volatile__ ("fmv.s.x f0, t2"  ); 
  __asm__ __volatile__ ("fmv.s.x f1, t1"  ); 
  __asm__ __volatile__ ("fmv.s.x f2, t0"  ); 

  __asm__ __volatile__ ("fmv.x.s t3, f3"  ); 
  __asm__ __volatile__ ("fmv.x.s t4, f4"  ); 
  __asm__ __volatile__ ("fmv.x.s t5, f5"  ); 
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 

  __asm__ __volatile__ ("fsw f0, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f1, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f2, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw  t3, 12(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("sw  t4, 16(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("sw  t5, 20(%0)": :"r"(dst) ); 

  return 0;
}

void move_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    move( input, move_output);
    
    int_output = (unsigned int *) move_output;
    for( i=0; i<6; i++){
        if ( int_output[i]  !=  move_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, MOVE_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, MOVE_TESTID, ERROR_CODE );
        print_value( (unsigned int *) move_output  );
        print_value( move_expect );
    }
}


