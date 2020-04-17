// This kernel performs a barrier among all tiles in tile group 
// This kernel uses the deprecated barrier library
// For the replacement, refer to the barrier cuda test

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);


extern "C" __attribute__ ((noinline))
int kernel_barrier_deprecated() {
	for (int i = 0; i < 16; i ++) {
		bsg_tile_group_barrier(&r_barrier, &c_barrier);
	}
	return 0;
}
