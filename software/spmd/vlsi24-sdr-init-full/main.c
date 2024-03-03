#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>


#define BUFFER_LEN_WORDS 8
#define BUFFER_LEN_BYTES 32

uint32_t local_buffer[BUFFER_LEN_WORDS];
uint32_t remote_buffer[BUFFER_LEN_WORDS];
int hold;

int main()
{
  bsg_set_tile_x_y();

  // credit limit to 32;
  int climit = 1;
  asm volatile ("csrw 0xfc0, %[climit]" : : [climit] "r" (climit));

  // calculate global_x,y;
  int cfg_pod;
  asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
  int pod_x = cfg_pod & 0x7;
  int pod_y = (cfg_pod & 0x78) >> 3; // 1 = podrow 0, 3 = podrow1;
  int global_x = (pod_x<<4) + __bsg_x;
  int global_y = (pod_y<<3) + __bsg_y;
  uint32_t send_down    = (pod_y == 1 || pod_y == 3 || pod_y == 5) && (__bsg_y == 7); // y = 15
  uint32_t send_up      = (pod_y == 3 || pod_y == 5 || pod_y == 7) && (__bsg_y == 0); // y = 24
 
  // calculate dest addr;
  volatile uint32_t* dest_addr;
  if (send_down) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((global_y+9)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  } else if (send_up) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((global_y-9)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  }
  
  if (send_up || send_down) {
    for (uint32_t i = 0; i < 1000000000; i++) {
      asm volatile ("nop");
    }
  }
  
  if (send_up) {
    asm volatile("": : :"memory");
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    // link x==31 has 64 more finish packets
    asm volatile("": : :"memory");
  }

  if (send_down) {
    asm volatile("": : :"memory");
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    dest_addr[0] = 0;
    asm volatile("": : :"memory");
  }

  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
