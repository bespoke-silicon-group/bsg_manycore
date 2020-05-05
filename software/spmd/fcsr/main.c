/**
 *  main.c
 *
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>
#include <fenv.h>
#pragma STDC FENV_ACCESS on

#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)

float data[4] __attribute__ ((section (".dram"))) = { 24, 5, 0, -1 };

int main()
{
  bsg_set_tile_x_y();
  float z = 0;
  fexcept_t flag;

  if ((__bsg_x == 0) && (__bsg_y == 0))
  {
    // test 1
    feclearexcept(FE_ALL_EXCEPT);
    z = data[0] / data[2];
    bsg_printf("%x\n", hex(z));
    if (z != INFINITY) 
    {
      bsg_fail();
    }
    fegetexceptflag(&flag, FE_ALL_EXCEPT);
    bsg_printf("%d\n", flag);
    

    // test 2
    feclearexcept(FE_ALL_EXCEPT);
    fegetexceptflag(&flag, FE_ALL_EXCEPT);
    bsg_printf("%d\n", flag);
    z = data[0] / data[2];
    if (z != INFINITY) 
    {
      bsg_fail();
    }
    fegetexceptflag(&flag, FE_ALL_EXCEPT);
    bsg_printf("%d\n", flag);


    bsg_finish();
  }

  bsg_wait_while(1);
}
