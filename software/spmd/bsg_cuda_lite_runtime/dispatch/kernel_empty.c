//This is an empty kernel
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_cuda_lite_runtime.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y

#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X - 1, 0, bsg_tiles_Y - 1);

//#define HOST_DISPATCH
#ifndef HOST_DISPATCH
#define ORIGIN_ONLY
#endif

int kernel_dispatch() {

    volatile unsigned long *ptr = (volatile unsigned long*) bsg_remote_ptr_io(IO_X_INDEX, 0xFFF0);
    *ptr = 1;

#ifndef HOST_DISPATCH    
#ifdef  ORIGIN_ONLY
    /* origin wakes everyone else up */
    if (__bsg_id == 0) cuda_tile_group_origin_task();
#else
    /* origin wakes each row */
    if (__bsg_id == 0) cuda_tile_group_col_origin_task(__bsg_x);
    /* first column in each row wakes the rest of the row */
    if (__bsg_x  == 0) cuda_tile_group_row_origin_task(__bsg_y);
#endif
#endif
    
    bsg_tile_group_barrier(&r_barrier, &c_barrier);

    return 0;
}
