// this is a simple program with a simple behaviour that can be used for analyzing/debugging vanilla profiler.
//  a core simply writes to a vector in main memory and reads back .


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#define N 1024
#define ANSWER 523776

int data[N] __attribute__ ((section (".dram"))) = {0};

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_id == 0)
  {
    // initialize data
    for (int i = 0; i < N; i++) 
    {
      data[i] = i;
    }


    //  load the data and sum them up.
    int sum = 0;
    for (int i = 0; i < N; i++)
    {
      sum += data[i]; 
    }


    if (sum == ANSWER)
      bsg_finish();
    else 
      bsg_fail();

  }

  bsg_wait_while(1);
}
