#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

//#define REPEAT 100000000
#define REPEAT 1000000
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
  uint32_t send_down    = (pod_y == 1) && (__bsg_y == 7); // y = 15
  uint32_t send_up      = (pod_y == 3) && (__bsg_y == 0); // y = 24
 
  // calculate dest addr;
  volatile uint32_t* dest_addr;
  if (send_down) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((24)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  } else if (send_up) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((15)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  }
  
  if (send_up || send_down) {
    // seed;
    uint8_t curr = (__bsg_id + 1) & 0xff;
    // local buffer with byte pointer;
    uint8_t* buffer_byte = (uint8_t*) local_buffer;

    for (uint32_t i = 0; i < REPEAT; i++) {
      // generate PRBS;
      for (int j = 0; j < BUFFER_LEN_BYTES; j++) {
        buffer_byte[j] = curr;
        int newbit = ((curr >> 7) ^ (curr > 5) ^ (curr >> 4) ^ (curr >> 3)) & 1;
        curr = ((curr << 1) | newbit) & 0xff;
      }
      // send remote stores;
      uint32_t temp0 = local_buffer[0];
      uint32_t temp1 = local_buffer[1];
      uint32_t temp2 = local_buffer[2];
      uint32_t temp3 = local_buffer[3];
      uint32_t temp4 = local_buffer[4];
      uint32_t temp5 = local_buffer[5];
      uint32_t temp6 = local_buffer[6];
      uint32_t temp7 = local_buffer[7];
      asm volatile("": : :"memory");
      dest_addr[0] = temp0;
      dest_addr[1] = temp1;
      dest_addr[2] = temp2;
      dest_addr[3] = temp3;
      dest_addr[4] = temp4;
      dest_addr[5] = temp5;
      dest_addr[6] = temp6;
      dest_addr[7] = temp7;
      bsg_fence();
      asm volatile("": : :"memory");
      // remote load;
      // verify;
      uint32_t val0 = dest_addr[0];
      uint32_t val1 = dest_addr[1];
      uint32_t val2 = dest_addr[2];
      uint32_t val3 = dest_addr[3];
      uint32_t val4 = dest_addr[4];
      uint32_t val5 = dest_addr[5];
      uint32_t val6 = dest_addr[6];
      uint32_t val7 = dest_addr[7];
      asm volatile("": : :"memory");
      if (val0 != local_buffer[0]) bsg_fail();
      if (val1 != local_buffer[1]) bsg_fail();
      if (val2 != local_buffer[2]) bsg_fail();
      if (val3 != local_buffer[3]) bsg_fail();
      if (val4 != local_buffer[4]) bsg_fail();
      if (val5 != local_buffer[5]) bsg_fail();
      if (val6 != local_buffer[6]) bsg_fail();
      if (val7 != local_buffer[7]) bsg_fail();
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
