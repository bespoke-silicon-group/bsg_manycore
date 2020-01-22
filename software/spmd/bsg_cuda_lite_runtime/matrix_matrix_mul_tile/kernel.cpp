/*!
 * This kernel performs matrix multiplication
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#define IGNORE_TAG 0
#include "bsg_tile_group_barrier.h"
#include <cstdint>
#include <cstring>
#include <bsg_algebra.hpp>

#ifndef BSG_ALGEBRA_HPP
/*
 * This is a naive implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C.
 * A, B, and C are resident in DRAM.
 *
 * NOTE: Compiler is optimizing multiplies for indexing
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline, aligned (2048))) kernel_matrix_multiply(TA *A, TB *B, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
        TC sum;
        for (uint32_t y = 0; y < A_HEIGHT; ++y) {
                for (uint32_t x = 0; x < B_WIDTH; ++x){
                        sum = 0;
                        for (uint32_t k = 0; k < A_WIDTH; k ++) {
                                sum += A[y * A_WIDTH + k] * B[k * B_WIDTH + x];
                        }
                        C[y * B_WIDTH + x] = sum;
                }
        }
        return 0;
}

/*
 * This is a slightly-smarter implementation of matrix multiplication
 * that multiplies the two matricies A and B and stores the result in
 * C. In this implementation, B is transposed into BT prior to calling
 * the kernel.
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline, aligned (2048))) kernel_matrix_multiply_transpose(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        TC sum;
        for (uint32_t y = 0; y < A_HEIGHT; ++y) {
                for (uint32_t x = 0; x < B_WIDTH; ++x){
                        sum = 0;
                        for (uint32_t k = 0; k < A_WIDTH; ++k) {
                                sum += A[y * A_WIDTH + k] * 
                                        BT[x * A_WIDTH + k];
                        }
                        C[y * B_WIDTH + x] = sum;
                }
        }

        return 0;
}

/*
 * This is a smarter implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C. In
 * this implementation, B is transposed into BT prior to calling the
 * kernel and all multiplies used to index the A, B and
 * C arrays are transformed into additions (nomul).
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline, aligned (2048))) kernel_matrix_multiply_transpose_nomul(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        TC sum;
        for (uint32_t y = 0, ayoff = 0, boff, coff = 0; y < A_HEIGHT; ++y, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x++, coff++){
                        sum = 0;
                        for (uint32_t aoff = ayoff; 
                             aoff < ayoff + A_WIDTH; 
                             ++aoff, ++boff) {
                                sum += A[aoff] * BT[boff];
                        }
                        C[coff] = sum;
                }
        }

        return 0;
}


template <unsigned int F, typename TA, typename TB, typename TC>
int __attribute__ ((noinline, aligned (2048))) kernel_matrix_multiply_transpose_nomul_unroll (
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        uint32_t incr = A_WIDTH * (F-1);
        for (uint32_t y = 0, ayoff = 0, boff = 0, coff = 0; y < A_HEIGHT; y ++, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x += F) {
                        uint32_t bofff = 0;
                        TC sum[F] = {0};
                        for (uint32_t aoff = ayoff; aoff < ayoff + A_WIDTH; aoff++, ++boff) {
                                bofff = boff;
#pragma GCC unroll 4 // Does this unroll correctly when F < 4?
                                for (uint32_t f = 0; f < F; ++f, bofff += A_WIDTH){
                                        sum[f] += A[aoff] * BT[bofff];
                                }
                        }

#pragma GCC unroll 4
                        for (uint32_t f = 0; f < F; f++){
                                C[coff + f] = sum[f];
                        }
                        boff += incr;
                        coff += F;
                }
        }
        return 0;
}

#endif //BSG_ALGERBA_HPP
/*
 * These versions are hand-unrolled
 * 
 * 
 * 
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline, aligned (2048))) kernel_matrix_multiply_transpose_nomul_unroll_hand_2(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
        static const int F = 2;

        for (uint32_t y = 0, ayoff = 0, boff = 0, coff = 0; y < A_HEIGHT; y ++, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x +=F) {
                        TC sum[F] = {0};
                        for (uint32_t aoff = ayoff; aoff < ayoff + A_WIDTH; aoff++, boff++) {
                                sum[0] += A[aoff] * BT[boff + 0];
                                sum[1] += A[aoff] * BT[boff + A_WIDTH];
                        }
                        C[coff + 0] = sum[0];
                        C[coff + 1] = sum[1];
                        boff += A_WIDTH;
                        coff += F;
                }
        }

        return 0;
}

asm(".align 0; .space 2048");
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline, aligned(2048))) kernel_matrix_multiply_transpose_nomul_unroll_hand_4(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
        static const unsigned int F = 4;
        unsigned int incr = (F-1)*A_WIDTH;
        for (uint32_t y = 0, ayoff = 0, boff = 0, coff = 0; y < A_HEIGHT; y ++, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x +=F) {
                        TC sum[F] = {0};
                        for (uint32_t aoff = ayoff; aoff < ayoff + A_WIDTH; aoff++, boff++) {
                                sum[0] += A[aoff] * BT[boff + 0];
                                sum[1] += A[aoff] * BT[boff + A_WIDTH ];
                                sum[2] += A[aoff] * BT[boff + A_WIDTH + A_WIDTH];
                                sum[3] += A[aoff] * BT[boff + A_WIDTH + A_WIDTH + A_WIDTH];
                        }
                        C[coff + 0] = sum[0];
                        C[coff + 1] = sum[1];
                        C[coff + 2] = sum[2];
                        C[coff + 3] = sum[3];
                        boff += incr;
                        coff += F;
                }
        }

        return 0;
}


/*
 * These are type-specific wrappers of the functions above. They are
 * wrapped with an extern "C" declaration to prevent name mangling.
 * 
 * We always run one iteration prior to the measurement iteration to
 * warm the I-Cache
 */
