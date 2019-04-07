//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_add(int *a, int *b, int *c, int n) {
  for (int i = 0; i < n; i++) {
  	c[i] = a[i] + b[i];
  }
  bsg_finish_x(IO_X_INDEX);
  return 0;
}
