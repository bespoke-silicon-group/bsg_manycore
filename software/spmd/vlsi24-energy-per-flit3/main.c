#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define DX 0
#define LEN 32
#define REPEAT 8

int data[LEN];
int hold;

int main()
{
  bsg_set_tile_x_y();

  // credit limit to 32;
  int climit = 31;
  asm volatile ("csrw 0xfc0, %[climit]" : : [climit] "r" (climit));

  // Words to store;
  uint32_t word0 = 0xaaaaaaaa;
  uint32_t word1 = 0x55555555;

  // calculate global_x;
  int cfg_pod;
  asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
  int pod_x = cfg_pod & 0x7;
  int global_x = (pod_x<<4) + __bsg_x;

  uint32_t send_right = ((__bsg_x % 4) == 0) && (global_x <= 64);
  uint32_t send_left  = ((__bsg_x % 4) == 3) && (global_x >= 31); 
 
  // calculate dest addr;
  volatile uint32_t* dest_addr;
  if (send_right) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((8+__bsg_y)<<23) |
      ((global_x+DX)<<16) |
      ((int) &data[0])
    );
  } else if (send_left) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((8+__bsg_y)<<23) |
      ((global_x-DX)<<16) |
      ((int) &data[0])
    );
  }
  
  if (send_left || send_right) {
    // send remote stores;
    bsg_unroll(1)
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[0] = word0;
      dest_addr[1] = word1;
      dest_addr[2] = word0;
      dest_addr[3] = word1;
      dest_addr[4] = word0;
      dest_addr[5] = word1;
      dest_addr[6] = word0;
      dest_addr[7] = word1;

      dest_addr[8] = word0;
      dest_addr[9] = word1;
      dest_addr[10] = word0;
      dest_addr[11] = word1;
      dest_addr[12] = word0;
      dest_addr[13] = word1;
      dest_addr[14] = word0;
      dest_addr[15] = word1;

      dest_addr[16] = word0;
      dest_addr[17] = word1;
      dest_addr[18] = word0;
      dest_addr[19] = word1;
      dest_addr[20] = word0;
      dest_addr[21] = word1;
      dest_addr[22] = word0;
      dest_addr[23] = word1;

      dest_addr[24] = word0;
      dest_addr[25] = word1;
      dest_addr[26] = word0;
      dest_addr[27] = word1;
      dest_addr[28] = word0;
      dest_addr[29] = word1;
      dest_addr[30] = word0;
      dest_addr[31] = word1;
    }
    bsg_unroll(1)
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[0] = word0;
      dest_addr[1] = word1;
      dest_addr[2] = word0;
      dest_addr[3] = word1;
      dest_addr[4] = word0;
      dest_addr[5] = word1;
      dest_addr[6] = word0;
      dest_addr[7] = word1;

      dest_addr[8] = word0;
      dest_addr[9] = word1;
      dest_addr[10] = word0;
      dest_addr[11] = word1;
      dest_addr[12] = word0;
      dest_addr[13] = word1;
      dest_addr[14] = word0;
      dest_addr[15] = word1;

      dest_addr[16] = word0;
      dest_addr[17] = word1;
      dest_addr[18] = word0;
      dest_addr[19] = word1;
      dest_addr[20] = word0;
      dest_addr[21] = word1;
      dest_addr[22] = word0;
      dest_addr[23] = word1;

      dest_addr[24] = word0;
      dest_addr[25] = word1;
      dest_addr[26] = word0;
      dest_addr[27] = word1;
      dest_addr[28] = word0;
      dest_addr[29] = word1;
      dest_addr[30] = word0;
      dest_addr[31] = word1;
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
