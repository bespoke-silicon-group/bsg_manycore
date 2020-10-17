//====================================================================
// addmm kernel common subroutine
// 06/20/2020 Lin Cheng (lc873@cornell.edu)
//====================================================================

// XXX: this compute subroutine handles one row of 8 outputs at a time
// to avoid dependency chains
//
// output row 1:
//   iter 0 - mat1[0][0] * ( mat2[0][0], mat2[0][1], ..., mat2[0][7] )
//   iter 1 - mat1[0][1] * ( mat2[1][0], mat2[1][1], ..., mat2[1][7] )
//   iter 2 - mat1[0][2] * ( mat2[2][0], mat2[2][1], ..., mat2[2][7] )

inline void compute_block(
                          float* bsg_attr_noalias sp_dest,
                          float* bsg_attr_noalias sp_mat1,
                          float* bsg_attr_noalias sp_mat2) {
        for (int iii = 0; iii < BLOCK_DIM; iii += 4) {
                for(int jjj = 0; jjj < BLOCK_DIM; jjj += 4) {
                        int sp_dest_base = iii * BLOCK_DIM + jjj;
                        register float res00 = sp_dest[sp_dest_base + 0             + 0];
                        register float res01 = sp_dest[sp_dest_base + 0             + 1];
                        register float res02 = sp_dest[sp_dest_base + 0             + 2];
                        register float res03 = sp_dest[sp_dest_base + 0             + 3];
                        register float res10 = sp_dest[sp_dest_base + BLOCK_DIM     + 0];
                        register float res11 = sp_dest[sp_dest_base + BLOCK_DIM     + 1];
                        register float res12 = sp_dest[sp_dest_base + BLOCK_DIM     + 2];
                        register float res13 = sp_dest[sp_dest_base + BLOCK_DIM     + 3];
                        register float res20 = sp_dest[sp_dest_base + 2 * BLOCK_DIM + 0];
                        register float res21 = sp_dest[sp_dest_base + 2 * BLOCK_DIM + 1];
                        register float res22 = sp_dest[sp_dest_base + 2 * BLOCK_DIM + 2];
                        register float res23 = sp_dest[sp_dest_base + 2 * BLOCK_DIM + 3];
                        register float res30 = sp_dest[sp_dest_base + 3 * BLOCK_DIM + 0];
                        register float res31 = sp_dest[sp_dest_base + 3 * BLOCK_DIM + 1];
                        register float res32 = sp_dest[sp_dest_base + 3 * BLOCK_DIM + 2];
                        register float res33 = sp_dest[sp_dest_base + 3 * BLOCK_DIM + 3];
                        for(int kkk = 0; kkk < BLOCK_DIM; kkk++) {
                                // for iiii in 0...4
                                //   for jjjj in 0...4
                                int mat1_base = kkk + iii * BLOCK_DIM;
                                register float mat1_0 = sp_mat1[mat1_base + 0];
                                register float mat1_1 = sp_mat1[mat1_base + BLOCK_DIM];
                                register float mat1_2 = sp_mat1[mat1_base + 2 * BLOCK_DIM];
                                register float mat1_3 = sp_mat1[mat1_base + 3 * BLOCK_DIM];
                                int mat2_base = kkk * BLOCK_DIM + jjj;
                                register float mat2_0 = sp_mat2[mat2_base + 0];
                                register float mat2_1 = sp_mat2[mat2_base + 1];
                                register float mat2_2 = sp_mat2[mat2_base + 2];
                                register float mat2_3 = sp_mat2[mat2_base + 3];
                                // compute
                                res00 += mat1_0 * mat2_0;
                                res01 += mat1_0 * mat2_1;
                                res02 += mat1_0 * mat2_2;
                                res03 += mat1_0 * mat2_3;
                                res10 += mat1_1 * mat2_0;
                                res11 += mat1_1 * mat2_1;
                                res12 += mat1_1 * mat2_2;
                                res13 += mat1_1 * mat2_3;
                                res20 += mat1_2 * mat2_0;
                                res21 += mat1_2 * mat2_1;
                                res22 += mat1_2 * mat2_2;
                                res23 += mat1_2 * mat2_3;
                                res30 += mat1_3 * mat2_0;
                                res31 += mat1_3 * mat2_1;
                                res32 += mat1_3 * mat2_2;
                                res33 += mat1_3 * mat2_3;
                        }
                        sp_dest[sp_dest_base + 0             + 0] = res00;
                        sp_dest[sp_dest_base + 0             + 1] = res01;
                        sp_dest[sp_dest_base + 0             + 2] = res02;
                        sp_dest[sp_dest_base + 0             + 3] = res03;
                        sp_dest[sp_dest_base + BLOCK_DIM     + 0] = res10;
                        sp_dest[sp_dest_base + BLOCK_DIM     + 1] = res11;
                        sp_dest[sp_dest_base + BLOCK_DIM     + 2] = res12;
                        sp_dest[sp_dest_base + BLOCK_DIM     + 3] = res13;
                        sp_dest[sp_dest_base + 2 * BLOCK_DIM + 0] = res20;
                        sp_dest[sp_dest_base + 2 * BLOCK_DIM + 1] = res21;
                        sp_dest[sp_dest_base + 2 * BLOCK_DIM + 2] = res22;
                        sp_dest[sp_dest_base + 2 * BLOCK_DIM + 3] = res23;
                        sp_dest[sp_dest_base + 3 * BLOCK_DIM + 0] = res30;
                        sp_dest[sp_dest_base + 3 * BLOCK_DIM + 1] = res31;
                        sp_dest[sp_dest_base + 3 * BLOCK_DIM + 2] = res32;
                        sp_dest[sp_dest_base + 3 * BLOCK_DIM + 3] = res33;
                }
        }
}


