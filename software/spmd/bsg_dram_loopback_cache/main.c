//====================================================================
// bsg_dram_loopback_cache.c
// 09/11/2018, tommy
//====================================================================
// This program will write and then read data from dram
//

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier.h"
#include "bsg_mutex.h"

#define VECTOR_LEN 8
#define DRAM_Y_CORD 1
#define CACHE_NUM_SET 512
#define CACHE_NUM_WAY 2
#define TAG_MEM_BOUNDARY 0x04000000

int data_vect[2][VECTOR_LEN] = {
  {0, 1, 4, 9, 16, 25, 36, 49},
  {2, 3, 5, 7, 11, 13, 17, 19}
};

int addr_vect[VECTOR_LEN] = {0*4, 1*4, 2*4, 3*4, 4*4, 5*4, 6*4, 7*4};
bsg_barrier tile0_barrier = BSG_BARRIER_INIT(0, 1, 0 ,0); 

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x, bsg_y);

  if (id < 2) 
  {
    // clear tag mem in cache
    for (int i = 0; i < CACHE_NUM_SET*CACHE_NUM_WAY; i++) 
    {
      bsg_remote_store(id, DRAM_Y_CORD, TAG_MEM_BOUNDARY + (i<<5), 0);
    }

    // write the vector.
    for (int i = 0; i < VECTOR_LEN; i++)
    {
      bsg_remote_store(id, DRAM_Y_CORD, addr_vect[i], data_vect[id][i]);
    }

    // write zero vectors for the same set but different tags,
    // so that the first vector is flushed and written to DRAM.
    for (int i = 0; i < VECTOR_LEN; i++)
    {
      bsg_remote_store(id, DRAM_Y_CORD, addr_vect[i] | 0x4000, 0xffffffff);
    }

    for (int i = 0; i < VECTOR_LEN; i++)
    {
      bsg_remote_store(id, DRAM_Y_CORD, addr_vect[i] | 0x8000, 0xffffffff);
    }

    int read_value;
    for (int j = VECTOR_LEN-1; j >= 0; j--)
    {
      bsg_remote_load(id, DRAM_Y_CORD, addr_vect[j], read_value);

      bsg_remote_ptr_io_store(0, addr_vect[j], read_value);

      if (read_value != data_vect[id][j])
      {
        bsg_remote_ptr_io_store(0, 0x0, read_value);
        bsg_remote_ptr_io_store(0, 0x0, data_vect[id][j]);
        bsg_fail();
      }
    }

    bsg_barrier_wait(&tile0_barrier, 0, 0);
  }

  if (id == 0)
  {
    bsg_finish_x(2);
  }
  else
  {
    bsg_wait_while(1);
  }
}
