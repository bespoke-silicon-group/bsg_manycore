
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


int amoadd_lock __attribute__ ((section (".dram"))) = 0;


int main() {
  bsg_set_tile_x_y();

  // enable interrupt (mstatus.mie = 1)
  int temp = 0x8;
  asm volatile ("csrrs x0, mstatus, %[temp]" : : [temp] "r" (temp));


  // enable remote interrupt (mie.remote = 1)
  temp = 0x10000;
  asm volatile("csrrs x0, mie, %[temp]" : : [temp] "r" (temp));


  // If you are the last tile, send everyone a remote interrupt.
  // Tiles join the amoadd barrier inside the remote interrupt handler, and exits the interrupt.
  if ((__bsg_x == bsg_tiles_X-1) && (__bsg_y == bsg_tiles_Y-1)) {
    for (int x = 0; x < bsg_tiles_X; x++) {
      for (int y = 0; y < bsg_tiles_Y; y++) {
        bsg_remote_store(x, y, 0xfffc, 1);
      }      
    }

    bsg_fence();

    // check that amoadd lock has been actually used.
    if (amoadd_lock == bsg_tiles_X*bsg_tiles_Y) {
      bsg_finish();
    } else {
      bsg_fail();
    }
  }

  bsg_wait_while(1);
}

