//====================================================================
// addmml kernel
// 03/09/2020 Kexin Zheng, Lin Cheng (kz73@cornell.edu, lc873@cornell.edu)
//====================================================================

#include <kernel_common.hpp>

// NB: This is an interesting opportunity for optimization. Dual-loop
// unrolling could allow loads to be spread across caches. Ideally the
// inner loop is unrolled completely first (?), then the outer loop is
// unrolled until maximum NB Loads are achieved.

// If the unroll factor > B, it will unroll by factor B instead.

template <unsigned int BY, unsigned int BX, bool TRANSPOSE>
__attribute__ ((noinline))
void load_block(float * bsg_attr_noalias sp_dest,
                const float bsg_attr_remote * bsg_attr_noalias src,
                uint32_t stride){
        bsg_unroll(2)
        for (int i = 0; i < BY; i++) {
                bsg_unroll(16)
                for (int j = 0 ; j < BX; j ++){
                        if (!TRANSPOSE)
                                sp_dest[BX * i + j] = src[i * stride + j];
                        else
                                sp_dest[i + BY * j] = src[i * stride + j];
                }
        }
}

template <unsigned int BY, unsigned int BX, bool TRANSPOSE>
void load_block(float * bsg_attr_noalias dest,
                HBTensor<float, 2> src,
                int by_i, int bx_i) {

        // Get the raw pointer
        bsg_attr_remote float * bsg_attr_noalias src_ptr =
                (float* bsg_attr_noalias) src.data_ptr();

        uint32_t* src_strides = src.get_strides();

        // Move the raw pointer to the row/column start.
        src_ptr = src_ptr +
                (by_i * BY * src_strides[0]) +
                (bx_i * BX * src_strides[1]);

        // Load from the source matrix, into the block.
        load_block<BX, BY, TRANSPOSE>(dest, src_ptr, src_strides[0]);
}

template <unsigned int BY, unsigned int BX>
__attribute__ ((noinline))
void store_block_and_reset(float bsg_attr_remote * bsg_attr_noalias src,
                           float * bsg_attr_noalias dest,
                           uint32_t stride){

        // TODO: In THEORY this can be more optimal. We should do
        // stores and zeros at the same time by issuing all stores,
        // then issuing all zeros, so that we have all available
        // credits by the time we load.
        for (int i = 0; i < BY; i++) {
                bsg_unroll(8)
                for (int j = 0 ; j < BX; j ++){
                        dest[i * stride + j] = src[i * BX + j];
                }
                bsg_unroll(8)
                for (int j = 0 ; j < BX; j ++){
                        src[i * BX + j] = 0.0f;
                }
        }
}

template <unsigned int BY, unsigned int BX>
void store_block_and_reset(HBTensor<float, 2> dest,
                           float * bsg_attr_noalias src,
                           int by_i, int bx_i) {

        // Get the raw pointer
        bsg_attr_remote float * bsg_attr_noalias dest_ptr =
                (float* bsg_attr_noalias) dest.data_ptr();

        uint32_t* dest_strides = dest.get_strides();

        // Move the raw pointer to the row/column start.
        dest_ptr = dest_ptr +
                (by_i * BY * dest_strides[0]) +
                (bx_i * BX * dest_strides[1]);

        // Store from the source matrix, into the block.
        store_block_and_reset<BY, BX>(src, dest_ptr, dest_strides[0]);
}


