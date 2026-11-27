// Two tiles run Dekker's handshake: each sets its own flag with an AMO and then loads the other
// tile's flag. amoswap.w.aq orders the load after the AMO, so the tiles can never both load 0.
//
// Plain amoswap.w does not order them. It is tried first, over flags in different vcaches and
// over different delays between the tiles, to find where the two can race on this machine.
// Those cases are then repeated with amoswap.w.aq.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define PARTNER_X  2
#define PARTNER_Y  1
#define NUM_LINES  8     // one flag per cache line
#define NUM_DELAYS 24    // MAX_DELAY in dekker.S

enum { PLAIN, AQ1, AQ2, NUM_VARIANTS };

typedef int (*main_f)(volatile int *go, int *mine, int *other);
typedef int (*partner_f)(volatile int *go, int *mine, int *other, int delay);
int dekker_main_plain(volatile int*, int*, int*);
int dekker_main_aq1(volatile int*, int*, int*);
int dekker_main_aq2(volatile int*, int*, int*);
int dekker_partner_plain(volatile int*, int*, int*, int);
int dekker_partner_aq1(volatile int*, int*, int*, int);
int dekker_partner_aq2(volatile int*, int*, int*, int);

int flags[NUM_LINES*VCACHE_BLOCK_SIZE_WORDS]
  __attribute__ ((section (".dram"), aligned (4*VCACHE_BLOCK_SIZE_WORDS)));

// written by the main tile into the partner's copy
volatile int job_valid, job_variant, job_delay, go;
int * volatile job_mine;
int * volatile job_other;
// written by the partner into the main tile's copy
volatile int ready, partner_loaded;

void partner()
{
  const partner_f f[NUM_VARIANTS] = {dekker_partner_plain, dekker_partner_aq1, dekker_partner_aq2};
  while (1) {
    bsg_wait_while(!job_valid);
    job_valid = 0;
    go = 0;
    partner_f run = f[job_variant];
    int *mine = job_mine;
    int *other = job_other;
    int delay = job_delay;
    bsg_remote_store(0, 0, &ready, 1);
    int loaded = run(&go, mine, other, delay);
    bsg_fence();   // the AMO has returned before the next case starts
    bsg_remote_store(0, 0, &partner_loaded, loaded);
  }
}

// returns 1 if both tiles loaded 0
int both_zero(int variant, int *mine, int *other, int delay)
{
  const main_f f[NUM_VARIANTS] = {dekker_main_plain, dekker_main_aq1, dekker_main_aq2};
  *mine = 0;
  *other = 0;
  bsg_fence();   // both flags are 0 in memory before the tiles start
  ready = 0;
  partner_loaded = -1;
  bsg_remote_store(PARTNER_X, PARTNER_Y, &job_mine, other);
  bsg_remote_store(PARTNER_X, PARTNER_Y, &job_other, mine);
  bsg_remote_store(PARTNER_X, PARTNER_Y, &job_delay, delay);
  bsg_remote_store(PARTNER_X, PARTNER_Y, &job_variant, variant);
  bsg_remote_store(PARTNER_X, PARTNER_Y, &job_valid, 1);
  bsg_wait_while(!ready);
  int loaded = f[variant](bsg_remote_ptr(PARTNER_X, PARTNER_Y, &go), mine, other);
  bsg_wait_while(partner_loaded < 0);
  return (loaded == 0) && (partner_loaded == 0);
}

int main()
{
  bsg_set_tile_x_y();
  if ((__bsg_x == PARTNER_X) && (__bsg_y == PARTNER_Y)) partner();
  if (__bsg_id != 0) bsg_wait_while(1);

  int races = 0;
  int bad = 0;
  for (int i = 0; i < NUM_LINES; i++) {
    for (int j = 0; j < NUM_LINES; j++) {
      if (i == j) continue;
      int *mine = &flags[i*VCACHE_BLOCK_SIZE_WORDS];
      int *other = &flags[j*VCACHE_BLOCK_SIZE_WORDS];
      for (int delay = 0; delay < NUM_DELAYS; delay++) {
        if (!both_zero(PLAIN, mine, other, delay)) continue;
        races++;
        bad += both_zero(AQ1, mine, other, delay);
        bad += both_zero(AQ2, mine, other, delay);
      }
    }
  }

  // number of cases where plain amoswap.w raced; 0 means this machine cannot show the bug.
  bsg_print_int(races);
  if (bad) bsg_fail();
  bsg_finish();
}
