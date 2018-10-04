/**
 *  bsg_dram_cache_evict.c
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier.h"
#include "bsg_mutex.h"

#define CACHE_NUM_SET 256
#define CACHE_NUM_WAY 2
#define TAG_MEM_MASK 0x07ffc000


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

    int tag_val;
    int read_val;

    bsg_remote_store(0, 1, 0x00000000, 0xcccccccc);
    bsg_remote_store(0, 1, 0x00000000 | 0x1000000, 0xdddddddd);

    // check tags
    tag_val = 0xffffffff;
    bsg_remote_load(0, 1, 0x0000 | TAG_MEM_MASK, tag_val);
    if (tag_val != 0)
    {
      bsg_fail_x(2);
    }

    tag_val = 0xffffffff;
    bsg_remote_load(0, 1, 0x2000 | TAG_MEM_MASK, tag_val);
    if (tag_val != 0x1000000) 
    {
      bsg_fail_x(2);
    }

    bsg_remote_load(0, 1, 0x00000000, read_val);
    if (read_val != 0xcccccccc)
    {
      bsg_fail_x(2);
    }

    bsg_remote_store(0, 1, 0x00000000 | 0x2000000, 0xeeeeeeee);

    // check tags
    tag_val = 0xffffffff;
    bsg_remote_load(0, 1, 0x0000 | TAG_MEM_MASK, tag_val);
    if (tag_val != 0)
    {
      bsg_fail_x(2);
    }

    tag_val = 0xffffffff;
    bsg_remote_load(0, 1, 0x2000 | TAG_MEM_MASK, tag_val);
    if (tag_val != 0x2000000)
    {
      bsg_fail_x(2);
    }

    bsg_remote_load(0, 1, 0x00000000 | 0x2000000, read_val);
    if (read_val != 0xeeeeeeee)
    {
      bsg_fail_x(2);
    }

    bsg_remote_store(0, 1, 0x00000000 | 0x1000000, 0x99999999);
    
    // check_tags
    tag_val = 0xffffffff;
    bsg_remote_load(0, 1, 0x0000 | TAG_MEM_MASK, tag_val);
    if (tag_val != 0x1000000)
    {
      bsg_fail_x(2);
    }

    bsg_remote_load(0, 1, 0x2000 | TAG_MEM_MASK, tag_val);
    if (tag_val != 0x2000000)
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
