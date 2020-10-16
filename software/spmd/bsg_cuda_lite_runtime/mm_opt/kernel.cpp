//====================================================================
// addmml kernel
// 03/09/2020 Kexin Zheng, Lin Cheng (kz73@cornell.edu, lc873@cornell.edu)
//====================================================================

#define BLOCK_DIM 8 // sqrt(4KB/4 byte/4 data matrix) = 15 max
#include <kernel_common.hpp>
#include <kernel_mm_opt.hpp>

extern "C" __attribute__ ((noinline))
int kernel_mm_opt(
                  hb_tensor_t* _result,
                  hb_tensor_t* _mat1,
                  hb_tensor_t* _mat2) {

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

