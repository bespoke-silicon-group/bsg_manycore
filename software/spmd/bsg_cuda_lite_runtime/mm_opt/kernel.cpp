//====================================================================
// mm kernel
//
// 03/09/2020 Kexin Zheng
// 06/10/2020 Lin Cheng
//
// This is a "output stationary" SPMD Matrix Multiplication implementation
// To get good performance, we perform three levels of blocking, or tiling
//  - blocking into L2
//  - blocking into scratchpad
//  - blocking into registers
//
// BLOCK_DIM is definted as the block size for "blocking into scratchpad"
//
// Blocing into L2:
//   We spatially distribute the output blocks to minimize per-iteration
//   L2 footprint. Say the output matrix has 4x2 blocks, and we have a
//   2x2 tile group -- then the tile group will work on the left most 4 blocks
//   0* 1* 2  3
//   4* 5* 6  7
//   So each iteration, we load 4 unique data blocks.
//   If we compute another way
//   0* 1* 2* 3*
//   4  5  6  7
//   We need to load 5 unique blocks each iteration.
//
// Blocking into scratchpad:
//   We fully compute a BLOCK_DIM * BLOCK_DIM output block at a time
//   Each iteration, we load one block of matrix A, and one block of Matrix B,
//   then accumulate the result of A * B into partial sum.
//   Since we transfer n^2 data and do n^3 computation, the larger the block,
//   the better the performance.
//
// Blocking into registers:
//   We want to reduce reads and writes to scratchpad, by keep data in the
//   registers for as long as possible. Thus, we block into registers with 4x4
//   sub-blocks
//   For each 4x4 output sub-block, we do the following:
//    - (1) load 4x4(16) partial sum into registers
//    - (2) read 1 element per row, for 4 rows that are relevant
//    - (3) read 1 element per col, for 4 cols that are relevant
//    - (4) perform 16 fmadd
//    - (5) goto step (2) until we reach the end of row/col
//
//          c0    c1    c2    c3
//
//    r0  r0*c0 r0*c1 r0*c2 r0*c3
//
//    r1  r1*c0 r1*c1 r1*c2 r1*c3
//
//    r2  r2*c0 r2*c1 r2*c2 r2*c3
//
//    r3  r3*c0 r3*c1 r3*c2 r3*c3
//
//    We use 16 + 8 = 24 registers in total
//    Refer to compute_block for more details
//====================================================================

#define BLOCK_DIM 8 // sqrt(4KB/4 byte/4 data matrix) = 15 max
#include <kernel_common.hpp>
#include <kernel_mm_opt.hpp>

extern "C" __attribute__ ((noinline))
int kernel_mm_opt(
                  hb_tensor_t* _result,
                  hb_tensor_t* _mat1,
                  hb_tensor_t* _mat2,
                  uint32_t host_block_dim) {

        hb_assert(host_block_dim == BLOCK_DIM);

        auto mat1 = HBTensor<float, 2>(_mat1);
        auto mat2 = HBTensor<float, 2>(_mat2);
        auto result = HBTensor<float, 2>(_result);

        // Start profiling
        bsg_cuda_print_stat_kernel_start();

        int r1 = mat1.dim(0);
        int c1 = mat1.dim(1);
        int r2 = mat2.dim(0);
        int c2 = mat2.dim(1);

        // calculate number of row and col blocks in each matrix
        // padding required
        int m1_num_blk_per_row = r1 / BLOCK_DIM; // how many blocks in m1 per row
        int m1_num_blk_per_col = c1 / BLOCK_DIM; // how many blocks in m1 per col
        int m2_num_blk_per_row = r2 / BLOCK_DIM; // how many blocks in m2 per row
        int m2_num_blk_per_col = c2 / BLOCK_DIM; // how many blocks in m2 per col

        float sp_mat1[BLOCK_DIM * BLOCK_DIM];
        float sp_mat2[BLOCK_DIM * BLOCK_DIM];
        float sp_result[BLOCK_DIM * BLOCK_DIM];

        for (int i = 0; i < m1_num_blk_per_row; i += BSG_TILE_GROUP_Y_DIM) {
                for (int j = 0; j < m2_num_blk_per_col; j += BSG_TILE_GROUP_X_DIM) {
                        int rr = i + __bsg_y;
                        int rc = j + __bsg_x;

                        // initialize scratchpad result (init to 0's)
                        // Unroll by a factor of 16 to minimize control overhead
                        bsg_unroll(16)
                        for (int sp = 0; sp < BLOCK_DIM * BLOCK_DIM; sp += 1) {
                                sp_result[sp] = 0;
                        }

                        // process mat1 and mat2 for this result block
                        // only care about blocks of mat1 in row rr
                        // and blocks of mat2 in col rc
                        for (int mat1x = 0, mat2y = 0; mat1x < m1_num_blk_per_col && mat2y < m2_num_blk_per_row; mat1x++, mat2y++) {
                                dram_to_spad_block(sp_mat1, mat1, rr, mat1x);
                                dram_to_spad_block(sp_mat2, mat2, mat2y, rc);
                                compute_block(sp_result, sp_mat1, sp_mat2);
                        }

                        // copy this block back into DRAM
                        for (int i = 0; i < BLOCK_DIM; i++) {
                                for (int j = 0; j < BLOCK_DIM; j++) {
                                        result(rr * BLOCK_DIM + i, rc * BLOCK_DIM + j) = sp_result[i * BLOCK_DIM + j];
                                }
                        }
                }
        }
        //   End profiling
        bsg_cuda_print_stat_kernel_end();

        g_barrier.sync();
        return 0;
}

