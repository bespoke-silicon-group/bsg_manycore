#include <bsg_manycore.h>
#include "saxpy-cpp.hpp"

/*
 * saxpy_cpp result: The aggregate blocks of load instructions by reordering past
 * store instructions (noalias), and the load-use distance is large (remote).
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp.md
 *
 */
extern "C"
void saxpy_cpp(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}
