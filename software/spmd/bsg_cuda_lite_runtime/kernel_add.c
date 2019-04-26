//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int  __attribute__ ((noinline)) kernel_add(int *a, int *b, int *c, int n) {
  int id = bsg_x_y_to_id(__bsg_x, __bsg_y);
  for (int i = (id * n); i < (id * n + n); i++) {
  	c[i] = a[i] + b[i];
  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  }
  return 0;
}
