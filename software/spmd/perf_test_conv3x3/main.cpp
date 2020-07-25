// running on 16x8

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"

#define N 9

// activation
float dram_data[bsg_tiles_X*bsg_tiles_Y][N] __attribute__ ((section (".dram"))) = {0.0f};
//  0.0f, 3.0f, 4.0f,
//  2.0f, 2.0f, 0.0f,
//  2.0f, 2.0f, 7.0f
//};
// weights
float local_data[N] = {0.0f};



bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

float conv3x3()
{
  float sum0 = 0.0f;
  float sum1 = 0.0f;
  float sum2 = 0.0f;

  float local_activation0 = dram_data[__bsg_id][0];
  float local_activation1 = dram_data[__bsg_id][1];
  float local_activation2 = dram_data[__bsg_id][2];
  sum0 += local_activation0*local_data[0];
  sum1 += local_activation1*local_data[1];
  sum2 += local_activation2*local_data[2];

  local_activation0 = dram_data[__bsg_id][3];
  local_activation1 = dram_data[__bsg_id][4];
  local_activation2 = dram_data[__bsg_id][5];
  sum0 += local_activation0*local_data[3];
  sum1 += local_activation1*local_data[4];
  sum2 += local_activation2*local_data[5];

  local_activation0 = dram_data[__bsg_id][6];
  local_activation1 = dram_data[__bsg_id][7];
  local_activation2 = dram_data[__bsg_id][8];
  sum0 += local_activation0*local_data[6];
  sum1 += local_activation1*local_data[7];
  sum2 += local_activation2*local_data[8];

  float sum = sum0 + sum1 + sum2;
  
  return sum;
}

int main()
{
  bsg_set_tile_x_y();

  // init local data
  // init activation
  float mydata = (float) __bsg_id;
  for (int i = 0; i < N; i++)
  {
    local_data[i] = mydata;
  }
  dram_data[__bsg_id][0] = 0.0f;
  dram_data[__bsg_id][1] = 3.0f;
  dram_data[__bsg_id][2] = 4.0f;
  dram_data[__bsg_id][3] = 2.0f;
  dram_data[__bsg_id][4] = 2.0f;
  dram_data[__bsg_id][5] = 0.0f;
  dram_data[__bsg_id][6] = 2.0f;
  dram_data[__bsg_id][7] = 2.0f;
  dram_data[__bsg_id][8] = 7.0f;
  bsg_fence();

  if (__bsg_id == 0) bsg_cuda_print_stat_start(0);
  barrier.sync(); 

  float sum = conv3x3();

  barrier.sync(); 
  if (__bsg_id == 0) bsg_cuda_print_stat_start(0);

  #define hex(x) (*(int*)&x)
  if (sum != mydata*22.0f) {
    bsg_printf("%x\n", hex(sum));
    bsg_fail();
  }

  if (__bsg_id == 0) bsg_finish();

  bsg_wait_while(1);

}
