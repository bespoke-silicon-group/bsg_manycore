// each counter is associated with a lock.
// each tile grabs one lock at a time and increments the counter.
// the origin tile in the end validates that all the counters have been incremented by the total number of the tiles.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
#define N 16

int lock[N] __attribute__ ((section (".dram"))) = {0};
int data[N] __attribute__ ((section (".dram"))) = {0};

void atomic_inc()
{
  for (int i = 0; i < N; i++) 
  {
    // grab lock
    int lock_val = 1;

    do {
      lock_val = bsg_amoswap_aq(&lock[i], 1);
    } while (lock_val != 0); 

    // critical region
    int local_data = data[i];
    data[i] = local_data+1; 


    // release
    bsg_amoswap_rl(&lock[i], 0);
  }

  // join barrier
  bsg_fence();
  bsg_tile_group_barrier(&r_barrier, &c_barrier);  

  // validate
  if (__bsg_id == 0)
  {
    int failed = 0;

    for (int i = 0; i < N; i++)
    {
      if (data[i] != (bsg_tiles_X*bsg_tiles_Y)) failed = 1;
    }
  
    if (failed == 0) 
    {
      bsg_finish();
    } 
    else
    {
      bsg_fail();
    }
  }
}

int main()
{

  bsg_set_tile_x_y();

  atomic_inc();

  bsg_wait_while(1);
}

