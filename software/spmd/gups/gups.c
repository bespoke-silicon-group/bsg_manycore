#include <bsg_manycore.h>

#define UNROLL 16
int gups(bsg_attr_remote int *__restrict G, int *__restrict A, int n)
{
    int k[UNROLL];
    int v[UNROLL];
    for (int i = 0; i < n; i += UNROLL) {
        bsg_unroll(32)
        for (int j = 0; j < UNROLL; ++j) {
            k[j] = A[i+j];
            v[j] = A[k[j]];
        }

        bsg_unroll(32)
        for (int j = 0; j < UNROLL; ++j)
            G[k[j]] = v[j] ^ k[j];
    }
    return 0;
}
