//====================================================================
// addmm kernel common subroutine
// 06/20/2020 Lin Cheng (lc873@cornell.edu)
//====================================================================

inline void compute_simple(
          float* dest,
          float* sp_mat1,
          float* sp_mat2,
          int dim_y,
          int dim_x,
          int mid_dim) {
    for (int i = 0; i < dim_y; i++) {
        int dest_row_offset = i * dim_x;
        int mat1_row_offset = i * mid_dim;
        for (int j = 0; j < dim_x; j++) {
            int k = 0;
            for (;k < mid_dim; k += 8) {
                int mat1_idx = mat1_row_offset + k;
                int mat2_idx = k * dim_x + j;
                register float tmp0 = sp_mat1[mat1_idx] * sp_mat2[mat2_idx];
                register float tmp1 = sp_mat1[mat1_idx + 1] * sp_mat2[mat2_idx + dim_x];
                register float tmp2 = sp_mat1[mat1_idx + 2] * sp_mat2[mat2_idx + 2 * dim_x];
                register float tmp3 = sp_mat1[mat1_idx + 3] * sp_mat2[mat2_idx + 3 * dim_x];
                register float tmp4 = sp_mat1[mat1_idx + 4] * sp_mat2[mat2_idx + 4 * dim_x];
                register float tmp5 = sp_mat1[mat1_idx + 5] * sp_mat2[mat2_idx + 5 * dim_x];
                register float tmp6 = sp_mat1[mat1_idx + 6] * sp_mat2[mat2_idx + 6 * dim_x];
                register float tmp7 = sp_mat1[mat1_idx + 7] * sp_mat2[mat2_idx + 7 * dim_x];
                dest[dest_row_offset + j] += (tmp0 + tmp1 + tmp2 + tmp3 + tmp4 + tmp5 + tmp6 + tmp7);
            }
        }
    }
}

inline void compute(
          float* dest,
          float* sp_mat1,
          float* sp_mat2,
          int dim_y,
          int dim_x,
          int mid_dim) {
    for (int i = 0; i < dim_y; i++) {
        int dest_row_offset = i * dim_x;
        int mat1_row_offset = i * mid_dim;
        for (int j = 0; j < dim_x; j++) {
            int k = 0;
            for (;k < mid_dim - 8; k += 8) {
                int mat1_idx = mat1_row_offset + k;
                int mat2_idx = k * dim_x + j;
                register float tmp0 = sp_mat1[mat1_idx] * sp_mat2[mat2_idx];
                register float tmp1 = sp_mat1[mat1_idx + 1] * sp_mat2[mat2_idx + dim_x];
                register float tmp2 = sp_mat1[mat1_idx + 2] * sp_mat2[mat2_idx + 2 * dim_x];
                register float tmp3 = sp_mat1[mat1_idx + 3] * sp_mat2[mat2_idx + 3 * dim_x];
                register float tmp4 = sp_mat1[mat1_idx + 4] * sp_mat2[mat2_idx + 4 * dim_x];
                register float tmp5 = sp_mat1[mat1_idx + 5] * sp_mat2[mat2_idx + 5 * dim_x];
                register float tmp6 = sp_mat1[mat1_idx + 6] * sp_mat2[mat2_idx + 6 * dim_x];
                register float tmp7 = sp_mat1[mat1_idx + 7] * sp_mat2[mat2_idx + 7 * dim_x];
                dest[dest_row_offset + j] += (tmp0 + tmp1 + tmp2 + tmp3 + tmp4 + tmp5 + tmp6 + tmp7);
            }
            // fixup
            register float tmp_fix = 0.0f;
            for (;k < mid_dim; k++) {
                int mat1_idx = mat1_row_offset + k;
                int mat2_idx = k * dim_x + j;
                tmp_fix += sp_mat1[mat1_idx] * sp_mat2[mat2_idx];
            }
            dest[dest_row_offset + j] += tmp_fix;
        }
    }
}

inline void dram_to_sp_simple(
          float* dest,
          HBTensor<float, 2> src,
          int dim_y,
          int dim_x,
          int r_idx,
          int c_idx) {
    for (int i = 0; i < dim_y; i++) {
        int row_offset = i * dim_x;
        int j = 0;
        for (;j < dim_x; j += 8) {
            register float tmp0 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j);
            register float tmp1 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 1);
            register float tmp2 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 2);
            register float tmp3 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 3);
            register float tmp4 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 4);
            register float tmp5 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 5);
            register float tmp6 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 6);
            register float tmp7 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 7);
            asm volatile("": : :"memory");
            dest[row_offset + j]     = tmp0;
            dest[row_offset + j + 1] = tmp1;
            dest[row_offset + j + 2] = tmp2;
            dest[row_offset + j + 3] = tmp3;
            dest[row_offset + j + 4] = tmp4;
            dest[row_offset + j + 5] = tmp5;
            dest[row_offset + j + 6] = tmp6;
            dest[row_offset + j + 7] = tmp7;
        }
    }
}

