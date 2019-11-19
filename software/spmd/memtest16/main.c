#include "bsg_manycore.h"
#include "bsg_barrier.h"
#include "bsg_set_tile_x_y.h"

#define N (4096*1)

int data[N] __attribute__ ((section (".dram"))) = {0};

bsg_barrier barr = BSG_BARRIER_INIT(0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int main()
{

  bsg_set_tile_x_y();
  if (__bsg_x == 0 && __bsg_y == 0) 
  {
    bsg_print_stat(0);
  }
  bsg_barrier_wait(&barr, 0, 0);

  // everyone stores
  int i = __bsg_id;
  while (i < N) 
  {
    data[i] = i;
    i += bsg_tiles_X * bsg_tiles_Y;
  }

  // everyone loads
  i = __bsg_id;
  while (i < N)
  {
    int ld_val = data[i];
    if (ld_val != i) bsg_fail();
    i += bsg_tiles_X * bsg_tiles_Y;
  }

  bsg_barrier_wait(&barr, 0, 0);
  if (__bsg_x == 0 && __bsg_y == 0) 
  {
    bsg_print_stat(1);
    bsg_finish();
  }

  bsg_wait_while(1);
}

