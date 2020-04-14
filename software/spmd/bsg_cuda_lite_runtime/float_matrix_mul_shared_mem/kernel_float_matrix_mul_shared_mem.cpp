/*!
 * This kernel performs tiled matrix multiplication with use of tile-group-shared memory
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

#define BLOCK_WIDTH 4



void __attribute__ ((noinline)) subblock2shmem (float *A, float *sh_dest, int M, int N, int block_size_y, int block_size_x, int sub_block_y, int sub_block_x) { 

	int start_y = sub_block_y * block_size_y;
	int start_x = sub_block_x * block_size_x;
	
	for (int iter_y = __bsg_y; iter_y < block_size_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = __bsg_x; iter_x < block_size_x; iter_x += bsg_tiles_X) { 
			// sh_dest[iter_y][iter_x] <-- A[iter_y + start_y][iter_x + start_x]
			bsg_tile_group_shared_store (float, sh_dest, (iter_y * block_size_x + iter_x), A[((iter_y + start_y) * N + iter_x + start_x)]);
		}
	}
	return; 
}


void __attribute__ ((noinline)) subblock2shmem_xposed (float *A, float *sh_dest, int M, int N, int block_size_y, int block_size_x, int sub_block_y, int sub_block_x) { 

	int start_y = sub_block_y * block_size_y;
	int start_x = sub_block_x * block_size_x;
	
	for (int iter_y = __bsg_y; iter_y < block_size_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = __bsg_x; iter_x < block_size_x; iter_x += bsg_tiles_X) { 
			// sh_dest[iter_x][iter_y] <-- A[iter_y + start_y][iter_x + start_x]
			bsg_tile_group_shared_store (float, sh_dest, (iter_x * block_size_y + iter_y), A[((iter_y + start_y) * N + iter_x + start_x)]);
		}
	}
	return; 
}


void __attribute__ ((noinline)) shmem2subblock (float *A, float *sh_src, int M, int N, int block_size_y, int block_size_x, int sub_block_y, int sub_block_x) { 

	int start_y = sub_block_y * block_size_y;
	int start_x = sub_block_x * block_size_x;
	
	for (int iter_y = __bsg_y; iter_y < block_size_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = __bsg_x; iter_x < block_size_x; iter_x += bsg_tiles_X) { 
			// A[iter_y + start_y][iter_x + start_x] <-- sh_src[iter_y][iter_x]
			bsg_tile_group_shared_load (float, sh_src, (iter_y * block_size_x + iter_x), A[((iter_y + start_y) * N + iter_x + start_x)]);
		}
	}
	return; 
}


void __attribute__ ((noinline)) subblock_shmem_matrix_mul_xposed (float *sh_A, float *sh_B, float *sh_C, int M, int N, int P, int block_size_y, int block_size_x, int block_num) { 

	
	for (int iter_y = __bsg_y; iter_y < block_size_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = __bsg_x; iter_x < block_size_x; iter_x += bsg_tiles_X) { 

			float sum = 0; 
			float lc_A, lc_B;
			for (int k = 0; k < BLOCK_WIDTH; k ++) { 
				// lc_A <-- sh_A[iter_y][iter_x]
				bsg_tile_group_shared_load (float, sh_A, (iter_y * BLOCK_WIDTH + k), lc_A); 
				// lc_B <-- sh_B[iter_y][iter_x]	remember B is transposed
				bsg_tile_group_shared_load (float, sh_B, (iter_x * BLOCK_WIDTH + k), lc_B);
				sum += lc_A * lc_B;
			}

			if (!block_num) { 
				// sh_C[iter_y][iter_x] <-- sum
				bsg_tile_group_shared_store (float, sh_C, (iter_y * block_size_x + iter_x), sum);
			}
			else { 
				float lc_C;
				// sh_C[iter_y][iter_x] += sum
				bsg_tile_group_shared_load (float, sh_C, (iter_y * block_size_x + iter_x), lc_C);
				bsg_tile_group_shared_store (float, sh_C, (iter_y * block_size_x + iter_x), lc_C + sum);
			} 
		}
	}
	return;
}







extern "C" __attribute__ ((noinline))
int kernel_float_matrix_mul_shared_mem(float *A, float *B, float *C, int M, int N, int P, int block_size_y, int block_size_x) {

	
	// declare tile-group shared memory
	bsg_tile_group_shared_mem (float, sh_A, (block_size_y * BLOCK_WIDTH));
	bsg_tile_group_shared_mem (float, sh_B, (BLOCK_WIDTH * block_size_x));
	bsg_tile_group_shared_mem (float, sh_C, (block_size_y * block_size_x));


	int num_blocks = N / BLOCK_WIDTH;	// *** Must divide evenly

	for (int block_num = 0; block_num < num_blocks; block_num ++) { 

		subblock2shmem (       A, sh_A, M, N, block_size_y, BLOCK_WIDTH, __bsg_tile_group_id_y, block_num);
 
		subblock2shmem_xposed (B, sh_B, N, P, BLOCK_WIDTH, block_size_x, block_num, __bsg_tile_group_id_x);

		barrier.sync();
		
		subblock_shmem_matrix_mul_xposed (sh_A, sh_B, sh_C, M, N, P, block_size_y, block_size_x, block_num);
		
		barrier.sync();
	}

	shmem2subblock (C, sh_C, M, P, block_size_y, block_size_x, __bsg_tile_group_id_y, __bsg_tile_group_id_x); 

	barrier.sync();

	return 0;
}
