//This kernel define an array on the DRAM and fills it, then stores the pointer to that array in *addr and kicks it back to host. 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

#define N 1024

volatile int A[N] __attribute__((section(".dram")));

extern "C" __attribute__ ((noinline))
int kernel_dram_device_allocated(int *addr, int block_size_x) {

	int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x); 
	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		A[start_x + iter_x] = start_x + iter_x;
	}

	*addr = (int) &A[0];

	barrier.sync();

  return 0;
}
