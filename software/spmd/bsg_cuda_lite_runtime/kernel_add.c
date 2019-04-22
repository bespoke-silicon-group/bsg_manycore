//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_add(int *a, int *b, int *c, int n) {
  int id = bsg_x_y_to_id(__bsg_x, __bsg_y);
  for (int i = (id * n); i < (id * n + n); i++) {
  	c[i] = a[i] + b[i];
  }
  return 0;
}
