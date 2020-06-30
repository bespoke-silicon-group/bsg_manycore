/*
 * This kernel performs matrix multiplication. 
 * 
 */
// BSG_TILE_GROUP_X_DIM and BSG_TILE_GROUP_Y_DIM must be defined
// before bsg_manycore.h and bsg_tile_group_barrier.h are
// included. bsg_tiles_X and bsg_tiles_Y must also be defined for
// legacy reasons, but they are deprecated.
#include <bsg_manycore.h>
#include <bsg_set_tile_x_y.h>
#include <cstdint>
#include <cstring>

/*
 * This is a naive implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C.
 *
 * NOTE: Compiler is optimizing multiplies for indexing
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) template_kernel_matrix_multiply_noopt(TA *A, TB *B, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
        TC sum;
        for (uint32_t y = 0; y < A_HEIGHT; ++y) {
                for (uint32_t x = 0; x < B_WIDTH; ++x){
                        sum = static_cast<TC>(0);
                        for (uint32_t k = 0; k < A_WIDTH; k ++) {
                                sum += A[y * A_WIDTH + k] * B[k * B_WIDTH + x];
                        }
                        C[y * B_WIDTH + x] = sum;
                }
        }
        return 0;
}

extern "C" int  __attribute__ ((noinline)) kernel_matrix_multiply_noopt(
              float *A, float *B, float *C,
              uint32_t A_HEIGHT, uint32_t A_WIDTH,
              uint32_t B_WIDTH, uint32_t iter) {
        int rc;

        for(int i = 0; i <= iter; ++i){
                rc = template_kernel_matrix_multiply_noopt(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
        }

        return rc;
}

/*
 * This is a slightly-smarter implementation of matrix multiplication
 * that multiplies the two matricies A and B and stores the result in
 * C. In this implementation, B is transposed into BT prior to calling
 * the kernel.
 *
 * NOTE: Compiler is optimizing multiplies for indexing
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) template_kernel_matrix_multiply_transpose(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        TC sum;
        for (uint32_t y = 0; y < A_HEIGHT; ++y) {
                for (uint32_t x = 0; x < B_WIDTH; ++x){
                        sum = static_cast<TC>(0);
                        for (uint32_t k = 0; k < A_WIDTH; ++k) {
                                sum += A[y * A_WIDTH + k] * 
                                        BT[x * A_WIDTH + k];
                        }
                        C[y * B_WIDTH + x] = sum;
                }
        }

        return 0;
}

extern "C" int  __attribute__ ((noinline)) kernel_matrix_multiply_transpose(
              float *A, float *B, float *C,
              uint32_t A_HEIGHT, uint32_t A_WIDTH,
              uint32_t B_WIDTH, uint32_t iter) {
        int rc;

        for(int i = 0; i <= iter; ++i){
                rc = template_kernel_matrix_multiply_transpose(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
        }

        return rc;
}

/*
 * This is a smarter implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C. In
 * this implementation, B is transposed into BT prior to calling the
 * kernel and all multiplies used to index the A, B and
 * C arrays are transformed into additions (nomul).
 */
