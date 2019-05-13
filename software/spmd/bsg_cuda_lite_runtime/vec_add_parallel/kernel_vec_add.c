//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_vec_add(int *a, int *b, int *c, int array_size) {
  int id = __bsg_tile_group_id * __bsg_grid_size + __bsg_id;
  int block_size = array_size / (__bsg_grid_size * bsg_tiles_X * bsg_tiles_Y);

  for (int i = id * block_size; i < (id + 1) * block_size; i ++) {
    	c[i] = a[i] + b[i];
  }
  return 0;
}
