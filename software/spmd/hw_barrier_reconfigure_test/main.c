
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define N 4
#define NUM_WORDS 16


extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int data[NUM_WORDS] = {0};

int barcfg_4x4[4*4] __attribute__ ((section (".dram"))) = {0};
int barcfg_16x8[16*8] __attribute__ ((section (".dram"))) = {0};


int main()
{
  bsg_set_tile_x_y();

  if (__bsg_id == 0) {
    bsg_hw_barrier_config_init(barcfg_4x4, 4, 4);
    bsg_hw_barrier_config_init(barcfg_16x8, 16, 8);
    bsg_fence();
  }

  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);

  // enable remote interrupt
  asm volatile ("csrrs x0, mstatus, %0" : : "r" (0x8));
  asm volatile ("csrrs x0, mie, %0" : : "r" (0x10000));

  // config hw barrier for 4x4
  int small_org_x = (__bsg_x / 4) * 4;
  int small_org_y = (__bsg_y / 4) * 4;
  int small_x = __bsg_x % 4;
  int small_y = __bsg_y % 4;
  int small_id = small_x + (4*small_y);
  int barcfg = barcfg_4x4[small_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (barcfg));

  int temp[NUM_WORDS];
  for (int n = 0; n < N; n++) {
    int tx = small_org_x + ((small_x + n) % 4);
    int ty = small_org_y + ((small_y + n) % 4);
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_load(tx, ty, &data[i], temp[i]);
    }
    
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    for (int i = 0; i < N; i++) {
      temp[i]++;
      bsg_remote_store(tx, ty, &data[i], temp[i]);
    }
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }




  // reconfigure to  16x8
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
  barcfg = barcfg_16x8[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (barcfg));
  
  for (int n = 0; n < 4*N; n++) {
    int tx = (__bsg_x + n) % bsg_tiles_X;
    int ty = (__bsg_y + n) % bsg_tiles_Y;
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_load (tx, ty, &data[i], temp[i]);
    }

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
    
    for (int i = 0; i < NUM_WORDS; i++) {
      temp[i]++;
      bsg_remote_store(tx, ty, &data[i], temp[i]);
    }
    
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }




  // reconfigure to  4x4
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
  barcfg = barcfg_4x4[small_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (barcfg));

  for (int n = 0; n < N; n++) {
    int tx = small_org_x + ((small_x + n) % 4);
    int ty = small_org_y + ((small_y + n) % 4);
    for (int i = 0; i < NUM_WORDS; i++) {
      bsg_remote_load(tx, ty, &data[i], temp[i]);
    }
    
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    for (int i = 0; i < NUM_WORDS; i++) {
      temp[i]++;
      bsg_remote_store(tx, ty, &data[i], temp[i]);
    }

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }


  // everyone validate
  for (int i = 0; i < N; i++) {
    if (data[i] != 6*N) {
      bsg_fail();
    }
  }

  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);

  if (__bsg_id == 0) {
    bsg_finish();
  }
  
  bsg_wait_while(1);
}

