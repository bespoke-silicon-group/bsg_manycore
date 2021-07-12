//====================================================================
// addmm kernel common subroutine
// 06/20/2020 Lin Cheng (lc873@cornell.edu)
//====================================================================

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

template <unsigned int B>
__attribute__ ((noinline))
void load_block( float * bsg_attr_noalias sp_dest,
                 const float bsg_attr_remote * bsg_attr_noalias src,
                 uint32_t stride){
    for (int i = 0; i < B; i++) {
            bsg_unroll(16)
            for(int j = 0 ; j < B; j ++){
                    sp_dest[B * i + j] = src[i * stride + j];
            }
    }
}

extern "C"
void dram_to_spad_block(
          float * bsg_attr_noalias dest,
          HBTensor<float, 2> src,
          int r_idx,
          int c_idx) {
    bsg_attr_remote float * bsg_attr_noalias src_ptr = (float* bsg_attr_noalias )src.data_ptr();
    uint32_t* src_strides = src.get_strides();
    bsg_attr_remote float * bsg_attr_noalias src_base = src_ptr + (r_idx * BLOCK_DIM * src_strides[0])
                      + (c_idx * BLOCK_DIM * src_strides[1]);
    load_block<BLOCK_DIM>(dest, src_base, src_strides[0]);
}
