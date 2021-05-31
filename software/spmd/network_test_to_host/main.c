
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 64

int main()
{
  for (int i = 0; i < N; i++) {
    bsg_print_int(i);
  } 

  bsg_finish();
  bsg_wait_while(1);
}

