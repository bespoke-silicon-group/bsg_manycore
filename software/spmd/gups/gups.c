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


