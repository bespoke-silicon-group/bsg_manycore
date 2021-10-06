#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"

int main()
{

  bsg_set_tile_x_y();

  if (__bsg_x == 0 && __bsg_y == 0)
      bsg_finish();
  
  bsg_wait_while(1);
}
