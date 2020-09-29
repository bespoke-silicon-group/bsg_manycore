#include <bsg_manycore.h>
#include "saxpy-cpp.hpp"

/*
 * saxpy_cpp result: Without bsg_attr_remote the compiler does not
 * separate the load and use instructions for data because compiler
 * does not have correct latency estimates for loads on A and B.
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp.md
 */
extern "C" 
void saxpy_cpp(float  *A, float  *B, float *C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}
