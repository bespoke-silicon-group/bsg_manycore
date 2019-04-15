//====================================================================
// bsg_cuda_lite_runtime
// 03/21/2019, shawnless.xie@gmail.com
//====================================================================
// This module is an example of cuda lite runtime.
//
// Any cuda-lite kernels should be linked with this runtime system.
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int kernel_regs[4] __attribute__ ((section ("CUDA_RTL"))) = { 0x0 }; 

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



/*
#define BARRIER_X_START     0
#define BARRIER_Y_START     0

#define BARRIER_X_END     (BARRIER_X_START + bsg_tiles_X - 1)
#define BARRIER_Y_END     (BARRIER_Y_START + bsg_tiles_Y - 1)
#define BARRIER_X_NUM     (BARRIER_X_END - BARRIER_X_START +1) 
#define BARRIER_Y_NUM     (BARRIER_Y_END - BARRIER_Y_START +1) 
#define BARRIER_TILES     (BARRIER_X_NUM * BARRIER_Y_NUM)

#define  BSG_BARRIER_DEBUG    1
#define  BSG_TILE_GROUP_X_DIM BARRIER_X_NUM
#define  BSG_TILE_GROUP_Y_DIM BARRIER_Y_NUM
#define  BSG_TILE_GROUP_Z_DIM 1
#define  BSG_TILE_GROUP_SIZE  (BSG_TILE_GROUP_X_DIM * BSG_TILE_GROUP_Y_DIM)
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER (row_barrier_inst1, col_barrier_inst1, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);
*/




/********************************************************************************************************
// This version (loading excess arguments from stack + barrier) is currently
// not functional due to hardware bug in basejump_stl. Comming soon...
#define __wait_until_valid_func()                                            \
        asm("__wait_until_valid_func:                                        \
               li         s0           ,    0x1000;                          \
               li         t0           ,    0x1;                             \
               lr.w       t1           ,    0 (  s0  );                      \
               bne        t0           ,    t1        ,     __init_param;    \
               lr.w.aq    t0           ,    0 (  s0  );                      \
                                                                             \
             __init_param:                                                   \
                lw        s1           ,     0 ( s0  );                      \
                lw        s2           ,     4 ( s0  );                      \
                lw        s3           ,     8 ( s0  );                      \
                lw        s4           ,    12 ( s0  );                      \
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
                jalr      s1;                                                \
                li        t0           ,    0x8;                             \
                bge       t0           ,    s2        ,     __kernel_return; \
                addi      t0           ,    s2        ,     -0x8;            \
                slli      t0           ,    t0        ,     0x2;             \
                add       sp           ,    sp        ,     t0;              \
              __kernel_return:                                               \
            ");                                                              \
                                                                             \
        bsg_tile_group_barrier(&row_barrier_inst1, &col_barrier_inst1);      \
                                                                             \
        asm("                                                                \
                li        t0           ,    0x1;                             \
                sw        t0           ,    0 ( s1   );                      \
                li        t0           ,    0x1;                             \
                sw        t0           ,    0 ( s4    );                     \
                j         __wait_until_valid_func;                           \
           ");
********************************************************************************************************/


int write_signal () 
{
  if (__bsg_x == 0 && __bsg_y == 0) 
  {
    int **signal_reg = (int **) 0x100c;
    int *signal_ptr = *signal_reg;
    *signal_ptr = 0x1; /* arbitrary */
  }
}


#define __wait_until_valid_func()                                            \
        asm("__wait_until_valid_func:                                        \
               li         s0           ,    0x1000;                          \
               li         t0           ,    0x1;                             \
               lr.w       t1           ,    0 (  s0  );                      \
               bne        t0           ,    t1        ,     __init_param;    \
               lr.w.aq    t0           ,    0 (  s0  );                      \
                                                                             \
             __init_param:                                                   \
                lw        s1           ,     0 ( s0  );                      \
                lw        s2           ,     4 ( s0  );                      \
                lw        s3           ,     8 ( s0  );                      \
                lw        s4           ,    12 ( s0  );                      \
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
              __invoke_kernel:                                               \
                jalr      s1;                                                \
                                                                             \
              __kernel_return:                                               \
                li        t0           ,    0x1;                             \
                sw        t0           ,    0 ( s0   );                      \
           ");                                                               \
           write_signal();                                                   \
           asm("j         __wait_until_valid_func");


int main()
{
  //declare the function pointer of the kernel

  //set up tile cord and group origins, maybe we can omit these if the loader
  //supports initilization.
  bsg_set_tile_x_y();

  __wait_until_valid_func();

  // bsg_finish();
}

