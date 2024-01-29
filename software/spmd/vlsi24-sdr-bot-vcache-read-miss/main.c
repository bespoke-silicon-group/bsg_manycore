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

  // calculate global_x,y;
  int cfg_pod;
  asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
  int pod_x = cfg_pod & 0x7;
  int pod_y = (cfg_pod & 0x78) >> 3; // 1 = podrow 0, 3 = podrow1;
  
  // top tile rows;
  uint32_t * myaddr = (uint32_t*) (
    0x81000000 |
    (1 << 9)  | // send to bot;
    (__bsg_x << 5)
  );

  if (__bsg_y == 7 && pod_y == 1 || __bsg_y == 0 && pod_y == 3) {
      for (int j = 0; j < MAX_INDEX; j++) {
        uint32_t * curr_addr = (uint32_t *) ((uint32_t) myaddr | (j << 10));
        curr_addr[0] = 0x0000ffff;
        curr_addr[1] = 0xffff0000;
        curr_addr[2] = 0x0000ffff;
        curr_addr[3] = 0xffff0000;
        curr_addr[4] = 0x0000ffff;
        curr_addr[5] = 0xffff0000;
        curr_addr[6] = 0x0000ffff;
        curr_addr[7] = 0xffff0000;
      }
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