template <typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) template_kernel_matrix_multiply_transpose_nomul(
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        TC sum;
        for (uint32_t y = 0, ayoff = 0, boff, coff = 0; y < A_HEIGHT; ++y, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x++, coff++){
                        sum = static_cast<TC>(0);
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

extern "C" int  __attribute__ ((noinline)) kernel_matrix_multiply_transpose_nomul(
              float *A, float *B, float *C,
              uint32_t A_HEIGHT, uint32_t A_WIDTH,
              uint32_t B_WIDTH, uint32_t iter) {
        int rc;

        for(int i = 0; i <= iter; ++i){
                rc = template_kernel_matrix_multiply_transpose_nomul(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
        }

        return rc;
}

/*
 * This is a smarter implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C. In
 * this implementation, B is transposed into BT prior to calling the
 * kernel and all multiplies used to index the A, B and C arrays are
 * transformed into additions (nomul). The row-column dot product is
 * unrolled by a factor of F (a template parameter)
 */
template <unsigned int F, typename TA, typename TB, typename TC>
int __attribute__ ((noinline)) template_kernel_matrix_multiply_transpose_nomul_unroll (
                      TA *A, TB *BT, TC *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {

        uint32_t incr = A_WIDTH * (F-1);
        for (uint32_t y = 0, ayoff = 0, boff = 0, coff = 0; y < A_HEIGHT; y ++, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x += F) {
                        uint32_t bofff = 0;
                        TC sum[F] = {{static_cast<TC>(0)}};
                        for (uint32_t aoff = ayoff; aoff < ayoff + A_WIDTH; aoff++, ++boff) {
                                bofff = boff;
#pragma GCC unroll 8 // Does this unroll correctly when F < 4?
                                for (uint32_t f = 0; f < F; ++f, bofff += A_WIDTH){
                                        sum[f] += A[aoff] * BT[bofff];
                                }
                        }

#pragma GCC unroll 8
                        for (uint32_t f = 0; f < F; f++){
                                C[coff + f] = sum[f];
                        }
                        boff += incr;
                        coff += F;
                }
        }
        return 0;
}

extern "C" int  __attribute__ ((noinline)) kernel_matrix_multiply_transpose_nomul_unroll(
              float *A, float *B, float *C,
              uint32_t A_HEIGHT, uint32_t A_WIDTH,
              uint32_t B_WIDTH, uint32_t iter) {
        int rc;

        for(int i = 0; i <= iter; ++i){
                rc = template_kernel_matrix_multiply_transpose_nomul_unroll<8>(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
        }

        return rc;
}

/*
 * This is a smarter implementation of matrix multiplication that
 * multiplies the two matricies A and B and stores the result in C. In
 * this implementation, B is transposed into BT prior to calling the
 * kernel and all multiplies used to index the A, B and C arrays are
 * transformed into additions (nomul). The row-column dot product is
 * unrolled by a factor of F (a template parameter)
 *
 *
 * This implementation differs from above because it avoids an
 * 0-ing/initialization hazard. The Manycore FPU pipeline is a 3-cycle
 * pipeline without hazard forwarding. When registers are initialized,
 * GCC assumes that moves are 1 cycle latency (or have fowarding) so
 * it does an fcvt from x0 to the first floating-point destination
 * register, and then copies that destination register into the other registers.
 *
 * This causes a ton of avoidable dependency stalls. So we use some inline assembly.
 */
template <unsigned int F, typename TA, typename TB>
int __attribute__ ((noinline)) template_kernel_matrix_multiply_transpose_nomul_unroll_init (
                      TA *A, TB *BT, float *C,
                      uint32_t A_HEIGHT, uint32_t A_WIDTH,
                      uint32_t B_WIDTH) {
        uint32_t incr = A_WIDTH * (F-1);
        for (uint32_t y = 0, ayoff = 0, boff = 0, coff = 0; y < A_HEIGHT; y ++, ayoff += A_WIDTH) {
                boff = 0;
                for (uint32_t x = 0; x < B_WIDTH; x += F) {
                        
                        uint32_t bofff = 0;
                        float sum[F];
#pragma GCC unroll 8
                        for (uint32_t f = 0; f < F; ++f){
                                asm volatile ("fmv.s.x %0,zero\n\t" : "=f" (sum[f]));
                        }

                        for (uint32_t aoff = ayoff; aoff < ayoff + A_WIDTH; aoff++, ++boff) {
                                bofff = boff;
#pragma GCC unroll 8
                                for (uint32_t f = 0; f < F; ++f, bofff += A_WIDTH){
                                        sum[f] += A[aoff] * BT[bofff];
                                }
                        }

#pragma GCC unroll 8
                        for (uint32_t f = 0; f < F; f++){
                                C[coff + f] = sum[f];
                        }
                        boff += incr;
                        coff += F;
                }
        }
        return 0;
}

extern "C" int  __attribute__ ((noinline)) kernel_matrix_multiply_transpose_nomul_unroll_init(
              float *A, float *B, float *C,
              uint32_t A_HEIGHT, uint32_t A_WIDTH,
              uint32_t B_WIDTH, uint32_t iter) {
        int rc;

        for(int i = 0; i <= iter; ++i){
                rc = template_kernel_matrix_multiply_transpose_nomul_unroll_init<8>(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH);
        }

        return rc;
}


/**
 * The only difference here, is that the data is copied into DMEM before computation.
 */
extern "C" int  __attribute__ ((noinline)) kernel_matrix_multiply_transpose_nomul_unroll_init_local(
              float *A, float *B, float *C,
              uint32_t A_HEIGHT, uint32_t A_WIDTH,
              uint32_t B_WIDTH, uint32_t iter) {
        int rc;

        // These arrays are resident in DMEM
        float A_local[A_HEIGHT * A_WIDTH];
        float B_local[A_WIDTH * B_WIDTH];
        float C_local[A_HEIGHT * B_WIDTH];

        memcpy (A_local, A, sizeof(A[0])*A_HEIGHT*A_WIDTH);
        memcpy (B_local, B, sizeof(B[0])*A_WIDTH*B_WIDTH);

        bsg_cuda_print_stat_kernel_start();
        for(int i = 0; i <= iter; ++i){
                rc = template_kernel_matrix_multiply_transpose_nomul_unroll_init<8>(A_local, B_local, C_local, A_HEIGHT, A_WIDTH, B_WIDTH);
        }
        bsg_cuda_print_stat_kernel_end();

        memcpy (C, C_local, sizeof(C[0])*A_HEIGHT*B_WIDTH);

        return rc;
}
