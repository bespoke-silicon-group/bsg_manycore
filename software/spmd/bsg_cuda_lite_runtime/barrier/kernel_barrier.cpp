// This kernel performs 16 barriers among all tiles in tile group 
// Uses the new template barrier library 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" int  __attribute__ ((noinline)) kernel_barrier() {

	for (int i = 0; i < 16; i ++) {
	        barrier.sync();
	}

	return 0;
}
