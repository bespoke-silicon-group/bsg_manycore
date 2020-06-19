#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

float A[1] = {NAN};

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_id == 0)
  {
    int a = (NAN >= NAN) ? 1 : 0;
    int b = (A[0] >= A[0]) ? 1 : 0;

    if(a != 0 || b != 0) {
      bsg_printf("Error: NAN >= NAN is equal to 0, but got following...\n");
      bsg_printf("     Hardcoded comparison reuslted in %d\n", a);
      bsg_printf("     Array element comparison reuslted in %d\n", b);
      bsg_fail();
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}
