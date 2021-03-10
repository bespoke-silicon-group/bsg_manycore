#include <bsg_manycore.h>
#include <bsg_set_tile_x_y.h>
#define UNROLL 8
__attribute__((noinline))
int gups(bsg_attr_remote int *__restrict G, int *__restrict A, int n)
{
    for (int i = 0; i < n; i += UNROLL) {
        int g[UNROLL];

        bsg_unroll(32)
        for (int j = 0; j < UNROLL; ++j)
            g[j] = G[A[i+j]] ^ A[i+j];

        bsg_unroll(32)
        for (int j = 0; j < UNROLL; ++j)
            G[A[i+j]] = g[j];
    }

    return 0;
}

#define BLOCK_SIZE 32
__attribute__((noinline))
int cuda_gups(bsg_attr_remote int *__restrict G, bsg_attr_remote int *__restrict A, int n_per_core)
{
    int block_size = n_per_core < BLOCK_SIZE ? n_per_core : BLOCK_SIZE;
    int A_local[block_size];

    for (int i = 0; i < n_per_core; i += block_size) {
        for (int j = 0; j < block_size; j++) {
            A_local[j] = A[bsg_id * n_per_core + i + j];
        }

        gups(G, A_local, block_size);
    }

    return 0;
}