inline void dram_to_sp(
          float* dest,
          HBTensor<float, 2> src,
          int dim_y,
          int dim_x,
          int r_idx,
          int c_idx) {
    for (int i = 0; i < dim_y; i++) {
        int row_offset = i * dim_x;
        int j = 0;
        for (;j < dim_x - 8; j += 8) {
            register float tmp0 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j);
            register float tmp1 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 1);
            register float tmp2 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 2);
            register float tmp3 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 3);
            register float tmp4 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 4);
            register float tmp5 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 5);
            register float tmp6 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 6);
            register float tmp7 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 7);
            asm volatile("": : :"memory");
            dest[row_offset + j]     = tmp0;
            dest[row_offset + j + 1] = tmp1;
            dest[row_offset + j + 2] = tmp2;
            dest[row_offset + j + 3] = tmp3;
            dest[row_offset + j + 4] = tmp4;
            dest[row_offset + j + 5] = tmp5;
            dest[row_offset + j + 6] = tmp6;
            dest[row_offset + j + 7] = tmp7;
        }
        // fixup
        for (;j < dim_x; j++) {
            dest[row_offset + j] = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j);
        }
    }
}

// same as the dram_to_sp above but with coeff

static void dram_to_sp_simple(
          float* dest,
          float coeff,
          HBTensor<float, 2> src,
          int dim_y,
          int dim_x,
          int r_idx,
          int c_idx) {
    for (int i = 0; i < dim_y; i++) {
        int row_offset = i * dim_x;
        int j = 0;
        for (;j < dim_x; j += 8) {
            register float tmp0 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j);
            register float tmp1 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 1);
            register float tmp2 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 2);
            register float tmp3 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 3);
            register float tmp4 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 4);
            register float tmp5 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 5);
            register float tmp6 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 6);
            register float tmp7 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 7);
            asm volatile("": : :"memory");
            tmp0 = tmp0 * coeff;
            tmp1 = tmp1 * coeff;
            tmp2 = tmp2 * coeff;
            tmp3 = tmp3 * coeff;
            tmp4 = tmp4 * coeff;
            tmp5 = tmp5 * coeff;
            tmp6 = tmp6 * coeff;
            tmp7 = tmp7 * coeff;
            dest[row_offset + j]     = tmp0;
            dest[row_offset + j + 1] = tmp1;
            dest[row_offset + j + 2] = tmp2;
            dest[row_offset + j + 3] = tmp3;
            dest[row_offset + j + 4] = tmp4;
            dest[row_offset + j + 5] = tmp5;
            dest[row_offset + j + 6] = tmp6;
            dest[row_offset + j + 7] = tmp7;
        }
    }
}

static void dram_to_sp(
          float* dest,
          float coeff,
          HBTensor<float, 2> src,
          int dim_y,
          int dim_x,
          int r_idx,
          int c_idx) {
    for (int i = 0; i < dim_y; i++) {
        int row_offset = i * dim_x;
        int j = 0;
        for (;j < dim_x - 8; j += 8) {
            register float tmp0 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j);
            register float tmp1 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 1);
            register float tmp2 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 2);
            register float tmp3 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 3);
            register float tmp4 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 4);
            register float tmp5 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 5);
            register float tmp6 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 6);
            register float tmp7 = src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j + 7);
            asm volatile("": : :"memory");
            tmp0 = tmp0 * coeff;
            tmp1 = tmp1 * coeff;
            tmp2 = tmp2 * coeff;
            tmp3 = tmp3 * coeff;
            tmp4 = tmp4 * coeff;
            tmp5 = tmp5 * coeff;
            tmp6 = tmp6 * coeff;
            tmp7 = tmp7 * coeff;
            dest[row_offset + j]     = tmp0;
            dest[row_offset + j + 1] = tmp1;
            dest[row_offset + j + 2] = tmp2;
            dest[row_offset + j + 3] = tmp3;
            dest[row_offset + j + 4] = tmp4;
            dest[row_offset + j + 5] = tmp5;
            dest[row_offset + j + 6] = tmp6;
            dest[row_offset + j + 7] = tmp7;
        }
        // fixup
        for (;j < dim_x; j++) {
            dest[row_offset + j] = coeff * src(r_idx * BLOCK_DIM + i, c_idx * BLOCK_DIM + j);
        }
    }
}

