// This kernel performs a barrier among all tiles in tile group 
// Uses the new template barrier 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier_template.hpp"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);


extern "C" int  __attribute__ ((noinline)) kernel_barrier_template() {

	bsg_tile_group_barrier(&r_barrier, &c_barrier);

	return 0;
}
