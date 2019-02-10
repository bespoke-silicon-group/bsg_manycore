//====================================================================
// bsg_dram_loopback_cache.c
// 09/11/2018, tommy
//====================================================================
// this program will write and then read data from dram
//

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define CACHE_NUM_SET 256
#define CACHE_NUM_WAY 2

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x, bsg_y);

  if (id == 0)
  {
    bsg_dram_store(0, 1234);
    int val;
    bsg_dram_load(0, val);
    if (val == 1234) 
    {
      bsg_finish_x(IO_X_INDEX);
    }
    else 
    {
      bsg_fail_x(IO_X_INDEX);
    }
  }
  else
  {
    bsg_wait_while(1);
  }
}
