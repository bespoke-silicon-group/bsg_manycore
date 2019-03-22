//====================================================================
// bsg_cuda_lite_runtime
// 03/21/2019, shawnless.xie@gmail.com
//====================================================================
// This module is an example of cuda lite runtime.
//
// Any cuda-lite kernels should be linked with this runtime system.
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//This defines the offset of the runtime variables 
#define CUDAL_PARAM_BASE_ADDR   0x1000
#define CUDAL_KERNEL_PTR_IDX    0x0     //function pointer of the kernel function
#define CUDAL_ARGC_IDX          0x4     //argc of the kernel function
#define CUDAL_ARGV_PTR_IDX      0x8     //argv of the kernel function
#define CUDAL_SIG_PTR_IDX       0xC     //the address that a signal will be write back to
                                        //when kernel finish computing.

//The RISCV ABI Paramters
//The maximum number of parameters passed via regsiter
#define CUDAL_REG_ARGS_NUM      8       
#define CUDAL_INVLID_PTR        0x1
#define CUDAL_SIG_VALUE         0x1


//According to RISC-V ABI, the 's' register should be saved by Callee
//and thus will remain their values after calling functions.
#define  ASM_PARAM_PTR      s0
#define  ASM_FUNC_PTR       s1
#define  ASM_ARGC           s2
#define  ASM_ARGV_PTR       s3
#define  ASM_SIG_PTR        s4

#define __bsg_init_param( )                               \
        asm(" li        s0 ,     0x1000;                   \
              lw        s1 ,     0 ( s0 );                 \
              lw        s2 ,     4 ( s0 );                 \
              lw        s3 ,     8 ( s0 );                 \
              lw        s4 ,    12 ( s0 );                 \
            ")

#define __wait_until_valid_func()       \
        asm("__wait_until_valid_func:                            \
             li         t0           ,   0x1;                    \
             lr.w       t1           ,   0  (  s1  );            \
             bne        t0           ,   t1,  __invoke_kernel ;  \
                lr.w.aq    t0           , 0 ( s1   );            \
             __invoke_kernel:                                    \
                lw        a0           ,     0 ( s3  );          \
                lw        a1           ,     4 ( s3  );          \
                lw        a2           ,     8 ( s3  );          \
                lw        a3           ,    12 ( s3  );          \
                lw        a4           ,    16 ( s3  );          \
                lw        a5           ,    20 ( s3  );          \
                lw        a6           ,    24 ( s3  );          \
                lw        a7           ,    28 ( s3  );          \
                jalr      s1;                                    \
                                                                 \
                li         t0           , 0x1;                   \
                sw         t0           , 0 ( s1   )   ;         \
                li         t0           , 0x1;                   \
                sw         t0           , 0 ( s4    )   ;        \
                j                         __wait_until_valid_func; \
           ")
int main()
{
  //declare the function pointer of the kernel

  //set up tile cord and group origins, maybe we can omit these if the loader
  //supports initilization.
  bsg_set_tile_x_y();

  __bsg_init_param( );
  __wait_until_valid_func();

  bsg_finish();
}

