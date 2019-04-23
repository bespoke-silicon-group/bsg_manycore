//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_empty(int *a, int*b) {
  int id = bsg_x_y_to_id(__bsg_x, __bsg_y);
  return 0;
}
