#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define REPEAT 1000
#define MAX_INDEX 2048

int hold;

int main()
{
  bsg_set_tile_x_y();

  // credit limit to 32;
  int climit = 31;
  asm volatile ("csrw 0xfc0, %[climit]" : : [climit] "r" (climit));

  
  // top tile rows;
  uint32_t * myaddr = (uint32_t*) (
    0x81000000 |
    (1 << 9)  | // send to bot;
    (__bsg_x << 5)
  );

  if (__bsg_y == 7) {
    for (int i = 0; i < REPEAT; i++) {
      for (int j = 0; j < MAX_INDEX; j++) {
        uint32_t * curr_addr = (uint32_t *) ((uint32_t) myaddr | (j << 10));
        asm volatile ("lw x0, 0(%[curr_addr])" : : [curr_addr] "r" (curr_addr));
      }
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
