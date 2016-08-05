#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"
// these are private variables
// we do not make them volatile
// so that they may be cached

extern int print_value( unsigned int *p);

///////////////////////////////////////////////////////////////////////////////////////////////
float        load_store_output[N]   = {0.0};
unsigned int load_store_expect[N]  = { 0x3F800000,0x40000000,0x40400000,0x40800000,0x40A00000,\
                                        0x40C00000,0x40E00000,0x41000000,0x41100000,0x41200000};

int load_store(float *src, float *dst){

  __asm__ __volatile__ ("flw f0, 0(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f1, 4(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f2, 8(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f3, 12(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f4, 16(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f5, 20(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f6, 24(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f7, 28(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f8, 32(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f9, 36(%0)": :"r"(src) ); 
    
  __asm__ __volatile__ ("fsw f0, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f1, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f2, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f3, 12(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f4, 16(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f5, 20(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f6, 24(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f7, 28(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f8, 32(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f9, 36(%0)": :"r"(dst) ); 
    
  return 0;
}
void load_store_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    load_store( input, load_store_output);
    
    int_output = (unsigned int *) load_store_output;
    for( i=0; i<N; i++){
        if ( int_output[i]  !=  load_store_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, LOAD_STORE_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, LOAD_STORE_TESTID, ERROR_CODE );
        print_value( (unsigned int *) load_store_output  );
        print_value( load_store_expect );
    }
}


