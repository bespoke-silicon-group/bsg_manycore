#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define VCACHE_BLOCK_SIZE_IN_WORDS 8
#define VCACHE_SETS 64
#define NUM_VCACHE 32
int data __attribute__ ((section (".dram"))) = {0};


int main()
{
  // store
  int *dram_ptr = &data;
  for (int i = 0; i < 5; i++) {
    for (int x = 0; x < NUM_VCACHE; x++) {
      int addr = (x*VCACHE_BLOCK_SIZE_IN_WORDS) + (NUM_VCACHE*VCACHE_BLOCK_SIZE_IN_WORDS*VCACHE_SETS*i);
      dram_ptr[addr] = addr;
    }
  }

  // load
  *dram_ptr = &data;
  int local_addr[NUM_VCACHE];
  int load_data[NUM_VCACHE];
  for (int i = 0; i < 5; i++) {

    for (int x = 0; x < NUM_VCACHE; x++) {
      int addr = (x*VCACHE_BLOCK_SIZE_IN_WORDS) + (NUM_VCACHE*VCACHE_BLOCK_SIZE_IN_WORDS*VCACHE_SETS*i);
      local_addr[x] = addr;
      load_data[x] = dram_ptr[addr];
    }

    for (int x = 0; x < NUM_VCACHE; x++) {
      if (local_addr[x] != load_data[x]) {
        bsg_fail();
        bsg_wait_while(1);
      }
    }
  }
  

  bsg_finish();
  bsg_wait_while(1);
}

