#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//#define N 536870912
#define N 32768
#define VCACHE_LINE_WORDS 8

int *dram_ptr = (int *) 0x80000000;

int main()
{
  bsg_set_tile_x_y();
  
  int stop = N/(bsg_tiles_Y*bsg_tiles_X);
  int* ptr = &dram_ptr[__bsg_id*stop];

  // store;
  bsg_unroll(1)
  for (int i = 0; i < stop; i+=VCACHE_LINE_WORDS) {
    ptr[i+0] = i+0;
    ptr[i+1] = i+1;
    ptr[i+2] = i+2;
    ptr[i+3] = i+3;
    ptr[i+4] = i+4;
    ptr[i+5] = i+5;
    ptr[i+6] = i+6;
    ptr[i+7] = i+7;
  }

  // load;
  int words[VCACHE_LINE_WORDS];

  bsg_unroll(1)
  for (int i = 0; i < stop; i+=VCACHE_LINE_WORDS) {
    words[0] = ptr[i+0]; 
    words[1] = ptr[i+1]; 
    words[2] = ptr[i+2]; 
    words[3] = ptr[i+3]; 
    words[4] = ptr[i+4]; 
    words[5] = ptr[i+5]; 
    words[6] = ptr[i+6]; 
    words[7] = ptr[i+7]; 
    if (words[0] != i+0) bsg_fail();
    if (words[1] != i+1) bsg_fail();
    if (words[2] != i+2) bsg_fail();
    if (words[3] != i+3) bsg_fail();
    if (words[4] != i+4) bsg_fail();
    if (words[5] != i+5) bsg_fail();
    if (words[6] != i+6) bsg_fail();
    if (words[7] != i+7) bsg_fail();
  }

  bsg_finish();

  bsg_wait_while(1);
}

