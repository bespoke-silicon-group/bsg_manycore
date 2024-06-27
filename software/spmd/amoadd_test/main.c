/*
  Description:
  Test to check if atomic adds work
  Every tile atomically updates the 2 counter variables in DRAM using 2 methods and tile 0 checks if the value is the same using both techniques and is equal to the sum of bsg_x_id * bsg_y_id
*/

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int data[2] __attribute__ ((section (".dram"))) = {0};
int lock __attribute__ ((section (".dram"))) = {0};

void atomic_add()
{
  // Perform an atomic add using amoadd.w
  int value0 = __bsg_x * __bsg_y;
  int result = bsg_amoadd_aq(&data[0], value0);

  // Perform an atomic add using amoswaps 
  // Acquires a lock and then updates the memory location in the critical region
  int lock_val = 1;

  // acquire
  do {
    lock_val = bsg_amoswap_aq(&lock, 1);
  } while (lock_val != 0);

  // Critical region
  int value1 = data[1] + __bsg_x *__bsg_y;
  data[1] = value1;

  // release
  bsg_amoswap_rl(&lock, 0);

  // Wait for all cores to finish
  bsg_fence();
  bsg_tile_group_barrier(&r_barrier, &c_barrier);

  if (__bsg_id == 0)
  {
    // bsg_printf("%d\n", data[0]);
    // bsg_printf("%d\n", data[1]);
    // Replaced to reduce runtime
    bsg_print_int(data[0]);
    bsg_print_int(data[1]);

    int expected = 0;
    int sum = 0;
    for (int i = 0; i < bsg_tiles_X; i++)
      expected += i;
    for (int i = 0; i < bsg_tiles_Y; i++)
      sum += i;
    expected *= sum;

    bsg_print_int(expected);
    if ((data[0] == data[1]) && (data[0] == expected))
      bsg_finish();
    else
      bsg_fail();
  }
}

int main()
{

  bsg_set_tile_x_y();

  atomic_add();

  bsg_wait_while(1);
}
