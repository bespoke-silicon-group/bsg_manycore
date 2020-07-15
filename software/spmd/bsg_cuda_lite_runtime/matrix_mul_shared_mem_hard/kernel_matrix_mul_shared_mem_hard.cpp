// * This kernel performs blocked matrix multiplication using 
//   tile group shared memory. Subblocks of input matrices are
//   loaded into tile group shared memory by all tiles, and 
//   accesses for matrix multiplication are done to the 
//   lower-latency tile group shared meomry instead of the long-
//   latency DRAM.
// * This code uses the hardware tile group shared memory 
//   in conjunction with it's library bsg_shared_mem.hpp
// * This version converts tile group shared memory and 
//   input vector pointers into two dimensional matrix 
//   references for better understanding of the code and
//   easier programming.
// * Tile group dimensions are fixed at 4x4.

// TEMPLATE_TG_DIM_X/Y must be defined before bsg_manycore.h is
// included. bsg_tiles_X and bsg_tiles_Y must also be defined for
// legacy reasons, but they are deprecated.


#define TEMPLATE_TG_DIM_X 4
#define TEMPLATE_TG_DIM_Y 4
#define TEMPLATE_BLOCK_SIZE_X  32
#define TEMPLATE_BLOCK_SIZE_Y  32
#define TEMPLATE_SUBBLOCK_SIZE 32
#define TEMPLATE_STRIPE_SIZE   1
#define bsg_tiles_X TEMPLATE_TG_DIM_X
#define bsg_tiles_Y TEMPLATE_TG_DIM_Y

#include <bsg_manycore.h>
#include "kernel_matrix_mul_shared_mem_hard.hpp"
#include <bsg_tile_group_barrier.hpp>
#include "bsg_shared_mem.hpp"

using namespace bsg_manycore;


bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;


// Load a BLOCK_SIZE_X x BLOCK_SIZE_Y submatrix 
// from DRAM into tile group shared memory
template <int TG_DIM_X, int TG_DIM_Y,
          int BLOCK_SIZE_X, int BLOCK_SIZE_Y,
          int STRIPE_SIZE, typename T>
    void __attribute__ ((noinline)) 
    memcpy_subblock_to_shmem (T *src,
                              T (&dst)[BLOCK_SIZE_Y][BLOCK_SIZE_X],
                              uint32_t M,
                              uint32_t N,
                              uint32_t sub_block_y,
                              uint32_t sub_block_x) { 
    
        uint32_t start_y = sub_block_y * BLOCK_SIZE_Y;
        uint32_t start_x = sub_block_x * BLOCK_SIZE_X;

        // Create a 2D reference to the source MxN matrix from the 1D input pointer 
        T (&src_2d)[M][N] = *reinterpret_cast<T (*)[M][N]> (src);
        // Offset the 2D pointer to start from the beginning of the sub-matrix to be accessed
        T (&A)[M][N] = *reinterpret_cast<T (*)[M][N]> (&(src_2d[start_y][start_x]));
        
        for (uint32_t iter_y = __bsg_y; iter_y < BLOCK_SIZE_Y; iter_y += TG_DIM_Y) { 
            for (uint32_t iter_x = __bsg_x; iter_x < BLOCK_SIZE_X; iter_x += TG_DIM_X) { 
                dst[iter_y][iter_x] = A[iter_y][iter_x];
            }
        }
        return; 
    }


// Load a BLOCK_SIZE_X x BLOCK_SIZE_Y submatrix 
// from DRAM into tile group shared memory and transpose it
template <int TG_DIM_X, int TG_DIM_Y,
          int BLOCK_SIZE_X, int BLOCK_SIZE_Y,
          int STRIPE_SIZE, typename T>
    void __attribute__ ((noinline)) 
    memcpy_subblock_to_shmem_transposed (T *src,
                                         T (&dst)[BLOCK_SIZE_X][BLOCK_SIZE_Y],
                                         uint32_t M,
                                         uint32_t N,
                                         uint32_t sub_block_y,
                                         uint32_t sub_block_x) { 
    
        uint32_t start_y = sub_block_y * BLOCK_SIZE_Y;
        uint32_t start_x = sub_block_x * BLOCK_SIZE_X;

        // Create a 2D reference to the source MxN matrix from the 1D input pointer 
        T (&src_2d)[M][N] = *reinterpret_cast<T (*)[M][N]> (src);
        // Offset the 2D pointer to start from the beginning of the sub-matrix to be accessed
        T (&A)[M][N] = *reinterpret_cast<T (*)[M][N]> (&(src_2d[start_y][start_x]));

        for (uint32_t iter_y = __bsg_y; iter_y < BLOCK_SIZE_Y; iter_y += TG_DIM_Y) { 
            for (uint32_t iter_x = __bsg_x; iter_x < BLOCK_SIZE_X; iter_x += TG_DIM_X) { 
                dst[iter_x][iter_y] = A[iter_y][iter_x];
            }
        }
        return; 
    }


