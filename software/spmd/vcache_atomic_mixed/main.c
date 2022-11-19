#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

int lock __attribute__ ((section (".dram"))) = {0};

int main()
{

  bsg_set_tile_x_y();

  if (__bsg_id == 0)
  {
    // Using a regular int* here cause an illegal ordering resulting in:
    //   x = 1, y = 0, z = 1
    //int* lock_ptr = &lock;
    volatile int* lock_ptr  = &lock;
    int x = *lock_ptr;
    int y = bsg_amoadd(lock_ptr, 1);
    int z = *lock_ptr;

    bsg_print_hexadecimal(x);
    bsg_print_hexadecimal(y);
    bsg_print_hexadecimal(z);
    if (x != 0 || y != 0 || z != 1) bsg_fail();

    bsg_finish();
  }

  bsg_wait_while(1);
}
