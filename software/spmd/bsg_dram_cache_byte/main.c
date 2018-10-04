/**
 *  bsg_dram_cache_byte.c
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier.h"
#include "bsg_mutex.h"

#define CACHE_NUM_SET 256
#define CACHE_NUM_WAY 2
#define TAG_MEM_MASK 0x07ffc000

void clear_block(int id)
{
  for (int i = 0; i < 8; i++) 
  {
    bsg_remote_store(id, 1, i << 2, 0);
  }
  int read_val;

  for (int i = 0; i < 8; i++)
  {      
    bsg_remote_load(id, 1, i << 2, read_val);
    if (read_val != 0)
    {
      bsg_fail_x(2);
    }
  }
}

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x, bsg_y);

  if (id == 0) 
  {
    // clear tag mem in cache.
    for (int i = 0; i < CACHE_NUM_SET*CACHE_NUM_WAY; i++) 
    {
      bsg_remote_store(id, 1, TAG_MEM_MASK + (i<<5), 0);
    }

   
    // read val 
    int read_val;
   
    // clear mem 
    clear_block(id);

    // write some byte-sized data
    bsg_remote_store_uint8(0, 1, 0, 0xef);
    bsg_remote_store_uint8(0, 1, 2, 0xad);
    bsg_remote_store_uint8(0, 1, 1, 0xbe);
    bsg_remote_store_uint8(0, 1, 3, 0xde);
    
    bsg_remote_load(id, 1, 0, read_val);
    if (read_val != 0xdeadbeef)
    {
      bsg_fail_x(2);
    }
   
    clear_block(id);
    
    bsg_remote_store_uint16(0, 1, 4, 0xbeef);
    bsg_remote_store_uint16(0, 1, 6, 0xdead);
    read_val = 0xffffffff;

    bsg_remote_load(0, 1, 4, read_val);
    if (read_val != 0xdeadbeef)
    {
      bsg_fail_x(2);
    }

    read_val = 0;
    bsg_remote_store(0, 1, 8, 0xffffffff);
    bsg_remote_store_uint16(0, 1, 8, 0xabcd);
    bsg_remote_store_uint8(0, 1, 8, 0xaa);
    bsg_remote_store_uint16(0, 1, 10, 0xcccc);
    bsg_remote_store_uint8(0, 1, 11, 0x77);
    
    bsg_remote_load(0, 1, 8, read_val);
    if (read_val != 0x77ccabaa)
    {
      bsg_fail_x(2);
    }

    bsg_finish_x(2);
  }
  else
  {
    bsg_wait_while(1);
  }
}
