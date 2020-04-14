// This kernel performs a memcpy from arrya src to 
// array dst in DRAM with the given size (in words)

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline)) 
int kernel_device_memcpy(int *dst, const int *src, const int size) {

	int __bsg_tile_group_id = (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
	int __bsg_tile_group_size = (bsg_tiles_X * bsg_tiles_Y);
	int block_size_x = size / (__bsg_grid_dim_y * __bsg_grid_dim_x);
	
	int start_x = block_size_x * __bsg_tile_group_id;
	int end_x = start_x + block_size_x;

	for (int iter_x = start_x + __bsg_id; iter_x < end_x; iter_x += __bsg_tile_group_size) {
		dst[iter_x] = src[iter_x];
	}

	barrier.sync();

  return 0;
}
