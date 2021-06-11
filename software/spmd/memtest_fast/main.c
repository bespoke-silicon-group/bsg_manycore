#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define VCACHE_BLOCK_SIZE_IN_WORDS 8
#define VCACHE_SETS 64
#define NUM_VCACHE 32
int data __attribute__ ((section (".dram"))) = {0};

// testing only the subsets of vcaches to speed up simulation, but testing enough to test every wh ruche link.
#define N 8
int cache_ids[N] = {0,1,14,15,16,17,30,31};

// stride within a vcache
#define STRIDE (NUM_VCACHE*VCACHE_BLOCK_SIZE_IN_WORDS*VCACHE_SETS)

int main()
{
  // for each vcache, we are storing five times (assume 4-way assoc) to the same set, but different tags, to cause fill and evict.
  int local_addr[N][5];

  int i = 0;

  // store
  int *dram_ptr = &data;
  for (int x = 0; x < N; x++) {
    int cache_id = cache_ids[x];
    int addr = (cache_id*VCACHE_BLOCK_SIZE_IN_WORDS);
 
    // unrolling five times 
    dram_ptr[addr] = addr;
    local_addr[x][0] = addr;
    addr += STRIDE;

    dram_ptr[addr] = addr;
    local_addr[x][1] = addr;
    addr += STRIDE;

    dram_ptr[addr] = addr;
    local_addr[x][2] = addr;
    addr += STRIDE;

    dram_ptr[addr] = addr;
    local_addr[x][3] = addr;
    addr += STRIDE;

    dram_ptr[addr] = addr;
    local_addr[x][4] = addr;

    bsg_print_int(i++);
  }

  // load
  dram_ptr = &data;

  for (int x = 0; x < N; x++) {
    register int load_data[5];
    int cache_id = cache_ids[x];
    int addr = (cache_id*VCACHE_BLOCK_SIZE_IN_WORDS);

    // unrolling remote loads in parallel
    load_data[0] = dram_ptr[addr];
    addr += STRIDE;
    load_data[1] = dram_ptr[addr];
    addr += STRIDE;
    load_data[2] = dram_ptr[addr];
    addr += STRIDE;
    load_data[3] = dram_ptr[addr];
    addr += STRIDE;
    load_data[4] = dram_ptr[addr];

    if (load_data[0] != local_addr[x][0]) bsg_fail();
    if (load_data[1] != local_addr[x][1]) bsg_fail();
    if (load_data[2] != local_addr[x][2]) bsg_fail();
    if (load_data[3] != local_addr[x][3]) bsg_fail();
    if (load_data[4] != local_addr[x][4]) bsg_fail();

    bsg_print_int(i++);
  }


  bsg_finish();
  bsg_wait_while(1);
}

