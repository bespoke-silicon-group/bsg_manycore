
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define MAX_COUNT 10000

int main()
{
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == 0)) {

    volatile int i = 0;
    while (i < MAX_COUNT)
    {
      i++;
    }
    
    bsg_printf("%d\n", i);

    if ( i == MAX_COUNT) 
      bsg_finish();
    else
      bsg_fail();
  }

  bsg_wait_while(1);
}

