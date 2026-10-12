#ifndef __KERNEL_HPP
#define __KERNEL_HPP

// This file defines N number of mostly identical kernels (up to 16 currently)
// These kernels will
// - print hello from a tile
// - process an input buffer of size N by adding 100*its kernel id
// - sync using a global AMOADD, waiting for all K kernels to reach

#define MAKE_KERNEL_DEF(x) kernel##x
#define KERNEL_DEF(x) \
  extern "C" __attribute__ ((noinline))                                               \
  int MAKE_KERNEL_DEF(x)(int *buffer, int n, int *sync, int k) {                      \
  bsg_printf("Hello from kernel %d -- Tile X: %d Tile Y: %d\n", x, __bsg_x, __bsg_y); \
                                                                                      \
  for (int i = 0; i < n; i++) {                                                       \
      buffer[x*n+i] += 100*(x+1);                                                     \
      bsg_printf("kernel %d Process[%d]: %d\n", x, i, buffer[x*n+i]);                 \
  }                                                                                   \
                                                                                      \
  volatile int *sync_ptr = sync;                                                      \
  int sync_val;                                                                       \
  bsg_printf("[kernel %d] Trying to sync to EVA: %x", x, sync);                       \
  bsg_amoadd(sync, 1);                                                                \
  while ((sync_val = *sync_ptr) < k) {                                                \
     bsg_printf("[kernel %d] Waiting for sync_ptr == %d (%d)", x, k, sync_val);       \
  }                                                                                   \
                                                                                      \
  return 0;                                                                           \
}

#endif

