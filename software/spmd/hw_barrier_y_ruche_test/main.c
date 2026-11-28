#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

// One column of 2R+1 tiles, R = BARRIER_RUCHE_FACTOR_Y. The root is at row R,
// so rows 0 and 2R reach it over RS and RN.
#define R BARRIER_RUCHE_FACTOR_Y
#define ROWS bsg_tiles_Y
#define ROOT_ROW (ROWS/2)

#if R < 2
#error "hw_barrier_y_ruche_test needs BARRIER_RUCHE_FACTOR_Y >= 2"
#endif
#if bsg_tiles_X != 1 || bsg_tiles_Y != 2*R+1
#error "hw_barrier_y_ruche_test needs a 1 x (2*BARRIER_RUCHE_FACTOR_Y+1) tile group"
#endif

#define ITERATIONS 16
#define DELAY 1500
enum { P, W, E, N, S, RW, RE, RN, RS, ROOT };

volatile int ready[ROWS];
volatile int start;
volatile int arrived;
volatile int errors[ROWS];

// Row a tile sends to for output direction dir, or -1 if dir is not a Y link.
static int parent_row(int y, int dir)
{
  switch (dir) {
    case N:  return y-1;
    case S:  return y+1;
    case RN: return y-R;
    case RS: return y+R;
    default: return -1;
  }
}

// Input direction at the parent for a child sending in direction dir.
static int parent_input(int dir)
{
  switch (dir) {
    case N:  return S;
    case S:  return N;
    case RN: return RS;
    default: return RN;
  }
}

// Check that config forms one tree rooted at ROOT_ROW: every other row sends
// to a row inside the column, each tile's input mask is exactly P plus its
// children, and every row reaches the root. Rows 0 and ROWS-1 must use the
// ruche links, so the barrier exercises them.
static int check_config(const int *config)
{
  int failures = 0;
  int inputs[ROWS];
  int parent[ROWS];

  for (int y = 0; y < ROWS; y++) {
    inputs[y] = 1 << P;
  }

  for (int y = 0; y < ROWS; y++) {
    int dir = config[y] >> OUTDIR_OFFSET;
    if (y == ROOT_ROW) {
      parent[y] = y;
      if (dir != ROOT) failures++;
      continue;
    }
    int p = parent_row(y, dir);
    if (p < 0 || p >= ROWS) {
      failures++;
      parent[y] = ROOT_ROW;
      continue;
    }
    parent[y] = p;
    inputs[p] |= 1 << parent_input(dir);
  }

  for (int y = 0; y < ROWS; y++) {
    if ((config[y] & ((1 << OUTDIR_OFFSET)-1)) != inputs[y]) failures++;

    int node = y;
    for (int hops = 0; hops < ROWS && node != ROOT_ROW; hops++) {
      node = parent[node];
    }
    if (node != ROOT_ROW) failures++;
  }

  if ((config[0] >> OUTDIR_OFFSET) != RS) failures++;
  if ((config[ROWS-1] >> OUTDIR_OFFSET) != RN) failures++;

  return failures;
}

int main(void)
{
  bsg_set_tile_x_y();

  int config[ROWS];
  bsg_hw_barrier_config_init(config, bsg_tiles_X, bsg_tiles_Y);
  int failures = check_config(config);

  int cfg = config[__bsg_y];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (cfg));
  bsg_remote_store(0, 0, &ready[__bsg_y], 1);
  bsg_fence();

  if (__bsg_y == 0) {
    for (int y = 0; y < ROWS; y++) {
      bsg_wait_while(ready[y] == 0);
    }
    for (int y = 0; y < ROWS; y++) {
      bsg_remote_store(0, y, &start, 1);
    }
    bsg_fence();
  }
  bsg_wait_while(start == 0);

  for (int iteration = 1; iteration <= ITERATIONS; iteration++) {
    // Alternate the late arrival between the two ruche leaves.
    if (__bsg_y == ((iteration & 1) ? 0 : ROWS-1)) {
      for (volatile int delay = 0; delay < DELAY; delay++) { }
    }

    arrived = iteration;
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    for (int y = 0; y < ROWS; y++) {
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
    for (int y = 0; y < ROWS; y++) {
      if (errors[y] != 0) {
        bsg_fail();
      }
    }
    bsg_finish();
  }
  bsg_wait_while(1);
}
