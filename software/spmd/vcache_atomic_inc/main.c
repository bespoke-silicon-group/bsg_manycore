#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

int lock __attribute__ ((section (".dram"))) = {0};
int data __attribute__ ((section (".dram"))) = {0};

void atomic_inc()
{
  // grab lock
  int lock_val = 1;

  do {
    lock_val = bsg_amoswap_aq(&lock, 1);
  } while (lock_val != 0); 
  bsg_printf("I got the lock! x=%d y=%d\n", __bsg_x, __bsg_y);

  // critical region
  int local_data = data;
  data = local_data+1; 
  bsg_printf("%d\n",local_data);

  bsg_printf("I'm releasing the lock... x=%d y=%d\n", __bsg_x, __bsg_y);

  // release
  bsg_amoswap_rl(&lock, 0);

  if (local_data == (bsg_tiles_X*bsg_tiles_Y)-1) bsg_finish();

}

int main()
{

  bsg_set_tile_x_y();

  atomic_inc();

  bsg_wait_while(1);
}