// Store a BLOCK_SIZE_X x BLOCK_SIZE_Y submatrix 
// from tile group shared memory to DRAM 
template <int TG_DIM_X, int TG_DIM_Y,
          int BLOCK_SIZE_X, int BLOCK_SIZE_Y,
          int STRIPE_SIZE, typename T>
    void __attribute__ ((noinline))
    memcpy_shmem_to_subblock (T *dst,
                              T (&src)[BLOCK_SIZE_Y][BLOCK_SIZE_X],
                              uint32_t M,
                              uint32_t N,
                              uint32_t sub_block_y,
                              uint32_t sub_block_x) { 

        uint32_t start_y = sub_block_y * BLOCK_SIZE_Y;
        uint32_t start_x = sub_block_x * BLOCK_SIZE_X;

        // Create a 2D reference to an MxN destination matrix from the 1D input pointer 
        T (&dst_2d)[M][N] = *reinterpret_cast<T (*)[M][N]> (dst);
        // Offset the 2D pointer to start from the beginning of the sub-matrix to be accessed
        T (&A)[M][N] = *reinterpret_cast<T (*)[M][N]> (&(dst_2d[start_y][start_x]));

        
        for (uint32_t iter_y = __bsg_y; iter_y < BLOCK_SIZE_Y; iter_y += TG_DIM_Y) { 
            for (uint32_t iter_x = __bsg_x; iter_x < BLOCK_SIZE_X; iter_x += TG_DIM_X) { 
                A[iter_y][iter_x] = src[iter_y][iter_x];
            }
        }
        return; 
    }


// Perform a submatrix multiplication among two 
// matrices stored in tile group shared memory
// and store into tile group shared memory
template <int TG_DIM_X, int TG_DIM_Y,
          int BLOCK_SIZE_X, int BLOCK_SIZE_Y,
          int SUBBLOCK_SIZE, int STRIPE_SIZE,
          typename TA, typename TB, typename TC>
    void __attribute__ ((noinline))
    subblock_shmem_matrix_mul_transposed (
                                          TA (&A)[BLOCK_SIZE_Y][SUBBLOCK_SIZE],
                                          TB (&B)[BLOCK_SIZE_X][SUBBLOCK_SIZE],
                                          TC (&C)[BLOCK_SIZE_Y][BLOCK_SIZE_X ],
                                          uint32_t M,
                                          uint32_t N,
                                          uint32_t P,
                                          uint32_t block_num) {
                                   
        for (uint32_t iter_y = __bsg_y; iter_y < BLOCK_SIZE_Y; iter_y += TG_DIM_Y) { 
            for (uint32_t iter_x = __bsg_x; iter_x < BLOCK_SIZE_X; iter_x += TG_DIM_X) { 
                TC sum = static_cast<TC>(0); 

                // sum += A[iter_y][iter_x] * B[iter_y][iter_x]
                // Remember, B is transposed
                for (uint32_t k = 0; k < SUBBLOCK_SIZE; k ++) { 
                    sum += A[iter_y][k] * B[iter_x][k]; 
                }
                
                if (!block_num) { 
                    C[iter_y][iter_x] = sum;
                }
                else { 
                    C[iter_y][iter_x] += sum;
                } 
            }
        }
        return;
    }


