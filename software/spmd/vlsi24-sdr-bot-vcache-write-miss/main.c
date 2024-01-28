#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define REPEAT 1
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
    uint32_t curr_data = 0x0000ffff;
    for (int i = 0; i < REPEAT; i++) {
      for (int j = 0; j < MAX_INDEX; j++) {
        uint32_t * curr_addr = (uint32_t *) ((uint32_t) myaddr | (j << 10));
        curr_addr[0] = curr_data;
        curr_data = curr_data ^ 0xffffffff; // flip store bits;
      }
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
