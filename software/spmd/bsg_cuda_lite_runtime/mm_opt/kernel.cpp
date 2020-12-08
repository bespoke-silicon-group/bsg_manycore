//====================================================================
// addmml kernel
// 03/09/2020 Kexin Zheng, Lin Cheng (kz73@cornell.edu, lc873@cornell.edu)
//====================================================================
#include <kernel_common.hpp>

// NB: This is an interesting opportunity for optimization. Dual-loop
// unrolling could allow loads to be spread across caches. Ideally the
// inner loop is unrolled completely first (?), then the outer loop is
// unrolled until maximum NB Loads are achieved.

// Locations:
//     src should be in remote memory (DRAM)
//     dest should be in local scratchpad
template <unsigned int BY, unsigned int BX, bool TRANSPOSE>
inline void load_block(float * bsg_attr_noalias dest,
                float bsg_attr_remote * bsg_attr_noalias src,
                uint32_t  bsg_attr_remote * bsg_attr_noalias src_strides,
                int by_i, int bx_i) {

        // Move the raw pointer to the row/column start.
        src = src +
                (by_i * BY * src_strides[0]) +
                (bx_i * BX * src_strides[1]);

        //        bsg_unroll(16)
        //        for (int i = 0; i < BY; i++) {
        //                asm("lw x0, %0": : "m" (src[i * src_strides[0]]));
        //        }

        //bsg_unroll(2)
        for (int i = 0; i < BY; i++) {
                // If the unroll factor > B, it will unroll by factor B
                // instead.
                bsg_unroll(16)
                for (int j = 0 ; j < BX; j ++){
                        if (!TRANSPOSE)
                                dest[BX * i + j] = src[i * src_strides[0] + j];
                        else
                                dest[i + BY * j] = src[i * src_strides[0] + j];
                }
        }
}

// Store the result (psum) to remote memory and reset the psum array
// in scratchpad.
// Locations:
//     src should be in local scratchpad
//     dest should be in remote memory (DRAM)
template <unsigned int BY, unsigned int BX>
inline void store_block_and_reset(float * bsg_attr_noalias src,
                           float bsg_attr_remote * bsg_attr_noalias dest,
                           uint32_t  bsg_attr_remote * bsg_attr_noalias dest_strides,
                           int by_i, int bx_i) {

       // Move the raw pointer to the row/column start.
        dest = dest +
                (by_i * BY * dest_strides[0]) +
                (bx_i * BX * dest_strides[1]);

        // Store from the source matrix, into the block.
        // TODO: In THEORY this can be more optimal. We should do
        // stores and zeros at the same time by issuing all stores,
        // then issuing all zeros, so that we have all available
        // credits by the time we load.
        for (int i = 0; i < BY; i++) {
                bsg_unroll(16)
                for (int j = 0 ; j < BX; j ++){
                        dest[i * dest_strides[0] + j] = src[i * BX + j];
                        src[i * BX + j] = 0.0f;
                }
        }
}

