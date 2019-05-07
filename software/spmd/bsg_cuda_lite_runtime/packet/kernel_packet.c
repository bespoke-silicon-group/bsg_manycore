//This kernel sends an IO packet from each tile with the __bsg_id 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

/*
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h" 

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
*/

int  __attribute__ ((noinline)) kernel_packet() {
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, __bsg_id);
  //bsg_tile_group_barrier(&r_barrier, &c_barrier);
  return 0;
}
