#include "raw.h"
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdio.h>

void timebegin() {
  printf("At begin: \n");
  bsg_print_time();
}

void timeend() {
  printf("At end: \n");
  bsg_print_time();
}
