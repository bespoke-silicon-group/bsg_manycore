// Exercise cache block management using ordinary loads and stores only.
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BW VCACHE_BLOCK_SIZE_WORDS
#define BLOCKS 32

int buf[BLOCKS*BW] __attribute__((section(".dram"), aligned(VCACHE_BLOCK_SIZE_BYTES)));
volatile int local_word = 0x12345678;
volatile unsigned ticks;
volatile int command, done;

static void check(int id, int got, int expected)
{
  if (got != expected) {
    bsg_print_int(id);
    bsg_print_hexadecimal(got);
    bsg_print_hexadecimal(expected);
    bsg_fail();
  }
}

// A second tile supplies a software clock: vanilla has no cycle CSR. It later
// uses the very same DRAM block, so both tiles necessarily target one vcache.
static void partner(void)
{
  while (!command) ticks++;
  volatile int *p = buf;
  for (int i = 1; i <= 16; i++) {
    bsg_wait_while(command != i);
    check(40, p[0], 0x6000 + i);
    p[0] = 0x7000 + i;
    bsg_cbo_clean_block((void *)p);
    p[0] = -1;
    bsg_cbo_inv_block((void *)p);
    check(41, p[0], 0x7000 + i);
    bsg_cbo_flush_block((void *)p);
    bsg_fence();
    bsg_remote_store(0, 0, &done, i);
  }
  bsg_wait_while(1);
}

static void noops(int id, void *p)
{
  bsg_print_int(id);
  // More than the forward FIFO's request slots, with no intervening data
  // memory access to accidentally conceal a missing slot restoration.
  __asm__ volatile (
    ".rept 16\n\t.insn i 0x0f, 2, x0, %0, 0\n\t.endr\n\t"
    ".rept 16\n\t.insn i 0x0f, 2, x0, %0, 1\n\t.endr\n\t"
    ".rept 16\n\t.insn i 0x0f, 2, x0, %0, 2\n\t.endr"
    : : "r"(p) : "memory");
  bsg_fence();
  check(id, local_word, 0x12345678);
}

// Blocks 4-11 hold 0x5000 + i in word 0 after test 20. Timing a dependent load
// from each of them multiplies the hit/miss difference, which keeps the clean vs
// flush comparison well clear of timing noise.
#define TIMED_FIRST 4
#define TIMED_BLOCKS 8

// Measure dependent loads of the timed blocks against the other tile's counter.
// Fences keep the counter reads on either side of the loads and their credits.
static unsigned load_ticks(void)
{
  volatile int *v = buf;
  volatile unsigned *clock = (volatile unsigned *)bsg_remote_ptr(1, 0, &ticks);
  unsigned start = *clock;
  __asm__ volatile ("add x0, %0, x0" : : "r"(start));
  bsg_fence();
  for (int i = TIMED_FIRST; i < TIMED_FIRST + TIMED_BLOCKS; i++)
    check(30, v[i*BW], 0x5000 + i);
  bsg_fence();
  return *clock - start;
}

