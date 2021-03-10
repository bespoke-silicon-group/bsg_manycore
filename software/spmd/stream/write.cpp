#include <bsg_manycore.h>
#include <bsg_tile_group_barrier.hpp>
#include "config.h"

extern "C" int stream_write(bsg_attr_remote float *__restrict A, int n, int id, int nids)
{
    for (int i = id * BLOCK_SIZE; i < n; i += BLOCK_SIZE * nids)
    {
        bsg_unroll(32)
        for (int j = 0; j < BLOCK_SIZE; ++j)
        {
            A[i+j] = 1.0;
        }
    }

    return 0;
}

extern "C" int cuda_stream_write(bsg_attr_remote float *__restrict A, int n)
{
    bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;
    bsg_cuda_print_stat_kernel_start();
    stream_write(A, n, bsg_id, bsg_tiles_X*bsg_tiles_Y);
    bsg_cuda_print_stat_kernel_end();
    barrier.sync();
    return 0;
}
