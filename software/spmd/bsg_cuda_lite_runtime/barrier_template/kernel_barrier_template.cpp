// This kernel performs 16 barriers among all tiles in tile group 
// Uses the new template barrier 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier_template.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" int  __attribute__ ((noinline)) kernel_barrier_template() {

	for (int i = 0; i < 16; i ++) {
	        barrier.sync();
	}

	return 0;
}
