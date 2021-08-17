
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config.h"

#define N 4

int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int data[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};
int myid[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};



int main()
{
  bsg_set_tile_x_y();

  // enable remote interrupt
  asm volatile ("csrrs x0, mstatus, %0" : : "r" (0x8));
  asm volatile("csrrs x0, mie, %0" : : "r" (0x10000));

  // config hw barrier
  int barcfg = barcfg_16x8[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (barcfg));


  // barrier loop
  for (int i = 0; i < N; i++) {
    // do updates
    bsg_amoadd(&data[(__bsg_id+i)%(bsg_tiles_X*bsg_tiles_Y)], 1);

    // last tile sends remote interrupt to everyone.
    if (__bsg_id == (bsg_tiles_X*bsg_tiles_Y)-1) {
      for (int y = 0; y < bsg_tiles_Y; y++) {
        for (int x = 0; x < bsg_tiles_X; x++) {
          bsg_remote_store(x,y,0xfffc,1);
        }
      }
    }

    // fence before barrier
    bsg_fence();
    // join barrier
    bsg_barsend();
    // wait for barrier to complete
    bsg_barrecv();
  }

  // validate
  if (__bsg_id == 0) {
    for (int i = 0; i < bsg_tiles_X*bsg_tiles_Y; i++) {
      if (data[i] != N) {
        bsg_fail();
        bsg_wait_while(1);
      }
    }

    for (int i = 0; i < bsg_tiles_X*bsg_tiles_Y; i++) {
      if (myid[i] != N) {
        bsg_fail();
        bsg_wait_while(1);
      }
    }

    bsg_finish();
  }
  
  bsg_wait_while(1);
}

