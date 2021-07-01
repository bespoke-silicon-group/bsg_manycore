
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 8

int idata[N] = {3,6,2,4,1,7,3,4};
float fdata1[N] = {-1.0, 3.0, 4.0, 9.0, 1.0, 2.0, 11.0, -2.0};
float fdata2[N] = {-7.0, 2.0, -7.0, 8.0, 1.0, -6.0, 1.0, 3.0};


int main()
{
  bsg_set_tile_x_y();

  if (__bsg_x == 0 && __bsg_y == 0)
  {
    int sum = 0;

    bsg_cuda_print_stat_start(0);

    for (int i = 0; i < N; i++)
    {
      sum += idata[i];
    }

    float dp = 0.0;
    for (int i = 0; i < N; i++)
    {
      dp += fdata1[i] * fdata2[i];
    }
   
    int product = 1;
    for (int i = 0; i < N; i++)
    {
      product = product * idata[i];
    } 

    bsg_cuda_print_stat_end(0);

    if (sum == 30 && dp == 51.0f && product == 12096)
      bsg_finish();
    else
      bsg_fail();
  }

  bsg_wait_while(1);
}

