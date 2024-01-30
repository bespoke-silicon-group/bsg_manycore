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
  
  if (send_up || send_down) {
    for (uint32_t i = 0; i < REPEAT; i++) {
      dest_addr[ 0] = 0x4b296c82;
      dest_addr[ 1] = 0x75d4b8a5;
      dest_addr[ 2] = 0x73f3e966;
      dest_addr[ 3] = 0xe2b4dc6c;
      dest_addr[ 4] = 0x5f5a1d85;
      dest_addr[ 5] = 0x7f4854a6;
      dest_addr[ 6] = 0xd4a4e4f1;
      dest_addr[ 7] = 0x32673c0b;
      dest_addr[ 8] = 0xd39d7a9e;
      dest_addr[ 9] = 0x85d78695;
      dest_addr[10] = 0xb38daa33;
      dest_addr[11] = 0x3a20fe97;
      dest_addr[12] = 0x7d3936c0;
      dest_addr[13] = 0xc028d072;
      dest_addr[14] = 0x63a788a1;
      dest_addr[15] = 0xfaa2fa60;
      asm volatile("": : :"memory");
    }
    //for (uint32_t i = 0; i < REPEAT; i++) {
    //  dest_addr[16] = 0x7af9072e;
    //  dest_addr[17] = 0xb0403600;
    //  dest_addr[18] = 0x953e060e;
    //  dest_addr[19] = 0x6e7073a4;
    //  dest_addr[20] = 0xe88de494;
    //  dest_addr[21] = 0x7c1c5286;
    //  dest_addr[22] = 0x2161f2ef;
    //  dest_addr[23] = 0x09598c20;
    //  dest_addr[24] = 0x0345da72;
    //  dest_addr[25] = 0x6ba9bfc4;
    //  dest_addr[26] = 0x3eae6217;
    //  dest_addr[27] = 0xefa1a0a9;
    //  dest_addr[28] = 0xf2c991ae;
    //  dest_addr[29] = 0x9e91caab;
    //  dest_addr[30] = 0x69e182d0;
    //  dest_addr[31] = 0x2056f8bb;
    //  asm volatile("": : :"memory");
    //}
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
      uint32_t val8  = dest_addr[ 8];
      uint32_t val9  = dest_addr[ 9];
      uint32_t val10 = dest_addr[10];
      uint32_t val11 = dest_addr[11];
      uint32_t val12 = dest_addr[12];
      uint32_t val13 = dest_addr[13];
      uint32_t val14 = dest_addr[14];
      uint32_t val15 = dest_addr[15];
      asm volatile("": : :"memory");
      if (val0  != 0x4b296c82) bsg_fail();
      if (val1  != 0x75d4b8a5) bsg_fail();
      if (val2  != 0x73f3e966) bsg_fail();
      if (val3  != 0xe2b4dc6c) bsg_fail();
      if (val4  != 0x5f5a1d85) bsg_fail();
      if (val5  != 0x7f4854a6) bsg_fail();
      if (val6  != 0xd4a4e4f1) bsg_fail();
      if (val7  != 0x32673c0b) bsg_fail();
      if (val8  != 0xd39d7a9e) bsg_fail();
      if (val9  != 0x85d78695) bsg_fail();
      if (val10 != 0xb38daa33) bsg_fail();
      if (val11 != 0x3a20fe97) bsg_fail();
      if (val12 != 0x7d3936c0) bsg_fail();
      if (val13 != 0xc028d072) bsg_fail();
      if (val14 != 0x63a788a1) bsg_fail();
      if (val15 != 0xfaa2fa60) bsg_fail();
    }
    //for (uint32_t i = 0; i < REPEAT/10; i++) {
    //  uint32_t val16 = dest_addr[16];
    //  uint32_t val17 = dest_addr[17];
    //  uint32_t val18 = dest_addr[18];
    //  uint32_t val19 = dest_addr[19];
    //  uint32_t val20 = dest_addr[20];
    //  uint32_t val21 = dest_addr[21];
    //  uint32_t val22 = dest_addr[22];
    //  uint32_t val23 = dest_addr[23];
    //  uint32_t val24 = dest_addr[24];
    //  uint32_t val25 = dest_addr[25];
    //  uint32_t val26 = dest_addr[26];
    //  uint32_t val27 = dest_addr[27];
    //  uint32_t val28 = dest_addr[28];
    //  uint32_t val29 = dest_addr[29];
    //  uint32_t val30 = dest_addr[30];
    //  uint32_t val31 = dest_addr[31];
    //  asm volatile("": : :"memory");
    //  if (val16 != 0x7af9072e) bsg_fail();
    //  if (val17 != 0xb0403600) bsg_fail();
    //  if (val18 != 0x953e060e) bsg_fail();
    //  if (val19 != 0x6e7073a4) bsg_fail();
    //  if (val20 != 0xe88de494) bsg_fail();
    //  if (val21 != 0x7c1c5286) bsg_fail();
    //  if (val22 != 0x2161f2ef) bsg_fail();
    //  if (val23 != 0x09598c20) bsg_fail();
    //  if (val24 != 0x0345da72) bsg_fail();
    //  if (val25 != 0x6ba9bfc4) bsg_fail();
    //  if (val26 != 0x3eae6217) bsg_fail();
    //  if (val27 != 0xefa1a0a9) bsg_fail();
    //  if (val28 != 0xf2c991ae) bsg_fail();
    //  if (val29 != 0x9e91caab) bsg_fail();
    //  if (val30 != 0x69e182d0) bsg_fail();
    //  if (val31 != 0x2056f8bb) bsg_fail();
    //}
  }


  bsg_fence(); 
  bsg_finish();
  bsg_lr(&hold);
  bsg_lr_aq(&hold);
}
