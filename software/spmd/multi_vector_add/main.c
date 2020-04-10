#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 1024

int data1[N] __attribute__ ((section (".dram"))) = {0};
int data2[N] __attribute__ ((section (".dram"))) = {0};
int data3[N] __attribute__ ((section (".dram"))) = {0};
int data4[N] __attribute__ ((section (".dram"))) = {0};
int data9[N] __attribute__ ((section (".dram"))) = {0};

int main()
{
  bsg_set_tile_x_y();

  for (int i = 0; i < N; i++)
  {
    data1[i] = i+2;
    data2[i] = i+3;
    data3[i] = i+5;
    data4[i] = i+7;
  }
  
  for (int i = 0; i < N; i++)
  {
    int a1 = data1[i];
    int a2 = data2[i];
    int a3 = data3[i];
    int a4 = data4[i];
    data9[i] = a1+a2+a3+a4;
  }

  for (int i = 0; i < N; i++)
  {
    if (data9[i] != (i<<2)+17) bsg_fail();
  }


  bsg_finish();
  bsg_wait_while(1);
}

