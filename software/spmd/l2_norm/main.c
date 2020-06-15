#define N 512
#include <math.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "data.h"

#define hex(X) (*(int*)&X)

int main()
{

  bsg_set_tile_x_y();

  float sum = 0.0f;
  for (int i = 0; i < N; i++)
  {
    float diff = a[i] - b[i];
    sum += diff*diff;
  }
  
  float dist = sqrtf(sum);

  bsg_printf("expected = 4b8fa036\n");
  bsg_printf("actual   = %x\n", hex(dist));

  if (hex(dist) == 0x4b8fa036)
    bsg_finish();
  else
    bsg_fail();

  bsg_wait_while(1);
}

