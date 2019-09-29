/*!
 * This kernel performs max pool 2d 
 * Takes in a MxN matrix and stores the maximum of each sub matrix
 * Inside one element in the PxW result matrix
 * M and N should divide evenly by P and W, respectively.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int  __attribute__ ((noinline)) kernel_max_pool2d(int *A, int *B, int M, int N, int P, int W, int block_size_y, int block_size_x) {

	if (__bsg_id == 0)
		bsg_print_stat(__bsg_tile_group_id);

	int sub_block_y = M / P; // Should divide evenly	
	int sub_block_x = N / W; // Should divide evenly	
	int start_y = __bsg_tile_group_id_y * block_size_y;
	int start_x = __bsg_tile_group_id_x * block_size_x;
	int end_y = start_y + block_size_y;
	int end_x = start_x + block_size_x;

	for (int iter_y = start_y + __bsg_y; iter_y < end_y; iter_y += bsg_tiles_Y) { 
		for (int iter_x = start_x + __bsg_x; iter_x < end_x; iter_x += bsg_tiles_X) { 

			int src_start_y = iter_y * sub_block_y;
			int src_start_x = iter_x * sub_block_x;
			int src_end_y = src_start_y + sub_block_y;
			int src_end_x = src_start_x + sub_block_x;
		
			int sub_max = A[src_start_y * N + src_start_x]; 

			for (int y = src_start_y; y < src_end_y; y ++) { 
				for (int x = src_start_x; x < src_end_x; x ++) { 
					if (A[y * N + x] > sub_max) { 
						sub_max = A[y * N + x];
					}
				}
			}

			B[iter_y * W + iter_x] = sub_max;
		}
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	if (__bsg_id == 0)
		bsg_print_stat(1000 + __bsg_tile_group_id);

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	return 0;
}
