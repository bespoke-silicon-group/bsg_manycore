/**
 *  quicktouch
 *
 *  one tile writes some value to the first word of data_mem of all the other tiles,
 *  and validates reading back.
 *  this tile also computes some floating-point multiply-add value and store
 *  in the first word of each vcache, and it reads them back to validate.
 *
 *  This is a quick smoke test for gate-level simulation.
 *
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define VCACHE_BLOCK_SIZE_IN_WORDS 8

float data __attribute__ ((section (".dram"))) = {0};


int main()
{

  int remote_tile_store_val[bsg_global_X*(bsg_global_Y-1)];
  int remote_tile_load_val[bsg_global_X*(bsg_global_Y-1)];
  int my_int;

  // store a calculated val in each tile's dmem
  for (int x = 0; x < bsg_global_X; x++)
  {
    for (int y = 0; y < bsg_global_Y-1; y++)
    {
      int id = x+(y*bsg_global_X);
      remote_tile_store_val[id] = 0xdead+x+y;
      bsg_remote_store(x, y, &my_int, remote_tile_store_val[id]);

    }
  }
  
  // load the stored vals from tiles and  put them in local dmem
  for (int x = 0; x < bsg_global_X; x++)
  {
    for (int y = 0; y < bsg_global_Y-1; y++)
    {
      int id = x+(y*bsg_global_X);
      bsg_remote_load(x, y, &my_int, remote_tile_load_val[id]);
    }
  }

  // validate
  for (int id = 0; id < bsg_global_X*(bsg_global_Y-1); id++)
  {
    if (remote_tile_load_val[id] != remote_tile_store_val[id])
      bsg_fail();
  }


  // first half of array = bot vcache
  // second half of array = top vcache
  float vcache_store_val[bsg_global_X*2];
  float vcache_load_val[bsg_global_X*2];
  
  // store the float val to each vcache.
  float a = 1.1;
  float c = -0.32;

  float *dram_ptr = &data;
  for (int x = 0; x < 2*bsg_global_X; x++)
  {
    float b = (float) x;
    vcache_store_val[x] = (a*b)+c;
    dram_ptr[VCACHE_BLOCK_SIZE_IN_WORDS*x] = vcache_store_val[x];
  }

  // load the float vals from the vcaches.
  float temp;
  for (int x = 0; x < 2*bsg_global_X; x++)
  {
    temp = dram_ptr[VCACHE_BLOCK_SIZE_IN_WORDS*x];
    vcache_load_val[x] = temp;
  }

  // validate
  for (int x = 0; x < bsg_global_X*2; x++)
  {
    if (vcache_load_val[x] != vcache_store_val[x])
      bsg_fail();
  }



  for (int i = 0; i < 32; i++) {
    bsg_print_int(i);
  } 

  bsg_finish();
  
  bsg_wait_while(1);
}

