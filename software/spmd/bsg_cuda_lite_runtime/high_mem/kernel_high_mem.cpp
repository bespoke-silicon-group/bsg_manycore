#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

extern "C" __attribute__ ((noinline))
int kernel_high_mem(unsigned *A, unsigned *B, int N) {
    for (int i = 0; i < N; ++i) {
        B[i] = A[i];
    }
    return 0;
}
