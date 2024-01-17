#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define REPEAT 1000000000U

int data;

int main()
{
  bsg_set_tile_x_y();


  // calculate dest addr;
  uint32_t dy = (__bsg_y+4) % 8;
  uint32_t dx = (__bsg_x+8) % 16;
  volatile uint32_t* dest_addr = (uint32_t*) (
    0x20000000 |
    (dy<<24) |
    (dx<<18) |
    ((int) &data)
  );
  
  // set it to zero;
  *dest_addr = 0;

  // load + update + store;
  for (uint32_t i = 0; i < REPEAT; i++) {
    int load_val = *dest_addr;
    int store_val = load_val + 1;
    *dest_addr = store_val;
  }

  // check;
  uint32_t load_val2 = *dest_addr;
  if (load_val2 != REPEAT) {
    bsg_fail();
  }
  
  
  bsg_fence();
  bsg_finish();
  bsg_wait_while(1);
}

