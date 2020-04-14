
/*!
  Takes a vector A of length N and a 1D filter of size F, padding size P, and stride S.
  Performs 1D convolution of A with the filter and stores the result in a vector B
  of size M = 1 + (N - F + 2P) / S.
*/

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "math.h"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__((noinline))
int kernel_conv1d(const float *A,
                  const int N,
                  const float *filter,
                  const int F,
                  const int P,
                  float *B,
                  const int S,
                  const int block_size)
{
        /*
          Recall the organization of a kernel being executed: Cores are in tilegroups, and tile groups
          are in a grid. Since this is a 1D convolution, we need to flatten everyting to 1D. So we compute
          our tile group index as though it were a 1D grid. Each tile group is responsible for computing
          block_size many elements, so we compute our start index of our tilegroup as simply the product
          of our tile group index and block_size. The end index is consequently start + block_size.
          Since each index in the output vector is independent from the other indices, the tiles
          step through their assigned indices, computung the result.
        */
        const int tile_group_idx = __bsg_grid_dim_x * __bsg_tile_group_id_y + __bsg_tile_group_id_x;
        const int start = tile_group_idx * block_size;
        const int end = start + block_size;
        const int M = 1 + (N - F + 2 * P) / S;
        const int num_cores = bsg_tiles_X * bsg_tiles_Y;
        for(int i = start + __bsg_id; i < end; i += num_cores)
        {
                int window_idx = i * S;
                float res = 0;
                for(int j = 0; j < F; j++)
                {
                        int a_idx = window_idx - P + j;
                        float a = 0;
                        if(0 <= a_idx && a_idx < N)
                                a = A[a_idx];

                        res += filter[j] * a;
                }
                B[i] = res;
        }
        barrier.sync();
        return 0;
}
