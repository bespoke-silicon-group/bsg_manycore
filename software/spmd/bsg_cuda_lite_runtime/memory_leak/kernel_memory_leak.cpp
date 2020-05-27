// This is an empty kernel that takes in 8 very large chunks of data
// as input arguments. It is used to check for any memory leaks on the 
// host side.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" int  __attribute__ ((noinline)) kernel_memory_leak(int *A, int *B, int *C, int *D) {

    barrier.sync();
    return 0;
}
