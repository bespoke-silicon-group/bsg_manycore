#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define N 64

float data[N] __attribute__ ((section (".dram"))) = {
68.88436890, 51.59088135, -15.88568401, -48.21664810, 
2.25494432, -19.01317215, 56.75971603, -39.33745575, 
-4.68060923, 16.67640877, 81.62257385, 0.93737113, 
-43.63243103, 51.16083908, 23.67379951, -49.89873123, 
81.94924927, 96.55709839, 62.04344559, 80.43318939, 
-37.97048569, 45.96635056, 79.76765442, 36.79678726, 
-5.57145691, -79.85975647, -13.16563320, 22.17739487, 
82.60221100, 93.32127380, -4.59804487, 73.06198883, 
-47.90153885, 61.00556564, 9.73986053, -97.19165802, 
43.94093704, -20.23529243, 64.96899414, 33.63064194, 
-99.77143860, -1.28442669, 73.52055359, -51.21782303, 
-34.95912933, 74.09424591, -61.78658295, 13.50214767, 
-52.27681351, 93.50804901, 60.63589478, -10.40608597, 
-83.91083527, -35.98907852, 1.58812845, 86.56676483, 
-78.18843079, 10.25344944, 41.31228256, 9.48818207, 
62.89337158, 8.05672169, 92.76770782, 20.63712502
};



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

int main()
{
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == 0))
  {
    float M[N] = {0};
  
    // copy the data from DRAM to local DMEM
    for (int i = 0; i < N; i++)
    {
      M[i] = data[i];
    }

    // calculate sum
    //
    float sum = 0;
    for (int i = 0; i < N; i++)
    {
      sum += M[i];
    }
    bsg_printf("sum= %x\n", hex(sum));

    if (hex(sum) != 0x4469598c)
      bsg_fail_x(0);

    // calculate average
    //
    float average = sum / N;
    bsg_printf("average= %x\n", hex(average));
    
    if (hex(average) != 0x4169598c)
      bsg_fail_x(0);

    // calculate variance
    //
    float variance = 0.0;
    for (int i = 0; i < N; i++)
    {
      variance += (average - M[i])*(average - M[i]);
    }
    variance = variance / N;
  
    bsg_printf("variance= %x\n", hex(variance));
    if (hex(variance) != 0x453563d8)
      bsg_fail_x(0);

    // median
    float median = find_median(M, N);
    bsg_printf("median= %x\n", hex(median));
    if (hex(median) != 0x413e0b76)
      bsg_fail_x(0);


    // copy the data from DRAM to local DMEM again
    for (int i = 0; i < N; i++)
    {
      M[i] = data[i];
    }

    // max
    int neg_infty = 0xff800000;
    float max = flt(neg_infty); // negative infinity
    for (int i = 0; i < N; i++)
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
    for (int i = 0; i < N; i++)
    {
      if (M[i] < min)
      {
        min = M[i]; 
      }
    }
    bsg_printf("min= %x\n", hex(min));
    if (hex(min) != 0xc2c78afa)
      bsg_fail_x(0);




    bsg_finish();
  }

  bsg_wait_while(1);
}
