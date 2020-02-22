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



// These symbols are set by the host interface, once a kernel is dispatched to execute on tiles
// Function pointer to the location of kernel in memory
volatile __attribute__((weak)) int32_t cuda_kernel_ptr = 0;
// Argument count of the kernel function
volatile __attribute__((weak)) uint32_t cuda_argc = 0;
 // Pointer to the list of kernel's arguments in memory
volatile __attribute__((weak)) uint32_t cuda_argv_ptr = 0;
 // Location kernel writes it's finish signal into
volatile __attribute__((weak)) uint32_t cuda_finish_signal_addr = 0;
// The value that kernel writes in cuda_finish_signal_addr when it is finished
volatile __attribute__((weak)) uint32_t cuda_finish_signal_val = 0;
// When cuda_kernel_ptr equals this value means the kernel is not loaded
volatile __attribute__((weak)) uint32_t cuda_kernel_not_loaded_val = 0;



//The RISCV ABI Paramters
//The maximum number of parameters passed via regsiter
#define CUDAL_REG_ARGS_NUM      8


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


static int write_finish_signal () 
{
  if (__bsg_id == 0) 
  {
     int *signal_ptr = (int *) cuda_finish_signal_addr; 
     *signal_ptr = cuda_finish_signal_val;     
  }
}




#define __wait_until_valid_func()                                            \
        asm("__wait_until_valid_func:                                        \
               lw         t0           ,    cuda_kernel_not_loaded_val;      \
               la         s0           ,    cuda_kernel_ptr;                 \
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
                lw        t0           ,    cuda_kernel_not_loaded_val;      \
                sw        t0           ,    0 ( s0   );                      \
           ");                                                               \
           write_finish_signal();                                            \
           asm("j         __wait_until_valid_func");



//           bsg_tile_group_barrier(&main_r_barrier, &main_c_barrier);         \

static inline void cuda_tile_group_set_runtime_values(int x, int y)
{
	// set argc
	uint32_t *rmt_argc_ptr =
		(uint32_t*) bsg_remote_ptr(x,y,&cuda_argc);

	*rmt_argc_ptr = cuda_argc;

	// set argv
	uint32_t *rmt_argv_ptr =
		(uint32_t*) bsg_remote_ptr(x,y,&cuda_argv_ptr);

	*rmt_argv_ptr = cuda_argv_ptr;

	// set the finish signal addr
	uint32_t *rmt_finish_signal_addr_ptr =
		(uint32_t*) bsg_remote_ptr(x,y,&cuda_finish_signal_addr);

	*rmt_finish_signal_addr_ptr = cuda_finish_signal_addr;

	asm volatile ( "fence" ::: "memory" );

	// set cuda kernel ptr
	int32_t *rmt_kernel_ptr =
		(int32_t*) bsg_remote_ptr(x,y,&cuda_kernel_ptr);

	*rmt_kernel_ptr = cuda_kernel_ptr;
}


static inline void cuda_tile_group_set_config_values(int x, int y)
{
	// set group org x
	int *grp_org_x_rmt = (int*)bsg_remote_ptr(x,y, &__bsg_grp_org_x);
	*grp_org_x_rmt = __bsg_grp_org_x;

	// set group org y
	int *grp_org_y_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_grp_org_y);
	*grp_org_y_rmt = __bsg_grp_org_y;

	// set coordinate x
	int *x_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_x);
	*x_rmt = x;

	// set coordinate y
	int *y_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_y);
	*y_rmt = y;

	// set id
	int *id_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_id);
	*id_rmt = bsg_x_y_to_id(x,y);

	// set tile group id x
	int *group_id_x_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_tile_group_id_x);
	*group_id_x_rmt = __bsg_tile_group_id_x;

	// set tile group id y
	int *group_id_y_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_tile_group_id_y);
	*group_id_y_rmt = __bsg_tile_group_id_y;

	// set tile group id
	int *group_id_rmt = (int*)bsg_remote_ptr(x,y,&__bsg_tile_group_id);
	*group_id_rmt = __bsg_tile_group_id;

	// set grid dim x
	int *grid_dim_x = (int*)bsg_remote_ptr(x,y,&__bsg_grid_dim_x);
	*grid_dim_x = __bsg_grid_dim_x;

	// set grid dim y
	int *grid_dim_y = (int*)bsg_remote_ptr(x,y,&__bsg_grid_dim_y);
	*grid_dim_y = __bsg_grid_dim_y;


	// set the finish signal value
	uint32_t *rmt_finish_signal_val_ptr =
		(uint32_t*) bsg_remote_ptr(x,y,&cuda_finish_signal_val);

	*rmt_finish_signal_val_ptr = cuda_finish_signal_val;

	/* // set the not loaded value */
	uint32_t *rmt_kernel_not_loaded_val_ptr =
		(uint32_t*) bsg_remote_ptr(x,y,&cuda_kernel_not_loaded_val);

	*rmt_kernel_not_loaded_val_ptr = cuda_kernel_not_loaded_val;

}

static inline void cuda_tile_group_set_values(int x, int y)
{
	// set someone else's stuff
	cuda_tile_group_set_config_values(x, y);
	cuda_tile_group_set_runtime_values(x, y);
}

static inline void cuda_tile_group_row_origin_task(int y)
{
	// set everyone else's stuff in this row
	for (int x = 0; x < bsg_tiles_X; x++) {
		if (__bsg_x == x) continue;
		cuda_tile_group_set_values(x, y);
	}
}

static inline void cuda_tile_group_col_origin_task(int x)
{
	// set everyone else's stuff in this column
	for (int y = 0; y < bsg_tiles_Y; y++) {
		if (__bsg_y == y) continue;
		cuda_tile_group_set_values(x, y);
	}
}

static inline void cuda_tile_group_origin_task()
{
        // set everyone else's stuff
        for (int y = 0; y < bsg_tiles_Y; y++) {
		for (int x = 0; x < bsg_tiles_X; x++) {
			if (__bsg_x == x && __bsg_y == y) continue;
			cuda_tile_group_set_values(x,y);
		}
	}
}

#endif
