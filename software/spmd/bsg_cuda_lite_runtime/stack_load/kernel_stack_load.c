//This kernel tests to make sure elements loaded through stack are correct
// Kernel takes in 15 elemtns and write the sum into an array -- each tile writes to one element of array

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);


int  __attribute__ ((noinline)) kernel_stack_load(int *sum, int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9, int a10, int a11, int a12, int a13, int a14, int a15) {

	if (__bsg_id == 0)
		bsg_print_stat(__bsg_tile_group_id);

	int res = a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12 + a13 + 14 + a15;
	sum[__bsg_id] = res;
	bsg_tile_group_barrier(&r_barrier, &c_barrier);

	if (__bsg_id == 0)
		bsg_print_stat(1000 + __bsg_tile_group_id);

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	return 0;
}
