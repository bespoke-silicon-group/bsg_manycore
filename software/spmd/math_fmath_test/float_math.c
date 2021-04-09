// Note: copied from /spmd/float_math/main.c

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>
#include "math_common.h"

#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)
float local_lst[64] = {0.0};

void quicksort(float* lst, int n)
{
  if (n == 1)
  {
    return;
  }

  float center = lst[0];
  int front = 0;
  int back = n-1;

  for (int i = 1; i < n; i++)
  {
    float temp = lst[i];
    if (temp >= center)
    {
      local_lst[back] = temp;
      back--;
    }
    else
    {
      local_lst[front] = temp;
      front++;
    }
  } 

  if (back == front)
  {
    local_lst[back] = center; 

    for (int i = 0; i < n; i++) 
    {
      lst[i] = local_lst[i];
    }    
    if (front != 0)
    {
      quicksort(lst, front);
    }
    if (back != n-1)
    {
      quicksort(&(lst[back+1]), n-1-back);
    }
  }
  else
  {
    bsg_fail_x(3);
  }
}

float find_median(float* arr, int n)
{
  quicksort(arr, n);
  if (n % 2 == 0) // even
  {
    return (arr[(n/2)-1] + arr[(n/2)]) / 2.0;
  }
  else
  {
    return arr[n/2];
  }
}

void float_math_test(float *data)
{

  float M[K] = {0};
  
  // copy the data from DRAM to local DMEM
  for (int i = 0; i < K; i++)
  {
    M[i] = data[i];
  }

  // calculate sum
  //
  float sum = 0;
  for (int i = 0; i < K; i++)
  {
    sum += M[i];
  }
  bsg_printf("sum= %x\n", hex(sum));

  if (hex(sum) != 0x4469598c)
    bsg_fail_x(0);

  // calculate average
  //
  float average = sum / K;
  bsg_printf("average= %x\n", hex(average));
    
  if (hex(average) != 0x4169598c)
    bsg_fail_x(0);

  // calculate variance
  //
  float variance = 0.0;
  for (int i = 0; i < K; i++)
  {
    variance += (average - M[i])*(average - M[i]);
  }
  variance = variance / K;
  
  bsg_printf("variance= %x\n", hex(variance));
  if (hex(variance) != 0x453563d8)
    bsg_fail_x(0);

  // median
  float median = find_median(M, K);
  bsg_printf("median= %x\n", hex(median));
  if (hex(median) != 0x413e0b76)
    bsg_fail_x(0);


  // copy the data from DRAM to local DMEM again
  for (int i = 0; i < K; i++)
  {
    M[i] = data[i];
  }

  // max
  int neg_infty = 0xff800000;
  float max = flt(neg_infty); // negative infinity
  for (int i = 0; i < K; i++)
  {
    if (M[i] > max)
    {
      max = M[i]; 
    }
  }
  bsg_printf("max= %x\n", hex(max));
  if (hex(max) != 0x42c11d3c)
    bsg_fail_x(0);


  // min
  int pos_infty = 0x7f800000;
  float min = flt(pos_infty); // pos infinity
  for (int i = 0; i < K; i++)
  {
    if (M[i] < min)
    {
      min = M[i]; 
    }
  }
  bsg_printf("min= %x\n", hex(min));
  if (hex(min) != 0xc2c78afa)
    bsg_fail_x(0);


}
