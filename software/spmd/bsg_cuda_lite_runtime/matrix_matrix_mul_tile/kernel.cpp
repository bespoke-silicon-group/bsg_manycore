/*!
 * This kernel performs matrix multiplication
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
#include <cstdint>
#include <cstring>

/*
 * This is a naive implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C.
 * A, B, and C are resident in DRAM.
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) kernel_matrix_multiply(TA *A, TB *B, TC *C,
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
 * This is a naive implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C.
 * A, B, and C are resident in DRAM, but are copied into A_local,
 * B_local, and C_local in DMEM prior to computation.
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) kernel_matrix_multiply_dmem(TA *A, TB *B, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        // These arrays are resident in DMEM
        TA A_local[A_HEIGHT * A_WIDTH];
        TB B_local[A_WIDTH * B_WIDTH];
        TC C_local[A_HEIGHT * B_WIDTH];

        memcpy (A_local, A, sizeof(TA)*A_HEIGHT*A_WIDTH);
        memcpy (B_local, B, sizeof(TB)*A_WIDTH*B_WIDTH);

        TC sum;
        for (uint32_t y = 0; y < A_HEIGHT; ++y) {
                for (uint32_t x = 0; x < B_WIDTH; ++x){
                        sum = 0;
                        for (uint32_t k = 0; k < A_WIDTH; k ++) {
                                sum += A_local[y * A_WIDTH + k] * 
                                        B_local[k * B_WIDTH + x];
                        }
                        C_local[y * B_WIDTH + x] = sum;
                }
        }

        memcpy (C, C_local, sizeof(TC)*A_HEIGHT*B_WIDTH);

        return 0;
}

/*
 * This is a slightly-smarter implementation of matrix multiplication
 * that multiplies the two matricies A and B and stores the result in
 * C. In this implementation, B is transposed into BT prior to calling
 * the kernel.
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) kernel_matrix_multiply_transpose(
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
int __attribute__ ((noinline)) kernel_matrix_multiply_transpose_nomul(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        TC sum;
        for (uint32_t y = 0, ayoff = 0, boff = 0, coff = 0; y < A_HEIGHT; ++y) {
                for (uint32_t x = 0; x < B_WIDTH; ++x, ++coff){
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

/*
 * These are type-specific wrappers of the functions above. They are
 * wrapped with an extern "C" declaration to prevent name mangling.
 * 
 * We always run one iteration prior to the measurement iteration to
 * warm the I-Cache
 */
extern "C" {
        int  __attribute__ ((noinline)) kernel_matrix_multiply_dram_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(0);
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(0);
                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dram_int16(
                      int16_t *A, int16_t *B, int16_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(1);
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(1);
                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dram_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(2);
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(2);
                return rc;
        }


        int  __attribute__ ((noinline)) kernel_matrix_multiply_dram_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(3);
                rc = kernel_matrix_multiply(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(3);
                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

                int rc;
                // These arrays are resident in DMEM
                int A_local[A_HEIGHT * A_WIDTH];
                int B_local[A_WIDTH * B_WIDTH];
                int C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply(A_local, B_local, C_local, 
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(4);
                rc = kernel_matrix_multiply(A_local, B_local, C_local, 
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(4);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_int16(
                      int16_t *A, int16_t *B, int16_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int16_t A_local[A_HEIGHT * A_WIDTH];
                int16_t B_local[A_WIDTH * B_WIDTH];
                int16_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply(A_local, B_local, C_local,
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(5);
                rc = kernel_matrix_multiply(A_local, B_local, C_local,
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(5);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int8_t A_local[A_HEIGHT * A_WIDTH];
                int8_t B_local[A_WIDTH * B_WIDTH];
                int8_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply(A_local, B_local, C_local,
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(6);
                rc = kernel_matrix_multiply(A_local, B_local, C_local,
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(6);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }


        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply(A_local, B_local, C_local,
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(7);
                rc = kernel_matrix_multiply(A_local, B_local, C_local,
                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(7);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int A_local[A_HEIGHT * A_WIDTH];
                int B_local[A_WIDTH * B_WIDTH];
                int C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(8);
                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(8);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_int16(
                      int16_t*A, int16_t*B, int16_t*C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int16_t A_local[A_HEIGHT * A_WIDTH];
                int16_t B_local[A_WIDTH * B_WIDTH];
                int16_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(9);
                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(9);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int8_t A_local[A_HEIGHT * A_WIDTH];
                int8_t B_local[A_WIDTH * B_WIDTH];
                int8_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(10);
                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(10);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(11);
                rc = kernel_matrix_multiply_transpose(A_local, B_local, C_local,
                                                      A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(11);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_nomul_int(
                      int *A, int *B, int *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int A_local[A_HEIGHT * A_WIDTH];
                int B_local[A_WIDTH * B_WIDTH];
                int C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(12);
                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(12);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_nomul_int16(
                      int16_t*A, int16_t*B, int16_t*C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int16_t A_local[A_HEIGHT * A_WIDTH];
                int16_t B_local[A_WIDTH * B_WIDTH];
                int16_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(13);
                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(13);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_nomul_int8(
                      int8_t *A, int8_t *B, int8_t *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                int8_t A_local[A_HEIGHT * A_WIDTH];
                int8_t B_local[A_WIDTH * B_WIDTH];
                int8_t C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(14);
                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(14);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }

        int  __attribute__ ((noinline)) kernel_matrix_multiply_dmem_transpose_nomul_float(
                      float *A, float *B, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
                int rc;

                // These arrays are resident in DMEM
                float A_local[A_HEIGHT * A_WIDTH];
                float B_local[A_WIDTH * B_WIDTH];
                float C_local[A_HEIGHT * B_WIDTH];

                memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
                memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_start(15);
                rc = kernel_matrix_multiply_transpose_nomul(A_local, B_local, C_local,
                                                            A_HEIGHT, A_WIDTH, B_WIDTH);
                bsg_cuda_print_stat_end(15);

                memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

                return rc;
        }
}
