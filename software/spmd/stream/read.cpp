#include <bsg_manycore.h>
#include <bsg_set_tile_x_y.h>
#include <bsg_tile_group_barrier.hpp>
#include "config.h"

#define UNROLL 4

extern "C" int stream_read(bsg_attr_remote float *__restrict A, int n, int id, int nids)
{
    float tmp[UNROLL];

    for (int i = id * BLOCK_SIZE; i < n; i += BLOCK_SIZE * nids)
    {
        bsg_unroll(32)
        for (int j = 0; j < (BLOCK_SIZE/UNROLL); ++j)
        {
            bsg_unroll(32)
            for (int k = 0; k < UNROLL; ++k)
            {
                tmp[k] += A[i+j+k*UNROLL];
            }
        }
    }

    float r = 0.0;
    for (int i = 0; i < UNROLL; ++i)
        r += tmp[i];

    return r;
}


extern "C" int cuda_stream_read(bsg_attr_remote float *__restrict A, int n)
{
    bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;
    bsg_cuda_print_stat_kernel_start();
    int r = stream_read(A, n, bsg_id, bsg_tiles_X*bsg_tiles_Y);
    bsg_cuda_print_stat_kernel_end();
    barrier.sync();
    return r;
}
