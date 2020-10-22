//  TEST DESCRIPTION
//  Every tile writes its id on DMEM of every tile. (each has unique address on DMEM)
//  and then every tile reads what other tiles wrote to validate.
//  this tests all routing paths between tiles and congestions in the network.
//  This test works as long as 'data' fits in dmem.


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
#define N (bsg_tiles_X*bsg_tiles_Y)



int main()
{
  // this array will be written by every tile with remote store.
  volatile int data[N] = {0};

  bsg_set_tile_x_y();
  
  // everyone writes to each other
  for (int x = 0; x < bsg_tiles_X; x++)
  {
    for (int y = 0; y < bsg_tiles_Y; y++)
    {
      // use your id as an index and store your id.
      bsg_remote_store(x, y, &data[__bsg_id], __bsg_id);
    }
  }

  // join barrier
  bsg_fence();
  bsg_tile_group_barrier(&r_barrier, &c_barrier);  

  // validate
  // data in this array should match the index.
  for (int i = 0; i < __bsg_id; i++)
  {
    if (i != data[i]) bsg_fail();
  }

  bsg_tile_group_barrier(&r_barrier, &c_barrier);  
  
  if (__bsg_id == 0) 
  {
    bsg_finish();
  }
  else
  {
    bsg_wait_while(1);
  }


}

