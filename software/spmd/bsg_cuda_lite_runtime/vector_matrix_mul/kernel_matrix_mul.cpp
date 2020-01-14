/*!
 * This kernel performs matrix multiplication 
 * For now the matrices are assumed to have the same X/Y dimension n.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
#include <cstdint>
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
template <typename TA, typename TB, typename TC>
int kernel_matrix_mul(TA *A, TB *B, TC *C, 
                      uint32_t A_HEIGHT, uint32_t A_WIDTH, 
                      uint32_t B_WIDTH, 
                      uint32_t block_size_y, uint32_t block_size_x) {

	uint32_t start_y = __bsg_tile_group_id_y * block_size_y;
	uint32_t start_x = __bsg_tile_group_id_x * block_size_x;
	uint32_t end_y = start_y + block_size_y;
	uint32_t end_x = start_x + block_size_x;

	for (uint32_t iter_y = start_y + __bsg_y; iter_y < end_y; iter_y += bsg_tiles_Y) { 
		for (uint32_t iter_x = start_x + __bsg_x; iter_x < end_x; iter_x += bsg_tiles_X) { 
			TC sum = 0; 
			for (uint32_t k = 0; k < A_WIDTH; k ++) { 
				sum += A[iter_y * A_WIDTH + k] * B[k * B_WIDTH + iter_x];
			}
			C[iter_y * B_WIDTH + iter_x] = sum;
		}
	}

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	return 0;
}

extern "C" {
        int  __attribute__ ((noinline)) kernel_matrix_mul_int(int *A, int *B, int *C, 
                      uint32_t A_HEIGHT, uint32_t A_WIDTH, 
                      uint32_t B_WIDTH, 
                      uint32_t block_size_y, uint32_t block_size_x) {

                return kernel_matrix_mul(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH, block_size_y, block_size_x);
        }

        int  __attribute__ ((noinline)) kernel_matrix_mul_int16(int16_t *A, int16_t *B, int16_t *C, 
                      uint32_t A_HEIGHT, uint32_t A_WIDTH, 
                      uint32_t B_WIDTH, 
                      uint32_t block_size_y, uint32_t block_size_x) {

                return kernel_matrix_mul(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH, block_size_y, block_size_x);
        }

        int  __attribute__ ((noinline)) kernel_matrix_mul_int8(int8_t *A, int8_t *B, int8_t *C, 
                      uint32_t A_HEIGHT, uint32_t A_WIDTH, 
                      uint32_t B_WIDTH, 
                      uint32_t block_size_y, uint32_t block_size_x) {

                return kernel_matrix_mul(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH, block_size_y, block_size_x);
        }


        int  __attribute__ ((noinline)) kernel_matrix_mul_float(float *A, float *B, float *C, 
                      uint32_t A_HEIGHT, uint32_t A_WIDTH, 
                      uint32_t B_WIDTH, 
                      uint32_t block_size_y, uint32_t block_size_x) {

                return kernel_matrix_mul(A, B, C, A_HEIGHT, A_WIDTH, B_WIDTH, block_size_y, block_size_x);
        }
}
