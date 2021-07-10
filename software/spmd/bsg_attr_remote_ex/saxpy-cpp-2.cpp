#include <bsg_manycore.h>
#include "saxpy-cpp.hpp"

/*
 * saxpy_cpp_remote result: The aggregates blocks of load instructions
 * far from their use site but cannot reorder them to create larger
 * blocks because it cannot determine if writes to C affect data in A
 * and B (i.e. that the pointers do not alias)
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp_remote.md
 */
extern "C"
void saxpy_cpp_remote(float bsg_attr_remote * A, float bsg_attr_remote * B, float bsg_attr_remote * C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}
