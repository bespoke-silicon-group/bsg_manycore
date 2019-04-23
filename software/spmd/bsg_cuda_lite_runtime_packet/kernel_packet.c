//This kernel adds 2 vectors 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_packet() {
  int id = bsg_x_y_to_id(__bsg_x, __bsg_y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x8000, id);
  return 0;
}
