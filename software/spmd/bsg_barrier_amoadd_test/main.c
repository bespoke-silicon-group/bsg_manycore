#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"


#define N 10

// defined in bsg_barrier_amoadd.S
extern void bsg_barrier_amoadd(int*, int*);

int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int data[bsg_tiles_X*bsg_tiles_Y] __attribute__  ((section (".dram"))) = {0};


int main()
{
  bsg_set_tile_x_y();

  for (int i = 0; i < N; i++) {
    // increment your number by 1
    bsg_amoadd(&data[__bsg_id], 1);
    // fence before joining barrier
    bsg_fence();
    // join barrier
    bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
    // check the result of your neighbor
    if (data[__bsg_id % (bsg_tiles_X*bsg_tiles_Y)] != i+1) {
      bsg_fail();
      bsg_wait_while(1);
    } 
  }

  if (__bsg_id == 0) {
    bsg_finish();
  }
  bsg_wait_while(1);
}

