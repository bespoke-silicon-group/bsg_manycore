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

float dram_data __attribute__ ((section (".dram"))) = {0};
int my_int;

int main()
{

  int remote_tile_store_val[bsg_global_Y][bsg_global_X];

  // store a calculated val in each tile's dmem
  for (int y = 0; y < bsg_global_Y; y++) {
    for (int x = 0; x < bsg_global_X; x++) {
      int hash_val = 0xdead+x+y;
      remote_tile_store_val[y][x] = hash_val;
      bsg_remote_store(x, y, &my_int, hash_val);
    }
  }
  
  // load the stored vals from tiles and  put them in local dmem
  for (int y = 0; y < bsg_global_Y; y++) {
    for (int x = 0; x < bsg_global_X/8; x++) {
      register int local_hash[8];
      int curr_x = x*8;
      bsg_remote_load(curr_x++, y, &my_int, local_hash[0]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[1]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[2]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[3]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[4]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[5]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[6]);
      bsg_remote_load(curr_x++, y, &my_int, local_hash[7]);
      
      curr_x = x*8;
      if (local_hash[0] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[1] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[2] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[3] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[4] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[5] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[6] != remote_tile_store_val[y][curr_x++]) bsg_fail();
      if (local_hash[7] != remote_tile_store_val[y][curr_x++]) bsg_fail();
    }
  }


  // store the float val to each vcache.
  float vcache_store_val[bsg_global_X*2];
  float a = 1.1;
  float c = -0.32;

  float *dram_ptr = &dram_data;
  for (int x = 0; x < 2*bsg_global_X; x++) {
    float b = (float) x;
    float hash_val = (a*b)+c; 
    vcache_store_val[x] = hash_val;
    dram_ptr[VCACHE_BLOCK_SIZE_IN_WORDS*x] = hash_val;
  }

  // load the float val to validate
  // loop unroll by 8
  for (int x = 0; x < 2*bsg_global_X/8; x++) {
    register float local_hash[8];   
    int curr_x = x*8*VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[0] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[1] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[2] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[3] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[4] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[5] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[6] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;
    local_hash[7] = dram_ptr[curr_x];
    curr_x += VCACHE_BLOCK_SIZE_IN_WORDS;

    // validate
    curr_x = 8*x;
    if (local_hash[0] != vcache_store_val[curr_x+0]) bsg_fail();
    if (local_hash[1] != vcache_store_val[curr_x+1]) bsg_fail();
    if (local_hash[2] != vcache_store_val[curr_x+2]) bsg_fail();
    if (local_hash[3] != vcache_store_val[curr_x+3]) bsg_fail();
    if (local_hash[4] != vcache_store_val[curr_x+4]) bsg_fail();
    if (local_hash[5] != vcache_store_val[curr_x+5]) bsg_fail();
    if (local_hash[6] != vcache_store_val[curr_x+6]) bsg_fail();
    if (local_hash[7] != vcache_store_val[curr_x+7]) bsg_fail();
  }


  // send print ints to the host.
  for (int i = 0; i < 32; i++) {
    bsg_print_int(i);
  } 

  bsg_finish();
  bsg_wait_while(1);

}

