#include <bsg_manycore.h>
#include "saxpy-c.h"

/*
 * saxpy_c result: Without bsg_attr_remote the compiler does not
 * separate the load and use instructions for data because compiler
 * does not have correct latency estimates for loads on A and B.
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_c.md
 */
void saxpy_c(float  *A, float  *B, float *C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                 C[i] = alpha * A[i] + B[i];
        }
}

/*
 * saxpy_c_remote result: The aggregates blocks of load instructions
 * far from their use site but cannot reorder them to create larger
 * blocks because it cannot determine if writes to C affect data in A
 * and B (i.e. that the pointers do not alias)
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_c_remote.md
 */
void saxpy_c_remote(float bsg_attr_remote * A, float bsg_attr_remote * B, float bsg_attr_remote * C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                 C[i] = alpha * A[i] + B[i];
        }
}

