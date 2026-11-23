#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"

#define ITERATIONS 16
#define OUTDIR_OFFSET 16

enum { P, W, E, N, S, RW, RE, RN, RS, ROOT };

// Rows 0 and 4 reach the root at row 2 over RS and RN, respectively.
static const int config[5] = {
  (RS << OUTDIR_OFFSET) | (1 << P),
  (S << OUTDIR_OFFSET) | (1 << P),
  (ROOT << OUTDIR_OFFSET) | (1 << P) | (1 << N) | (1 << S) | (1 << RN) | (1 << RS),
  (N << OUTDIR_OFFSET) | (1 << P),
  (RN << OUTDIR_OFFSET) | (1 << P)
};

volatile int ready[5];
volatile int start;
volatile int arrived;
volatile int errors[5];

int main(void)
{
  bsg_set_tile_x_y();

  int cfg = config[__bsg_y];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (cfg));
  bsg_remote_store(0, 0, &ready[__bsg_y], 1);
  bsg_fence();

  if (__bsg_y == 0) {
    for (int y = 0; y < 5; y++) {
      bsg_wait_while(ready[y] == 0);
    }
    for (int y = 0; y < 5; y++) {
      bsg_remote_store(0, y, &start, 1);
    }
    bsg_fence();
  }
  bsg_wait_while(start == 0);

  int failures = 0;
  for (int iteration = 1; iteration <= ITERATIONS; iteration++) {
    if (__bsg_y == ((iteration & 1) ? 0 : 4)) {
      for (volatile int delay = 0; delay < 1500; delay++) { }
    }

    arrived = iteration;
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    for (int y = 0; y < 5; y++) {
      int value;
      bsg_remote_load(0, y, &arrived, value);
      if (value != iteration) {
        failures++;
      }
    }

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }

  bsg_remote_store(0, 0, &errors[__bsg_y], failures);
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  if (__bsg_y == 0) {
    for (int y = 0; y < 5; y++) {
      if (errors[y] != 0) {
        bsg_fail();
      }
    }
    bsg_finish();
  }
  bsg_wait_while(1);
}
