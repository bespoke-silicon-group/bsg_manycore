/*
  Description:
  Test to check if atomic adds work
  Every tile atomically updates the 2 counter variables in DRAM using 2 methods and tile 0 checks if the value is the same using both techniques and is equal to the sum of bsg_x_id * bsg_y_id
*/

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex2.hpp"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int data __attribute__((section(".dram"))) = 0;

bsg_mutex2_t mtx __attribute__((section(".dram")));

int main()
{

  bsg_set_tile_x_y();

  bsg_mutex_node_t lcl, *lclptr;
  lclptr = (bsg_mutex_node_t*)bsg_tile_group_remote_ptr(int, bsg_x, bsg_y, &lcl);

  bsg_mutex2_acquire(&mtx, lclptr);
  bsg_print_hexadecimal(0xdeadbeef);
  bsg_mutex2_release(&mtx, lclptr);
  
  bsg_finish();

  bsg_wait_while(1);
}
