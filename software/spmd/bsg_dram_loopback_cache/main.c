//====================================================================
// bsg_dram_loopback_cache.c
// 09/11/2018, tommy
//====================================================================
// this program will write and then read data from dram
//

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier.h"
#include "bsg_mutex.h"

#define VECTOR_LEN 8
#define CACHE_NUM_SET 256
#define CACHE_NUM_WAY 2

int data_vect[2][VECTOR_LEN] = {
  {0, 1, 4, 9, 16, 25, 36, 49},
  {2, 3, 5, 7, 11, 13, 17, 19}
};

bsg_barrier tile0_barrier = BSG_BARRIER_INIT(0, 1, 0 ,0); 

void test_store_stride(int id, int offset, int stride, int **data_vect)
{
  int addr_vect[VECTOR_LEN];

  // set up addr vector.
  for (int i = 0; i < VECTOR_LEN; i++)
  {
    addr_vect[i] = offset + (i*stride);
  }

  int x_coord_mask = id << 28;
  
  // write data vector.
  for (int i = 0; i < VECTOR_LEN; i++)
  {
    bsg_dram_store(x_coord_mask | addr_vect[i], data_vect[id][i]);
  }

  // write zero vectors for the same set but different tags,
  // so that the first vector is flushed and written to DRAM.
  for (int i = 0; i < VECTOR_LEN; i++)
  {
    bsg_dram_store(x_coord_mask | addr_vect[i] | 0x1000000, 0xffffffff); 
  }

  for (int i = 0; i < VECTOR_LEN; i++)
  {
    bsg_dram_store(x_coord_mask | addr_vect[i] | 0x2000000, 0xeeeeeeee); 
  }
  
  int read_val;
  for (int i = VECTOR_LEN-1; i >= 0; i--)
  {
    bsg_dram_load(x_coord_mask | addr_vect[i], read_val); 

    if (read_val != data_vect[id][i])
    {
      bsg_fail_x(2);
    }
  }
}

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x, bsg_y);

  if (id < 2) 
  {
    //// clear tag mem in cache.
    //int tag_addr_mask = (id << 28) | (1 << 27); 
    //for (int i = 0; i < CACHE_NUM_SET*CACHE_NUM_WAY; i++) 
    //{
    //  bsg_dram_store(tag_addr_mask | (i << 5), 0);
    //}

    //for (int i = 0; i < 8; i++) 
    //{
    //  test_store_stride(id, 0, (4 << i), (int**) data_vect);
    //  test_store_stride(id, 4, (4 << i), (int**) data_vect);
    //  test_store_stride(id, 8, (4 << i), (int**) data_vect);
    //  test_store_stride(id, 12, (4 << i), (int**) data_vect);
    //}

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
