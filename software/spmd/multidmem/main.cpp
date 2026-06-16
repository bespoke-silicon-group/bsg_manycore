
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier_amoadd.h"
#include "kernel.hpp"

// Some global variables needed for amoadd barrier
extern "C" void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;

static int data[16] __attribute__ ((section (".dmem"))) = {
    0xfaaa, 0xfaaa, 0xfaaa, 0xfaaa,
    0xfbbb, 0xfbbb, 0xfbbb, 0xfbbb,
    0xfccc, 0xfccc, 0xfccc, 0xfccc,
    0xfddd, 0xfddd, 0xfddd, 0xfddd
};

// Preamble, setup only done by core 0
void preamble() {
    bsg_printf("Hello from tile 0\n");
    bsg_printf("rodata is located at: %x\n", &data[0]);
    for (int i = 0; i < 16; i++) {
        if (i % 4 == 0) {
            bsg_printf("\n\t");
        }
        bsg_printf("%x\t", data[i]);
    }
    bsg_printf("\n");
}

// Postamble, cleanup only done by core 0
void postamble() {
    bsg_finish();
}

int main()
{
   int i;
  /************************************************************************
   This will setup the  X/Y coordination. Current pre-defined corrdinations 
   includes:
        __bsg_x         : The X cord inside the group 
        __bsg_y         : The Y cord inside the group
        __bsg_org_x     : The origin X cord of the group
        __bsg_org_y     : The origin Y cord of the group
  *************************************************************************/
  bsg_set_tile_x_y();
  bsg_fence();

  // Do some setup from your "host" tile
  if (__bsg_id == 0) {
    preamble();
  }

  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
  if (__bsg_id == 1) kernel1();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
  if (__bsg_id == 2) kernel2();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);

  // Do some cleanup if necessary 
  if (__bsg_id == 0) {
    postamble();
  }

  // Spin
  bsg_wait_while(1);
}

