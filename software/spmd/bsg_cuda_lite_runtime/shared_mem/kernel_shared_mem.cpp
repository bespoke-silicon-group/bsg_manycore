// This kernel declares a tile group shared memory, stores and loads to test the barrier and shared memory functionality 
// The test uses two different stripes for storing to shared mem and loading from it. 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier_template.hpp"


extern "C" int  __attribute__ ((noinline)) kernel_shared_mem (int *A, int N) {

	bsg_barrier<2,2> my_barrier (0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

	bsg_tile_group_shared_mem (int, sh_arr, N); 

	for (int iter_x = __bsg_id; iter_x < N; iter_x += bsg_tiles_X * bsg_tiles_Y) {
		bsg_tile_group_shared_store(int, sh_arr, iter_x, iter_x);
	}


	my_barrier.sync();

	int block_size = N / (bsg_tiles_X * bsg_tiles_Y);
	for (int iter_x = __bsg_id * block_size; iter_x < (__bsg_id + 1) * block_size; iter_x ++) { 
		bsg_tile_group_shared_load(int, sh_arr, iter_x, A[iter_x]);
	}

	my_barrier.sync();


  return 0;
}
