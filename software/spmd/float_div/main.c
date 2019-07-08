#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)


int main()
{
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == 0))
  {
    float a = 1.0;
    float b = 3.0;
    float c = a / b;

    bsg_printf("%x\n", hex(c));
    if (hex(c) == 0x3eaaaaab)
      bsg_finish();
    else
      bsg_fail();
    

  }

  bsg_wait_while(1);
}
