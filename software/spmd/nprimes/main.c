/**
 *  main.c
 *
 *  nprimes
 *
 *  find the sum of first N prime numbers.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 20
#define ANSWER 639

int main()
{

  bsg_set_tile_x_y();

  int prime[N] = {0};

  if (__bsg_x == 0 && __bsg_y == 0)
  {
    int n = 1;
    prime[0] = 2;
    int curr = 3;

    while (n < N)
    {
      int is_prime = 1;

      for (int i = 0; i < n; i++)
      {
        if (prime[i] * prime[i] > curr)
        {
          break;
        }

        if (curr % prime[i] == 0) 
        {
          is_prime = 0;
        }
      }

      if (is_prime == 1)
      {
        prime[n] = curr;
        n++;
        curr++;
      }
      else
      {
        curr++;
      }
    }

    int sum = 0;
    for (int i = 0; i < N; i++)
    {
      bsg_printf("prime[%0d] = %0d\n", i, prime[i]);
      sum += prime[i];
    }

    if (sum == ANSWER)
    {
      bsg_printf("PASS: %0d\n", sum);
      bsg_finish();
    }
    else
    {
      bsg_printf("FAIL: %0d\n", sum);
      bsg_fail();
    }
  }

  bsg_wait_while(1);
}
