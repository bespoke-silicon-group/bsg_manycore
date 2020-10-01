#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"

#define N 10

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> d_barrier;

int main()
{
  bsg_set_tile_x_y();
  
  int id = __bsg_id;

  for (int i = 0; i < N; i++)
  {
    if (id == 0) bsg_cuda_print_stat_start(0);
    d_barrier.sync();
    if (id == 0) bsg_cuda_print_stat_end(0);
  }

  if (id == 0) bsg_finish();

  bsg_wait_while(1);
}
