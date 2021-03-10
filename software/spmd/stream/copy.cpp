#include <bsg_manycore.h>
#include <bsg_tile_group_barrier.hpp>
#include "config.h"

#define UNROLL 4
extern "C" int stream_copy(bsg_attr_remote float *__restrict A, bsg_attr_remote float *__restrict B, int n, int id, int nids)
{
    for (int i = id * BLOCK_SIZE; i < n; i += BLOCK_SIZE * nids)
    {
        bsg_unroll(32)
        for (int j = 0; j < BLOCK_SIZE; ++j)
        {
            bsg_unroll(32)
            for (int k = 0; k < (BLOCK_SIZE/UNROLL); k++)
            {
                A[i+j+k*UNROLL] = B[i+j+k*UNROLL];
            }
        }
    }

    return 0;
}

extern "C" int cuda_stream_copy(bsg_attr_remote float *__restrict A, bsg_attr_remote float *__restrict B, int n)
{
    bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;
    bsg_cuda_print_stat_kernel_start();
    stream_copy(A, B, n, bsg_id, bsg_tiles_X*bsg_tiles_Y);
    bsg_cuda_print_stat_kernel_end();
    barrier.sync();
    return 0;
}
