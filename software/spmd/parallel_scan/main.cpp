// running on 16x8

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"
#include "bsg_mutex.h"

#define N 16

// weights
int data[N] = {0.0};
int result[N] = {0.0};
int prev_sum = 0;
int wait = 0;

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

int main()
{
  bsg_set_tile_x_y();

  // init local data
  int mydata = __bsg_id;
  for (int i = 0; i < N; i++)
  {
    data[i] = mydata;
  }

  if (__bsg_id == 0) bsg_cuda_print_stat_start(0);
  barrier.sync(); 

  // calculate local_sum
  int local_sum = 0;
  for (int i = 0; i< N; i++)
  {
    local_sum += data[i];
  } 
  
  //bsg_printf("[%d] local_sum: %d\n", __bsg_id, local_sum);

  if (__bsg_id == 0)
  {
    // send local sum to next
    bsg_remote_store(1, 0, &prev_sum, local_sum);
    bsg_remote_store(1, 0, &wait, 1);
    int scan_result = 0;
    for (int i = 0; i < N; i++)
    {
      scan_result += data[i];
      result[i] = scan_result;
    }
  }
  else
  {
    // go to sleep, wait for the local sum from prev.
    bsg_wait_local_int(&wait, 1);
    //bsg_printf("[%d] prev_sum: %d\n", __bsg_id, prev_sum);
    
    if (__bsg_id != bsg_tiles_X-1)
    {
      bsg_remote_store(__bsg_id+1, 0, &prev_sum, local_sum+prev_sum);
      bsg_remote_store(__bsg_id+1, 0, &wait, 1);
    }

    int scan_result = prev_sum;
    for (int i = 0; i < N; i++)
    {
      scan_result += data[i];
      result[i] = scan_result;
    }

/*
    if (__bsg_id == bsg_tiles_X-1)
    {
      bsg_printf("last: %d\n", result[N-1]);
    }
*/  

  }
  



  barrier.sync(); 
  if (__bsg_id == 0) bsg_cuda_print_stat_start(0);


  if (__bsg_id == bsg_tiles_X-1)
  {
    if (result[N-1] != 1920)
      bsg_fail();
    else
      bsg_finish();    
  }

  bsg_wait_while(1);

}
