//This is an empty kernel

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

extern "C" __attribute__ ((noinline))
int kernel_dma(int *A, int *B, int n) {

    if (__bsg_id == 0) {
        for (int i = 0; i < n; i++)
            B[i] = A[i];
    }

    return 0;
}
