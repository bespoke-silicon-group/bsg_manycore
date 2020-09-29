#include <bsg_manycore.h>
#include "saxpy-c.h"

/*
 * saxpy_c_const result: Const does not produce the same effect as noalias. This
 * is a common misconception. The following code produces the same assembly as
 * saxpy_c.
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_c_const.md
 */
void saxpy_c_const(float const * const A, float const * const B, float * const C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}
