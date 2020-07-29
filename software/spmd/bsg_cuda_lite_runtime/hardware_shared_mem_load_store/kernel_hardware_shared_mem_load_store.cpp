// * This kernel loads a memory block from DRAM into hardware
//   tile group shared memory, and stores it back to another 
//   array to DRAM to be compared.
// * Tile group dimensions are fixed at 4x4.

// TEMPLATE_TG_DIM_X/Y must be defined before bsg_manycore.h is
// included. bsg_tiles_X and bsg_tiles_Y must also be defined for
// legacy reasons, but they are deprecated.


#define TEMPLATE_TG_DIM_X 4
#define TEMPLATE_TG_DIM_Y 4
#define TEMPLATE_BLOCK_SIZE    1024
#define TEMPLATE_STRIPE_SIZE   1
#define bsg_tiles_X TEMPLATE_TG_DIM_X
#define bsg_tiles_Y TEMPLATE_TG_DIM_Y

#include <bsg_manycore.h>
#include "kernel_hardware_shared_mem_load_store.hpp"
#include <bsg_tile_group_barrier.hpp>
#include "bsg_shared_mem.hpp"

using namespace bsg_manycore;


bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;


template <int TG_DIM_X,
          int TG_DIM_Y,
          int BLOCK_SIZE,
          int STRIPE_SIZE,
          typename T>
    int __attribute__ ((noinline))
    hardware_shared_mem_load_store(T *A, T *B) {
    
        // Declare tile-group shared memory
        TileGroupSharedMem<T, BLOCK_SIZE, TG_DIM_X, TG_DIM_Y, STRIPE_SIZE> A_sh;
        
        for (int iter_x = __bsg_id; iter_x < BLOCK_SIZE; iter_x += TG_DIM_X * TG_DIM_Y) {
            A_sh[iter_x] = A[iter_x];
        }

        barrier.sync();

        for (int iter_x = __bsg_id; iter_x < BLOCK_SIZE; iter_x += TG_DIM_X * TG_DIM_Y) {
            B[iter_x] = A_sh[iter_x];
        }

        barrier.sync();

        return 0;
    }


extern "C" {
    int  __attribute__ ((noinline)) kernel_hardware_shared_mem_load_store(float *A,
                                                                          float *sum, 
                                                                          uint32_t WIDTH, 
                                                                          uint32_t block_size) {
        int rc;
        bsg_cuda_print_stat_kernel_start();

        rc = hardware_shared_mem_load_store <TEMPLATE_TG_DIM_X,
                                             TEMPLATE_TG_DIM_Y,
                                             TEMPLATE_BLOCK_SIZE,
                                             TEMPLATE_STRIPE_SIZE>  (A,
                                                                     sum);

        barrier.sync();

        bsg_cuda_print_stat_kernel_end();

        return rc;
    }
}
