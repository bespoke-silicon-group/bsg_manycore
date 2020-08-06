#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 1024

float  data1[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data2[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data3[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data4[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data5[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data6[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data7[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data8[N] __attribute__ ((section (".dram"))) = {0.0f};
float  data9[N] __attribute__ ((section (".dram"))) = {0.0f};

int main()
{
  bsg_set_tile_x_y();

  for (int i = 0; i < N; i++)
  {
    float fi = (float) i;
    data1[i] = fi+2.0f;
    data2[i] = fi+3.0f;
    data3[i] = fi+5.0f;
    data4[i] = fi+7.0f;
    data5[i] = fi+2.0f;
    data6[i] = fi+3.0f;
    data7[i] = fi+5.0f;
    data8[i] = fi+7.0f;
  }
  
  for (int i = 0; i < N; i++)
  {
    float register a1, a2, a3, a4, a5, a6, a7, a8;
    a1 = data1[i];
    a2 = data2[i];
    a3 = data3[i];
    a4 = data4[i];
    a5 = data5[i];
    a6 = data6[i];
    a7 = data7[i];
    a8 = data8[i];
    data9[i] = a1+a2+a3+a4+a5+a6+a7+a8;
  }

  for (int i = 0; i < N; i++)
  {
    float fi = (float) i;
    fi = (fi * 8.0f) + 34.0f;
    if (data9[i] != fi) bsg_fail();
  }


  bsg_finish();
  bsg_wait_while(1);
}