// Accumulate the product of two BY-by-BX input matrices into an
// output matrix.
//
// This is done by iteratively computing SBY-by-SBX sub-matrix
// outputs, and individually accumulating those into the output
// matrix.
template<unsigned int BY, unsigned int SBY, unsigned int BX, unsigned int SBX, bool M1_TRANSPOSE>
void accum_block(float* bsg_attr_noalias dest,
                 float* bsg_attr_noalias mat1,
                 float* bsg_attr_noalias mat2) {

        static_assert((BX % SBX) == 0, "X Block-Dimension must be a multiple of the X Sub-Block Dimension");
        static_assert((BY % SBY) == 0, "Y Block-Dimension must be a multiple of the Y Sub-Block Dimension");

        // Iterate through the SBY-by-SBX sub-blocks in the BY-by-BX block.
        for (int by_i = 0; by_i < BY/SBY; ++by_i) {
                for (int bx_i = 0; bx_i < BX/SBX; ++bx_i) {

                        // Compute the y,x location of the sub-block corner
                        int sb_anchor_y = (by_i * SBY);
                        int sb_anchor_x = (bx_i * SBX);

                        // Load in a SBY-by-SBX sub-block of the
                        // output matrix into psum for accumulation.
                        float psum[SBY][SBX];

                        // The sub-block is "anchored" by the
                        // upper-right corner at by_i, bx_i
                        float * bsg_attr_noalias sb_anchor = &(dest[sb_anchor_y * BX + sb_anchor_x]);

                        bsg_unroll(16)
                        for(int sby_i = 0; sby_i < SBY; ++sby_i){
                                bsg_unroll(16)
                                for(int sbx_i = 0; sbx_i < SBX; ++sbx_i){
                                        psum[sby_i][sbx_i] = sb_anchor[sby_i * BX + sbx_i];
                                }
                        }

                        // Compute an SBY-by-SBX output sub-block by
                        // performing BX, SBY-by-1 x 1-by-SBX
                        // vector-vector multiplies, and accumulate
                        // with the result
                        for(int sbx_i = 0; sbx_i < BX; ++sbx_i) {
                                // Load an SBY-by-1 sub-column of mat1,
                                // 1-by-SBX sub-row of mat2, and perform a
                                // SBY-by-1 x 1-by-SBX vector-vector multiply
                                // that produces an SBY-by-SBX output matrix.
                                float col[SBY];
                                float row[SBX];

                                // Load an SBY-by-1 sub-column of mat1,
                                if (!M1_TRANSPOSE) {
                                        float * bsg_attr_noalias col_anchor = &(mat1[sb_anchor_y * BX + sbx_i]);
                                        bsg_unroll(16)
                                        for(int i = 0; i < SBY; ++i){
                                                col[i] = col_anchor[i * BX];
                                        }
                                } else {
                                        float * bsg_attr_noalias col_anchor = &(mat1[sb_anchor_y + sbx_i * BY]);
                                        bsg_unroll(16)
                                        for(int i = 0; i < SBY; ++i){
                                                col[i] = col_anchor[i];
                                        }
                                }

                                // Load an SBX-by-1 sub-column of mat2
                                float * bsg_attr_noalias row_anchor = &(mat2[sbx_i * BY + sb_anchor_x]);
                                bsg_unroll(16)
                                for(int i = 0; i < SBX; ++i){
                                    row[i] = row_anchor[i];
                                }

                                // Perform a SBY-by-1 x 1-by-SBX
                                // vector-vector multiply to produce
                                // an SBY-by-SBX output matrix

                                // Add the result to the partial sum
                                // This could be done in two steps,
                                // but we do it in one to use FMA
                                // instructions
                                bsg_unroll(16)
                                for(int sby_i = 0; sby_i < SBY; ++sby_i){
                                        bsg_unroll(16)
                                        for(int sbx_i = 0; sbx_i < SBX; ++sbx_i){
                                                psum[sby_i][sbx_i] += col[sby_i] * row[sbx_i];
                                        }
                                }
                        }

                        // Write the partial sum sub-block back into
                        // the result.
                        for(int sby_i = 0; sby_i < SBY; ++sby_i){
                                for(int sbx_i = 0; sbx_i < SBX; ++sbx_i){
                                        sb_anchor[sby_i * BX + sbx_i] = psum[sby_i][sbx_i];
                                }
                        }
                }
        }
}

// BX is the X-dimension of the sub-block
// BY is the Y-dimension of the sub-block
// _mat1 is a r1 x c1 matrix
// _mat2 is a r2 x c2 matrix
// c1 == r2
// c1 % BX == 0, r2 % BX == 0
// c2 % BY == 0, r1 % BY == 0
template<unsigned int BX, unsigned int BY, bool LOAD_M1_TRANSPOSED>
int kernel_mm_opt(hb_tensor_t* _result,
                  hb_tensor_t* _mat1,
                  hb_tensor_t* _mat2) {

        auto mat1 = HBTensor<float, 2>(_mat1);
        auto mat2 = HBTensor<float, 2>(_mat2);
        auto result = HBTensor<float, 2>(_result);

        int r1 = mat1.dim(0);
        int c1 = mat1.dim(1);
        int r2 = mat2.dim(0);
        int c2 = mat2.dim(1);


        // M1 columns must equal M2 Rows
        hb_assert(c1 == r2);

        // This MM implementation is blocked into BY-by-BX output
        // blocks. This implies the following dimension constraints:

        // M1 columns must be divisible by the Block X-dimension
        hb_assert(c1 % BX == 0);
        // M2 rows must be divisible by the Block X-dimension
        hb_assert(r2 % BX == 0);

        // M1 rows must be divisible by the Block Y-dimension
        hb_assert(r1 % BY == 0);
        // M2 columns must be divisible by the Block Y-dimension
        hb_assert(c2 % BY == 0);

        // Compute the number of blocks, the loop bound of the
        // inner-loop.
        int blocks = c1 / BX; // r2 / BX

        // Local Storage for input blocks
        float block_row[BY * BX];
        float block_col[BX * BY];

        // Local storage for partial sums (output)
        float psum[BY * BX];

        for (int i = 0; i < BY; i++) {
                bsg_unroll(16)
                for (int j = 0 ; j < BX; j ++){
                        psum[i * BX + j] = 0.0f;
                }
        }

        // Start profiling
        bsg_cuda_print_stat_kernel_start();

        // Iterate through available output blocks in the X and Y
        // dimensions. Jump by the tile group size between iterations
        // to assign unique work.
        // Yes, this should be TGID
        for (int by_i = __bsg_y; by_i < r1/BY; by_i += BSG_TILE_GROUP_Y_DIM) {
                for (int bx_i = __bsg_x; bx_i < c2/BX; bx_i += BSG_TILE_GROUP_X_DIM) {

                        // Multiply the blocks, and accumulate into the result
                        for (int bz_i = 0; bz_i < blocks; bz_i++) {
                                load_block<BY, BX, LOAD_M1_TRANSPOSED>(block_row, mat1, by_i, bz_i);
                                load_block<BY, BX, false>(block_col, mat2, bz_i, bx_i);
                                accum_block<BY, BY/2, BX, BX/2, LOAD_M1_TRANSPOSED>(psum, block_row, block_col);
                        }

                        // Store the result, AND zero the psum array
                        // to leverage parallel remote and local
                        // stores.
                        store_block_and_reset<BY, BX>(result, psum, by_i, bx_i);
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
