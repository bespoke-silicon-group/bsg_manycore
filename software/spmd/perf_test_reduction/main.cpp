// running on 16x8

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"

#define N 128

#define hex(x) (*(int*)&x)

float dram_data[N] __attribute__ ((section (".dram"))) = {0.0f};
float local_data[N] = {0.0f};


bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;


float reduction()
{
  float sum = 0.0f;
  float val;

  for (int y = 0; y < bsg_tiles_Y; y++)
  {
    for (int x = 0; x < bsg_tiles_X; x++)
    {
      bsg_remote_flt_load(x, y, &local_data[__bsg_id], val);
      sum += val;
    }
  }

  return sum;
}

int main()
{
  bsg_set_tile_x_y();

  // init local data
  float mydata = (float) __bsg_id;
  for (int i = 0; i < N; i++)
  {
    local_data[i] = mydata;
  }

  if (__bsg_id == 0) bsg_cuda_print_stat_start(0);
  barrier.sync(); 

  // do reduction
  float sum = reduction();
  
  // store result in DRAM
  dram_data[__bsg_id] = sum;

  barrier.sync(); 
  if (__bsg_id == 0) bsg_cuda_print_stat_start(0);

  if (sum != 8128.0f) {
    // bsg_printf("%x\n", hex(sum));
    // Replaced to reduce simulation runtime by removing printf from binary
    bsg_print_hexadecimal(sum);
    bsg_fail();
  }

  if (__bsg_id == 0) bsg_finish();

  bsg_wait_while(1);
}
