#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_barrier_amoadd.h"

int lock __attribute__ ((section (".dram"))) = 0;
int sense = 1;

int main()
{
  bsg_set_tile_x_y();
  
  int id = __bsg_id;
  
  if (id == 0) bsg_print_int(0);
  bsg_barrier_amoadd(&lock, &sense);
  if (id == 0) bsg_print_int(0);
  bsg_barrier_amoadd(&lock, &sense);
  if (id == 0) bsg_print_int(0);
  bsg_barrier_amoadd(&lock, &sense);
  if (id == 0) bsg_print_int(0);
  bsg_barrier_amoadd(&lock, &sense);
  if (id == 0) bsg_print_int(0);
  bsg_barrier_amoadd(&lock, &sense);
  if (id == 0) bsg_print_int(0);
  bsg_barrier_amoadd(&lock, &sense);
  if (id == 0) bsg_print_int(0);

  if (id == 0) {
    bsg_finish();
  }

  bsg_wait_while(1);
}
