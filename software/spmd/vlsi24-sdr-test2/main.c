#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define REPEAT 200000000

int data;
int hold;

int main()
{
  bsg_set_tile_x_y();

  // credit limit to 32;
  int climit = 32;
  asm volatile ("csrw 0xfc0, %[climit]" : : [climit] "r" (climit));

  // Words to store;
  uint32_t word0 = 0x00000000;
  uint32_t word1 = 0xffffffff;

  // calculate global_x,y;
  int cfg_pod;
  asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
  int pod_x = cfg_pod & 0x7;
  int pod_y = (cfg_pod & 0x78) >> 3; // 1 = podrow 0, 3 = podrow1;
  int global_x = (pod_x<<4) + __bsg_x;
  int global_y = (pod_y<<3) + __bsg_y;
  uint32_t send_down    = (pod_y == 1) && (__bsg_y == 6 || __bsg_y == 7); // y = 15
  uint32_t send_up      = (pod_y == 3) && (__bsg_y == 0 || __bsg_y == 1); // y = 24
 
  // calculate dest addr;
  volatile uint32_t* dest_addr;
  if (send_down) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((global_y+10)<<23) |
      ((global_x)<<16) |
      ((int) &data)
    );
  } else if (send_up) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((global_y-10)<<23) |
      ((global_x)<<16) |
      ((int) &data)
    );
  }
  
  if (send_up || send_down) {
    // send remote stores;
    bsg_unroll(1)
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;

      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
      dest_addr[0] = 0x00000000;
      dest_addr[0] = 0xffffffff;
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
