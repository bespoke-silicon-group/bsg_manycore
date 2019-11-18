/*!
 * This kernel reads data from DRAM into tile memory. 
 */

#include <stddef.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int  __attribute__ ((noinline)) kernel_memread_reg_base(volatile int *src, 
                                                        size_t nels, int *res) {
        bsg_cuda_print_stat_start(1);
        // Load all the data (but drop it on the floor)
        for (size_t ei = 0; ei < nels; ++ei) {
                src[ei];
        }
        // Store the last value in the array into res to demonstrate
        // that the program executed successfully.
        *res = src[nels - 1];
        bsg_cuda_print_stat(1);
        bsg_tile_group_barrier (&r_barrier, &c_barrier); 
        bsg_cuda_print_stat_end(1);
        return 0;
}

int  __attribute__ ((noinline)) kernel_memread_reg_2(volatile int *src, 
                                                      size_t nels, int *res) {
        bsg_cuda_print_stat_start(2);
        // Load all the data (but drop it on the floor)
#pragma GCC unroll 2
        for (size_t ei = 0; ei < nels; ++ei) {
                src[ei];
        }
        // Store the last value in the array into res to demonstrate
        // that the program executed successfully.
        *res = src[nels - 1];
        bsg_cuda_print_stat(2);
        bsg_tile_group_barrier (&r_barrier, &c_barrier); 
        bsg_cuda_print_stat_end(2);
        return 0;
}

int  __attribute__ ((noinline)) kernel_memread_reg_4(volatile int *src, 
                                                      size_t nels, int *res) {
        bsg_cuda_print_stat_start(4);
        // Load all the data (but drop it on the floor)
#pragma GCC unroll 4
        for (size_t ei = 0; ei < nels; ++ei) {
                src[ei];
        }
        // Store the last value in the array into res to demonstrate
        // that the program executed successfully.
        *res = src[nels - 1];
        bsg_cuda_print_stat(4);
        bsg_tile_group_barrier (&r_barrier, &c_barrier); 
        bsg_cuda_print_stat_end(4);
        return 0;
}

int  __attribute__ ((noinline)) kernel_memread_reg_8(volatile int *src, 
                                                      size_t nels, int *res) {
        bsg_cuda_print_stat_start(8);
        // Load all the data (but drop it on the floor)
#pragma GCC unroll 8
        for (size_t ei = 0; ei < nels; ++ei) {
                src[ei];
        }
        // Store the last value in the array into res to demonstrate
        // that the program executed successfully.
        *res = src[nels - 1];
        bsg_cuda_print_stat(8);
        bsg_tile_group_barrier (&r_barrier, &c_barrier); 
        bsg_cuda_print_stat_end(8);
        return 0;
}

int  __attribute__ ((noinline)) kernel_memread_reg_16(volatile int *src, 
                                                      size_t nels, int *res) {
        bsg_cuda_print_stat_start(16);
        // Load all the data (but drop it on the floor)
#pragma GCC unroll 16
        for (size_t ei = 0; ei < nels; ++ei) {
                src[ei];
        }
        // Store the last value in the array into res to demonstrate
        // that the program executed successfully.
        *res = src[nels - 1];
        bsg_cuda_print_stat(16);
        bsg_tile_group_barrier (&r_barrier, &c_barrier); 
        bsg_cuda_print_stat_end(16);
        return 0;
}

int  __attribute__ ((noinline)) kernel_memread_reg_32(volatile int *src, 
                                                      size_t nels, int *res) {
        bsg_cuda_print_stat_start(32);
        // Load all the data (but drop it on the floor)
#pragma GCC unroll 32
        for (size_t ei = 0; ei < nels; ++ei) {
                src[ei];
        }
        // Store the last value in the array into res to demonstrate
        // that the program executed successfully.
        *res = src[nels - 1];
        bsg_cuda_print_stat(32);
        bsg_tile_group_barrier (&r_barrier, &c_barrier); 
        bsg_cuda_print_stat_end(32);
        return 0;
}
