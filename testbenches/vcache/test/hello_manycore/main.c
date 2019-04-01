/**
 *  main.c
 *
 *  hello manycore
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define NUM_DATA 4

int data[NUM_DATA] __attribute__ ((section (".dram"))) = {2, 3, 5, 7};

int main()
{
  // set up bsg_x, bsg_y.
  bsg_set_tile_x_y();
  
  if ((bsg_x == 0) && (bsg_y == 0))
  {
    int sum = 0; 
    for (int i = 0; i < NUM_DATA; i++)
    {
      sum += data[i];
    }

    if (sum == 17)
    {
      bsg_finish_x(3);
    }
    else
    {
      bsg_fail_x(3);
    }
  }

  bsg_wait_while(1);
}
