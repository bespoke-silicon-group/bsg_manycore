// STREAM write bandwidth test

#include "bsg_manycore.h"
#include "bsg_barrier.h"
#include "bsg_set_tile_x_y.h"

// Base of data_ptr pointer
#define DRAM_BASE (0x81000000)
// Offset for each tile to start at a different vcache
#define LINE_OFFSET (4*VCACHE_BLOCK_SIZE_WORDS)
// Offset to alternate 
#define CACHE_OFFSET (4*VCACHE_CAPACITY_WORDS)
// Stride by cache lines == number of caches
// so that we stay in the same cache
#define STRIDE (4*VCACHE_BLOCK_SIZE_WORDS*2*bsg_global_X)

#ifndef DRAM_BASE
#error Must set DRAM_BASE
#endif

#ifndef ITERATIONS
#error Must set ITERATIONS
#endif

#ifndef STREAM_SIZE_MB
#error Must set STREAM_SIZE_MB
#endif

#define STREAM_SIZE (STREAM_SIZE_MB * 1024 * 1024)
#define STREAM_LINES (STREAM_SIZE / VCACHE_BLOCK_SIZE_WORDS / 4)
#define STREAM_MAX (DRAM_BASE + STREAM_SIZE)

bsg_barrier sync_barrier = BSG_BARRIER_INIT(0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int main()
{
  // set tiles
  bsg_set_tile_x_y();

  int top_not_bottom, bytes_written, bytes_read;
  int *data_ptr;

  bsg_fence();
  bsg_barrier_wait(&sync_barrier, 0, 0);

  if (__bsg_id == 0) {
    bsg_printf("########### STARTING WRITE BANDWIDTH TEST ############\n");
    bsg_print_time();
    bsg_printf("###################################\n");
  }

  for (int i = 1; i <= ITERATIONS; i++) {
    top_not_bottom = (__bsg_y < bsg_tiles_Y) ? 1 : 0;
    data_ptr = (int *)(DRAM_BASE + __bsg_x*LINE_OFFSET + top_not_bottom*CACHE_OFFSET);
    bsg_unroll(16)
    while (data_ptr < (int *)STREAM_MAX) {
      asm volatile ("sw x0, 0(%[data_ptr])" : : [data_ptr] "r" (data_ptr));
      data_ptr = data_ptr + STRIDE;
    }
    bsg_fence();
    bsg_barrier_wait( &sync_barrier, 0, 0);
    if (__bsg_id == 0) {
      bsg_printf("##### %d/%d #####\n", i, ITERATIONS);
    }
  }

  if (__bsg_id == 0) {
    bsg_printf("########### FINISHED WRITE BANDWIDTH TEST ############\n");
    bsg_print_time();
    bsg_printf("###################################\n");

    bytes_written = bsg_tiles_X * bsg_tiles_Y * STREAM_LINES * VCACHE_BLOCK_SIZE_WORDS * 4;
    bytes_read    = bsg_tiles_X * bsg_tiles_Y * STREAM_LINES * VCACHE_BLOCK_SIZE_WORDS * 4;
    bsg_printf("kBytes written: %d kBytes read: %d\n", bytes_written/1024, bytes_read/1024);
  }

  bsg_fence();
  bsg_barrier_wait(&sync_barrier, 0, 0);

  if (__bsg_id == 0) {
    bsg_printf("########### STARTING READ BANDWIDTH TEST ############\n");
    bsg_print_time();
    bsg_printf("###################################\n");
  }

  top_not_bottom = (__bsg_y < bsg_tiles_Y) ? 1 : 0;
  data_ptr = (int *)(DRAM_BASE + __bsg_x*LINE_OFFSET + top_not_bottom*CACHE_OFFSET);
  for (int i = 1; i <= ITERATIONS; i++) {
    bsg_unroll(16)
    while (data_ptr < (int *)STREAM_MAX) {
      asm volatile ("lw x0, 0(%[data_ptr])" : : [data_ptr] "r" (data_ptr));
      data_ptr = data_ptr + STRIDE;
    }
    bsg_fence();
    bsg_barrier_wait(&sync_barrier, 0, 0);
    if (__bsg_id == 0) {
      bsg_printf("##### %d/%d #####\n", i, ITERATIONS);
    }
  }

  if (__bsg_id == 0) {
    bsg_printf("########### FINISHED READ BANDWIDTH TEST ############\n");
    bsg_print_time();
    bsg_printf("###################################\n");

    bsg_printf("%x %x %x %x\n", bsg_tiles_X, bsg_tiles_Y, STREAM_LINES, VCACHE_BLOCK_SIZE_WORDS);
    bytes_read    = bsg_tiles_X * bsg_tiles_Y * STREAM_LINES * VCACHE_BLOCK_SIZE_WORDS * 4;
    bsg_printf("kBytes read: %d\n", bytes_read/1024);
  }

  if (__bsg_id == 0) {
    bsg_finish();
  }

  bsg_wait_while(1);
}



