//This kernel adds 2 vectors using shared memory, each tile group loads a block into shared memory and performs addition, and stores it back. 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_vec_add_shared_mem(int *A, int *B, int *C, int N, int block_size_x) {

	// Declare tile-group shared memroy with specific size
	bsg_tile_group_shared_mem (int, sh_A, block_size_x);
	bsg_tile_group_shared_mem (int, sh_B, block_size_x); 
	bsg_tile_group_shared_mem (int, sh_C, block_size_x); 


	int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x); 


	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		// Store from DRAM into tile-group shared memory
		bsg_tile_group_shared_store(int, sh_A, iter_x, A[start_x + iter_x]); 
		bsg_tile_group_shared_store(int, sh_B, iter_x, B[start_x + iter_x]); 
		
	}


	barrier.sync();


	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		int lc_A, lc_B;
		// Load from tile group shared memory and store into local variable lc_A & lc_B
		bsg_tile_group_shared_load (int, sh_A, iter_x, lc_A);
		bsg_tile_group_shared_load (int, sh_B, iter_x, lc_B);

		// Store the sum of lc_A and lc_B into tile-group shared memroy sh_C
		bsg_tile_group_shared_store (int, sh_C, iter_x, (lc_A + lc_B));
	}


	barrier.sync();	


	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		// Load from tile-group shared memory lc_C and store the result into DRAM 
		bsg_tile_group_shared_load(int, sh_C, iter_x, C[start_x + iter_x]); 
	}


	barrier.sync();


  return 0;
}
