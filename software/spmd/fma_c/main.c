
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

float data[4] __attribute__ ((section (".dram"))) = {4,6,7,11};

int main()
{
  bsg_set_tile_x_y();

  float z = (data[0] * data[1]) + data[2];
  if (z != 31.0) bsg_fail();
  
  z = (data[1] * data[2]) - data[3];
  if (z != 31.0) bsg_fail();

  bsg_finish();

  bsg_wait_while(1);
}

