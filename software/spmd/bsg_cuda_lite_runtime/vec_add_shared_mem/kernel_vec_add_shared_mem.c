//This kernel adds 2 vectors using shared memory, each tile group loads a block into shared memory and performs addition, and stores it back. 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);



int  __attribute__ ((noinline)) kernel_vec_add_shared_mem(int *A, int *B, int *C, int N, int block_size_x) {

	// Declare tile-group shared memroy with specific size

	// *** For now, declaration of tile-group shared memory is done by hand, as the macro is faulty. TODO: Fix *** 
//	int *sh_A, *sh_B, *sh_C;
//	bsg_tilegroup_int (sh_A, block_size_x);
//	bsg_tilegroup_int (sh_B, block_size_x); 
//	bsg_tilegroup_int (sh_C, block_size_x); 


	int sh_A[block_size_x / (bsg_tiles_X * bsg_tiles_Y)];
	int sh_B[block_size_x / (bsg_tiles_X * bsg_tiles_Y)];
	int sh_C[block_size_x / (bsg_tiles_X * bsg_tiles_Y)];



	int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x); 


	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		// Store from DRAM into tile-group shared memory
		bsg_tilegroup_store(sh_A, iter_x, A[start_x + iter_x]); 
		bsg_tilegroup_store(sh_B, iter_x, B[start_x + iter_x]); 
		
	}


	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		int lc_A, lc_B;
		// Load from tile group shared memory and store into local variable lc_A & lc_B
		bsg_tilegroup_load (sh_A, iter_x, lc_A);
		bsg_tilegroup_load (sh_B, iter_x, lc_B);

		// Store the sum of lc_A and lc_B into tile-group shared memroy sh_C
		bsg_tilegroup_store (sh_C, iter_x, (lc_A + lc_B));
	}

	
	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		// Load from tile-group shared memory lc_C and store the result into DRAM 
		bsg_tilegroup_load(sh_C, iter_x, C[start_x + iter_x]); 
	}


	bsg_tile_group_barrier(&r_barrier, &c_barrier);


  return 0;
}
