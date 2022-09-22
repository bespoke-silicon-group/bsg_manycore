#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

#ifndef ITERS
#error "define ITERS"
#endif

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

volatile int data __attribute__((section(".dram"))) = 0;

int mtx __attribute__((section(".dram"))) = 0;

static void acquire()
{
    int v = 1;
    do {
        v = bsg_amoswap_aq(&mtx, 1);
    } while (v != 0);
}

static void release()
{
    bsg_amoswap_rl(&mtx, 0);
}

int main()
{

  bsg_set_tile_x_y();

  for (int i = 0; i < ITERS; i++) {
      acquire();
      data += 1;
      release();
  }

  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  if (bsg_x == 0 && bsg_y == 0) {
      bsg_print_int(data);
      if (data != ITERS*bsg_tiles_X*bsg_tiles_Y)
          bsg_fail();
      else
          bsg_finish();
  }

  bsg_wait_while(1);
}
