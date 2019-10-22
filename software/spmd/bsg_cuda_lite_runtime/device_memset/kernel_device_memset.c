// This kernel performs a memset on an array in DRAM 
// With the given size (in words) and value

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);



int  __attribute__ ((noinline)) kernel_device_memset(int *dst, const int val, const int size) {

	int __bsg_tile_group_id = (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
	int __bsg_tile_group_size = (bsg_tiles_X * bsg_tiles_Y);
	int block_size_x = size / (__bsg_grid_dim_y * __bsg_grid_dim_x);
	
	int start_x = block_size_x * __bsg_tile_group_id;
	int end_x = start_x + block_size_x;

	for (int iter_x = start_x + __bsg_id; iter_x < end_x; iter_x += __bsg_tile_group_size) {
		dst[iter_x] = val;
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

  return 0;
}
