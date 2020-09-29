#include <bsg_manycore.h>
#include "saxpy-cpp.hpp"

/*
 * saxpy_c result: Without bsg_attr_noalias, the compiler cannot guarantee that
 * stores to C do not affect A and B, so load/store instructions are not
 * reordered to overlap loop iterations and hide load latency.
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_c.md
 */
extern "C"
void saxpy_cpp(float  *  A, float  *  B, float *C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
 * saxpy_cpp_noalias: With bsg_attr_noalias, the code "guarantees" that stores to
 * C do not affect A and B so load/store instructions can be reordered because
 * the pointers do not alias.
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp_noalias.md
 *
 */
extern "C"
void saxpy_cpp_noalias(float * bsg_attr_noalias A, float * bsg_attr_noalias B, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}


/*
 * Use caution when applying bsg_attr_noalias to multi-dimensional
 * pointers. In this example LLVM produces worse code than GCC.

 * This is a known issue in LLVM with a patch under review (as of 8/20):
 * Google: restrict support in llvm
 * LLVM Patch: https://reviews.llvm.org/D69542

 * In this example, A is a 2xN_ELS array. We will perform saxpy using
 * A[0] as x and A[1] as y.

 * In saxpy_noalias_A, below, bsg_attr_noalias is only applied to the first
 * dimension of A. The compiler still believes that writes to C affect
 * data in the second dimension of A and cannot reorder instructions.

 * In saxpy_A_noalias, below, bsg_attr_noalias is only applied to the
 * second dimension of A. similar to saxpy_noalias_A, the compiler
 * sill believes that writes to C can affect the pointer in the first
 * dimension of A and cannot reorder instructions

 * bsg_attr_noalias must be applied to each pointer dimension to be
 * inferred correctly.

 * saxpy_noalias_A result: The compiler cannot guarantee that stores
 * to C do not affect the second dimension of A, so loop iterations are
 * not overlapped

 * saxpy_A_noalias result: The compiler cannot guarantee that stores
 * to C do not affect the first dimension of A, so loop iterations are
 * not overlapped

 * saxpy_noalias_noalias result: In LLVM, the compiler does not infer
 * correct aliasing. GCC does (see below)

 * The disassembly and compiler flags are shown in snippets/saxpy_cpp_noalias_A.md, 
 * snippets/saxpy_cpp_A_noalias.md, and snippets/saxpy_cpp_noalias_noalias.md
 */
extern "C"
void saxpy_cpp_noalias_A(float * bsg_attr_noalias * A, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
        }
}

extern "C"
void saxpy_cpp_A_noalias(float ** bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
        }
}

extern "C"
void saxpy_cpp_noalias_noalias(float * bsg_attr_noalias * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
        }
}


/*
 * If multdimensional arrays do not work (above) try flattening the
 * array and using strided accesses. In the example below, A is 2*N_ELS
 * elements long.
 *
 * saxpy_cpp_noalias_flat result: Loads and stores are reordered. If flattening
 * and striding is possible it is more efficient than two independent arrays
 * because the compiler can use immediates to access both arrays and use one
 * index variable.
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp_noalias_flat.md
 *
 */
extern "C"
void saxpy_cpp_noalias_flat(float * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + A[i + N_ELS];
        }
}

/*
 * Care should also be taken when functions could be inlined. In the
 * example below, saxpy_inline calls saxpy_noalias (above), but
 * saxpy_noalias is small enough that it is inlined. 

 * Inlining saxpy_noalias discards bsg_attr_noalias qualifiers. The
 * assembly generated does not reorder loads and stores. 

 * To prevent inlining, use __attribute__ ((noinline)) on functions
 * that you do not want to be inlined (saxpy_noalias in this example)

 * saxpy_cpp_inline result: Inlining discards bsg_attr_noalias qualifiers, if the
 * caller does not have bsg_attr_noalias qualifiers. Loads and stores are not
 * reordered
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp_inline.md
 */
extern "C"
void saxpy_cpp_inline(float * A, float * B, float * C, float alpha) {
        saxpy_cpp_noalias(A, B, C, alpha);
}

/* 
 * bsg_attr_noalias can be inferred through casts. In the following
 * code, we cast a 1-D pointer into a [2][N_ELS] array.  
 *
 * The example below also works in both LLVM and GCC, as long as A has
 * the bsg_attr_noalias qualifier
 *
 * saxpy_cpp_cast result: The compiler keeps the bsg_attr_noalias
 * qualifier through casts. 
 *
 * The disassembly and compiler flags are shown in snippets/saxpy_cpp_cast.md
 */
extern "C"
void saxpy_cpp_cast(float * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha) {
        float (&xy)[2][N_ELS] = *reinterpret_cast<float (*)[2][N_ELS]> (A);
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * xy[0][i] + xy[1][i];
        }
}
