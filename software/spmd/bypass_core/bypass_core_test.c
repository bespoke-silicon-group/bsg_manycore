#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bypass_common.h"

extern unsigned int input[N];

///////////////////////////////////////////////////////////////////////////////////////////////
//    bypass core
unsigned int  bypass_core_output[N]  = {0};
unsigned int  bypass_core_expect[N]  = {0x3, 0x4, 0x5};

int bypass_core(unsigned int *src, unsigned int *dst){

  //MEM --> EXE
  __asm__ __volatile__ ("lw t0, 0(%0)"::"r"(src) ); 
  __asm__ __volatile__ ("lw t1, 4(%0)"::"r"(src) ); 
  __asm__ __volatile__ ("add t4, t0, t1" );  //3 = 1+ 2

  //WB --> EXE
  __asm__ __volatile__ ("lw t1, 8(%0)"::"r"(src) ); //3
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("add t5, t0, t1" );  //4 = 1+ 3

  //READ/WRITE RF at the same time
  __asm__ __volatile__ ("lw t1, 12(%0)"::"r"(src) ); //4
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("add t6, t0, t1" );  //5 = 1+ 4

  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 
  __asm__ __volatile__ ("nop"  ); 
  
  //Write back the result
  __asm__ __volatile__ ("sw t4, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t5, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t6, 8(%0)" : :"r"(dst) ); 

}

void bypass_core_test(unsigned int  *input){
    
    int i, error =0;
    unsigned int * int_output;

    bypass_core( input, bypass_core_output);
    
    int_output = (unsigned int *) bypass_core_output;
    for( i=0; i<3; i++){
        if ( int_output[i]  !=  bypass_core_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, BYPASS_CORE_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, BYPASS_CORE_TESTID, ERROR_CODE );
        print_value( (unsigned int *) bypass_core_output  );
        bsg_remote_ptr_io_store(0,0x0,0x11111111);
        print_value( bypass_core_expect );
    }
}