extern "C" {
        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dram_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dram_int16(
                      int16_t *A, int16_t *B, int16_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dram_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                return rc;
        }


        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dram_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {

                int rc, temp = IGNORE_TAG;
                // These arrays are resident in DMEM
                int A_local[A_HEIGHT * A_WIDTH];
                int B_local[A_WIDTH * B_WIDTH];
                int C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_int16(
                      int16_t *A, int16_t *B, int16_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int16_t A_local[A_HEIGHT * A_WIDTH];
                int16_t B_local[A_WIDTH * B_WIDTH];
                int16_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int8_t A_local[A_HEIGHT * A_WIDTH];
                int8_t B_local[A_WIDTH * B_WIDTH];
                int8_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }


        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int A_local[A_HEIGHT * A_WIDTH];
                int B_local[A_WIDTH * B_WIDTH];
                int C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_int16(
                      int16_t*A, int16_t*B, int16_t*C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int16_t A_local[A_HEIGHT * A_WIDTH];
                int16_t B_local[A_WIDTH * B_WIDTH];
                int16_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int8_t A_local[A_HEIGHT * A_WIDTH];
                int8_t B_local[A_WIDTH * B_WIDTH];
                int8_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int A_local[A_HEIGHT * A_WIDTH];
                int B_local[A_WIDTH * B_WIDTH];
                int C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_int16(
                      int16_t*A, int16_t*B, int16_t*C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int16_t A_local[A_HEIGHT * A_WIDTH];
                int16_t B_local[A_WIDTH * B_WIDTH];
                int16_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                int8_t A_local[A_HEIGHT * A_WIDTH];
                int8_t B_local[A_WIDTH * B_WIDTH];
                int8_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_unroll_hand_2_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul_unroll_hand_2(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

       int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_unroll_hand_4_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul_unroll_hand_4(A_local, B_local, C_local,
                                                                                  A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_unroll2_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul_unroll<2>(A_local, B_local, C_local,
                                                                              A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline, aligned (4096))) kernel_matrix_multiply_dmem_transpose_nomul_unroll4_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH, uint32_t tag, uint32_t iter) {
                int rc, temp = IGNORE_TAG;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                for(int i = 0; i <= iter; ++i){
                        bsg_cuda_print_stat_start(temp);
                        rc = kernel_matrix_multiply_transpose_nomul_unroll<4>(A_local, B_local, C_local,
                                                                              A_HEIGHT, A_WIDTH, B_WIDTH);
                        bsg_cuda_print_stat_end(temp);
                        temp = tag;
                }

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }
}
