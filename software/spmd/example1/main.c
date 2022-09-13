
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define N 4
int dram_data[N*3] __attribute__ ((section (".dram"))) = {1,2,3,4, 5,6,7,8, 1,2,3,4}; // allocated in DRAM. assume that the host already copied data here.
int dmem_data[N]; // allocated in DMEM.

// HW barrier configuration
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};
// Amoadd locks
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;



int main()
{
  bsg_set_tile_x_y();
  
  // bsg_tiles_Y = how big is the tile group in Y dimension? (assumed to be 1 here)
  // bsg_tiles_X = how big is the tile group in X dimension? (assumed to be 3 here)
 
  // tile 0 calculates barcfg
  if (__bsg_id == 0) {
    // calculate HW barrier config.
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
  }

  // AMOADD barrier, after this, every tile can know that barcfg is ready.
  bsg_fence();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);  


  // configure HW barrier
  int my_barcfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (my_barcfg));
  

  // each tile copies data from DMEM
  int * dram_ptr = &dram_data[__bsg_id*N]; // calculate its ptr in dram.
  bsg_unroll(4)
  for (int i = 0; i < N; i++) {
    dmem_data[i] = dram_ptr[i];
  }

  // enter HW barrier
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();


  // tile 0 can read from other DMEMs and check.
  if (__bsg_id == 0) {
    int sum = 0;
    // use tile group ptr
    for (int x = 0; x < bsg_tiles_X; x++) {
      // calculate remote DMEM ptr
      int * ptr = bsg_remote_ptr(x,0,&dmem_data);
      bsg_unroll(4)
      for (int i = 0; i < N; i++) {
        sum += ptr[i];
      }
    }

    #define ANSWER  46
    if (sum == ANSWER) {
      //bsg_print_int(sum);
      bsg_finish();
    } else {
      //bsg_print_int(sum);
      bsg_fail();
    }
  }

 
  bsg_wait_while(1);
}

