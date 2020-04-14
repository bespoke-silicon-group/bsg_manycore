//This kernel performs a barrier among all tiles in tile group 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;


extern "C" __attribute__ ((noinline))
int kernel_host_memset() {
	barrier.sync();
	return 0;
}
