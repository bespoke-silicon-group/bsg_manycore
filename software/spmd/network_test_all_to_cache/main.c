//  TEST DESCRIPTION
//  Every tiles writes to DRAM M times.
//  The origin tile reads all of them back, and validate.
//  this tests all routing paths between tiles to caches, and congestions in the network.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
#define N (bsg_tiles_X*bsg_tiles_Y)
#define M 64

// Tiles write to this array.
int data[N*64] __attribute__ ((section (".dram"))) = {0};


int main()
{

  // set tiles
  bsg_set_tile_x_y();

  
  // Everyone writes to DRAM.
  // With a stride that is equal to the number of tiles.
  // set the data to the index of the array.
  for (int i = 0; i < M; i++)
  {
    int idx = (N*i) + __bsg_id;
    data[idx] = idx;
  }


  // join barrier
  bsg_fence();
  bsg_tile_group_barrier(&r_barrier, &c_barrier);  


  // validated by origin tile.
  if (__bsg_id == 0) 
  {
    // every data in the array needs to match the index.
    for (int i = 0; i < N*M; i++)
    {
      if (i != data[i]) bsg_fail();
    }

    bsg_finish();
  }
  else
  {
    bsg_wait_while(1);
  }


}

