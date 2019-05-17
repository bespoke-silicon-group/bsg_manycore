// This kernel declares a tile group shared memory, stores and loads to test the barrier and shared memory functionality 
// If the shared memory does not perform correctly, the test hangs. 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);


int  __attribute__ ((noinline)) kernel_shared_mem (int N) {

	int *sh_arr;
	bsg_tilegroup_int (sh_arr, N); 

	for (int iter_x = __bsg_id; iter_x < N; iter_x += bsg_tiles_X * bsg_tiles_Y) {
		bsg_tilegroup_store(sh_arr, iter_x, iter_x);
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier);

	for (int iter_x = __bsg_id; iter_x < N; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		int val; 
		bsg_tilegroup_load(sh_arr, iter_x, val);
		if (val != iter_x) { 
			while(1);
		}
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

  return 0;
}
