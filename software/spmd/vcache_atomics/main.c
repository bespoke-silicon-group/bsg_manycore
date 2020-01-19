#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

int lock __attribute__ ((section (".dram"))) = {0};
int lock2 __attribute__ ((section (".dram"))) = {0};

int main()
{

  bsg_set_tile_x_y();

  if (__bsg_id == 0) 
  {
    lock = 123;

    int result = bsg_amoswap(&lock, 1); 
    if (result != 123) bsg_fail();
    bsg_printf("%d\n", result);

    result = bsg_amoswap_aq(&lock, 2);
    if (result != 1) bsg_fail();
    bsg_printf("%d\n", result);

    result = bsg_amoswap_rl(&lock, 3);
    if (result != 2) bsg_fail();
    bsg_printf("%d\n", result);

    result = bsg_amoswap_aqrl(&lock, 4);
    if (result != 3) bsg_fail();
    bsg_printf("%d\n", result);


    lock2= 1;
    int result2 = bsg_amoor(&lock2,2);
    if (result2 != 1) bsg_fail();
    bsg_printf("%d\n", result2);

    result2 = bsg_amoor_aq(&lock2,4);
    if (result2 != 3) bsg_fail();
    bsg_printf("%d\n", result2);

    result2 = bsg_amoor_rl(&lock2,8);
    if (result2 != 7) bsg_fail();
    bsg_printf("%d\n", result2);

    result2 = bsg_amoor_aqrl(&lock2,16);
    if (result2 != 15) bsg_fail();
    bsg_printf("%d\n", result2);

    bsg_finish();
  }

  bsg_wait_while(1);
}

