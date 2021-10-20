//  Each tile loads words from neighboring tiles' DMEM and increment and store them back.
//  Each time, the increment is done on different location, so that the barrier is required between load and store phases.
//  After each load phase, the last tile interrupts every tile in the tile group.
//  During the interrupt, all the tiles needs to synchronize using amoadd barrier before calling mret.
//  In the end, all the words should be incremented to N, which is the number of iterations.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define N 4
#define NUM_WORDS 16

extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int myid[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

int mydata[NUM_WORDS] = {0};

int main()
{
  bsg_set_tile_x_y();


  // initialized barcfg
  if (__bsg_id == 0) {
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
    bsg_fence();
  }

  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);


  // config hw barrier
  int cfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (cfg));

  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);

  // enable remote interrupt
  asm volatile ("csrrs x0, mstatus, %0" : : "r" (0x8));
  asm volatile("csrrs x0, mie, %0" : : "r" (0x10000));



  // barrier loop
  int temp[NUM_WORDS];
  for (int n = 0; n < N; n++) {
    int tx = (__bsg_x + n) % bsg_tiles_X;
    int ty = (__bsg_y + n) % bsg_tiles_Y;

    // load from other tiles
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_load(tx,ty,&mydata[i], temp[i]);
    }


    // last tile sends remote interrupt to everyone.
    if (__bsg_id == (bsg_tiles_X*bsg_tiles_Y)-1) {
      for (int y = 0; y < bsg_tiles_Y; y++) {
        for (int x = 0; x < bsg_tiles_X; x++) {
          bsg_remote_store(x,y,0xfffc,1);
        }
      }
    }

    // HW Barrier
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();


    // increment and store back
    for (int i = 0; i < NUM_WORDS; i++) {
      temp[i]++;
    }
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_store(tx,ty,&mydata[i], temp[i]);
    }

    // HW Barrier
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }

  // everyone validates mydata.
  for (int i = 0; i < NUM_WORDS; i++) {
    if (mydata[i] != N) {
      bsg_fail();
    }
  }

  // HW Barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  // validate
  if (__bsg_id == 0) {
    for (int i = 0; i < bsg_tiles_X*bsg_tiles_Y; i++) {
      if (myid[i] != N) {
        bsg_fail();
      }
    }
    bsg_finish();
  }
  
  bsg_wait_while(1);
}

