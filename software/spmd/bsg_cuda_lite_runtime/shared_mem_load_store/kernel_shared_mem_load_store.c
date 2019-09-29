/*!
 * This kernel loads input array into shared memory and stores it back to another location to test the functionality of tile group shared memory and barrier
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);




int  __attribute__ ((noinline)) kernel_shared_mem_load_store(int *A_in, int *A_out, int M, int N, int block_size_y, int block_size_x) {

	if (__bsg_id == 0)
		bsg_print_stat(__bsg_tile_group_id);
	
	// declare tile-group shared memory
	bsg_tile_group_shared_mem (int, sh_A, (block_size_y * block_size_x));


	int start_y = __bsg_tile_group_id_y * block_size_y;
	int start_x = __bsg_tile_group_id_x * block_size_x;

	// Load a (block_size_y * block_size_x) block of A_in into tile_group_shared memory 
	for (int iter_y = __bsg_y; iter_y < block_size_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = __bsg_x; iter_x < block_size_x; iter_x += bsg_tiles_X) { 
			bsg_tile_group_shared_store (int, sh_A, (iter_y * block_size_x + iter_x) , A_in[(start_y + iter_y) * N + (start_x + iter_x)]);
		}
	}


	bsg_tile_group_barrier (&r_barrier, &c_barrier); 

	
	// Store the same (block_size_y * block_size_x) block of shared memory into A_out
	for (int iter_y = __bsg_y; iter_y < block_size_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = __bsg_x; iter_x < block_size_x; iter_x += bsg_tiles_X) { 
			bsg_tile_group_shared_load (int, sh_A, (iter_y * block_size_x + iter_x) , A_out[(start_y + iter_y) * N + (start_x + iter_x)]);
		}
	}


	bsg_tile_group_barrier (&r_barrier, &c_barrier); 

	if (__bsg_id == 0)
		bsg_print_stat(1000 + __bsg_tile_group_id);

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	return 0;
}
