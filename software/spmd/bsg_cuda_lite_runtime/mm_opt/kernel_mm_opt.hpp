//====================================================================
// addmm kernel common subroutine
// 06/20/2020 Lin Cheng (lc873@cornell.edu)
//====================================================================

// Accumulate the product of two BY-by-BX input matrices into an
// output matrix.
// 
// This is done by iteratively computing SBY-by-SBX sub-matrix
// outputs, and individually accumulating those into the output
// matrix.
template<unsigned int BX, unsigned int SBX, unsigned int BY, unsigned int SBY, bool M1_TRANSPOSE>
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

                        for(int sby_i = 0; sby_i < SBY; ++sby_i){
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

                                // NB: Ideally, mat1 would be loaded
                                // transposed, so that this can be
                                // simplified with a reused index and
                                // unique offset.

                                // Load an SBY-by-1 sub-column of mat1,
                                if (!M1_TRANSPOSE) {
                                        float * bsg_attr_noalias col_anchor = &(mat1[sb_anchor_y * BX + sbx_i]);
                                        for(int i = 0; i < SBY; ++i){
                                                col[i] = col_anchor[i * BX];
                                        }
                                } else {
                                        float * bsg_attr_noalias col_anchor = &(mat1[sb_anchor_y + sbx_i * BY]);
                                        for(int i = 0; i < SBY; ++i){
                                                col[i] = col_anchor[i];
                                        }
                                }

                                // Load an SBX-by-1 sub-column of mat2
                                float * bsg_attr_noalias row_anchor = &(mat2[sbx_i * BY + sb_anchor_x]);
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
                                for(int sby_i = 0; sby_i < SBY; ++sby_i){
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


// NB: This is an interesting opportunity for optimization. Dual-loop
// unrolling could allow loads to be spread across caches. Ideally the
// inner loop is unrolled completely first (?), then the outer loop is
// unrolled until maximum NB Loads are achieved.

// If the unroll factor > B, it will unroll by factor B instead.

template <unsigned int BX, unsigned int BY, bool TRANSPOSE>
__attribute__ ((noinline))
void load_block(
                float * bsg_attr_noalias sp_dest,
                const float bsg_attr_remote * bsg_attr_noalias src,
                uint32_t stride){
        bsg_unroll(2)
        for (int i = 0; i < BX; i++) {
                bsg_unroll(16)
                for (int j = 0 ; j < BY; j ++){
                        if (!TRANSPOSE)
                                sp_dest[BX * i + j] = src[i * stride + j];
                        else
                                sp_dest[i + BY * j] = src[i * stride + j];
                }
        }
}

template <unsigned int BX, unsigned int BY, bool TRANSPOSE>
void load_block(
                float * bsg_attr_noalias dest,
                HBTensor<float, 2> src,
                int r_idx,
                int c_idx) {

        // Get the raw pointer
        bsg_attr_remote float * bsg_attr_noalias src_ptr = 
                (float* bsg_attr_noalias) src.data_ptr();

        uint32_t* src_strides = src.get_strides();

        // Move the raw pointer to the row/column start.
        src_ptr = src_ptr + 
                (r_idx * BX * src_strides[0]) +
                (c_idx * BY * src_strides[1]);
        
        // Load from the source matrix, into the block.
        load_block<BX, BY, TRANSPOSE>(dest, src_ptr, src_strides[0]);
}
