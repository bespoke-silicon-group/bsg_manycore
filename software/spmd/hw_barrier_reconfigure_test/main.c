
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config.h"

#define N 4

extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int data = 0;



int main()
{
  bsg_set_tile_x_y();

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

  for (int i = 0; i < N; i++) {
    int temp;
    int tx = small_org_x + ((small_x + i) % 4);
    int ty = small_org_y + ((small_y + i) % 4);
    bsg_remote_load(tx, ty, &data, temp);
    
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    temp++;
    bsg_remote_store(tx, ty, &data, temp);

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }




  // reconfigure to  16x8
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
  barcfg = barcfg_16x8[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (barcfg));
  
  for (int i = 0; i < 4*N; i++) {
    int temp;
    int tx = (__bsg_x + i) % bsg_tiles_X;
    int ty = (__bsg_y + i) % bsg_tiles_Y;
    bsg_remote_load (tx, ty, &data, temp);

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
    
    temp++;
    bsg_remote_store(tx, ty, &data, temp);
    
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }




  // reconfigure to  4x4
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);
  barcfg = barcfg_4x4[small_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (barcfg));

  for (int i = 0; i < N; i++) {
    int temp;
    int tx = small_org_x + ((small_x + i) % 4);
    int ty = small_org_y + ((small_y + i) % 4);
    bsg_remote_load(tx, ty, &data, temp);
    
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    temp++;
    bsg_remote_store(tx, ty, &data, temp);

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }


  // validate
  if (__bsg_id == 0) {
    for (int y = 0; y < bsg_tiles_Y; y++) {
      for (int x = 0; x < bsg_tiles_X; x++) {
        int temp = -1;
        bsg_remote_load(x,y,&data,temp);
        if (temp != 6*N) {
          bsg_fail();
          bsg_wait_while(1);
        }
      }
    }
    bsg_finish();
  }

  
  bsg_wait_while(1);
}

