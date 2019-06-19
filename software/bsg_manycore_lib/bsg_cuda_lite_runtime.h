//====================================================================
// bsg_cuda_lite_runtime
// 03/21/2019, shawnless.xie@gmail.com
//====================================================================
// This module is an example of cuda lite runtime.
//
// Any cuda-lite kernels should be linked with this runtime system.


#ifndef BSG_CUDA_LITE_RUNTIME_H_
#define BSG_CUDA_LITE_RUNTIME_H_




#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "stdint.h"

int kernel_regs[4] __attribute__ ((section ("CUDA_RTL"))) = { 0x0 }; 

//This defines the offset of the runtime variables 
#define CUDAL_PARAM_BASE_ADDR   0x1100
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



/*
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(main_r_barrier, main_c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
*/




uint32_t cuda_kernel_ptr = 0;
uint32_t cuda_argc = 0;
uint32_t cuda_argv_ptr = 0; 
uint32_t cuda_finish_signal_addr = 0; 




int write_finish_signal () 
{
  if (__bsg_id == 0) 
  {
     int *signal_ptr = (int *) cuda_finish_signal_addr; 
     *signal_ptr = 0x1;     
  }
}




#define __wait_until_valid_func()                                            \
        asm("__wait_until_valid_func:");                                     \
        bsg_set_tile_x_y();                                                  \
        asm("                                                                \		
               la         s0           ,    cuda_kernel_ptr;                 \
               li         t0           ,    0x1;                             \
               lr.w       t1           ,    0 (  s0  );                      \
               bne        t0           ,    t1        ,     __init_param;    \
               lr.w.aq    t0           ,    0 (  s0  );                      \
                                                                             \
             __init_param:                                                   \
                la        t0           ,    cuda_kernel_ptr;                 \
                lw        s1           ,     0 ( t0  );                      \
                la        t0           ,    cuda_argc;                       \
                lw        s2           ,     0 ( t0  );                      \
                la        t0           ,    cuda_argv_ptr;                   \
                lw        s3           ,     0 ( t0  );                      \
                la        t0           ,    cuda_finish_signal_addr;         \
                lw        s4           ,     0 ( t0  );                      \
                                                                             \
                                                                             \
             __load_argument:                                                \
                lw        a0           ,     0 ( s3  );                      \
                lw        a1           ,     4 ( s3  );                      \
                lw        a2           ,     8 ( s3  );                      \
                lw        a3           ,    12 ( s3  );                      \
                lw        a4           ,    16 ( s3  );                      \
                lw        a5           ,    20 ( s3  );                      \
                lw        a6           ,    24 ( s3  );                      \
                lw        a7           ,    28 ( s3  );                      \
                                                                             \
                li        t0           ,    0x8;                             \
                bge       t0           ,    s2        ,     __invoke_kernel; \
                                                                             \
                addi      t0           ,    s2        ,     -0x8;            \
                slli      t0           ,    t0        ,     0x2;             \
                sub       sp           ,    sp        ,     t0;              \
                li        t0           ,    0x8;                             \
                li        t1           ,    0x20;                            \
                li        t3           ,    0x0;                             \
                                                                             \
              __load_stack:                                                  \
                add       t2           ,    t1        ,     s3;              \
                lw        t4           ,    0 (t2);                          \
                add       t5           ,    t3        ,     sp;              \
                sw        t4           ,    0 (t5);                          \
                addi      t0           ,    t0        ,     0x1;             \
                addi      t1           ,    t1        ,     0x4;             \
                addi      t3           ,    t3        ,     0x4;             \
                blt       t0           ,    s2        ,     __load_stack;    \
                                                                             \
              __invoke_kernel:                                               \
                jalr      s1");                                              \
                                                                             \
           asm("li        t0           ,    0x8;                             \
                bge       t0           ,    s2        ,     __kernel_return; \
                addi      t0           ,    s2        ,     -0x8;            \
                slli      t0           ,    t0        ,     0x2;             \
                add       sp           ,    sp        ,     t0;              \
                                                                             \
             __kernel_return:                                                \
                li        t0           ,    0x1;                             \
                sw        t0           ,    0 ( s0   );                      \
           ");                                                               \
           write_finish_signal();                                            \
           asm("j         __wait_until_valid_func");



//           bsg_tile_group_barrier(&main_r_barrier, &main_c_barrier);         \


#endif
