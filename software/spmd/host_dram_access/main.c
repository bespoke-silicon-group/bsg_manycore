
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


int main()
{
  bsg_set_tile_x_y();
  int data[4] = {0x142, -100, 10, 1};

  if (__bsg_x == 0 && __bsg_y == 0)
  {
    for (int i = 0; i < 4; i++)
    {
      bsg_host_dram_store(i<<2, data[i]);
    }


    int load_val[4] = {0};

    for (int i =0; i < 4; i++)
    {
      bsg_host_dram_load(i<<2, load_val[i]);
    }

    for (int i = 0; i < 4; i++)
    {
      if (data[i] != load_val[i])
      {
        bsg_printf("i=%d, expected=%d, actual=%d\n", i, data[i], load_val[i]);
        bsg_fail();
      }
    }
    
    bsg_finish();
  }

  bsg_wait_while(1);
}

