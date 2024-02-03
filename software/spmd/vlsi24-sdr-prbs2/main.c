#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

//#define REPEAT 100000000
#define REPEAT 10000000
#define BUFFER_LEN_WORDS 8
#define BUFFER_LEN_BYTES 32

uint32_t local_buffer[BUFFER_LEN_WORDS];
uint32_t remote_buffer[BUFFER_LEN_WORDS];
int hold;

int main()
{
  bsg_set_tile_x_y();

  // credit limit to 32;
  int climit = 32;
  asm volatile ("csrw 0xfc0, %[climit]" : : [climit] "r" (climit));

  // calculate global_x,y;
  int cfg_pod;
  asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
  int pod_x = cfg_pod & 0x7;
  int pod_y = (cfg_pod & 0x78) >> 3; // 1 = podrow 0, 3 = podrow1;
  int global_x = (pod_x<<4) + __bsg_x;
  uint32_t send_down    = (pod_y == 1) && (__bsg_y < 4); // y = 15
  uint32_t send_up      = (pod_y == 3) && (__bsg_y < 4); // y = 24
  uint32_t read_down    = (pod_y == 1) && (__bsg_y >= 4); // y = 15
  uint32_t read_up      = (pod_y == 3) && (__bsg_y >= 4); // y = 24
 
  // calculate dest addr;
  volatile uint32_t* dest_addr;
  if (send_down) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((__bsg_y+24)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  } else if (send_up) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((__bsg_y+8)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  }  else if (read_down) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((__bsg_y+20)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  } else if (read_up) {
    dest_addr  = (uint32_t*) (
      0x40000000 |
      ((__bsg_y+4)<<23) |
      ((global_x)<<16) |
      ((int) &remote_buffer)
    );
  }
  
  uint32_t random_data_0 = 0x4b296c82;
  uint32_t random_data_1 = 0x75d4b8a5;
  uint32_t random_data_2 = 0x73f3e966;
  uint32_t random_data_3 = 0xe2b4dc6c;
  uint32_t random_data_4 = 0x5f5a1d85;
  uint32_t random_data_5 = 0x7f4854a6;
  uint32_t random_data_6 = 0xd4a4e4f1;
  uint32_t random_data_7 = 0x32673c0b;
  if (__bsg_y % 4 == 1) {
    random_data_0 = 0xd39d7a9e;
    random_data_1 = 0x85d78695;
    random_data_2 = 0xb38daa33;
    random_data_3 = 0x3a20fe97;
    random_data_4 = 0x7d3936c0;
    random_data_5 = 0xc028d072;
    random_data_6 = 0x63a788a1;
    random_data_7 = 0xfaa2fa60;
  } else if (__bsg_y % 4 == 2) {
    random_data_0 = 0x7af9072e;
    random_data_1 = 0xb0403600;
    random_data_2 = 0x953e060e;
    random_data_3 = 0x6e7073a4;
    random_data_4 = 0xe88de494;
    random_data_5 = 0x7c1c5286;
    random_data_6 = 0x2161f2ef;
    random_data_7 = 0x09598c20;
  } else if (__bsg_y % 4 == 3) {
    random_data_0 = 0x0345da72;
    random_data_1 = 0x6ba9bfc4;
    random_data_2 = 0x3eae6217;
    random_data_3 = 0xefa1a0a9;
    random_data_4 = 0xf2c991ae;
    random_data_5 = 0x9e91caab;
    random_data_6 = 0x69e182d0;
    random_data_7 = 0x2056f8bb;
  }
  
  if (send_up || send_down) {
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[ 0] = random_data_0;
      dest_addr[ 1] = random_data_1;
      dest_addr[ 2] = random_data_2;
      dest_addr[ 3] = random_data_3;
      dest_addr[ 4] = random_data_4;
      dest_addr[ 5] = random_data_5;
      dest_addr[ 6] = random_data_6;
      dest_addr[ 7] = random_data_7;
      asm volatile("": : :"memory");
    }
  }
  
  if (read_up || read_down) {
    for (uint32_t i = 0; i < REPEAT/10; i++) {
      // wait for send
      asm volatile ("nop");
    }
    for (uint32_t i = 0; i < REPEAT/10; i++) {
      // remote load;
      // verify;
      uint32_t val0  = dest_addr[ 0];
      uint32_t val1  = dest_addr[ 1];
      uint32_t val2  = dest_addr[ 2];
      uint32_t val3  = dest_addr[ 3];
      uint32_t val4  = dest_addr[ 4];
      uint32_t val5  = dest_addr[ 5];
      uint32_t val6  = dest_addr[ 6];
      uint32_t val7  = dest_addr[ 7];
      asm volatile("": : :"memory");
      if (val0  != random_data_0) bsg_fail();
      if (val1  != random_data_1) bsg_fail();
      if (val2  != random_data_2) bsg_fail();
      if (val3  != random_data_3) bsg_fail();
      if (val4  != random_data_4) bsg_fail();
      if (val5  != random_data_5) bsg_fail();
      if (val6  != random_data_6) bsg_fail();
      if (val7  != random_data_7) bsg_fail();
    }
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
