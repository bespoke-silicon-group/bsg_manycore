// * This kernel performs naive matrix matrix multiplication.
//   All accesses to input and output matrices are to and from DRAM.
// * Tile group dimensions are fixed at 4x4.

// TEMPLATE_TG_DIM_X/Y must be defined before bsg_manycore.h is
// included. bsg_tiles_X and bsg_tiles_Y must also be defined for
// legacy reasons, but they are deprecated.

#define TEMPLATE_TG_DIM_X 4
#define TEMPLATE_TG_DIM_Y 4
#define bsg_tiles_X TEMPLATE_TG_DIM_X
#define bsg_tiles_Y TEMPLATE_TG_DIM_Y

#include <bsg_manycore.h>
#include "kernel_matrix_mul.hpp"
#include <bsg_tile_group_barrier.hpp>


bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;


template <int TG_DIM_X, int TG_DIM_Y,
          typename TA, typename TB, typename TC>
int  __attribute__ ((noinline)) group_matrix_multiply(TA *A, TB *B, TC *C,
                                                      uint32_t A_HEIGHT,
                                                      uint32_t A_WIDTH,
                                                      uint32_t B_WIDTH,
                                                      uint32_t block_size_y,
                                                      uint32_t block_size_x) {

    uint32_t start_y = __bsg_tile_group_id_y * block_size_y;
    uint32_t start_x = __bsg_tile_group_id_x * block_size_x;
    uint32_t end_y = start_y + block_size_y;
    uint32_t end_x = start_x + block_size_x;
    
    // Double check matrix output dimensions. Only write where valid data is.
    end_y = A_HEIGHT < (start_y + block_size_y) ? A_HEIGHT : (start_y + block_size_y);
    end_x = B_WIDTH < (start_x + block_size_x) ? B_WIDTH : (start_x + block_size_x);

    for (uint32_t iter_y = start_y + __bsg_y; iter_y < end_y; iter_y += TG_DIM_Y) {
        for (uint32_t iter_x = start_x + __bsg_x; iter_x < end_x; iter_x += TG_DIM_X) {
            TC sum = static_cast<TC>(0);

            for (uint32_t k = 0; k < A_WIDTH; k ++){
                sum += A[iter_y * A_WIDTH + k] * B[k * B_WIDTH + iter_x];
            }

            C[iter_y * B_WIDTH + iter_x] = sum;
        }
    }

    barrier.sync();

    return 0;
}


extern "C" {
    int  __attribute__ ((noinline)) kernel_matrix_mul(float *A, float *B, float *C,
                                                      uint32_t A_HEIGHT,
                                                      uint32_t A_WIDTH,
                                                      uint32_t B_WIDTH,
                                                      uint32_t block_size_y,
                                                      uint32_t block_size_x) {
        int rc;
        bsg_cuda_print_stat_kernel_start();

        rc = group_matrix_multiply <TEMPLATE_TG_DIM_X,
                                    TEMPLATE_TG_DIM_Y> (A, B, C,
                                                        A_HEIGHT,
                                                        A_WIDTH,
                                                        B_WIDTH,
                                                        block_size_y,
                                                        block_size_x);

        barrier.sync();

        bsg_cuda_print_stat_kernel_end();
        return rc;
    }
}
