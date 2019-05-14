/*!
 * This kernel performs matrix multiplication 
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_matrix_mul(int *A, int *B, int *C, int n) {

	int thread_count_x = n / (__bsg_grid_dim_x * bsg_tiles_X);
	int thread_count_y = n / (__bsg_grid_dim_y * bsg_tiles_Y);

	int start_y = (__bsg_tile_group_id_y * bsg_tiles_Y + __bsg_y) * block_size_x;
	int start_x = (__bsg_tile_group_id_x * bsg_tiles_X + __bsg_x) * block_size_y;


	for (int iter_y = 0 ; iter_y < thread_count_y; iter_y ++) { 
		for (int iter_x = 0; iter_x < thead_count_x; iter_x ++) { 

			int sum = 0;
			int id_y = start_y + iter_y; 
			int id_x = start_x + iter_x;
			for (int k = 0; k < n; k ++) { 
				sum += A[id_y * n + k] * B[k * n + id_x];
			}
			C[id_y * n + id_x] = res;
		}
	}

	return 0;
}
