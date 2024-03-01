#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

#define REPEAT 1000000

int data;
int hold;

// store in DMEM;
uint32_t word0 = 0x00000000;
uint32_t word1 = 0xffffffff;

int main()
{
  bsg_set_tile_x_y();

  // credit limit to 32;
  int climit = 32;
  asm volatile ("csrw 0xfc0, %[climit]" : : [climit] "r" (climit));

  // load from DMEM
  float *floatptr0 = (float*)(&word0);
  float *floatptr1 = (float*)(&word1);

  // calculate global_x,y;
  int cfg_pod;
  asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
  int pod_x = cfg_pod & 0x7;
  int pod_y = (cfg_pod & 0x78) >> 3; // 1 = podrow 0, 3 = podrow1;
  int global_x = (pod_x<<4) + __bsg_x;
  int global_y = (pod_y<<3) + __bsg_y;
  uint32_t send_down    = (pod_y == 1 || pod_y == 3 || pod_y == 5) && (__bsg_y >= 4); // y = 15
  uint32_t send_up      = (pod_y == 3 || pod_y == 5 || pod_y == 7) && (__bsg_y <= 3); // y = 24
 
  // calculate dest addr;
  volatile float* dest_addr;
  if (send_down) {
    dest_addr  = (float*) (
      0x40000000 |
      ((global_y+12)<<23) |
      ((global_x)<<16) |
      ((int) &data)
    );
  } else if (send_up) {
    dest_addr  = (float*) (
      0x40000000 |
      ((global_y-12)<<23) |
      ((global_x)<<16) |
      ((int) &data)
    );
  }
  
  if (send_up || send_down) {
    // send remote stores;
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[0]  = *floatptr1;
      dest_addr[1]  = *floatptr1;
      dest_addr[2]  = *floatptr1;
      dest_addr[3]  = *floatptr1;
      dest_addr[4]  = *floatptr1;
      dest_addr[5]  = *floatptr1;
      dest_addr[6]  = *floatptr1;
      dest_addr[7]  = *floatptr1;
      dest_addr[8]  = *floatptr1;
      dest_addr[9]  = *floatptr1;
      dest_addr[10] = *floatptr1;
      dest_addr[11] = *floatptr1;
      dest_addr[12] = *floatptr1;
      dest_addr[13] = *floatptr1;
      dest_addr[14] = *floatptr1;
      dest_addr[15] = *floatptr1;
    }
    // send remote loads;
    for (uint32_t i = 0; i < REPEAT; i++) {
      float var_0  = dest_addr[0];
      float var_1  = dest_addr[1];
      float var_2  = dest_addr[2];
      float var_3  = dest_addr[3];
      float var_4  = dest_addr[4];
      float var_5  = dest_addr[5];
      float var_6  = dest_addr[6];
      float var_7  = dest_addr[7];
      float var_8  = dest_addr[8];
      float var_9  = dest_addr[9];
      float var_10 = dest_addr[10];
      float var_11 = dest_addr[11];
      float var_12 = dest_addr[12];
      float var_13 = dest_addr[13];
      float var_14 = dest_addr[14];
      float var_15 = dest_addr[15];
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}