#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)

float A[4];
float B[4];

float dataA[4] __attribute__ ((section (".dram"))) = { 1.0, 1.0, 1.0, 1.0};
float dataB[4] __attribute__ ((section (".dram"))) = { 3.0, 5.0, 7.0, 11.0};

int main()
{
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == 0))
  {
    float a = 1.0;
    float b = 3.0;
    float c = a / b;

    bsg_printf("%x\n", hex(c));
    if (hex(c) != 0x3eaaaaab)
      bsg_fail();
    

    for (int i = 0; i < 4; i++)
    {
      A[i] = 1.0;
      B[i] = 3.0;
    }

    for (int i = 0; i < 4; i++)
    {
      float C = A[i] / B[i];
      bsg_printf("%x\n", hex(C));
    }

    for (int i = 0; i < 4; i++)
    {
      float d = dataA[i] / dataB[i];
      bsg_printf("%x\n", hex(d));
      
    }

    
    bsg_finish();
  }

  bsg_wait_while(1);
}
