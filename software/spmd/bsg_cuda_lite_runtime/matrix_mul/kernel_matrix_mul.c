/*!
 * This kernel performs matrix multiplication 
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_matrix_mul(int *A, int *B, int *C, int n) {

	int block_size_x = n / (__bsg_grid_dim_x * bsg_tiles_X);
	int block_size_y = n / (__bsg_grid_dim_y * bsg_tiles_Y);

	int start_y = (__bsg_tile_group_id_y * bsg_tiles_Y + __bsg_y) * block_size_y;
	int start_x = (__bsg_tile_group_id_x * bsg_tiles_X + __bsg_x) * block_size_x;


	for (int iter_y = start_y; iter_y < start_y + block_size_y; iter_y ++) { 
		for (int iter_x = start_x; iter_x < start_x + block_size_x; iter_x ++) { 

			int res = 0;
			for (int k = 0; k < n; k ++) { 
				res += A[iter_y * n + k] * B[k * n + iter_x];
			}
			C[iter_y * n + iter_x] = res;
		}
	}

	return 0;
}
