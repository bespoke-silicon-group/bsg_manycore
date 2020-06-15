#define N 256
#include <math.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define hex(X) (*(int*)&X)

float vecA[N]; 
float vecB[N];

int main()
{

  bsg_set_tile_x_y();

  // initialize
  for (int i = 0; i < N; i++)
  {
    vecA[i] = (float) i;
    vecB[i] = (float) i;
  }


  bsg_cuda_print_stat_start(0);
  float dp = 0.0f;
  #pragma GCC unroll 4
  for (int i = 0; i < N; i++)
  {
    dp += vecA[i] * vecB[i];
  }
  bsg_cuda_print_stat_end(0);
  
  bsg_printf("expected = 4aa9ab00\n");
  bsg_printf("actual   = %x\n", hex(dp));

  if (hex(dp) == 0x4aa9ab00)
    bsg_finish();
  else
    bsg_fail();

  bsg_wait_while(1);
}
