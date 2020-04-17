//This kernel takes a pointer to a location in DRAM, and fills it with an arbitrary value 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_dram_host_allocated(int *addr) {

	*addr = 0x1234;

	barrier.sync();

  return 0;
}
