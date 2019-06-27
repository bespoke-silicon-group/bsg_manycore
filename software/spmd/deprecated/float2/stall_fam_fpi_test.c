#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"

extern float input[N];

///////////////////////////////////////////////////////////////////////////////////////////////
//    fam to fpi  stalls
float        stall_fam_fpi_output[N]= {0.0};
unsigned int stall_fam_fpi_expect[N]= {0x40400000,0x40800000,0x40A00000, 0x40C00000,0x40C00001};

int stall_fam_fpi(float *src, float *dst){

  __asm__ __volatile__ ("flw f0, 0(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f1, 4(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f2, 8(%0)" : :"r"(src) ); 
  __asm__ __volatile__ ("flw f3, 12(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f4, 16(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f5, 20(%0)": :"r"(src) ); 
  __asm__ __volatile__ ("flw f6, 24(%0)": :"r"(src) ); 

  __asm__ __volatile__ ("fadd.s  f10, f0,f1" ); //3.0, No Stall
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("fmv.x.s t0,  f10" );    

  __asm__ __volatile__ ("fadd.s  f11, f0,f2" ); //4.0, 1 Stall
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("fmv.x.s t1,  f11" );    


  __asm__ __volatile__ ("fadd.s  f12, f0,f3" ); //5.0, 2 Stall
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("fmv.x.s t2,  f12" );    

  __asm__ __volatile__ ("fadd.s  f13, f0,f4" ); //6.0, 3 Stall
  __asm__ __volatile__ ("fmv.x.s t3,  f13" );    

  __asm__ __volatile__ ("addi   t4, t3, 1" ); //fpi to fam stall
  

  __asm__ __volatile__ ("sw t0, 0(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t1, 4(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t2, 8(%0)" : :"r"(dst) ); 
  __asm__ __volatile__ ("sw t3, 12(%0)": :"r"(dst) ); 
  __asm__ __volatile__ ("sw t4, 16(%0)": :"r"(dst) ); 
}

void stall_fam_fpi_test(float *input){
    
    int i, error =0;
    unsigned int * int_output;

    stall_fam_fpi( input, stall_fam_fpi_output);
    
    int_output = (unsigned int *) stall_fam_fpi_output;
    for( i=0; i<5; i++){
        if ( int_output[i]  !=  stall_fam_fpi_expect[i] ) {
            error = 1; 
            break;
        }
    }

    if( error == 0 ){
        bsg_remote_ptr_io_store(0, STALL_FAM_FPI_TESTID, PASS_CODE );
    }else{
        bsg_remote_ptr_io_store(0, STALL_FAM_FPI_TESTID, ERROR_CODE );
        print_value( (unsigned int *) stall_fam_fpi_output  );
        bsg_remote_ptr_io_store(0,0x0,0x11111111);
        print_value( stall_fam_fpi_expect );
    }
}


