#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "mul_div_common.h"

extern int input[N];

#define NUM_RES  4
///////////////////////////////////////////////////////////////////////////////////////////////
//    mul div  core
int  mul_div_output[N]  = {0};
int  mul_div_expect[N]  = {0xfffffffa, 0xffffffff, 0x00000002, 0xffffffff, \
                           0xffffffff, 0x0,        0xffffffff, 0x00000003};

int mul_div(int *src, int *dst){

  __asm__ __volatile__ ("lw t0, 4(%0)"::"r"(src) );  //-2
  __asm__ __volatile__ ("lw t1, 8(%0)"::"r"(src) );  //3 
  __asm__ __volatile__ ("mul    t4,     t0, t1" );   //-6
  __asm__ __volatile__ ("mulh   t5,     t0, t1" );   //-6
  __asm__ __volatile__ ("mulhu  t6,     t0, t1" );   //0000_0002
  __asm__ __volatile__ ("mulhsu s11,    t0, t1" );   //FFFF_FFFF

  __asm__ __volatile__ ("div    s10,    t1, t0" );   //3/(-2) = -1 
  __asm__ __volatile__ ("divu   s9 ,    t1, t0" );   //3/FFFF_FFFE = 0 

  __asm__ __volatile__ ("rem    s8 ,    t1, t0" );   //3%(-2) = -1
  __asm__ __volatile__ ("remu   s7 ,    t1, t0" );   //3%FFFF_FFFE = 3 


  __asm__ __volatile__ ("sw t4, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t5, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t6, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s11, 12(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("sw s10, 16(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s9 , 20(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s8 , 24(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw s7 , 28(%0)" : :"r"(dst) ); 
}

void mul_div_test(int  *input){
    
    int i, error =0;
    unsigned int * int_output;

    mul_div( input, mul_div_output);
    
    int_output = (unsigned int *) mul_div_output;
    for( i=0; i<NUM_RES; i++){
        if ( int_output[i]  !=  mul_div_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, MUL_DIV_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, MUL_DIV_TESTID, ERROR_CODE );
        print_value( (unsigned int *) mul_div_output  );
        bsg_remote_ptr_io_store(0,0x0,0x11111111);
        print_value( mul_div_expect );
    }
}