int main(void)
{
  bsg_set_tile_x_y();
  if (bsg_id == 1) partner();
  if (bsg_id != 0) bsg_wait_while(1);

  volatile int *a = buf, *b = &buf[BW], *c = &buf[2*BW];

  // 1. Clean writes back; invalidate discards a later dirty value.
  a[0] = 0x11111111;
  bsg_cbo_clean_block((void *)a);
  a[0] = 0x22222222;
  bsg_cbo_inv_block((void *)a);
  check(1, a[0], 0x11111111);

  // 2. Invalidate does not write back, including a partially dirty block.
  b[0] = 0x33333333;
  bsg_cbo_flush_block((void *)b);
  b[0] = 0x3a3a3a3a;
  b[1] = 0x3b3b3b3b;
  bsg_cbo_inv_block((void *)b);
  check(2, b[0], 0x33333333);

  // 3. Flush writes back both ends of the block.
  c[0] = 0x44444444;
  c[BW-1] = 0x4f4f4f4f;
  bsg_cbo_flush_block((void *)c);
  c[0] = 0x55555555;
  bsg_cbo_inv_block((void *)c);
  check(3, c[0], 0x44444444);
  check(3, c[BW-1], 0x4f4f4f4f);

  // 4-6. rs1 is the last byte, and the encoded operation is not an offset.
  // The neighbouring block must keep its dirty value throughout.
  void *last = (char *)&buf[BW] - 1;
  b[0] = 0x22222222;
  a[0] = 0x12345678;
  bsg_cbo_flush_block(last);
  bsg_cbo_inv_block((void *)a);
  check(4, a[0], 0x12345678);
  a[0] = 0x23456789;
  bsg_cbo_clean_block(last);
  a[0] = -1;
  bsg_cbo_inv_block(last);
  check(5, a[0], 0x23456789);
  check(6, b[0], 0x22222222);

  noops(10, (void *)&local_word);
  noops(11, (void *)bsg_remote_ptr(0, 0, &local_word));
  noops(12, (void *)bsg_global_pod_ptr(0, 0, 0, 0, &local_word));
  noops(13, (void *)bsg_remote_ptr_io(IO_X_INDEX, 0xEAD8));
  noops(14, (void *)0x10000000);
  noops(15, (void *)bsg_global_ptr(bsg_global_X, bsg_global_Y-1, 0));
  noops(16, (void *)0);

  // 20. Many requests exceed both the issue slots and network credit limit.
  for (int i = 4; i < BLOCKS; i++) {
    buf[i*BW] = 0x5000 + i;
    bsg_cbo_clean_block(&buf[i*BW]);
    buf[i*BW] = -i;
  }
  for (int i = 4; i < BLOCKS; i++) bsg_cbo_inv_block(&buf[i*BW]);
  bsg_fence();
  for (int i = 4; i < BLOCKS; i++) check(20, buf[i*BW], 0x5000 + i);

  // 21. Stores immediately before and after invalidation on the same block.
  __asm__ volatile ("sw %1, 0(%0)\n\t.insn i 0x0f, 2, x0, %0, 0\n\tsw %2, 0(%0)"
                    : : "r"(a), "r"(0x1234), "r"(0x5678) : "memory");
  check(21, a[0], 0x5678);

  // 30-31. Clean retains hot blocks, while flush invalidates them. Their data
  // results alone are identical, so compare the time to reload the timed blocks.
  // Discard a warm-up iteration and use minima to exclude instruction misses.
  // With this repository's toolchain, clean_min and flush_min are 25 and 46
  // ticks on pod_1x1_4X2Y and 29 and 52 on pod_1x1. A clean that invalidates,
  // or a flush that does not, makes them equal to within a tick, so require a
  // tick per timed block.
  unsigned clean_min = ~0u, flush_min = ~0u;
  for (int i = 0; i < 17; i++) {
    load_ticks();  // make the timed blocks resident again after the last flush
    for (int j = TIMED_FIRST; j < TIMED_FIRST + TIMED_BLOCKS; j++)
      bsg_cbo_clean_block(&buf[j*BW]);
    bsg_fence();
    unsigned clean = load_ticks();
    for (int j = TIMED_FIRST; j < TIMED_FIRST + TIMED_BLOCKS; j++)
      bsg_cbo_flush_block(&buf[j*BW]);
    bsg_fence();
    unsigned flush = load_ticks();
    if (i && clean < clean_min) clean_min = clean;
    if (i && flush < flush_min) flush_min = flush;
  }
  bsg_print_int(31);
  bsg_print_unsigned(clean_min);
  bsg_print_unsigned(flush_min);
  check(31, clean_min + TIMED_BLOCKS < flush_min, 1);

  // 40-42. Each tile takes turns managing the same block at the same vcache.
  // Publishing the handoff only after a fence checks completion across tiles.
  for (int i = 1; i <= 16; i++) {
    a[0] = 0x6000 + i;
    bsg_cbo_flush_block((void *)a);
    bsg_fence();
    bsg_remote_store(1, 0, &command, i);
    bsg_wait_while(done != i);
    bsg_cbo_inv_block((void *)a);
    check(42, a[0], 0x7000 + i);
  }
  bsg_fence();
  bsg_finish();
  bsg_wait_while(1);
}
