
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 8

int data[N] = {3,6,2,4,1,7,3,4};

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_x == 0 && __bsg_y == 0)
  {
    int sum = 0;

    bsg_print_stat(0);

    for (int i = 0; i < N; i++)
    {
      sum += data[i];
    }

    
    bsg_printf("sum: %d\n", sum);

    bsg_print_stat(1);

    if (sum == 30)
      bsg_finish();
    else
      bsg_fail();
  }

  bsg_wait_while(1);
}

