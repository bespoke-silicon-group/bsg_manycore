//====================================================================
// addmml kernel
// 03/09/2020 Kexin Zheng, Lin Cheng (kz73@cornell.edu, lc873@cornell.edu)
//====================================================================

#define BLOCK_DIM 8 // sqrt(4KB/4 byte/4 data matrix) = 15 max
#include <kernel_common.hpp>
#include <kernel_mm_opt.hpp>

template<unsigned int BX, unsigned int BY, bool LOAD_M1_TRANSPOSED>
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
        //hb_assert(c1 == r2);

        // TODO: Assertions if block dimensions are non-sensical W.R.T
        // input dimensions (should be divisible)

        // BX is the X-dimension of the sub-block
        // BY is the Y-dimension of the sub-block
        // _mat1 is a r1 x c1 matrix
        // _mat2 is a r2 x c2 matrix
        // c1 == r2
        // c1 % BX == 0, r2 % BX == 0
        // c2 % BY == 0, r1 % BY == 0

        // Compute the number of blocks, the loop bound of the
        // inner-loop.
        int blocks = c1 / BX; // r2 / BX

        // Local Storage Blocks
        float block_row[BY * BX];
        float block_col[BX * BY];

        float psum[BY * BX];

        // Iterate through available output blocks in the X and Y
        // dimensions. Jump by the tile group size between iterations
        // to assign unique work.
        // Yes, this should be TGID
        for (int by_i = __bsg_y; by_i < r1/BY; by_i += BSG_TILE_GROUP_Y_DIM) {
                for (int bx_i = __bsg_x; bx_i < c2/BX; bx_i += BSG_TILE_GROUP_X_DIM) {
                        // Initialize the scratchpad for this particular sub-block
                        // Unroll by a factor of 16 to minimize control overhead
                        bsg_unroll(16)
                        for (int i = 0; i < BY * BX; ++i){
                               psum[i] = 0;
                        }

                        // Multiply the blocks, and accumulate into the result
                        for (int bz_i = 0; bz_i < blocks; bz_i++) {
                                load_block<BY, BX, LOAD_M1_TRANSPOSED>(block_row, mat1, by_i, bz_i);
                                load_block<BY, BX, false>(block_col, mat2, bz_i, bx_i);
                                accum_block<BY, BY/2, BX, BX/2, LOAD_M1_TRANSPOSED>(psum, block_row, block_col);
                        }

                        // Copy this block back into DRAM
                        // TODO: Create store_block method for unrolling. 
                        for (int sby_i = 0; sby_i < BY; ++sby_i) {
                                for (int sbx_i = 0; sbx_i < BX; ++sbx_i) {
                                       result(by_i * BY + sby_i, bx_i * BX + sbx_i) = psum[sby_i * BX + sbx_i];
                                }
                        }
                }
        }
        //   End profiling
        bsg_cuda_print_stat_kernel_end();

        g_barrier.sync();
        return 0;
}

extern "C"
int kernel_mm_opt_8x8(
                  hb_tensor_t* _result,
                  hb_tensor_t* _mat1,
                  hb_tensor_t* _mat2) {
        return kernel_mm_opt<8,8,false>(_result, _mat1, _mat2);
}
