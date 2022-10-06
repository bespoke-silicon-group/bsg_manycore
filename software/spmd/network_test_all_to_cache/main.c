//  TEST DESCRIPTION
//  Every tiles writes to DRAM M times.
//  The origin tile reads all of them back, and validate.
//  this tests all routing paths between tiles to caches, and congestions in the network.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define N (bsg_tiles_X*bsg_tiles_Y)
#define M 64

// HW barrier configuration
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

// AMOADD barrier
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;


// Tiles write to this array.
int data[N*64] __attribute__ ((section (".dram"))) = {0};


int main()
{

  // set tiles
  bsg_set_tile_x_y();


  // setup HW barrier
  if (__bsg_id == 0) {
    // calculate HW barrier config.
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
  }

  // AMOADD barrier
  bsg_fence();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);  

  // configure HW barrier
  int my_barcfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (my_barcfg));


  // join barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  
  // Everyone writes to DRAM.
  // With a stride that is equal to the number of tiles.
  // set the data to the index of the array.
  for (int i = 0; i < M; i++)
  {
    int idx = (N*i) + __bsg_id;
    data[idx] = idx;
  }


  // join barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();


  // validated by origin tile.
  if (__bsg_id == 0) 
  {
    // every data in the array needs to match the index.
    for (int i = 0; i < N*M; i++)
    {
      if (i != data[i]) bsg_fail();
    }

    bsg_finish();
  }
  else
  {
    bsg_wait_while(1);
  }
}

