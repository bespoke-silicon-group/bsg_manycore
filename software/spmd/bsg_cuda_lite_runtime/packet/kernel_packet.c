//This kernel sends an IO packet from each tile with the __bsg_x/y __bsg_grp_org_x/y __bsg_id 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_packet() {
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x1000, __bsg_x);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, __bsg_y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x3000, __bsg_grp_org_x);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x4000, __bsg_grp_org_y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x5000, __bsg_id);
  return 0;
}
