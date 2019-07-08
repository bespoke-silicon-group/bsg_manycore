//This kernel takes a pointer to a location in DRAM, and fills it with an arbitrary value 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int  __attribute__ ((noinline)) kernel_dram_host_allocated(int *addr) {

	*addr = 0x1234;

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

  return 0;
}
