// prefetch bandwidth test


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

// number of tiles used
#define N (bsg_tiles_X*bsg_tiles_Y)
// number of cache lines fetched by each tile
#define M (16*65536/bsg_tiles_X/bsg_tiles_Y/VCACHE_BLOCK_SIZE_WORDS)

// Tiles write to this array.
int data[1] __attribute__ ((section (".dram"))) = {0};


int main()
{

  // set tiles
  bsg_set_tile_x_y();


  // Everyone prefetch data from DRAM to vcache.
  int * data_ptr = &data[__bsg_id * VCACHE_BLOCK_SIZE_WORDS];
  int stride = N*VCACHE_BLOCK_SIZE_WORDS;
  int i = 0;

  while (i < M) {
    asm volatile ("lw x0, 0(%[data_ptr])" : : [data_ptr] "r" (data_ptr));
    data_ptr = data_ptr + stride;
    i++;
  }

  // fence
  bsg_fence();


  bsg_finish();

  bsg_wait_while(1);
}

