#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
//#define BSG_BARRIER_DEBUG
#include "bsg_tile_group_barrier.h"


INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int main()
{
  bsg_set_tile_x_y();
  
  int id = __bsg_id;

  if (id == 0) bsg_cuda_print_stat_start(0);
  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  if (id == 0) bsg_cuda_print_stat_end(0);

  if (id == 0) bsg_cuda_print_stat_start(0);
  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  if (id == 0) bsg_cuda_print_stat_end(0);

  if (id == 0) bsg_cuda_print_stat_start(0);
  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  if (id == 0) bsg_cuda_print_stat_end(0);

  if (id == 0) bsg_cuda_print_stat_start(0);
  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  if (id == 0) bsg_cuda_print_stat_end(0);

  if (id == 0) {
    bsg_finish();
  }

  bsg_wait_while(1);
}
