// This kernel performs a barrier among all tiles in tile group 
// Uses the new template barrier 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier_template.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> my_barrier;

extern "C" int  __attribute__ ((noinline)) kernel_barrier_template() {

	for (int i = 0; i < 16; i ++) {
	        my_barrier.sync();
	}

	return 0;
}
