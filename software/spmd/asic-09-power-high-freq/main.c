#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define NUM_ITER 100
#define ANSWER   6400.0f
//#define NUM_ITER 1000000000
//#define ANSWER   16777216.0f

#define fadd_asm(rd_p, rs1_p, rs2_p) \
    asm volatile ("fadd.s %[rd], %[rs1], %[rs2]" \
      : [rd] "=f" (rd_p) \
      : [rs1] "f" ((rs1_p)), [rs2] "f" ((rs2_p)))

int alert = 0;
int done[bsg_tiles_X*bsg_tiles_Y] = {0};
int delay[bsg_tiles_X*bsg_tiles_Y] = {
  0,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1
};

float sum = 0.0f;
float incr = 1.0f;
float answer = ANSWER;

int main()
{
  bsg_set_tile_x_y();
/*
  if (__bsg_id == 0) {
    int cfg_pod;
    asm volatile ("csrr %[cfg_pod], 0x360" : [cfg_pod] "=r" (cfg_pod));
    bsg_print_int(cfg_pod);
    bsg_fence();
  }
*/
  int mydelay = delay[__bsg_id];
  bsg_fence();

  // send done;
  volatile int* remote_done_ptr = bsg_remote_ptr(0,0,&done[__bsg_id]);
  *remote_done_ptr = 1;
  bsg_fence();

  if (__bsg_id == 0) {
    int done_count = 0;
    while (done_count < bsg_tiles_X*bsg_tiles_Y) {
      if (done[done_count] == 0) {
        continue;
      } else {
        done_count++;
      }
    }

    // wakeup everyone;
    for (int y = 0; y < bsg_tiles_Y; y++) {
      for (int x = 0; x < bsg_tiles_X; x++) {
        volatile int* remote_alert_ptr = bsg_remote_ptr(x,y,&alert);
        *remote_alert_ptr = 1;
      }
    }
  } else {
    int tmp;
    while (1) {
      tmp = bsg_lr(&alert);
      if (tmp) {
        break;
      } else {
        tmp = bsg_lr_aq(&alert);
        if (tmp) {
          break;
        }
      }
    } 
  }

  switch (mydelay) {
    case 3:
      asm volatile ("nop");
      asm volatile ("nop");
      asm volatile ("nop");
      break;
    case 2:
      asm volatile ("nop");
      asm volatile ("nop");
      break;
    case 1:
      asm volatile ("nop");
      asm volatile ("nop");
      break;
    case 0:
      break;
  }

  for (int i = 0; i < NUM_ITER; i++) {
    // fadd x 64
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
    fadd_asm(sum, sum, incr);
  }

  if (sum == answer) {
    bsg_finish();
  } else {
    bsg_fail();
  }

  bsg_wait_while(1);
}

