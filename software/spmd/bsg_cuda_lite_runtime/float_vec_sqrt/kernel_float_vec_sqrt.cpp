//This kernel stores the square root of the elements in the first vector into the second  

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "math.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;


extern "C" __attribute__ ((noinline))
int kernel_float_vec_sqrt(float *A, float *B, int N, int block_size_x) {

	int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x); 
	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) { 
		B[start_x + iter_x] = sqrtf(A[start_x + iter_x]);
	}

	barrier.sync();

  return 0;
}
