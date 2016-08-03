
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
// these are private variables
// we do not make them volatile
// so that they may be cached

#define N 10
#define ERROR_CODE          0x44444444
#define PASS_CODE           0x0

#define LOAD_STORE_TESTID   0x4

float        input[N]   = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0,9.0,10.0};
float        output[N]  = {0.0};
unsigned int expect[N]  = { 0x3F800000,0x40000000,0x40400000,0x40800000,0x40A00000,\
                            0x40C00000,0x40E00000,0x41000000,0x41100000,0x41200000};


int float_move(float *src, float *dst){

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

int print_value( unsigned int *p){
    int i;
    for(i=0; i<N; i++) 
        bsg_remote_ptr_io_store(0,0x0,p[i]);
}

void load_store_test(float *input, float *dest, unsigned int *expect){
    
    int i, error =0;
    unsigned int * int_dest;

    float_move( input, dest);
    
    int_dest = (unsigned int *) dest;
    for( i=0; i<N; i++){
        if ( int_dest[i]  !=  expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, LOAD_STORE_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, LOAD_STORE_TESTID, ERROR_CODE );
        print_value( output );
        print_value( expect );
    }
}

int main()
{
  bsg_set_tile_x_y();

  if(bsg_x == 0 && bsg_y == 0){

    load_store_test(input, output, expect);

    bsg_finish();
  }

  bsg_wait_while(1);
}

