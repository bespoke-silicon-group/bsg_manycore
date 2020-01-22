#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int __attribute__ ((noinline)) add(int* a, int* b, int* c) {
  if(__bsg_id == 0) {
    *c = *a +* b;
    return 0;
  } else {
    bsg_wait_while(1);
  }
}
