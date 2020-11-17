//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_fence_after_stats(float *A, float *B, float *C, int N, int block_size_x) {

  float buf[512];

  for (int iter = 1; iter < 4; iter++) {

    bsg_cuda_print_stat_start(iter);
    bsg_fence();

    int start_x = __bsg_id * block_size_x;
    int buf_offset = 0;
	  for (int idx = start_x; idx < start_x + block_size_x; idx++) {
      buf[buf_offset] = A[idx];
      buf_offset++;
	  }

    bsg_cuda_print_stat_end(iter);
    bsg_fence();

    buf_offset = 0;
	  for (int idx = start_x; idx < start_x + block_size_x; idx++) {
	 	  C[idx] = buf[buf_offset] + B[idx];
      buf_offset++;
	  }

	  barrier.sync();
  }

	return 0;
}
