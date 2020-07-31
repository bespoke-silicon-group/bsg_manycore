// Kernel to estimate DRAM latency

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>
#include <stddef.h>

const size_t VCACHE_NUM_BLOCKS = VCACHE_SET * VCACHE_WAY;
const size_t VCACHE_SIZE_WORDS = VCACHE_NUM_BLOCKS * VCACHE_BLOCK_SIZE_WORDS;

const size_t NUM_BANKS = 2 * bsg_tiles_Y;

const uint32_t DRAM_START_ADDR = 0x80000000;

// Returns the eva we should write to given the index in
// the Vcache.
//
// Inverse of bsg_manycore/v/vanilla_bean/hash_function.v
// Based on bsg_manycore/v/vanilla_bean/hash_function_reverse.v
uint32_t vcache_inverse_hash_function(size_t block_index,
                                      size_t bank) {
  return 0x80000000;
}

// Issues a load to given vcache block index and bank
inline void load_vcache_index(size_t i, size_t bank) {
  uint32_t eva = vcache_inverse_hash_function(i, bank);

  int dummy;
  asm volatile (
      "lw %0, 0(%1)"
      : "=r" (dummy)
      : "r" (eva));
}

// Flushes the vcache associated with a given bank
void flush_vcache(size_t bank) {
  // Distribute vcache block indices among all tiles
  size_t len_per_tile = VCACHE_SIZE_WORDS / (bsg_tiles_X * bsg_tiles_Y) + 1;
  size_t start = __bsg_id * len_per_tile;
  size_t end = start + len_per_tile;
  end = (end > VCACHE_SIZE_WORDS) ? VCACHE_SIZE_WORDS : end;

  // Issue load to each block index
  for(size_t i = start; i < end; ++i)
    load_vcache_index(i, bank);
}

extern "C" __attribute__ ((noinline))
int kernel_dram_latency(int dummy) {
  // Flush vcahe associated with bank 0
  flush_vcache(0);

  // Opens a new page assuming vcache size would be
  // a page boundary.
  load_vcache_index(VCACHE_NUM_BLOCKS, 0);

  bsg_cuda_print_stat_kernel_start();
  size_t offset = VCACHE_NUM_BLOCKS + 1;
  // Issue loads to 64 blocks in the opened page
  for(size_t i = offset; i < offset + 64; ++i)
    load_vcache_index(i, 0);
  bsg_cuda_print_stat_kernel_end();

  return 0;
}
