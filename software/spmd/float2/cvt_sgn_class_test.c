#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"

static float cvt_w_s_input[3]   = {1.0, -2.0, 3.0 } ;
static int   cvt_s_w_input[3]   = {1,   -2 ,  3   } ;

///////////////////////////////////////////////////////////////////////////////////////////////
//    FPI to ALU bypass
//    floating move --> alu addi 
float        cvt_sgn_class_output[N]   = {0.0};
unsigned int cvt_sgn_class_expect[N]  = { 0x1,       0xFFFFFFFE, 0x3,\
                                          0x3F800000,0xC0000000,0x40400000,\
                                          0xBF800000,0x00000040};

int cvt_sgn_class(float *fsrc, int*isrc, float *dst){

  __asm__ __volatile__ ("flw f0, 0(%0)" : :"r"(fsrc) ); 
  __asm__ __volatile__ ("flw f1, 4(%0)" : :"r"(fsrc) ); 
  __asm__ __volatile__ ("flw f2, 8(%0)" : :"r"(fsrc) ); 

  __asm__ __volatile__ ("lw t3, 12(%0)" : :"r"(fsrc) ); 
  __asm__ __volatile__ ("lw t4, 16(%0)" : :"r"(fsrc) ); 
  __asm__ __volatile__ ("lw t5, 20(%0)" : :"r"(fsrc) ); 

  __asm__ __volatile__ ("fcvt.w.s  t0, f0" );// t0=0x1 
  __asm__ __volatile__ ("fcvt.w.s  t1, f1" );// t1=-2 = 0xFFFFFFFE
  __asm__ __volatile__ ("fcvt.wu.s t2, f2" );// t2= 3 

  __asm__ __volatile__ ("fcvt.s.w  f3, t3" );// f3=1.0 = 0x3F800000 
  __asm__ __volatile__ ("fcvt.s.w  f4, t4" );// f4=-2.0= 0xC0000000
  __asm__ __volatile__ ("fcvt.s.wu f5, t5" );// f5=3.0 = 0x40400000

  __asm__ __volatile__ ("sw t0, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t1, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t2, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f3, 12(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f4, 16(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("fsw f5, 20(%0)" : :"r"(dst) ); 

  __asm__ __volatile__ ("flw f0, 0(%0)" : :"r"(fsrc) ); 
  __asm__ __volatile__ ("flw f1, 4(%0)" : :"r"(fsrc) ); 
  __asm__ __volatile__ ("fsgnj.s f2,f0,f1");// f2 = -1.0 = 0xBF800000
  __asm__ __volatile__ ("fclass.s t0, f0");  //  t0 = 0x00000040
  
  __asm__ __volatile__ ("fsw f2, 24(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw  t0, 28(%0)" : :"r"(dst) ); 
}

void cvt_sgn_class_test(){
    
    int i, error =0;
    unsigned int * int_output;

    cvt_sgn_class( cvt_w_s_input,cvt_s_w_input, cvt_sgn_class_output);
    
    int_output = (unsigned int *) cvt_sgn_class_output;
    for( i=0; i<8; i++){
        if ( int_output[i]  !=  cvt_sgn_class_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, CVT_SGN_CLASS_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, CVT_SGN_CLASS_TESTID, ERROR_CODE );
        print_value( (unsigned int *) cvt_sgn_class_output  );
        bsg_remote_ptr_io_store(0,0x0,0x11111111);
        print_value( cvt_sgn_class_expect );
    }
}


