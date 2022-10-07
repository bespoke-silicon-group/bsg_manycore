//  TEST DESCRIPTION
//  Every tile writes its id on DMEM of every tile. (each has unique address on DMEM)
//  and then every tile reads what other tiles wrote to validate.
//  this tests all routing paths between tiles and congestions in the network.
//  This test works as long as 'data' fits in dmem.


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define N (bsg_tiles_X*bsg_tiles_Y)

// this array will be written by every tile with remote store.
volatile int data[N] = {0};

// HW barrier configuration
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

// AMOADD barrier
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;


int main()
{

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

 
  // everyone writes to each other
  for (int x = 0; x < bsg_tiles_X; x++)
  {
    for (int y = 0; y < bsg_tiles_Y; y++)
    {
      // use your id as an index and store your id.
      bsg_remote_store(x, y, &data[__bsg_id], __bsg_id);
    }
  }

  // join barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  // validate
  // data in this array should match the index.
  for (int i = 0; i < __bsg_id; i++)
  {
    if (i != data[i]) bsg_fail();
  }

  // join barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();
  
  if (__bsg_id == 0) 
  {
    bsg_finish();
  }
  else
  {
    bsg_wait_while(1);
  }


}

