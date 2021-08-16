
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int myid[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

int main() {
  bsg_set_tile_x_y();

  // enable interrupt (mstatus.mie = 1)
  asm volatile ("csrrs x0, mstatus, %0" : : "r" (0x8));


  // enable remote interrupt (mie.remote = 1)
  asm volatile("csrrs x0, mie, %0" : : "r" (0x10000));


  // If you are the last tile, send everyone a remote interrupt.
  // Tiles join the amoadd barrier inside the remote interrupt handler, and exits the interrupt together.
  // Before joining the barrier, each tile stores its id in myid array.
  if ((__bsg_x == bsg_tiles_X-1) && (__bsg_y == bsg_tiles_Y-1)) {
    for (int x = 0; x < bsg_tiles_X; x++) {
      for (int y = 0; y < bsg_tiles_Y; y++) {
        bsg_remote_store(x, y, 0xfffc, 1);
      }      
    }

    // verify myid array.
    for (int i = 0; i < bsg_tiles_X*bsg_tiles_Y; i++) {
      if (myid[i] != i) {
        bsg_fail();
        bsg_wait_while(1);
      }
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}

