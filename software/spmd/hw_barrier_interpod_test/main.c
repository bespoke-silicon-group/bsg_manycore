//  One hardware barrier spanning every compute tile of every pod.
//
//  The program runs in all pods with one tile group per pod covering the whole
//  pod. Barrier links skip the vcache rows, so the compute tiles of all pods
//  form one (bsg_pods_X*bsg_tiles_X) x (bsg_pods_Y*bsg_tiles_Y) grid for the
//  barrier network. bsg_hw_barrier_config_init builds one tree over that grid;
//  its root is at the grid center, so leaves in every pod reach it over local
//  and ruche barrier links that cross pod boundaries in X and Y.
//
//  Each iteration delays one corner tile of the grid, then checks after the
//  barrier that the late tile, and the tile diagonally opposite the checker,
//  have both arrived. A barrier that releases early fails the check.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#if bsg_tiles_X != bsg_global_X || bsg_tiles_Y != bsg_global_Y
#error "hw_barrier_interpod_test needs one tile group covering each whole pod"
#endif

#define GRID_X (bsg_pods_X*bsg_tiles_X)
#define GRID_Y (bsg_pods_Y*bsg_tiles_Y)
#define ITERATIONS 8
#define DELAY 2000
#define POD_ID_VALID 0x10000

// Barrier configuration for the whole grid; each pod builds its own copy.
int barcfg[GRID_X*GRID_Y] __attribute__ ((section (".dram"))) = {0};

// Pod-local AMOADD barrier used once, after barcfg is built.
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;

volatile int pod_id = -1;
volatile int arrived = 0;

static inline int grid_load(int gx, int gy, volatile int *addr)
{
  int value;
  bsg_global_pod_load(gx / bsg_tiles_X, gy / bsg_tiles_Y,
                      gx % bsg_tiles_X, gy % bsg_tiles_Y, addr, value);
  return value;
}

int main()
{
  bsg_set_tile_x_y();

  // Find this tile's pod. Every tile writes each pod's pod_id at its own
  // (x,y). The value depends only on the target pod, so stores from different
  // pods to the same tile agree, and this tile's own store always arrives.
  for (int py = 0; py < bsg_pods_Y; py++) {
    for (int px = 0; px < bsg_pods_X; px++) {
      bsg_global_pod_store(px, py, __bsg_x, __bsg_y, &pod_id,
                           POD_ID_VALID | (py << 8) | px);
    }
  }
  bsg_fence();
  bsg_wait_while(pod_id == -1);
  int my_pod_x = pod_id & 0xff;
  int my_pod_y = (pod_id >> 8) & 0xff;

  int gx = my_pod_x*bsg_tiles_X + __bsg_x;
  int gy = my_pod_y*bsg_tiles_Y + __bsg_y;

  if (__bsg_id == 0) {
    bsg_hw_barrier_config_init(barcfg, GRID_X, GRID_Y);
  }
  bsg_fence();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);

  int my_barcfg = barcfg[gy*GRID_X + gx];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (my_barcfg));

  const int late_x[4] = {0, GRID_X-1, GRID_X-1, 0};
  const int late_y[4] = {0, GRID_Y-1, 0, GRID_Y-1};
  int failures = 0;

  for (int iteration = 1; iteration <= ITERATIONS; iteration++) {
    int lx = late_x[iteration % 4];
    int ly = late_y[iteration % 4];
    if (gx == lx && gy == ly) {
      for (volatile int delay = 0; delay < DELAY; delay++) { }
    }

    arrived = iteration;
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    if (grid_load(lx, ly, &arrived) != iteration) failures++;
    if (grid_load(GRID_X-1-gx, GRID_Y-1-gy, &arrived) != iteration) failures++;

    // Keep the next iteration from overwriting arrived before everyone reads it.
    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }

  if (failures != 0) {
    bsg_fail();
  }

  // All checks are done once this barrier completes.
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  if (__bsg_id == 0) {
    bsg_finish();
  }
  bsg_wait_while(1);
}
