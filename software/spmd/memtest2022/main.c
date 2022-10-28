// This tests no-write-allocate cache with evicting partially written cache blocks.
// Each tile has M arrays with size N to partially write over.
// At the end, each tile validates that written values are persistent and the unwritten part of memory remain zero.


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 3500
int data[N*bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};


int main()
{
  bsg_set_tile_x_y();


  // Flush cache by prefetching
  int *myarray = &data[(__bsg_id*N)];

  for (int j = 0; j < N; j += 8) {
    int *addr = &myarray[j];
    asm volatile ("lw x0, 0(%[addr])" \
              : \
              : [addr] "r" (addr));
  }
  

  // Write
  for (int j = 0; j < N; j++) {
    // only write to some of the multiples
    if (((j % 7) == 0) || ((j % 13) == 0)) {
      int write_val = __bsg_id + j;
      myarray[j] = write_val; 
    }
  }


  // Validate
  for (int j = 0; j < N; j+=2) {
    int valid_val;
    if (((j % 7) == 0) || ((j % 13) == 0)) {
      valid_val = __bsg_id + j;
    } else {
      valid_val = 0;
    }
  
    int read_val = myarray[j];
    if (valid_val != read_val) {
      bsg_fail();
    }
  }

  // wait for all tiles to send finish.
  bsg_finish();
  bsg_wait_while(1);
}

