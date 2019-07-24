#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BLOCK_SIZE 8
#define INDEX 1024

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_x == 0 && __bsg_y == 0) 
  {

    for (int b = 0; b < BLOCK_SIZE; b++)
    {
      for (int i = 0; i < INDEX; i++)
      {
        int addr = (b<<2) + (i<<5);
        bsg_dram_store(addr, addr);
        int load_val = -1;
        bsg_dram_load(addr, load_val);
        if (load_val != addr)
          bsg_fail();
      }
    }


    /*
    while (i < NUM_SEQ)
    {
      bsg_dram_store(prn, prn);
      int load_val = -1;
      bsg_dram_load(prn,load_val);

      if (prn != load_val)
        bsg_fail();
      else
        bsg_printf("SEQ[%d]=%d\n", i, prn);
  
      // calculate next 30-bit prn
      // 
      
    }
*/
 

    bsg_finish();
  }

  bsg_wait_while(1);
}

