//This kernel tests to make sure elements loaded through stack are correct
// Kernel takes in 15 elemtns and write the sum into an array -- each tile writes to one element of array

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_stack_load(int *sum, int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9, int a10, int a11, int a12, int a13, int a14, int a15) {

	int res = a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12 + a13 + a14 + a15;
	sum[__bsg_id] = res;
        barrier.sync();
	return 0;
}
