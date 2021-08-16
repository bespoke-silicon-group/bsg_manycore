// This test demonstrates linking the interrupt handler written in asm (interrupt.S).


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


int mydata __attribute__ ((section (".dram"))) = 0;


int main() {
  bsg_set_tile_x_y();

  // enable interrupt (mstatus.mie = 1)
  asm volatile ("csrrs x0, mstatus, %0" : : "r" (0x8));

  // enable remote interrupt (mie.remote = 1)
  asm volatile("csrrs x0, mie, %0" : : "r" (0x10000));

  // send yourself a remote interrupt.
  // the remote interrupt handler should set mydata to 0xbeef.
  bsg_remote_store(0,0, 0xfffc, 1);
  bsg_fence();

  // check that the mydata changed.
  if (0xbeef != mydata) {
    bsg_fail();
    bsg_wait_while(1);
  }

  bsg_finish();
  bsg_wait_while(1);
}

