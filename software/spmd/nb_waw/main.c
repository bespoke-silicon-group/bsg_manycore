#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

volatile int data[4] __attribute__((section(".dram"))) = {1, 2, 3, 0};

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_id == 0) {
    int last = data[3];
    bsg_putchar('0');

    int res = data[0];

    if(last == 0)
      res = data[3];

    if (res != 0)
      bsg_fail();
  
    bsg_finish();
  }

  bsg_wait_while(1);
}
