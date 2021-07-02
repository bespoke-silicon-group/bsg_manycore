/**
 *  main.c
 *  
 *  saif
 *
 *  Tests that bsg_saif_start() and bsg_saif_end() work correctly
 *  calculates the sum of first N fibonacci sequence recursively.
 *
 *  fib[0] = 0
 *  fib[1] = 1
 *  fib[n] = fib[n-1] + fib[n-2]
 *
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 15
#define ANSWER 986

int my_fib[N];

int fib(int n)
{
  if (n == 0)
  {
    return 0;
  }
  else if (n == 1)
  {
    return 1;
  }
  else
  {
    return fib(n-1) + fib(n-2);
  }
}

int main()
{

  bsg_set_tile_x_y();
  int sum;
  sum = 0;

  if ((__bsg_x == 0) && (__bsg_y == 0)) {
    bsg_saif_start();
    for (int i = 0; i < N; i++)
    {
      my_fib[i] = fib(i);
      bsg_printf("fib[%d] = %d\r\n", i, my_fib[i]);
      sum += my_fib[i];
    }
  
    bsg_saif_end();
    if (sum == ANSWER)
      bsg_finish();
    else
      bsg_fail();
  }

  bsg_wait_while(1);

}

