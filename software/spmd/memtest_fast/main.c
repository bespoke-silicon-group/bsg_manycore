#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define VCACHE_BLOCK_SIZE_IN_WORDS 8
#define VCACHE_SETS 64
#define NUM_VCACHE 32
int data __attribute__ ((section (".dram"))) = {0};

#define N 8
int cache_ids[N] = {0,1,14,15,16,17,30,31};

int main()
{
  // store
  int *dram_ptr = &data;
  for (int i = 0; i < 5; i++) {
    for (int x = 0; x < N; x++) {
      int cache_id = cache_ids[x];
      int addr = (cache_id*VCACHE_BLOCK_SIZE_IN_WORDS) + (NUM_VCACHE*VCACHE_BLOCK_SIZE_IN_WORDS*VCACHE_SETS*i);
      dram_ptr[addr] = addr;
    }
  }

  //bsg_fence();

  // load
  dram_ptr = &data;
  int local_addr[N];
  int load_data[N];
  for (int i = 0; i < 5; i++) {

    for (int x = 0; x < N; x++) {
      int cache_id = cache_ids[x];
      int addr = (cache_id*VCACHE_BLOCK_SIZE_IN_WORDS) + (NUM_VCACHE*VCACHE_BLOCK_SIZE_IN_WORDS*VCACHE_SETS*i);
      local_addr[x] = addr;
      load_data[x] = dram_ptr[addr];
    }

    for (int x = 0; x < N; x++) {
      if (local_addr[x] != load_data[x]) {
        bsg_fail();
        bsg_wait_while(1);
      }
    }
  }
  

  bsg_finish();
  bsg_wait_while(1);
}