// Accumulate the product of two BY-by-BX input matrices into an
// output matrix.
//
// This is done by iteratively computing SBY-by-SBX sub-matrix
// outputs, and individually accumulating those into the output
// matrix.
// Locations:
//     dest should be in local scratchpad
//     mat1 should be in local scratchpad
//     mat2 should be in local scratchpad
template<unsigned int BY, unsigned int SBY, unsigned int BX, unsigned int SBX, bool M1_TRANSPOSE>
inline void accum_block(float* bsg_attr_noalias dest,
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
                        // Location: Registers (for SBX == 4, SBY == 4)
                        float psum[SBY][SBX];

                        // The sub-block is "anchored" by the
                        // upper-right corner at by_i, bx_i
                        // Location: (pointer to) Scratchpad
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
                                // Locations:
                                //     col should be in registers (for SBY == 4)
                                //     row should be in registers (for SBX == 4)
                                float col[SBY];
                                float row[SBX];

                                // Load an SBY-by-1 sub-column of mat1,
                                if (!M1_TRANSPOSE) {
                                        // Location: (pointer to) Scratchpad
                                        float * bsg_attr_noalias col_anchor = &(mat1[sb_anchor_y * BX + sbx_i]);
                                        bsg_unroll(16)
                                        for(int i = 0; i < SBY; ++i){
                                                col[i] = col_anchor[i * BX];
                                        }
                                } else {
                                        // Location: (pointer to) Scratchpad
                                        float * bsg_attr_noalias col_anchor = &(mat1[sb_anchor_y + sbx_i * BY]);
                                        bsg_unroll(16)
                                        for(int i = 0; i < SBY; ++i){
                                                col[i] = col_anchor[i];
                                        }
                                }

                                // Load an SBX-by-1 sub-column of mat2
                                // Location: (pointer to) Scratchpad
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

                                // The code expects that psum, col,
                                // and row are all allocated in
                                // registers so that there are SBY *
                                // SBX fused-multiply-add instructions
                                // in a row.
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
                        bsg_unroll(16)
                        for(int sby_i = 0; sby_i < SBY; ++sby_i){
                                bsg_unroll(16)
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
// Asserts use bsg_printf, which can pollute the icache
//#define USE_ASSERT
template<unsigned int BX, unsigned int BY, bool LOAD_M1_TRANSPOSED, bool PROFILE>
__attribute__ ((noinline))
int kernel_mm_opt(float bsg_attr_remote * bsg_attr_noalias result,
                  uint32_t *bsg_attr_noalias result_strides,
                  float bsg_attr_remote * bsg_attr_noalias mat1,
                  uint32_t * bsg_attr_noalias mat1_strides,
                  int r1, int c1,
                  float bsg_attr_remote * bsg_attr_noalias mat2,
                  uint32_t * bsg_attr_noalias mat2_strides,
                  int r2, int c2
                  ) {
#ifdef USE_ASSERT

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
#endif

        // TODO: The compiler doesn't know that c1 is always (or
        // should always be) nonzero. This adds an extra BNE
        // instruction in the inner-loop. There should be some way to
        // signal to the compiler, perhaps with hb_assert?
        int blocks = c1 / BX; // r2 / BX

        // Local Storage for input blocks
        // Locations:
        //    block_row is in Local Scratchpad
        //    block_col is in Local Scratchpad
        float block_row[BY * BX];
        float block_col[BX * BY];

        // Local storage for partial sums (output)
        // Location: Local Scratchpad
        float psum[BY * BX];

        for (int i = 0; i < BY; i++) {
                bsg_unroll(16)
                for (int j = 0 ; j < BX; j ++){
                        psum[i * BX + j] = 0.0f;
                }
        }

        // To maximize locality, each tile should compute a number of
        // output blocks with spatially local data.
        //
        // This works best when the size (bytes) of the mat2 matrix
        // row is a multiple of the number of bytes in a row of
        // caches.
        
        // Split the work up into contiguous chunks, where each tile
        // will compute on one chunk.
        int bx_blocks = c2/BX;
        int bx_each = bx_blocks / BSG_TILE_GROUP_X_DIM;
        int bx_start = __bsg_x * (bx_each);
        int bx_end = bx_start + bx_each;
        // hb_assert(bx_each == 0);

        // Start profiling
        bsg_cuda_print_stat_kernel_start();

        // Iterate through available output blocks in the X and Y
        // dimensions. Jump by the tile group size between iterations
        // to assign unique work.
        // Yes, this should be TGID
        for (int by_i = __bsg_y; by_i < r1/BY; by_i += BSG_TILE_GROUP_Y_DIM) {
                for (int bx_i = __bsg_x; bx_i < c2/BX; bx_i += BSG_TILE_GROUP_X_DIM) {
                        //for (int bx_i = bx_start; bx_i < bx_end ; bx_i ++) {

                        // Multiply the blocks, and accumulate into the result

                        if(PROFILE)
                                bsg_cuda_print_stat_start(0);
                        for (int bz_i = 0; bz_i < blocks; bz_i++) {
                                if(PROFILE)
                                        bsg_cuda_print_stat_start(1);
                                load_block<BY, BX, LOAD_M1_TRANSPOSED>(block_row, mat1, mat1_strides, by_i, bz_i);
                                if(PROFILE){
                                        bsg_cuda_print_stat_end(1);
                                        bsg_cuda_print_stat_start(2);
                                }
                                load_block<BY, BX, false>(block_col, mat2, mat2_strides, bz_i, bx_i);
                                if(PROFILE){
                                        bsg_cuda_print_stat_end(2);
                                        bsg_cuda_print_stat_start(3);
                                }
                                accum_block<BY, 4, BX, 4, LOAD_M1_TRANSPOSED>(psum, block_row, block_col);
                                if(PROFILE){
                                        bsg_cuda_print_stat_end(3);
                                }
                        }

                        if(PROFILE)
                                bsg_cuda_print_stat_start(4);

                        // Store the result, AND zero the psum array
                        // to leverage parallel remote and local
                        // stores.
                        store_block_and_reset<BY, BX>(psum, result, result_strides, by_i, bx_i);

                        if(PROFILE){
                                bsg_cuda_print_stat_end(4);
                                bsg_cuda_print_stat_end(0);
                        }
                }
        }

        // End profiling
        bsg_cuda_print_stat_kernel_end();

        return 0;
}
/*
extern "C"
int kernel_mm_opt_8x8(
                  hb_tensor_t* _result,
                  hb_tensor_t* _mat1,
                  hb_tensor_t* _mat2) {

        auto mat1 = HBTensor<float, 2>(_mat1);
        auto mat2 = HBTensor<float, 2>(_mat2);
        auto result = HBTensor<float, 2>(_result);
        
        kernel_mm_opt<8,8,false, false>((float* bsg_attr_noalias) result.data_ptr(),
                                        result.get_strides(),
                                        (float* bsg_attr_noalias) mat1.data_ptr(),
                                        mat1.get_strides(),
                                        mat1.dim(0), mat1.dim(1),
                                        (float* bsg_attr_noalias) mat2.data_ptr(),
                                        mat2.get_strides(),
                                        mat2.dim(0), mat2.dim(1));
        g_barrier.sync();
        return 0;
}
*/
extern "C"
int kernel_mm_opt_16x16(
                  hb_tensor_t* _result,
                  hb_tensor_t* _mat1,
                  hb_tensor_t* _mat2) {

        auto mat1 = HBTensor<float, 2>(_mat1);
        auto mat2 = HBTensor<float, 2>(_mat2);
        auto result = HBTensor<float, 2>(_result);
        
        kernel_mm_opt<16,16,false, false>((float* bsg_attr_noalias) result.data_ptr(),
                                        result.get_strides(),
                                        (float* bsg_attr_noalias) mat1.data_ptr(),
                                        mat1.get_strides(),
                                        mat1.dim(0), mat1.dim(1),
                                        (float* bsg_attr_noalias) mat2.data_ptr(),
                                        mat2.get_strides(),
                                        mat2.dim(0), mat2.dim(1));
        g_barrier.sync();
        return 0;
}

