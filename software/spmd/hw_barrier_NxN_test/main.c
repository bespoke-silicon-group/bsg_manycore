//  Each tile loads words from neighboring tiles' DMEM and increment and store them back.
//  Each time, the increment is done on different location, so that the barrier is required between load and store phases.
//  In the end, all the words should be incremented to N, which is the number of iterations.


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define N 4
#define NUM_WORDS 16
// my private data in DMEM
int mydata[NUM_WORDS] = {0};

// HW barrier configuration
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

// AMOADD barrier
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;


int main()
{
  bsg_set_tile_x_y();

  // calculate barcfg
  if (__bsg_id == 0) {
    // calculate HW barrier config.
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
    // print the configuration matrix.
    for (int y = 0; y < bsg_tiles_Y; y++) {
      for (int x = 0; x < bsg_tiles_X; x++) {
        int id = (y*bsg_tiles_X) + x;
        bsg_printf("%0x,", barcfg[id]);
      } 
      bsg_printf("\n");
    }
  }

  // AMOADD barrier
  bsg_fence();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);  

  // configure HW barrier
  int my_barcfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (my_barcfg));


  // Iterate
  int temp[NUM_WORDS];

  for (int n = 0; n < N; n++) {
    // target coordinate
    int tx = (__bsg_x + n) % bsg_tiles_X;
    int ty = (__bsg_y + n) % bsg_tiles_Y;

    // load data from other tiles.
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_load(tx, ty, &mydata[i], temp[i]);
      temp[i]++;
    }
  
    // barrier
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    // increment the data and store back.
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_store(tx, ty, &mydata[i], temp[i]);
    }

    // barrier
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }

  // everyone validates
  for (int i = 0; i < NUM_WORDS; i++) {
    if (mydata[i] != N) {
      bsg_fail();
    }
  }
  
  // barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();


  if (__bsg_id == 0) {
    bsg_finish();
  }
  
  bsg_wait_while(1);
}

