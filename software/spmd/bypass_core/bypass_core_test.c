#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bypass_common.h"

extern unsigned int input[N];

///////////////////////////////////////////////////////////////////////////////////////////////
//    bypass core
unsigned int  bypass_core_output[N]  = {0};
unsigned int  bypass_core_expect[N]  = {0x23, 0x34, 0x45, 0x56, 0xdd};

int bypass_core(unsigned int *src, unsigned int *dst){

  //MEM --> EXE
  __asm__ __volatile__ ("lw t0, 0(%0)"::"r"(src) );
  __asm__ __volatile__ ("lw t1, 4(%0)"::"r"(src) );
  __asm__ __volatile__ ("add t4, t0, t1" );  //0x23 = 0x1+ 0x22

  //WB --> EXE
  __asm__ __volatile__ ("lw t1, 8(%0)"::"r"(src) ); //0x33
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("add t5, t0, t1" );  //0x34 = 0x1+ 0x33

  //WB --> ID
  __asm__ __volatile__ ("lw t1, 12(%0)"::"r"(src) ); //0x4
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("add t6, t0, t1" );  //0x45 = 0x1+ 0x44

  //WB --> IF, READ/WRITE RF at the same time
  __asm__ __volatile__ ("lw t1, 16(%0)"::"r"(src) ); //0x55
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("add s2, t0, t1" );  //0x56 = 0x1+ 0x55

  //WB --> ID, but with dependent stall
  __asm__ __volatile__ ("lw t1, 20(%0)"::"r"(src) );  //0x66 --> WB
  __asm__ __volatile__ ("nop");
  __asm__ __volatile__ ("lw t0, 24(%0)"::"r"(src)  ); //0x77 -->EXE
  //There will be a dependence stall here.
  //The value of t1 is supposed to be bypassed from WB stage.
  //But there is a dpendence stall, the bypassed value won't be pushed into EXE pipeline register.
  //And the t1 value from register file will be in the hold register(this is the wrong value).
  //The value in the hold register will be pushed into EXE pipleline regsiter when the stall disasserted,
  //because the value in WB have been written into the register file, thus no bypass.
  __asm__ __volatile__ ("add s3, t0, t1" );           //0xdd = 0x77 + 0x66  -->ID

  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("nop"  );
  __asm__ __volatile__ ("nop"  );

  //Write back the result
  __asm__ __volatile__ ("sw t4, 0(%0)" : :"r"(dst) );
  __asm__ __volatile__ ("sw t5, 4(%0)" : :"r"(dst) );
  __asm__ __volatile__ ("sw t6, 8(%0)" : :"r"(dst) );
  __asm__ __volatile__ ("sw s2, 12(%0)" : :"r"(dst) );
  __asm__ __volatile__ ("sw s3, 16(%0)" : :"r"(dst) );

}

void bypass_core_test(unsigned int  *input){

    int i, error =0;
    unsigned int * int_output;

    bypass_core( input, bypass_core_output);

    int_output = (unsigned int *) bypass_core_output;
    for( i=0; i<5; i++){
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


