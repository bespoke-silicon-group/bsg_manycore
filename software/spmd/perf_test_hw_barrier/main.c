#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier_amoadd.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};
int lock __attribute__ ((section (".dram"))) = 0;
int sense = 1;

int main()
{
  bsg_set_tile_x_y();
  
  int id = __bsg_id;
 
  if (id == 0) {
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
  }

  bsg_fence();
  bsg_barrier_amoadd(&lock, &sense);  

  int my_barcfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (my_barcfg));
 
  bsg_fence();
  bsg_barrier_amoadd(&lock, &sense);  

  if (id == 0) bsg_print_int(0);
  bsg_barsend();
  bsg_barrecv();
  if (id == 0) bsg_print_int(0);
  bsg_barsend();
  bsg_barrecv();
  if (id == 0) bsg_print_int(0);
  bsg_barsend();
  bsg_barrecv();
  if (id == 0) bsg_print_int(0);
  bsg_barsend();
  bsg_barrecv();
  if (id == 0) bsg_print_int(0);
  bsg_barsend();
  bsg_barrecv();
  if (id == 0) bsg_print_int(0);
  bsg_barsend();
  bsg_barrecv();
  if (id == 0) bsg_print_int(0);

  if (id == 0) {
    bsg_finish();
  }

  bsg_wait_while(1);
}
