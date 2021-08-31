#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"
#include "bsg_mcs_mutex.hpp"

#ifndef ITERS
#error "define ITERS"
#endif

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

volatile int data __attribute__((section(".dram"))) = 0;

bsg_mcs_mutex_t mtx __attribute__((section(".dram")));

int main()
{

  bsg_set_tile_x_y();

  bsg_mcs_mutex_node_t lcl, *lclptr;
  lclptr = (bsg_mcs_mutex_node_t*)bsg_tile_group_remote_ptr(int, bsg_x, bsg_y, &lcl);

  for (int i = 0; i < ITERS; i++) {
      bsg_mcs_mutex_acquire(&mtx, lclptr);
      data += 1;
      bsg_mcs_mutex_release(&mtx, lclptr);
  }

  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  if (bsg_x == 0 && bsg_y == 0) {
      bsg_print_int(data);
      if (data != ITERS * bsg_tiles_X * bsg_tiles_Y)
          bsg_fail();
      else
          bsg_finish();
  }

  bsg_wait_while(1);
}