// Accumulate the product of two BY-by-BX input matrices into an
// output matrix.
// 
// This is done by iteratively computing SBY-by-SBX sub-matrix
// outputs, and individually accumulating those into the output
// matrix.
template<unsigned int BX, unsigned int SBX, unsigned int BY, unsigned int SBY>
void accum_block(float* bsg_attr_noalias dest,
                 float* bsg_attr_noalias mat1,
                 float* bsg_attr_noalias mat2) {

        static_assert((BX % SBX) == 0, "X Block-Dimension must be a multiple of the X Sub-Block Dimension");
        static_assert((BY % SBY) == 0, "Y Block-Dimension must be a multiple of the Y Sub-Block Dimension");

        // Split the BY-by-BX output matrix into SBY-by-SBX
        // sub-matrices.
        for (int by_i = 0; by_i < BY; by_i += SBY) {
                for (int bx_i = 0; bx_i < BX; bx_i += SBX) {
                        // Load in a SBY-by-SBX sub-block of the
                        // output matrix into psum for accumulation.
                        float psum[SBY][SBX];

                        // The sub-block is "anchored" by the
                        // upper-right corner at by_i, bx_i
                        float * bsg_attr_noalias sb_anchor = &(dest[by_i * BX + bx_i]);

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
                                float * bsg_attr_noalias col_anchor = &(mat1[sbx_i + by_i * BX]);
                                for(int i = 0; i < SBY; ++i){
                                    col[i] = col_anchor[i * BX];
                                }

                                // Load an SBX-by-1 sub-column of mat2
                                float * bsg_attr_noalias row_anchor = &(mat2[sbx_i * BY + bx_i]);
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
template <unsigned int BX, unsigned int BY>
__attribute__ ((noinline))
void load_block(
                float * bsg_attr_noalias sp_dest,
                const float bsg_attr_remote * bsg_attr_noalias src,
                uint32_t stride){
        bsg_unroll(2)
        for (int i = 0; i < BX; i++) {
                bsg_unroll(16)
                for(int j = 0 ; j < BY; j ++){
                        sp_dest[BX * i + j] = src[i * stride + j];
                }
        }
}

template <unsigned int BX, unsigned int BY>
void load_block(
                float * bsg_attr_noalias dest,
                HBTensor<float, 2> src,
                int r_idx,
                int c_idx) {

        // Get the raw pointer
        bsg_attr_remote float * bsg_attr_noalias src_ptr = 
                (float* bsg_attr_noalias ) src.data_ptr();

        uint32_t* src_strides = src.get_strides();

        // Move the raw pointer to the row/column start.
        src_ptr = src_ptr + 
                (r_idx * BX * src_strides[0]) +
                (c_idx * BY * src_strides[1]);
        
        // Load from the source matrix, into the block.
        load_block<BX, BY>(dest, src_ptr, src_strides[0]);
}