template <int TG_DIM_X, int TG_DIM_Y,
          int BLOCK_SIZE_X, int BLOCK_SIZE_Y,
          int SUBBLOCK_SIZE, int STRIPE_SIZE,
          typename TA, typename TB, typename TC>
    int __attribute__ ((noinline))
    group_matrix_multiply(TA *A, TB *B, TC *C, 
                          uint32_t M,
                          uint32_t N,
                          uint32_t P) {
    
        // Declare tile-group shared memory
        TileGroupSharedMem<TA, (BLOCK_SIZE_Y * SUBBLOCK_SIZE), TG_DIM_X, TG_DIM_Y, STRIPE_SIZE> A_arr;
        TileGroupSharedMem<TB, (BLOCK_SIZE_X * SUBBLOCK_SIZE), TG_DIM_X, TG_DIM_Y, STRIPE_SIZE> B_arr;
        TileGroupSharedMem<TC, (BLOCK_SIZE_Y * BLOCK_SIZE_X ), TG_DIM_X, TG_DIM_Y, STRIPE_SIZE> C_arr;

        // Cast to a 2D tile group shared array
        TA (&A_sh)[BLOCK_SIZE_Y][SUBBLOCK_SIZE] = *reinterpret_cast<TA (*)[BLOCK_SIZE_Y][SUBBLOCK_SIZE]> (A_arr.addr());
        TB (&B_sh)[BLOCK_SIZE_X][SUBBLOCK_SIZE] = *reinterpret_cast<TB (*)[BLOCK_SIZE_X][SUBBLOCK_SIZE]> (B_arr.addr());
        TC (&C_sh)[BLOCK_SIZE_Y][BLOCK_SIZE_X ] = *reinterpret_cast<TC (*)[BLOCK_SIZE_Y][BLOCK_SIZE_X ]> (C_arr.addr());

        
        uint32_t num_blocks = (N + SUBBLOCK_SIZE-1) / SUBBLOCK_SIZE; 
    
        for (uint32_t block_num = 0; block_num < num_blocks; block_num ++) { 

            // Load a MxN submatrix from A in DRAM into 
            // tile group shared memory and transpose it
            memcpy_subblock_to_shmem<TG_DIM_X, TG_DIM_Y,
                                     SUBBLOCK_SIZE, BLOCK_SIZE_Y, STRIPE_SIZE>
                                     (A, A_sh, M, N,
                                      __bsg_tile_group_id_y, block_num);

            // Load a NxP submatrix from B in DRAM into 
            // tile group shared memory and transpose it
            memcpy_subblock_to_shmem_transposed<TG_DIM_X, TG_DIM_Y,
                                                BLOCK_SIZE_X, SUBBLOCK_SIZE, STRIPE_SIZE>
                                                (B, B_sh, N, P,
                                                 block_num, __bsg_tile_group_id_x);
            
            barrier.sync();

            // Perform submatrix multiplication in 
            // tile group shared memory            
            subblock_shmem_matrix_mul_transposed<TG_DIM_X, TG_DIM_Y,
                                                 BLOCK_SIZE_X, BLOCK_SIZE_Y,
                                                 SUBBLOCK_SIZE, STRIPE_SIZE>
                                                 (A_sh, B_sh, C_sh,
                                                  M, N, P, block_num);
            
            barrier.sync();
        }

        // Store the MxP submatrix multiplication result
        // from tile group shared memory into C in DRAM
        memcpy_shmem_to_subblock<TG_DIM_X, TG_DIM_Y,
                                 BLOCK_SIZE_X, BLOCK_SIZE_Y, STRIPE_SIZE>
                                 (C, C_sh, M, P,
                                  __bsg_tile_group_id_y, __bsg_tile_group_id_x); 
        
        barrier.sync();

        return 0;
    }


extern "C" {
    int  __attribute__ ((noinline)) kernel_matrix_mul_shared_mem_hard(float *A, float *B, float *C,
                                                                      uint32_t A_HEIGHT,
                                                                      uint32_t A_WIDTH,
                                                                      uint32_t B_WIDTH,
                                                                      uint32_t block_size_y,
                                                                      uint32_t block_size_x) {
        int rc;
        bsg_cuda_print_stat_kernel_start();

        rc = group_matrix_multiply <TEMPLATE_TG_DIM_X,
                                    TEMPLATE_TG_DIM_Y,
                                    TEMPLATE_BLOCK_SIZE_X,
                                    TEMPLATE_BLOCK_SIZE_Y,
                                    TEMPLATE_SUBBLOCK_SIZE,
                                    TEMPLATE_STRIPE_SIZE>  (A, B, C,
                                                            A_HEIGHT,
                                                            A_WIDTH,
                                                            B_WIDTH);

        barrier.sync();

        bsg_cuda_print_stat_kernel_end();

        return rc;
    }
}
