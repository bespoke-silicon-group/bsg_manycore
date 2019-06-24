#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
#include "bsg_barrier.h"

// for 4x4 manycore
#define BLOCK_SIZE 8
#define TAG_OFFSET 13
#define X_CORD_OFFSET 29

bsg_barrier my_barrier = BSG_BARRIER_INIT(0, 3, 0, 0);

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_y == 0)
  {

    if (__bsg_x != 0)
    {
      for (int b = 0; b < BLOCK_SIZE; b++)
      {
        int dram_addr[64] = {0};

        // calculate addresses
        for (int t = 0; t < 64; t++)
        {
          dram_addr[t] = (t<<TAG_OFFSET) + (b<<2) + (__bsg_x << X_CORD_OFFSET);
        }

        // store
        for (int t = 0; t < 64; t++)
        {
          bsg_dram_store(dram_addr[t], dram_addr[t]);
        }

        // load and validate
        for (int t = 0; t < 64; t++)
        {
          int dram_data = -1;

          bsg_dram_load(dram_addr[t], dram_data);

          if (dram_addr[t] != dram_data)
          {
            bsg_fail();
          }
        }

      }
    }  

    bsg_barrier_wait(&my_barrier, 0, 0);

    bsg_finish();
  }

  bsg_wait_while(1);
}

