/**
 *  
 *    main.c
 *    
 */



#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define N 10

float data1[N] __attribute__ ((section (".dram"))) = {
  -100, 0.0, 10.0, 45, -10000,
  -0.0, 453.3, 88, 10.0, 99.0
};

float data2[N] = {
  123.0, 11.0, 11.1, 9999, 0, -1534.2,
  99999, -0.314, 0.001, 3.23, 3.33 
};

int main()
{
  bsg_set_tile_x_y();

  // DRAM
  float max1 = -INFINITY;
  float min1 = +INFINITY;
  for (int i = 0; i < N; i++)
  {
    max1 = fmaxf(max1, data1[i]);
    min1 = fminf(min1, data1[i]);
  }

  if (max1 != 453.3f) bsg_fail();
  if (min1 != -10000.0f) bsg_fail();


  // DMEM
  float max2 = -INFINITY;
  float min2 = +INFINITY;
  for (int i = 0; i < N; i++)
  {
    max2 = fmaxf(max2, data2[i]);
    min2 = fminf(min2, data2[i]);
  }

  if (max2 != 99999.0f) bsg_fail();
  if (min2 != -1534.2f) bsg_fail();


  bsg_finish();
  
  bsg_wait_while(1);
}

