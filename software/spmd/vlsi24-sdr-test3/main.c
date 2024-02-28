#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define REPEAT 1000000

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
  uint32_t send_down    = (pod_y == 1) && (1); // y = 15
  uint32_t send_up      = (pod_y == 3) && (1); // y = 24
 
  // calculate dest addr;
  volatile uint32_t* dest_addr;
  if (send_down) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((__bsg_y+24)<<23) |
      ((global_x)<<16) |
      ((int) &data)
    );
  } else if (send_up) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((__bsg_y+8)<<23) |
      ((global_x)<<16) |
      ((int) &data)
    );
  }
  
  if (send_up || send_down) {
    // send remote stores;
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[0]  = word1;
      dest_addr[1]  = word1;
      dest_addr[2]  = word1;
      dest_addr[3]  = word1;
      dest_addr[4]  = word1;
      dest_addr[5]  = word1;
      dest_addr[6]  = word1;
      dest_addr[7]  = word1;
      dest_addr[8]  = word1;
      dest_addr[9]  = word1;
      dest_addr[10] = word1;
      dest_addr[11] = word1;
      dest_addr[12] = word1;
      dest_addr[13] = word1;
      dest_addr[14] = word1;
      dest_addr[15] = word1;
    }
    // send remote loads;
    for (uint32_t i = 0; i < REPEAT; i++) {
      uint32_t var_0  = dest_addr[0];
      uint32_t var_1  = dest_addr[1];
      uint32_t var_2  = dest_addr[2];
      uint32_t var_3  = dest_addr[3];
      uint32_t var_4  = dest_addr[4];
      uint32_t var_5  = dest_addr[5];
      uint32_t var_6  = dest_addr[6];
      uint32_t var_7  = dest_addr[7];
      uint32_t var_8  = dest_addr[8];
      uint32_t var_9  = dest_addr[9];
      uint32_t var_10 = dest_addr[10];
      uint32_t var_11 = dest_addr[11];
      uint32_t var_12 = dest_addr[12];
      uint32_t var_13 = dest_addr[13];
      uint32_t var_14 = dest_addr[14];
      uint32_t var_15 = dest_addr[15];
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}