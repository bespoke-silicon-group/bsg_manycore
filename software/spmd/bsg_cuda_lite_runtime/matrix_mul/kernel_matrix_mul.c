/*!
 * This kernel performs matrix multiplication 
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int  __attribute__ ((noinline)) kernel_matrix_mul(int *A, int *B, int *C, int M, int N, int P, int block_size_y, int block_size_x) {


	int start_y = __bsg_tile_group_id_y * block_size_y;
	int start_x = __bsg_tile_group_id_x * block_size_x;
	int end_y = M < (start_y + block_size_y) ? M : (start_y + block_size_y);
	int end_x = P < (start_x + block_size_x) ? P : (start_x + block_size_x);

	for (int iter_y = start_y + __bsg_y; iter_y < end_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = start_x + __bsg_x; iter_x < end_x; iter_x += bsg_tiles_X) { 
			int sum = 0; 
			for (int k = 0; k < N; k ++) { 
				sum += A[iter_y * N + k] * B[k * P + iter_x];
			}
			C[iter_y * P + iter_x] = sum;
		}
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	return 0;
}
