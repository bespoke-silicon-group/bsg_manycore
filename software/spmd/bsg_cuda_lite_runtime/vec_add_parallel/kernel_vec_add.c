//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_vec_add(int *a, int *b, int *c, int n) {
  for (int i = (__bsg_id * n); i < (__bsg_id * n + n); i++) {
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x1000, a[i]);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, b[i]);
    	c[i] = a[i] + b[i];
  }

  return 0;
}
